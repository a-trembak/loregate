#!/usr/bin/env bash
# Per-plan pipeline gate helpers (sourceable library).
# Usage: source scripts/pipeline-gates.sh

pg__root() {
  if [[ -n "${PG_ROOT:-}" ]]; then
    printf '%s' "${PG_ROOT%/}"
  else
    printf '%s' "${1%/}"
  fi
}

pg_normalize_plan_path() {
  local root plan_path norm
  root="$(pg__root "$1")"
  plan_path="$2"
  norm="$plan_path"

  if [[ "$norm" == "$root/"* ]]; then
    norm="${norm#"$root"/}"
  fi

  while [[ "$norm" == ./* ]]; do
    norm="${norm#./}"
  done

  while [[ "$norm" == *//* ]]; do
    norm="${norm//\/\//\/}"
  done

  norm="${norm%/}"
  printf '%s' "$norm"
}

pg__path_hash12() {
  local norm="$1" digest=""
  if command -v sha256sum >/dev/null 2>&1; then
    digest="$(printf '%s' "$norm" | sha256sum | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    digest="$(printf '%s' "$norm" | shasum -a 256 | awk '{print $1}')"
  else
    echo "pipeline-gates: sha256sum or shasum required" >&2
    return 1
  fi
  printf '%s' "${digest:0:12}"
}

pg__extract_ticket() {
  local norm="$1" basename="${norm##*/}" ticket=""

  if [[ "$basename" =~ ([A-Za-z][A-Za-z0-9]*-[0-9]+) ]]; then
    ticket="${BASH_REMATCH[1]}"
    # Bash 3.2 (macOS) has no ${var^^}; use tr.
    printf '%s' "$ticket" | tr '[:lower:]' '[:upper:]'
    return 0
  fi

  if [[ "$norm" =~ ([A-Za-z][A-Za-z0-9]*-[0-9]+) ]]; then
    ticket="${BASH_REMATCH[1]}"
    printf '%s' "$ticket" | tr '[:lower:]' '[:upper:]'
    return 0
  fi

  return 1
}

pg__base_slug_for_plan() {
  local root="$1" plan_path="$2" norm ticket=""
  norm="$(pg_normalize_plan_path "$root" "$plan_path")"
  if ticket="$(pg__extract_ticket "$norm")"; then
    printf '%s' "$ticket"
  else
    pg__path_hash12 "$norm"
  fi
}

# True when we can mkdir and create a file under dir (probe then remove).
pg__dir_writable() {
  local d="$1" probe
  mkdir -p "$d" 2>/dev/null || return 1
  probe="$d/.pg_write_probe_$$"
  if ! printf 'ok\n' >"$probe" 2>/dev/null; then
    rm -f "$probe" 2>/dev/null || true
    return 1
  fi
  rm -f "$probe" 2>/dev/null || true
  return 0
}

pg__abs_root() {
  local root="$1"
  if [[ -d "$root" ]]; then
    (cd "$root" && pwd -P) 2>/dev/null && return 0
  fi
  printf '%s' "$root"
}

# Home (or /tmp) fallback when project .cursor/gates is not writable
# (e.g. Operation not permitted / com.apple.provenance on agent sandboxes).
pg__fallback_gates_base() {
  local root="$1" abs hash home
  abs="$(pg__abs_root "$root")"
  hash="$(pg__path_hash12 "$abs")" || return 1
  home="${HOME:-/tmp}"
  printf '%s/.cursor/spells-gates/%s/gates' "$home" "$hash"
}

pg__primary_gates_base() {
  local root="$1"
  printf '%s/.cursor/gates' "$root"
}

pg__redirect_path() {
  local root="$1"
  printf '%s/.cursor/gates-redirect' "$root"
}

# Resolve the gates base directory for writes (and preferred reads).
# Order: PG_GATES_BASE / CSP_GATES_BASE → gates-redirect → primary if writable → fallback.
pg_gates_base() {
  local root base redirect line
  root="$(pg__root "$1")"

  if [[ -n "${PG_GATES_BASE:-}" ]]; then
    printf '%s' "${PG_GATES_BASE%/}"
    return 0
  fi
  if [[ -n "${CSP_GATES_BASE:-}" ]]; then
    printf '%s' "${CSP_GATES_BASE%/}"
    return 0
  fi

  redirect="$(pg__redirect_path "$root")"
  if [[ -f "$redirect" ]]; then
    line="$(head -n 1 "$redirect" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [[ -n "$line" ]] && pg__dir_writable "$line"; then
      printf '%s' "$line"
      return 0
    fi
  fi

  base="$(pg__primary_gates_base "$root")"
  if pg__dir_writable "$base"; then
    printf '%s' "$base"
    return 0
  fi

  base="$(pg__fallback_gates_base "$root")" || return 1
  if ! pg__dir_writable "$base"; then
    echo "pipeline-gates: cannot write gates under primary or fallback ($base)" >&2
    return 1
  fi

  # Best-effort redirect so humans/tools discover the fallback; ignore failure.
  if mkdir -p "$(dirname "$redirect")" 2>/dev/null; then
    printf '%s\n' "$base" >"$redirect" 2>/dev/null || true
  fi

  echo "pipeline-gates: using fallback gates base: $base" >&2
  printf '%s' "$base"
}

pg_gate_dir() {
  local root kind base
  root="$(pg__root "$1")"
  kind="$2"
  base="$(pg_gates_base "$root")" || return 1
  printf '%s/%s' "$base" "$kind"
}

pg_gate_path() {
  local root kind slug
  root="$(pg__root "$1")"
  kind="$2"
  slug="$3"
  printf '%s/%s' "$(pg_gate_dir "$root" "$kind")" "$slug"
}

pg_legacy_path() {
  local root kind
  root="$(pg__root "$1")"
  kind="$2"
  case "$kind" in
    plan-gate) printf '%s/.cursor/plan-gate.pending' "$root" ;;
    critique-gate) printf '%s/.cursor/critique-gate.pending' "$root" ;;
    plan-critique-clear) printf '%s/.cursor/plan-critique.clear' "$root" ;;
    review-gate) printf '%s/.cursor/review-gate.pending' "$root" ;;
    docs-gate) printf '%s/.cursor/docs-gate.pending' "$root" ;;
    commit-approved) printf '%s/.cursor/commit-approved.pending' "$root" ;;
    *)
      echo "pipeline-gates: unknown kind: $kind" >&2
      return 1
      ;;
  esac
}

pg_slug_for_plan() {
  local root plan_path kind candidate norm gate_file existing_line1 existing_norm hash12
  root="$(pg__root "$1")"
  plan_path="$2"
  kind="${3:-}"

  if [[ -z "$kind" ]]; then
    pg__base_slug_for_plan "$root" "$plan_path"
    return
  fi

  norm="$(pg_normalize_plan_path "$root" "$plan_path")"
  candidate="$(pg__base_slug_for_plan "$root" "$plan_path")"

  if [[ "$candidate" =~ ^[0-9a-f]{12}$ ]]; then
    printf '%s' "$candidate"
    return
  fi

  gate_file="$(pg_gate_path "$root" "$kind" "$candidate")"
  if [[ -f "$gate_file" ]]; then
    existing_line1="$(head -n 1 "$gate_file" | tr -d '\r')"
    existing_norm="$(pg_normalize_plan_path "$root" "$existing_line1")"
    if [[ "$existing_norm" != "$norm" ]]; then
      hash12="$(pg__path_hash12 "$norm")"
      printf '%s-%s' "$candidate" "$hash12"
      return
    fi
  fi

  printf '%s' "$candidate"
}

pg__write_gate_file() {
  local root="$1" kind="$2" plan_path="$3" slug="$4"
  local norm base_slug gate_path gate_dir
  norm="$(pg_normalize_plan_path "$root" "$plan_path")"
  base_slug="$(pg__base_slug_for_plan "$root" "$plan_path")"
  gate_path="$(pg_gate_path "$root" "$kind" "$slug")" || return 1
  gate_dir="$(pg_gate_dir "$root" "$kind")" || return 1
  if ! mkdir -p "$gate_dir" 2>/dev/null; then
    echo "pipeline-gates: mkdir failed: $gate_dir" >&2
    return 1
  fi
  if ! {
    printf '%s\n' "$norm"
    if [[ "$slug" == "$base_slug" && ! "$slug" =~ ^[0-9a-f]{12}$ ]]; then
      printf 'ticket: %s\n' "$base_slug"
    fi
  } >"$gate_path" 2>/dev/null; then
    echo "pipeline-gates: write failed: $gate_path" >&2
    return 1
  fi
  if [[ ! -f "$gate_path" ]]; then
    echo "pipeline-gates: write missing after create: $gate_path" >&2
    return 1
  fi
  return 0
}

pg_migrate_legacy() {
  local root kind plan_path="${3:-}" legacy line1 norm_plan norm_legacy slug
  root="$(pg__root "$1")"
  kind="$2"
  legacy="$(pg_legacy_path "$root" "$kind")"

  if [[ ! -f "$legacy" ]]; then
    return 0
  fi

  line1="$(head -n 1 "$legacy" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [[ -z "$line1" ]]; then
    echo "warning: legacy gate $legacy has empty plan path; skipping migrate" >&2
    return 0
  fi

  if [[ -n "$plan_path" ]]; then
    norm_plan="$(pg_normalize_plan_path "$root" "$plan_path")"
    norm_legacy="$(pg_normalize_plan_path "$root" "$line1")"
    if [[ "$norm_plan" != "$norm_legacy" ]]; then
      return 0
    fi
  fi

  slug="$(pg_slug_for_plan "$root" "$line1" "$kind")"
  if [[ ! -f "$(pg_gate_path "$root" "$kind" "$slug")" ]]; then
    pg__write_gate_file "$root" "$kind" "$line1" "$slug" || return 1
  fi
  if ! rm -f "$legacy" 2>/dev/null; then
    echo "pipeline-gates: failed to remove legacy gate: $legacy" >&2
    return 1
  fi
  return 0
}

pg_write_gate() {
  local root kind plan_path slug
  root="$(pg__root "$1")"
  kind="$2"
  plan_path="$3"
  pg_migrate_legacy "$root" "$kind" "$plan_path" || return 1
  slug="$(pg_slug_for_plan "$root" "$plan_path" "$kind")" || return 1
  pg__write_gate_file "$root" "$kind" "$plan_path" "$slug"
}

# Search primary then fallback (and env/redirect base) so sticky primary markers are found.
pg__find_gate_for_plan() {
  local root="$1" kind="$2" plan_path="$3" norm dir f line1 existing_norm fb redirect line
  local -a dirs=()
  local seen=""
  norm="$(pg_normalize_plan_path "$root" "$plan_path")"

  dirs+=("$(pg__primary_gates_base "$root")/$kind")
  if fb="$(pg__fallback_gates_base "$root")"; then
    dirs+=("$fb/$kind")
  fi
  redirect="$(pg__redirect_path "$root")"
  if [[ -f "$redirect" ]]; then
    line="$(head -n 1 "$redirect" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [[ -n "$line" ]]; then
      dirs+=("$line/$kind")
    fi
  fi
  if [[ -n "${PG_GATES_BASE:-}" ]]; then
    dirs+=("${PG_GATES_BASE%/}/$kind")
  fi
  if [[ -n "${CSP_GATES_BASE:-}" ]]; then
    dirs+=("${CSP_GATES_BASE%/}/$kind")
  fi

  for dir in "${dirs[@]}"; do
    [[ -n "$dir" && -d "$dir" ]] || continue
    case " $seen " in
      *" $dir "*) continue ;;
    esac
    seen+=" $dir"
    for f in "$dir"/*; do
      [[ -f "$f" ]] || continue
      line1="$(head -n 1 "$f" | tr -d '\r')"
      existing_norm="$(pg_normalize_plan_path "$root" "$line1")"
      if [[ "$existing_norm" == "$norm" ]]; then
        printf '%s' "$f"
        return 0
      fi
    done
  done

  return 1
}

pg_clear_gate() {
  local root kind plan_path gate_file remaining=0
  root="$(pg__root "$1")"
  kind="$2"
  plan_path="$3"
  pg_migrate_legacy "$root" "$kind" "$plan_path" || return 1

  # Clear every matching copy (primary + fallback) until none remain.
  while gate_file="$(pg__find_gate_for_plan "$root" "$kind" "$plan_path")"; do
    if ! rm -f "$gate_file" 2>/dev/null; then
      echo "pipeline-gates: clear failed (permission?): $gate_file" >&2
      return 1
    fi
    if [[ -f "$gate_file" ]]; then
      echo "pipeline-gates: clear failed; file still present: $gate_file" >&2
      return 1
    fi
  done
  return 0
}

pg_list_gates() {
  local root kind dir f slug line1 fb redirect line
  local -a dirs=()
  local seen_dirs="" seen_slugs=""
  root="$(pg__root "$1")"
  kind="$2"
  pg_migrate_legacy "$root" "$kind" || true

  dirs+=("$(pg__primary_gates_base "$root")/$kind")
  if fb="$(pg__fallback_gates_base "$root")"; then
    dirs+=("$fb/$kind")
  fi
  redirect="$(pg__redirect_path "$root")"
  if [[ -f "$redirect" ]]; then
    line="$(head -n 1 "$redirect" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [[ -n "$line" ]]; then
      dirs+=("$line/$kind")
    fi
  fi
  if [[ -n "${PG_GATES_BASE:-}" ]]; then
    dirs+=("${PG_GATES_BASE%/}/$kind")
  fi
  if [[ -n "${CSP_GATES_BASE:-}" ]]; then
    dirs+=("${CSP_GATES_BASE%/}/$kind")
  fi

  for dir in "${dirs[@]}"; do
    [[ -n "$dir" && -d "$dir" ]] || continue
    case " $seen_dirs " in
      *" $dir "*) continue ;;
    esac
    seen_dirs+=" $dir"
    for f in "$dir"/*; do
      [[ -f "$f" ]] || continue
      slug="${f##*/}"
      case " $seen_slugs " in
        *" $slug "*) continue ;;
      esac
      seen_slugs+=" $slug"
      line1="$(head -n 1 "$f" | tr -d '\r')"
      printf '%s\t%s\n' "$slug" "$line1"
    done
  done
}
