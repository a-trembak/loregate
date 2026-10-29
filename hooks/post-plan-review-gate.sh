#!/usr/bin/env bash
# Reminds the agent about HITL review gate after plan completion.
# Does NOT auto-start engineer-review (preserves human-in-the-loop).
# Install: copy/symlink this file + hooks.json into the consumer project's .cursor/

set -euo pipefail

input="$(cat || true)"

# Prefer workspace root from hook payload when present; else cwd
root="$(pwd)"
if command -v jq >/dev/null 2>&1; then
  w="$(printf '%s' "$input" | jq -r '.workspace_roots[0] // .cwd // empty' 2>/dev/null || true)"
  if [[ -n "${w:-}" && -d "$w" ]]; then
    root="$w"
  fi
fi

emit_followup() {
  local message="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '{"followup_message":%s}\n' "$(printf '%s' "$message" | jq -Rs .)"
  else
    local safe_message
    safe_message="$(printf '%s' "$message" | tr -d '"\\' | tr '\n' ' ')"
    printf '%s\n' "{\"followup_message\":\"${safe_message}\"}"
  fi
}

status=""
if command -v jq >/dev/null 2>&1; then
  status="$(printf '%s' "$input" | jq -r '.status // empty' 2>/dev/null || true)"
else
  status="$(printf '%s' "$input" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

if [[ "$status" == "aborted" || "$status" == "error" ]]; then
  printf '%s\n' '{}'
  exit 0
fi

pg_lib="$root/scripts/pipeline-gates.sh"
if [[ ! -f "$pg_lib" ]]; then
  hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ "$hook_dir" == */.cursor/hooks ]]; then
    pg_lib="$(cd "$hook_dir/../.." && pwd)/scripts/pipeline-gates.sh"
  else
    pg_lib="$(cd "$hook_dir/.." && pwd)/scripts/pipeline-gates.sh"
  fi
fi

if [[ ! -f "$pg_lib" ]]; then
  emit_followup "pipeline-gates helper missing at $root/scripts/pipeline-gates.sh. Run lgt update to refresh kit scripts."
  exit 0
fi

# shellcheck source=/dev/null
source "$pg_lib"

pg_migrate_legacy "$root" review-gate

plan_path=""
if [[ -n "${CURSOR_PLAN_PATH:-}" ]]; then
  plan_path="$(printf '%s\n' "$CURSOR_PLAN_PATH" | head -n 1 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
fi
if [[ -z "$plan_path" ]] && command -v jq >/dev/null 2>&1; then
  plan_path="$(printf '%s' "$input" | jq -r '.plan_path // .plan // empty' 2>/dev/null || true)"
fi

if [[ -n "$plan_path" ]]; then
  slug="$(pg_slug_for_plan "$root" "$plan_path" review-gate)"
  gate_file="$(pg_gate_path "$root" review-gate "$slug")"
  if [[ -f "$gate_file" ]]; then
    rel_gate="${gate_file#"$root"/}"
    # Important: followup_message auto-continues the agent. If we only say "ask
    # HITL", the agent re-asks forever and ignores a prior user skip/approve/done
    # that arrived while the stop-hook loop was running. Prefer honoring an
    # existing answer; only re-ask when none is in the chat yet.
    message="Plan-complete marker still present (${rel_gate}, plan: ${plan_path}). If the user already replied skip, approve, or done anywhere in this chat after the gate was asked, delete ${rel_gate} immediately and continue skill finish-plan (start csp-engineer-reviewer or csp-multi-repo-supervisor). Do not re-ask. If they have not answered yet: apply review-surface first (checkout the feature branch in each open folder, call SetActiveBranch — do not create-pr, pipeline is not finished), then ask HITL via skill hitl-choice (AskQuestion when available; else typed skip / approve / done / fixes). After skip / approve / done, start engineer-review."
    emit_followup "$message"
    exit 0
  fi
fi
# Unknown plan path: stay silent. followup_message auto-continues every chat
# in this workspace. Listing foreign slugs is unresolvable there (do not
# delete) and loops until hooks.json loop_limit. finish-plan still writes
# this plan's review-gate; honor skip/approve/done in the owning chat.

printf '%s\n' '{}'
exit 0
