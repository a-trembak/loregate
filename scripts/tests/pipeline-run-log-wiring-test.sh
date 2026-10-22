#!/usr/bin/env bash
# Wiring contract: allowlisted dual-write surfaces mention pipeline-run-log.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=lib-assert.sh
source "$(dirname "$0")/lib-assert.sh"
fail=0

assert_grep() {
  local name="$1" path="$2" pattern="$3"
  if grep -E -q -- "$pattern" "$ROOT/$path"; then
    echo "OK   $name"
  else
    echo "FAIL $name: /$pattern/ not in $path" >&2
    fail=1
  fi
}

assert_file() {
  local name="$1" path="$2"
  if [[ -f "$ROOT/$path" ]]; then
    echo "OK   $name"
  else
    echo "FAIL $name: missing $path" >&2
    fail=1
  fi
}

HELPER="scripts/pipeline-run-log.sh"
assert_file helper_exists "$HELPER"

# Installer copies helper + gitignore recommendation
assert_grep installer_copies "scripts/install-to-project.sh" "pipeline-run-log\\.sh"
assert_grep installer_gitignore "scripts/install-to-project.sh" "run-log/"

ALLOWLIST=(
  "commands/lgt-start-task.md"
  "commands/references/lgt-start-task-full.md"
  "commands/references/lgt-start-task-fast.md"
  "commands/lgt-start-issue-task.md"
  "skills/tech-spec/SKILL.md"
  "skills/approve-plan/SKILL.md"
  "skills/finish-plan/SKILL.md"
  "skills/hitl-choice/SKILL.md"
  "skills/local-diff-review-gate/SKILL.md"
  "skills/propose-commit/SKILL.md"
  "skills/create-pr/SKILL.md"
)

for path in "${ALLOWLIST[@]}"; do
  base="$(basename "$path" .md)"
  base="${base%.SKILL}"
  assert_grep "${base}_helper" "$path" "pipeline-run-log"
  assert_grep "${base}_invocation" "$path" "invocation_id|invocation"
done

# Bootstrap mint + init + promote + brief on start commands
assert_grep_start_task start_task_init "pipeline-run-log\\.sh init|run-log.*init"
assert_grep_start_task start_task_promote "promote"
assert_grep_start_task start_task_brief "brief-upsert"
assert_grep start_issue_init "commands/lgt-start-issue-task.md" "pipeline-run-log\\.sh init|run-log.*init"
assert_grep start_issue_promote "commands/lgt-start-issue-task.md" "promote"

# Approve-plan handles refuse-on-conflict promote
assert_grep approve_promote "skills/approve-plan/SKILL.md" "promote"
assert_grep approve_refuse "skills/approve-plan/SKILL.md" "refuse|conflict"

# hitl-choice appends after token and may pass --invocation to status
assert_grep hitl_append "skills/hitl-choice/SKILL.md" "append"
assert_grep hitl_status_inv "skills/hitl-choice/SKILL.md" "--invocation|invocation"

# Forbidden content guidance somewhere in allowlist or docs-facing spines
assert_grep_start_task start_no_chat_dump "chat transcript|ticket bod"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
