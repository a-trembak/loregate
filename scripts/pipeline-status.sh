#!/usr/bin/env bash
# Pipeline orientation resolver: derive where-am-I from gates + session ledger.
# Sourceable library (defines helpers only) + CLI:
#   pipeline-status.sh [--root <dir>]
#   pipeline-status.sh --json [--root <dir>]
#   pipeline-status.sh --canvas-url [--root <dir>] [--kit-root <dir>]
#   source scripts/pipeline-status.sh   # functions only; no record printed

ps__script_dir() {
  local src="${BASH_SOURCE[0]}"
  cd "$(dirname "$src")" && pwd
}

# shellcheck source=pipeline-gates.sh
source "$(ps__script_dir)/pipeline-gates.sh"

# --- Collect pending human gates (plan/critique/review/docs) ---
ps__collect_pending() {
  local kind slug plan_path
  for kind in plan-gate critique-gate review-gate docs-gate; do
    while IFS=$'\t' read -r slug plan_path; do
      [[ -n "${slug:-}" ]] || continue
      printf '%s\t%s\t%s\n' "$kind" "$slug" "$plan_path"
    done < <(pg_list_gates "$PS_ROOT" "$kind")
  done
}

# Precedence for current stage/layer when several pending: docs > review > critique > plan
ps__pick_pending_kind() {
  local line kind
  local has_docs=0 has_review=0 has_critique=0 has_plan=0
  while IFS=$'\t' read -r kind _ _; do
    [[ -n "${kind:-}" ]] || continue
    case "$kind" in
      docs-gate) has_docs=1 ;;
      review-gate) has_review=1 ;;
      critique-gate) has_critique=1 ;;
      plan-gate) has_plan=1 ;;
    esac
  done < <(ps__collect_pending)
  if [[ "$has_docs" -eq 1 ]]; then
    printf '%s' "docs-gate"
  elif [[ "$has_review" -eq 1 ]]; then
    printf '%s' "review-gate"
  elif [[ "$has_critique" -eq 1 ]]; then
    printf '%s' "critique-gate"
  elif [[ "$has_plan" -eq 1 ]]; then
    printf '%s' "plan-gate"
  else
    return 1
  fi
}

ps__find_ledger() {
  local base dir
  base="$(pg_gates_base "$PS_ROOT" 2>/dev/null)" || base="$PS_ROOT/.cursor/gates"
  dir="$base/trajectory-run"
  if [[ -f "$dir/session-full.json" ]]; then
    printf '%s' "$dir/session-full.json"
    return 0
  fi
  if [[ -f "$dir/session-fast.json" ]]; then
    printf '%s' "$dir/session-fast.json"
    return 0
  fi
  if [[ -f "$dir/session-issue.json" ]]; then
    printf '%s' "$dir/session-issue.json"
    return 0
  fi
  # Sticky primary ledger when writes moved to fallback
  dir="$PS_ROOT/.cursor/gates/trajectory-run"
  if [[ -f "$dir/session-full.json" ]]; then
    printf '%s' "$dir/session-full.json"
    return 0
  fi
  if [[ -f "$dir/session-fast.json" ]]; then
    printf '%s' "$dir/session-fast.json"
    return 0
  fi
  if [[ -f "$dir/session-issue.json" ]]; then
    printf '%s' "$dir/session-issue.json"
    return 0
  fi
  return 1
}

ps__route_from_ledger() {
  local path="$1" base
  base="$(basename "$path")"
  case "$base" in
    session-full.json) printf '%s' "full" ;;
    session-fast.json) printf '%s' "fast" ;;
    session-issue.json) printf '%s' "issue" ;;
    *) printf '%s' "unknown" ;;
  esac
}

ps__layer_for_stage() {
  local stage="$1"
  case "$stage" in
    idle|"")
      printf '%s' "idle"
      ;;
    jira-fetch|jira-transition-in-progress|jira-transition|pipeline-route-hitl|fetch)
      printf '%s' "fetch"
      ;;
    bootstrap|csp-tech-spec|writing-plans|approve-plan|csp-implementation-critic|plan-gate|critique-gate|clean-decision-docs|issue-fix-plan)
      printf '%s' "plan"
      ;;
    start-build|csp-software-developer|csp-bug-fixer|executing-plans)
      printf '%s' "build"
      ;;
    review-gate|engineer-review|csp-engineer-reviewer|csp-multi-repo-supervisor)
      printf '%s' "review"
      ;;
    update-docs|create-pr|docs-gate|pipeline-finale-hitl)
      printf '%s' "ship"
      ;;
    *)
      # Heuristic fallbacks for gate-shaped or unknown stage ids
      case "$stage" in
        *review*) printf '%s' "review" ;;
        *docs*|*pr*) printf '%s' "ship" ;;
        *plan*|*spec*|*critic*) printf '%s' "plan" ;;
        *build*|*developer*|*fixer*) printf '%s' "build" ;;
        *fetch*|*route*|*jira*) printf '%s' "fetch" ;;
        *) printf '%s' "idle" ;;
      esac
      ;;
  esac
}

ps__legal_returns_json() {
  local stage="$1"
  case "$stage" in
    review-gate)
      printf '%s' '[{"from":"review-gate","to":"Build/csp-software-developer","how":"Answer fixes at the gate"}]'
      ;;
    critique-gate|csp-implementation-critic)
      printf '%s' '[{"from":"critique","to":"Plan/rewrite or same critic ask","how":"Answer revise or accept F<id>"}]'
      ;;
    plan-gate|approve-plan)
      printf '%s' '[{"from":"approve-plan","to":"Plan","how":"Answer revise"}]'
      ;;
    tech-spec)
      printf '%s' '[{"from":"csp-tech-spec","to":"Plan","how":"Answer revise"}]'
      ;;
    docs-gate|update-docs)
      printf '%s' '[{"from":"docs","to":"Docs","how":"Provide path/URL"}]'
      ;;
    engineer-review|csp-engineer-reviewer)
      printf '%s' '[{"from":"engineer-review","to":"Review","how":"Answer clarify tokens"}]'
      ;;
    *)
      printf '%s' '[]'
      ;;
  esac
}

ps__json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

# Same invocation id regex as pipeline-run-log.sh (silent — status omits enrichment on mismatch).
ps__valid_invocation_id() {
  local id="$1"
  [[ "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]
}

# Resolve run-log journal: --invocation → pending plan slug → pointer → omit.
# Sets nothing / returns 1 when omitted. Prints absolute path on success.
ps__resolve_run_log() {
  local first_pending_plan="${1:-}"
  local run_dir
  run_dir="$(pg_gates_base "$PS_ROOT" 2>/dev/null)/run-log"
  if [[ ! -d "$run_dir" ]]; then
    run_dir="$PS_ROOT/.cursor/gates/run-log"
  fi
  local candidate="" id="" ptr line key val
  local ptr_id="" ptr_plan="" ptr_slug="" ptr_journal=""

  if [[ -n "${PS_INVOCATION:-}" ]]; then
    if ! ps__valid_invocation_id "$PS_INVOCATION"; then
      : # omit enrichment for invalid --invocation; do not hard-exit
    else
      candidate="$run_dir/inv-${PS_INVOCATION}.md"
      if [[ -f "$candidate" ]]; then
        printf '%s' "$candidate"
        return 0
      fi
      # inv gone: use pointer slug/journal when same invocation id
      ptr="$run_dir/current-invocation"
      if [[ -f "$ptr" ]]; then
        ptr_id=""
        ptr_plan=""
        ptr_slug=""
        ptr_journal=""
        while IFS= read -r line || [[ -n "$line" ]]; do
          [[ "$line" == *:* ]] || continue
          key="${line%%:*}"
          val="${line#*:}"
          val="${val#"${val%%[![:space:]]*}"}"
          val="${val%"${val##*[![:space:]]}"}"
          case "$key" in
            invocation) ptr_id="$val" ;;
            plan) ptr_plan="$val" ;;
            slug) ptr_slug="$val" ;;
            journal) ptr_journal="$val" ;;
          esac
        done <"$ptr"
        if [[ -n "$ptr_id" ]] && ps__valid_invocation_id "$ptr_id" && [[ "$ptr_id" == "$PS_INVOCATION" ]]; then
          if [[ -n "$ptr_journal" && "$ptr_journal" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.md$ ]]; then
            candidate="$run_dir/$ptr_journal"
            if [[ -f "$candidate" ]]; then
              printf '%s' "$candidate"
              return 0
            fi
          fi
          if [[ -n "$ptr_slug" && "$ptr_slug" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
            candidate="$run_dir/${ptr_slug}.md"
            if [[ -f "$candidate" ]]; then
              printf '%s' "$candidate"
              return 0
            fi
          fi
          if [[ -n "$ptr_plan" ]]; then
            local slug
            slug="$(pg_slug_for_plan "$PS_ROOT" "$ptr_plan")"
            candidate="$run_dir/${slug}.md"
            if [[ -f "$candidate" ]]; then
              printf '%s' "$candidate"
              return 0
            fi
          fi
        fi
      fi
    fi
  fi

  if [[ -n "$first_pending_plan" ]]; then
    local slug
    slug="$(pg_slug_for_plan "$PS_ROOT" "$first_pending_plan")"
    candidate="$run_dir/${slug}.md"
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  fi

  ptr="$run_dir/current-invocation"
  if [[ -f "$ptr" ]]; then
    id=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == invocation:* ]]; then
        id="${line#invocation:}"
        id="${id#"${id%%[![:space:]]*}"}"
        id="${id%"${id##*[![:space:]]}"}"
        break
      fi
    done <"$ptr"
    if [[ -n "$id" ]] && ps__valid_invocation_id "$id"; then
      candidate="$run_dir/inv-${id}.md"
      if [[ -f "$candidate" ]]; then
        printf '%s' "$candidate"
        return 0
      fi
      # Pointer may already list slug/journal after promote (no inv file).
      ptr_id=""
      ptr_plan=""
      ptr_slug=""
      ptr_journal=""
      while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == *:* ]] || continue
        key="${line%%:*}"
        val="${line#*:}"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        case "$key" in
          invocation) ptr_id="$val" ;;
          plan) ptr_plan="$val" ;;
          slug) ptr_slug="$val" ;;
          journal) ptr_journal="$val" ;;
        esac
      done <"$ptr"
      if [[ -n "$ptr_journal" && "$ptr_journal" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.md$ ]]; then
        candidate="$run_dir/$ptr_journal"
        if [[ -f "$candidate" ]]; then
          printf '%s' "$candidate"
          return 0
        fi
      fi
      if [[ -n "$ptr_slug" && "$ptr_slug" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
        candidate="$run_dir/${ptr_slug}.md"
        if [[ -f "$candidate" ]]; then
          printf '%s' "$candidate"
          return 0
        fi
      fi
      if [[ -n "$ptr_plan" ]]; then
        local slug2
        slug2="$(pg_slug_for_plan "$PS_ROOT" "$ptr_plan")"
        candidate="$run_dir/${slug2}.md"
        if [[ -f "$candidate" ]]; then
          printf '%s' "$candidate"
          return 0
        fi
      fi
    fi
  fi

  return 1
}

ps__run_log_tail_json() {
  local path="$1" n="${2:-5}"
  python3 -c '
import json, sys
path, n = sys.argv[1], int(sys.argv[2])
try:
    lines = open(path, encoding="utf-8").read().splitlines()
except OSError:
    print("[]")
    raise SystemExit(0)
body = [ln for ln in lines if ln.startswith("- ")]
print(json.dumps(body[-n:] if n > 0 else body))
' "$path" "$n"
}

ps__build_record() {
  local pending_kind="" stage layer route="unknown" ledger_path="" critique_clear="false"
  local stages_json="[]" pending_json="[]" legal_json="[]"
  local canvas_path="docs/superpowers/pipeline-flow.html"
  local canvas_hash="" canvas_query=""
  local kind slug plan_path first_pending_plan=""

  if ledger_path="$(ps__find_ledger)"; then
    route="$(ps__route_from_ledger "$ledger_path")"
    stages_json="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps(d.get("stages_entered") or []))' "$ledger_path")"
  else
    ledger_path=""
  fi

  # pending_gates array + first plan path for the precedence-winning pending kind
  pending_json="$(
    {
      echo '['
      local first=1
      while IFS=$'\t' read -r kind slug plan_path; do
        [[ -n "${kind:-}" ]] || continue
        if [[ "$first" -eq 1 ]]; then
          first=0
        else
          printf ','
        fi
        printf '{"kind":%s,"slug":%s,"plan_path":%s}' \
          "$(ps__json_escape "$kind")" \
          "$(ps__json_escape "$slug")" \
          "$(ps__json_escape "$plan_path")"
      done < <(ps__collect_pending)
      echo ']'
    }
  )"

  if pending_kind="$(ps__pick_pending_kind)"; then
    stage="$pending_kind"
    while IFS=$'\t' read -r kind slug plan_path; do
      [[ -n "${kind:-}" ]] || continue
      if [[ "$kind" == "$pending_kind" ]]; then
        first_pending_plan="$plan_path"
        break
      fi
    done < <(ps__collect_pending)
  elif [[ -n "$ledger_path" ]]; then
    stage="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); s=d.get("stages_entered") or []; print(s[-1] if s else "idle")' "$ledger_path")"
  else
    stage="idle"
  fi
  [[ -n "$stage" ]] || stage="idle"
  layer="$(ps__layer_for_stage "$stage")"

  # critique_clear: plan-critique-clear for the active pending plan path when known
  if [[ -n "$first_pending_plan" ]] && \
     pg__find_gate_for_plan "$PS_ROOT" "plan-critique-clear" "$first_pending_plan" >/dev/null 2>&1; then
    critique_clear="true"
  else
    critique_clear="false"
  fi

  legal_json="$(ps__legal_returns_json "$stage")"

  canvas_query="route=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$route")"
  canvas_query+="&layer=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$layer")"
  canvas_query+="&stage=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$stage")"
  if [[ "$stage" != "idle" ]]; then
    canvas_hash="#$stage"
  fi

  local ledger_json="null"
  if [[ -n "$ledger_path" ]]; then
    # Prefer path relative to project root when under PS_ROOT
    local rel="$ledger_path"
    if [[ "$ledger_path" == "$PS_ROOT/"* ]]; then
      rel="${ledger_path#"$PS_ROOT"/}"
    fi
    ledger_json="$(ps__json_escape "$rel")"
  fi

  local run_log_abs="" run_log_rel_json="null" run_log_tail_json="[]"
  if run_log_abs="$(ps__resolve_run_log "$first_pending_plan")"; then
    local rel_rl="$run_log_abs"
    if [[ "$run_log_abs" == "$PS_ROOT/"* ]]; then
      rel_rl="${run_log_abs#"$PS_ROOT"/}"
    fi
    run_log_rel_json="$(ps__json_escape "$rel_rl")"
    run_log_tail_json="$(ps__run_log_tail_json "$run_log_abs" 5)"
  fi

  python3 - "$route" "$layer" "$stage" "$pending_json" "$critique_clear" "$ledger_json" "$stages_json" "$legal_json" "$canvas_path" "$canvas_hash" "$canvas_query" "$run_log_rel_json" "$run_log_tail_json" <<'PY'
import json, sys
route, layer, stage = sys.argv[1], sys.argv[2], sys.argv[3]
pending = json.loads(sys.argv[4])
critique_clear = sys.argv[5] == "true"
ledger_raw = sys.argv[6]
ledger_path = None if ledger_raw == "null" else json.loads(ledger_raw)
stages = json.loads(sys.argv[7])
legal = json.loads(sys.argv[8])
canvas_path, canvas_hash, canvas_query = sys.argv[9], sys.argv[10], sys.argv[11]
run_log_raw = sys.argv[12]
run_log_path = None if run_log_raw == "null" else json.loads(run_log_raw)
run_log_tail = json.loads(sys.argv[13])
rec = {
  "route": route,
  "layer": layer,
  "stage": stage,
  "pending_gates": pending,
  "critique_clear": critique_clear,
  "ledger_path": ledger_path,
  "stages_entered": stages,
  "legal_returns": legal,
  "canvas": {
    "path": canvas_path,
    "hash": canvas_hash,
    "query": canvas_query,
  },
  "run_log_path": run_log_path,
  "run_log_tail": run_log_tail,
}
print(json.dumps(rec, ensure_ascii=False))
PY
}

# Resolve an absolute HTML path Cursor can open (workspace / ~/.cursor / kit).
# Prefer consumer project copy so chat file links stay inside the agent workspace.
# Chat markdown must use this bare path — never append ?query#hash (File not found).
ps__resolve_canvas_file() {
  local kit="$1"
  local rel="docs/superpowers/pipeline-flow.html"
  local cand resolved
  for cand in \
    "$PS_ROOT/$rel" \
    "${HOME}/.cursor/pipeline-canvases/pipeline-flow.html" \
    "$kit/$rel"
  do
    if [[ -e "$cand" ]]; then
      # Prefer the workspace/consumer path as written (keep symlink path under PS_ROOT
      # so Cursor opens a file inside the agent workspace, not only the kit realpath).
      if [[ "$cand" == "$PS_ROOT/"* ]]; then
        printf '%s\n' "$cand"
        return 0
      fi
      resolved="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$cand" 2>/dev/null || printf '%s' "$cand")"
      printf '%s\n' "$resolved"
      return 0
    fi
  done
  printf '%s\n' "$kit/$rel"
  return 0
}

ps__print_text() {
  local json="$1"
  local kit="$2"
  local canvas_file
  canvas_file="$(ps__resolve_canvas_file "$kit")"
  python3 - "$json" "$canvas_file" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
canvas_file = sys.argv[2]
route = d.get("route") or "unknown"
layer = d.get("layer") or "idle"
stage = d.get("stage") or "idle"
legal = d.get("legal_returns") or []
if legal:
    legal_bits = []
    for item in legal:
        to = item.get("to") or ""
        how = item.get("how") or ""
        if how:
            legal_bits.append(f"{to} ({how})")
        else:
            legal_bits.append(to)
    legal_s = "; ".join(legal_bits)
else:
    legal_s = "none — happy path only"
canvas = d.get("canvas") or {}
query = canvas.get("query") or ""
hash_ = canvas.get("hash") or ""
# Bare filesystem path only — Cursor chat treats ?query#hash as part of the
# filename and fails with File not found. Highlight params go on the next line.
print(f"Route: {route} · Layer: {layer} · Stage: {stage}")
# Next stages hint from legal + stage family (kept short)
next_map = {
  "review-gate": "engineer-review → update-docs → create-pr",
  "docs-gate": "create-pr",
  "critique-gate": "start-build → software-developer",
  "plan-gate": "implementation-critic → start-build",
  "csp-software-developer": "review-gate → engineer-review",
  "start-build": "software-developer → review-gate",
  "csp-tech-spec": "writing-plans → approve-plan",
  "writing-plans": "approve-plan → implementation-critic",
  "idle": "(none)",
}
nxt = next_map.get(stage, "(see pipeline-flow)")
print(f"Next: {nxt}")
print(f"Legal returns: {legal_s}")
print(f"Canvas: {canvas_file}")
highlight = ""
if query:
    highlight = "?" + query
highlight += hash_
if highlight:
    print(f"Canvas highlight: {highlight}")
tail = d.get("run_log_tail") or []
if tail:
    import re
    last = tail[-1]
    m = re.search(r"note=(.*)$", last)
    note = m.group(1) if m else last
    print(f"Recent: {note}")
PY
}

ps__print_canvas_url() {
  local json="$1" kit="$2"
  local canvas_file
  canvas_file="$(ps__resolve_canvas_file "$kit")"
  python3 - "$json" "$canvas_file" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
canvas_file = sys.argv[2]
canvas = d.get("canvas") or {}
query = canvas.get("query") or ""
hash_ = canvas.get("hash") or ""
# Browser / file URL with orientation params (not for Cursor markdown file links).
full = canvas_file
if query:
    full += "?" + query
full += hash_
print(full)
PY
}

ps__main() {
  local mode="text" kit_root="" record

  # PS_ROOT / PS_INVOCATION are intentionally global: helpers read them.
  PS_ROOT=""
  PS_INVOCATION=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        mode="json"
        shift
        ;;
      --canvas-url)
        mode="canvas-url"
        shift
        ;;
      --root)
        PS_ROOT="${2:?--root requires a directory}"
        shift 2
        ;;
      --invocation)
        PS_INVOCATION="${2:?--invocation requires an id}"
        shift 2
        ;;
      --kit-root)
        kit_root="${2:?--kit-root requires a directory}"
        shift 2
        ;;
      -h|--help)
        cat <<'EOF'
Usage: pipeline-status.sh [--root <dir>] [--kit-root <dir>] [--invocation <id>]
       pipeline-status.sh --json [--root <dir>] [--invocation <id>]
       pipeline-status.sh --canvas-url [--root <dir>] [--kit-root <dir>]
EOF
        exit 0
        ;;
      *)
        echo "pipeline-status: unknown argument: $1" >&2
        exit 2
        ;;
    esac
  done

  if [[ -z "$PS_ROOT" ]]; then
    PS_ROOT="$(pwd)"
  fi
  PS_ROOT="$(cd "$PS_ROOT" && pwd)"

  if [[ -z "$kit_root" ]]; then
    # Prefer sibling of this script (kit or installed copy under project scripts/)
    kit_root="$(cd "$(ps__script_dir)/.." && pwd)"
  fi

  record="$(ps__build_record)"

  case "$mode" in
    json)
      printf '%s\n' "$record"
      ;;
    canvas-url)
      ps__print_canvas_url "$record" "$kit_root"
      ;;
    text)
      ps__print_text "$record" "$kit_root"
      ;;
  esac
}

# CLI entry: when executed (not sourced), parse args and print the orientation record.
# When sourced, only function definitions above remain available.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  ps__main "$@"
fi
