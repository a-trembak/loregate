#!/usr/bin/env bash
# Contract: product commits only after propose-commit + approve-commit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=lib-assert.sh
source "$(dirname "$0")/lib-assert.sh"
fail=0

assert_file() {
  local path="$1"
  if [[ ! -f "$ROOT/$path" ]]; then
    echo "FAIL missing file: $path" >&2
    fail=1
  else
    echo "OK   file $path"
  fi
}

assert_grep() {
  local name="$1" path="$2" pattern="$3"
  if grep -E -q "$pattern" "$ROOT/$path" 2>/dev/null; then
    echo "OK   $name"
  else
    echo "FAIL $name: /$pattern/ not in $path" >&2
    fail=1
  fi
}

assert_no_grep() {
  local name="$1" path="$2" pattern="$3"
  if grep -E -q "$pattern" "$ROOT/$path" 2>/dev/null; then
    echo "FAIL $name: /$pattern/ unexpectedly in $path" >&2
    fail=1
  else
    echo "OK   $name"
  fi
}

assert_file "skills/propose-commit/SKILL.md"
assert_file "skills/hitl-choice/SKILL.md"
assert_file "skills/hitl-choice/references/presets.md"
assert_file "skills/software-developer/SKILL.md"
assert_file "skills/bug-fix/SKILL.md"
assert_file "skills/create-pr/SKILL.md"
assert_file "skills/engineer-review/SKILL.md"
assert_file "skills/update-docs/SKILL.md"
assert_file "commands/lgt-start-task.md"
assert_file "commands/lgt-start-issue-task.md"
assert_file "skills/finish-plan/references/review-surface.md"
assert_file "scripts/pipeline-gates.sh"

assert_grep skill_name "skills/propose-commit/SKILL.md" "^name: propose-commit$"
assert_grep skill_approve "skills/propose-commit/SKILL.md" "approve-commit"
assert_grep skill_revise "skills/propose-commit/SKILL.md" "revise"
assert_grep skill_marker "skills/propose-commit/SKILL.md" "commit-approved"
assert_grep skill_no_push "skills/propose-commit/SKILL.md" "Do not.*git push|never.*git push|Do \\*\\*not\\*\\* \`git push\`"
assert_grep skill_no_pr "skills/propose-commit/SKILL.md" "pull request"
assert_grep skill_review_pre "skills/propose-commit/SKILL.md" "engineer-review"
assert_grep skill_local_diff_pre "skills/propose-commit/SKILL.md" "local-diff-review-gate"
assert_grep skill_no_no_miss_jump "skills/propose-commit/SKILL.md" "no_miss"
assert_grep skill_no_add_all "skills/propose-commit/SKILL.md" "git add -A|git add \\."

assert_grep hitl_preset "skills/hitl-choice/references/presets.md" "Propose commit"
assert_grep hitl_token "skills/hitl-choice/references/presets.md" "approve-commit"

assert_grep sd_no_commit "skills/software-developer/SKILL.md" "Never.*git commit|do not.*git commit|no product commit|forbid.*git commit"
assert_grep bf_no_commit "skills/bug-fix/SKILL.md" "Never.*git commit|do not.*git commit|no product commit|forbid.*git commit"

assert_grep create_pr_guard "skills/create-pr/SKILL.md" "propose-commit|commit-approved"
assert_grep create_pr_gate_find "skills/create-pr/SKILL.md" "pg__find_gate_for_plan|pipeline-gates\\.sh"
assert_grep create_pr_gate_clear "skills/create-pr/SKILL.md" "pg_clear_gate.*commit-approved|commit-approved.*pg_clear_gate"
assert_grep create_pr_no_quiet "skills/create-pr/SKILL.md" "must not silently commit|do not silently commit|Never silently commit|quiet product commit"
assert_grep propose_staged_match "skills/propose-commit/SKILL.md" "git diff --cached --name-only|restore --staged"
assert_grep docs_repo_no_commit "skills/update-docs/SKILL.md" "docs_repo.*uncommitted|Do \\*\\*not\\*\\*.*git commit"

assert_grep er_handoff "skills/engineer-review/SKILL.md" "propose-commit"
assert_grep docs_residual "skills/update-docs/SKILL.md" "propose-commit"
assert_grep_start_task start_full "propose-commit"
assert_grep_start_task start_fast "propose-commit"
assert_grep start_issue "commands/lgt-start-issue-task.md" "propose-commit"

assert_grep surface_uncommitted "skills/finish-plan/references/review-surface.md" "git status|git diff|uncommitted"
assert_grep gates_kind "scripts/pipeline-gates.sh" "commit-approved"

assert_grep flow_md "docs/superpowers/pipeline-flow.md" "propose-commit"
assert_grep flow_html "docs/superpowers/pipeline-flow.html" "propose-commit"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
