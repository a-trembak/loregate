#!/usr/bin/env bash
# Consumer-project pipeline run-log helper (orientation journal only).
# Usage:
#   pipeline-run-log.sh init|append|promote|read-tail|path|brief-upsert [flags]

prl__script_dir() {
  local src="${BASH_SOURCE[0]}"
  cd "$(dirname "$src")" && pwd
}

# shellcheck source=pipeline-gates.sh
source "$(prl__script_dir)/pipeline-gates.sh"

prl__iso8601() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

prl__validate_invocation() {
  local id="$1"
  if [[ ! "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
    echo "pipeline-run-log: invalid invocation id: $id" >&2
    return 2
  fi
  return 0
}

# Exclusive lock for journal writes. Prefer util-linux `flock` when present;
# otherwise use a portable mkdir lock (macOS ships neither flock nor util-linux).
prl__with_lock() {
  local lockfile="$1"
  shift
  mkdir -p "$(dirname "$lockfile")"

  if command -v flock >/dev/null 2>&1; then
    touch "$lockfile"
    # shellcheck disable=SC2034
    exec 200>"$lockfile"
    if ! flock -x 200; then
      echo "pipeline-run-log: flock failed" >&2
      exec 200>&-
      return 1
    fi
    local rc=0
    "$@" || rc=$?
    flock -u 200 2>/dev/null || true
    exec 200>&-
    return "$rc"
  fi

  local lockdir="${lockfile}.d"
  local lock_parent attempts=0
  lock_parent="$(dirname "$lockfile")"
  while ! mkdir "$lockdir" 2>/dev/null; do
    # Contention: lockdir exists. Permission / other errors: fail fast (do not sleep 200s).
    if [[ ! -d "$lockdir" ]]; then
      echo "pipeline-run-log: cannot create lock ($lockdir)" >&2
      return 1
    fi
    if [[ ! -w "$lock_parent" ]]; then
      echo "pipeline-run-log: lock parent not writable ($lock_parent)" >&2
      return 1
    fi
    attempts=$((attempts + 1))
    if [[ "$attempts" -gt 200 ]]; then
      echo "pipeline-run-log: lock timeout ($lockdir)" >&2
      return 1
    fi
    sleep 1
  done
  local rc=0
  "$@" || rc=$?
  rmdir "$lockdir" 2>/dev/null || true
  return "$rc"
}

prl__normalize_note() {
  python3 -c '
import sys
text = sys.argv[1] if len(sys.argv) > 1 else ""
text = " ".join(text.replace("\r", "\n").split())
if len(text) > 120:
    text = text[:120]
print(text, end="")
' "${1:-}"
}

prl__run_log_dir() {
  local base
  base="$(pg_gates_base "$1" 2>/dev/null)" || base="$1/.cursor/gates"
  printf '%s/run-log' "$base"
}

prl__inv_path() {
  printf '%s/inv-%s.md' "$(prl__run_log_dir "$1")" "$2"
}

prl__slug_path() {
  local root="$1" plan="$2" slug
  slug="$(pg_slug_for_plan "$root" "$plan")"
  printf '%s/%s.md' "$(prl__run_log_dir "$root")" "$slug"
}

prl__pointer_path() {
  printf '%s/current-invocation' "$(prl__run_log_dir "$1")"
}

prl__brief_path() {
  printf '%s/briefs/inv-%s.brief.md' "$(prl__run_log_dir "$1")" "$2"
}

# Write pointer. Optional plan/slug/journal (relative under run-log) after successful promote.
prl__write_pointer() {
  local root="$1" id="$2" plan="${3:-}" slug="${4:-}" journal="${5:-}" ptr
  ptr="$(prl__pointer_path "$root")"
  mkdir -p "$(dirname "$ptr")"
  {
    printf 'invocation: %s\n' "$id"
    if [[ -n "$plan" ]]; then
      printf 'plan: %s\n' "$plan"
    fi
    if [[ -n "$slug" ]]; then
      printf 'slug: %s\n' "$slug"
    fi
    if [[ -n "$journal" ]]; then
      printf 'journal: %s\n' "$journal"
    fi
    printf 'updated: %s\n' "$(prl__iso8601)"
  } >"$ptr"
}

# Read pointer key=value fields into caller variables (names as $2..$5).
# Avoids Bash 4 `local -n` so macOS Bash 3.2 works.
prl__read_pointer() {
  local root="$1"
  local __id_var="$2" __plan_var="$3" __slug_var="$4" __journal_var="$5"
  local ptr line key val _id="" _plan="" _slug="" _journal="" v
  for v in "$__id_var" "$__plan_var" "$__slug_var" "$__journal_var"; do
    [[ "$v" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 2
  done
  eval "$__id_var=\"\""
  eval "$__plan_var=\"\""
  eval "$__slug_var=\"\""
  eval "$__journal_var=\"\""
  ptr="$(prl__pointer_path "$root")"
  [[ -f "$ptr" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *:* ]] || continue
    key="${line%%:*}"
    val="${line#*:}"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    case "$key" in
      invocation) _id="$val" ;;
      plan) _plan="$val" ;;
      slug) _slug="$val" ;;
      journal) _journal="$val" ;;
    esac
  done <"$ptr"
  [[ -n "$_id" ]] || return 1
  prl__validate_invocation "$_id" >/dev/null 2>&1 || return 1
  eval "$__id_var=\"\$_id\""
  eval "$__plan_var=\"\$_plan\""
  eval "$__slug_var=\"\$_slug\""
  eval "$__journal_var=\"\$_journal\""
  return 0
}

# When inv-<id>.md is gone, resolve journal via pointer slug/journal for same id.
prl__journal_from_pointer() {
  local root="$1" want_id="$2"
  local ptr_id="" ptr_plan="" ptr_slug="" ptr_journal="" candidate=""
  prl__read_pointer "$root" ptr_id ptr_plan ptr_slug ptr_journal || return 1
  [[ "$ptr_id" == "$want_id" ]] || return 1

  if [[ -n "$ptr_journal" ]]; then
    # Relative under run-log only — reject path traversal / absolute / slash-bearing names.
    if [[ "$ptr_journal" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.md$ ]]; then
      candidate="$(prl__run_log_dir "$root")/$ptr_journal"
      if [[ -f "$candidate" ]]; then
        printf '%s' "$candidate"
        return 0
      fi
    fi
  fi

  if [[ -n "$ptr_slug" ]]; then
    if [[ "$ptr_slug" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
      candidate="$(prl__run_log_dir "$root")/${ptr_slug}.md"
      if [[ -f "$candidate" ]]; then
        printf '%s' "$candidate"
        return 0
      fi
    fi
  fi

  if [[ -n "$ptr_plan" ]]; then
    candidate="$(prl__slug_path "$root" "$ptr_plan")"
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  fi

  return 1
}

# While inv-<id>.md exists, always use it (even if --plan passed).
# After promote removes inv, resolve via --plan or pointer slug/journal (same id).
prl__resolve_journal() {
  local root="$1" id="${2:-}" plan="${3:-}"
  local inv=""

  if [[ -n "$id" ]]; then
    inv="$(prl__inv_path "$root" "$id")"
    if [[ -f "$inv" ]]; then
      printf '%s' "$inv"
      return 0
    fi
  fi

  if [[ -n "$plan" ]]; then
    printf '%s' "$(prl__slug_path "$root" "$plan")"
    return 0
  fi

  if [[ -n "$id" ]]; then
    local from_ptr=""
    if from_ptr="$(prl__journal_from_pointer "$root" "$id")"; then
      printf '%s' "$from_ptr"
      return 0
    fi
    printf '%s' "$(prl__inv_path "$root" "$id")"
    return 0
  fi

  return 1
}

prl__write_journal_header() {
  local path="$1" id="$2" plan="${3:-}" slug="${4:-}" route="${5:-unknown}" started="${6:-}"
  [[ -n "$started" ]] || started="$(prl__iso8601)"
  {
    printf '# Pipeline run-log\n'
    printf 'invocation: %s\n' "$id"
    if [[ -n "$plan" ]]; then
      printf 'plan: %s\n' "$plan"
    fi
    if [[ -n "$slug" ]]; then
      printf 'slug: %s\n' "$slug"
    fi
    printf 'route: %s\n' "$route"
    printf 'started: %s\n' "$started"
    printf '\n'
  } >"$path"
}

prl__read_header_value() {
  local path="$1" key="$2"
  awk -F': ' -v k="$key" '
    /^# / { next }
    /^$/ { exit }
    /^- / { exit }
    $1 == k { print substr($0, index($0, ": ") + 2); exit }
  ' "$path" 2>/dev/null || true
}

prl__last_body_stage_note() {
  local path="$1"
  python3 -c '
import re, sys
path = sys.argv[1]
try:
    lines = open(path, encoding="utf-8").read().splitlines()
except OSError:
    sys.exit(0)
body = [ln for ln in lines if ln.startswith("- ")]
if not body:
    sys.exit(0)
m = re.search(r"stage=([^|]+)\s*\|\s*note=(.*)$", body[-1])
if m:
    print(m.group(1).strip() + "\t" + m.group(2))
' "$path"
}

prl_cmd_init() {
  local root="" id="" route="unknown" reset=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root) root="${2:?}"; shift 2 ;;
      --invocation) id="${2:?}"; shift 2 ;;
      --route) route="${2:?}"; shift 2 ;;
      --reset) reset=1; shift ;;
      *)
        echo "pipeline-run-log: unknown argument: $1" >&2
        return 2
        ;;
    esac
  done
  [[ -n "$root" && -n "$id" ]] || {
    echo "pipeline-run-log: init requires --root and --invocation" >&2
    return 2
  }
  prl__validate_invocation "$id" || return $?
  root="$(cd "$root" && pwd)"

  local inv dir
  dir="$(prl__run_log_dir "$root")"
  inv="$(prl__inv_path "$root" "$id")"
  mkdir -p "$dir"

  if [[ -f "$inv" && "$reset" -eq 0 ]]; then
    echo "pipeline-run-log: refuse init; journal already exists (pass --reset): $inv" >&2
    return 1
  fi

  prl__with_lock "${inv}.lock" prl__write_journal_header "$inv" "$id" "" "" "$route" || return 1
  prl__write_pointer "$root" "$id"
  return 0
}

# Duplicate stage+note check and write share one lock critical section.
prl__append_locked() {
  local journal="$1" stage="$2" normalized="$3"
  local last stamp last_stage last_note
  last="$(prl__last_body_stage_note "$journal")"
  if [[ -n "$last" ]]; then
    last_stage="${last%%$'\t'*}"
    last_note="${last#*$'\t'}"
    if [[ "$last_stage" == "$stage" && "$last_note" == "$normalized" ]]; then
      return 0
    fi
  fi
  stamp="$(prl__iso8601)"
  printf -- '- %s | stage=%s | note=%s\n' "$stamp" "$stage" "$normalized" >>"$journal"
}

prl_cmd_append() {
  local root="" id="" plan="" stage="" note=""
  local have_note=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root) root="${2:?}"; shift 2 ;;
      --invocation) id="${2:?}"; shift 2 ;;
      --plan) plan="${2:?}"; shift 2 ;;
      --stage) stage="${2:?}"; shift 2 ;;
      --note) note="${2:-}"; have_note=1; shift 2 ;;
      *)
        echo "pipeline-run-log: unknown argument: $1" >&2
        return 2
        ;;
    esac
  done
  [[ -n "$root" && -n "$id" && -n "$stage" && "$have_note" -eq 1 ]] || {
    echo "pipeline-run-log: append requires --root --invocation --stage --note" >&2
    return 2
  }
  prl__validate_invocation "$id" || return $?
  root="$(cd "$root" && pwd)"

  local journal normalized
  journal="$(prl__resolve_journal "$root" "$id" "$plan")"
  if [[ ! -f "$journal" ]]; then
    echo "pipeline-run-log: journal missing: $journal" >&2
    return 1
  fi
  normalized="$(prl__normalize_note "$note")"
  prl__with_lock "${journal}.lock" prl__append_locked "$journal" "$stage" "$normalized"
}

prl__promote_locked() {
  # Expects: PRL_SRC PRL_DST PRL_ID PRL_PLAN PRL_SLUG PRL_ROUTE PRL_STARTED PRL_ROOT
  local source="$PRL_SRC" target="$PRL_DST"
  if [[ -f "$target" ]]; then
    echo "pipeline-run-log: refuse-on-conflict; target exists: $target" >&2
    return 1
  fi
  if ! mv "$source" "$target"; then
    echo "pipeline-run-log: promote mv failed" >&2
    return 1
  fi
  local body tmp
  body="$(awk '/^- /{p=1} p' "$target")"
  tmp="${target}.tmp.$$"
  {
    printf '# Pipeline run-log\n'
    printf 'invocation: %s\n' "$PRL_ID"
    printf 'plan: %s\n' "$PRL_PLAN"
    printf 'slug: %s\n' "$PRL_SLUG"
    printf 'route: %s\n' "$PRL_ROUTE"
    printf 'started: %s\n' "$PRL_STARTED"
    printf '\n'
    if [[ -n "$body" ]]; then
      printf '%s\n' "$body"
    fi
  } >"$tmp" || {
    echo "pipeline-run-log: promote header refresh failed" >&2
    rm -f "$tmp"
    return 1
  }
  if ! mv "$tmp" "$target"; then
    echo "pipeline-run-log: promote header refresh failed" >&2
    rm -f "$tmp"
    return 1
  fi
  # Successful promote only: refresh pointer with plan/slug/journal (not on refuse).
  prl__write_pointer "$PRL_ROOT" "$PRL_ID" "$PRL_PLAN" "$PRL_SLUG" "${PRL_SLUG}.md"
  return 0
}

prl_cmd_promote() {
  local root="" id="" plan="" route=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root) root="${2:?}"; shift 2 ;;
      --invocation) id="${2:?}"; shift 2 ;;
      --plan) plan="${2:?}"; shift 2 ;;
      --route) route="${2:?}"; shift 2 ;;
      *)
        echo "pipeline-run-log: unknown argument: $1" >&2
        return 2
        ;;
    esac
  done
  [[ -n "$root" && -n "$id" && -n "$plan" ]] || {
    echo "pipeline-run-log: promote requires --root --invocation --plan" >&2
    return 2
  }
  prl__validate_invocation "$id" || return $?
  root="$(cd "$root" && pwd)"

  local source target slug existing_route existing_started norm_plan
  source="$(prl__inv_path "$root" "$id")"
  if [[ ! -f "$source" ]]; then
    echo "pipeline-run-log: promote source missing: $source" >&2
    return 1
  fi
  slug="$(pg_slug_for_plan "$root" "$plan")"
  target="$(prl__slug_path "$root" "$plan")"
  norm_plan="$(pg_normalize_plan_path "$root" "$plan")"

  if [[ -f "$target" ]]; then
    echo "pipeline-run-log: refuse-on-conflict; target exists: $target" >&2
    return 1
  fi

  existing_route="$(prl__read_header_value "$source" "route")"
  existing_started="$(prl__read_header_value "$source" "started")"
  [[ -n "$route" ]] || route="${existing_route:-unknown}"
  [[ -n "$existing_started" ]] || existing_started="$(prl__iso8601)"

  PRL_SRC="$source" PRL_DST="$target" PRL_ID="$id" PRL_PLAN="$norm_plan" \
    PRL_SLUG="$slug" PRL_ROUTE="$route" PRL_STARTED="$existing_started" \
    PRL_ROOT="$root" \
    prl__with_lock "${source}.lock" prl__promote_locked
}

prl_cmd_path() {
  local root="" id="" plan=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root) root="${2:?}"; shift 2 ;;
      --invocation) id="${2:?}"; shift 2 ;;
      --plan) plan="${2:?}"; shift 2 ;;
      *)
        echo "pipeline-run-log: unknown argument: $1" >&2
        return 2
        ;;
    esac
  done
  [[ -n "$root" ]] || {
    echo "pipeline-run-log: path requires --root" >&2
    return 2
  }
  [[ -n "$id" || -n "$plan" ]] || {
    echo "pipeline-run-log: path requires --invocation and/or --plan" >&2
    return 2
  }
  if [[ -n "$id" ]]; then
    prl__validate_invocation "$id" || return $?
  fi
  root="$(cd "$root" && pwd)"
  prl__resolve_journal "$root" "$id" "$plan"
  printf '\n'
}

prl_cmd_read_tail() {
  local root="" id="" plan="" lines=12
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root) root="${2:?}"; shift 2 ;;
      --invocation) id="${2:?}"; shift 2 ;;
      --plan) plan="${2:?}"; shift 2 ;;
      --lines) lines="${2:?}"; shift 2 ;;
      *)
        echo "pipeline-run-log: unknown argument: $1" >&2
        return 2
        ;;
    esac
  done
  [[ -n "$root" ]] || {
    echo "pipeline-run-log: read-tail requires --root" >&2
    return 2
  }
  if [[ -n "$id" ]]; then
    prl__validate_invocation "$id" || return $?
  fi
  root="$(cd "$root" && pwd)"
  local journal
  if ! journal="$(prl__resolve_journal "$root" "$id" "$plan")"; then
    return 0
  fi
  if [[ ! -f "$journal" ]]; then
    return 0
  fi
  grep '^\- ' "$journal" 2>/dev/null | tail -n "$lines" || true
}

prl__write_brief() {
  local brief="$1" id="$2" route="$3" goal="$4" next="$5" stamp="$6"
  {
    printf '# Pipeline run brief\n'
    printf 'invocation: %s\n' "$id"
    printf 'route: %s\n' "$route"
    printf 'updated: %s\n' "$stamp"
    printf '\n'
    printf '## Goal\n'
    printf '%s\n' "${goal:-(none)}"
    printf '\n'
    printf '## Constraints\n'
    printf '%s\n' '- Short orientation brief only; no chat transcripts or ticket dumps.'
    printf '\n'
    printf '## Closed-set decisions\n'
    printf '%s\n' '- (record tokens as they happen)'
    printf '\n'
    printf '## Next stage\n'
    printf '%s\n' "${next:-(unset)}"
  } >"$brief"
  python3 -c '
path = "'"$brief"'"
lines = open(path, encoding="utf-8").read().splitlines()
if len(lines) > 40:
    open(path, "w", encoding="utf-8").write("\n".join(lines[:40]) + "\n")
'
}

prl_cmd_brief_upsert() {
  local root="" id="" route="unknown" goal="" next=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root) root="${2:?}"; shift 2 ;;
      --invocation) id="${2:?}"; shift 2 ;;
      --route) route="${2:?}"; shift 2 ;;
      --goal) goal="${2:?}"; shift 2 ;;
      --next) next="${2:?}"; shift 2 ;;
      *)
        echo "pipeline-run-log: unknown argument: $1" >&2
        return 2
        ;;
    esac
  done
  [[ -n "$root" && -n "$id" ]] || {
    echo "pipeline-run-log: brief-upsert requires --root and --invocation" >&2
    return 2
  }
  prl__validate_invocation "$id" || return $?
  root="$(cd "$root" && pwd)"

  local brief
  brief="$(prl__brief_path "$root" "$id")"
  mkdir -p "$(dirname "$brief")"
  prl__with_lock "${brief}.lock" prl__write_brief "$brief" "$id" "$route" "$goal" "$next" "$(prl__iso8601)"
}

prl__main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    init) prl_cmd_init "$@" ;;
    append) prl_cmd_append "$@" ;;
    promote) prl_cmd_promote "$@" ;;
    read-tail) prl_cmd_read_tail "$@" ;;
    path) prl_cmd_path "$@" ;;
    brief-upsert) prl_cmd_brief_upsert "$@" ;;
    -h|--help|help)
      cat <<'EOF'
Usage:
  pipeline-run-log.sh init --root <project> --invocation <id> [--route <…>] [--reset]
  pipeline-run-log.sh append --root <project> --invocation <id> [--plan <path>] \
    --stage <id> --note "<short text>"
  pipeline-run-log.sh promote --root <project> --invocation <id> --plan <path> [--route <…>]
  pipeline-run-log.sh read-tail --root <project> [--invocation <id>] [--plan <path>] [--lines N]
  pipeline-run-log.sh path --root <project> [--invocation <id>] [--plan <path>]
  pipeline-run-log.sh brief-upsert --root <project> --invocation <id> [--route <…>] \
    [--goal "<text>"] [--next "<stage>"]
EOF
      return 0
      ;;
    "")
      echo "pipeline-run-log: missing subcommand" >&2
      return 2
      ;;
    *)
      echo "pipeline-run-log: unknown subcommand: $cmd" >&2
      return 2
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  prl__main "$@"
fi
