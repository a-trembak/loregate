#!/usr/bin/env bash
# Contract: before review-gate HITL, finish-plan must surface the work in the
# human's client (checkout open folders + SetActiveBranch) so they can look at
# the diff. This is an intermediate convenience step — not create-pr, not the
# pipeline end. After skip/approve/done, engineer-review continues.
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
  if grep -E -q "$pattern" "$ROOT/$path"; then
    echo "OK   $name"
  else
    echo "FAIL $name: /$pattern/ not in $path" >&2
    fail=1
  fi
}

assert_no_grep() {
  local name="$1" path="$2" pattern="$3"
  if grep -E -q "$pattern" "$ROOT/$path"; then
    echo "FAIL $name: /$pattern/ unexpectedly in $path" >&2
    fail=1
  else
    echo "OK   $name"
  fi
}

assert_file "skills/finish-plan/references/review-surface.md"
assert_file "skills/finish-plan/references/local-diff-review.md"
assert_file "skills/finish-plan/SKILL.md"
assert_file "commands/lgt-finish-plan.md"
assert_file "skills/create-pr/SKILL.md"
assert_file "skills/software-developer/references/branch-setup.md"

assert_grep finish_skill_ref "skills/finish-plan/SKILL.md" "review-surface.md"
assert_grep finish_skill_local_diff "skills/finish-plan/SKILL.md" "local-diff-review.md"
assert_grep finish_skill_before_hitl "skills/finish-plan/SKILL.md" "Apply review-surface"
assert_grep finish_cmd_ref "commands/lgt-finish-plan.md" "review-surface.md"
assert_grep finish_cmd_local_diff "commands/lgt-finish-plan.md" "local-diff-review.md"
assert_grep finish_reask "skills/finish-plan/SKILL.md" "re-run review-surface"
assert_grep finish_then_engineer "skills/finish-plan/SKILL.md" "csp-engineer-reviewer"
assert_grep finish_outbound_fixes "skills/finish-plan/SKILL.md" "apply-fixes|local-diff-review/comments"
assert_no_grep finish_no_surface_create "skills/finish-plan/SKILL.md" "mode:surface"

assert_grep surface_set_active "skills/finish-plan/references/review-surface.md" "SetActiveBranch"
assert_grep surface_checkout "skills/finish-plan/references/review-surface.md" "git( -C.*)? checkout"
assert_grep surface_open_folder "skills/finish-plan/references/review-surface.md" "open folder|workspace folder|human has open"
assert_grep surface_not_worktree "skills/finish-plan/references/review-surface.md" "worktree"
assert_grep surface_every_repo "skills/finish-plan/references/review-surface.md" "every.*repo|each.*repo"
assert_grep surface_intermediate "skills/finish-plan/references/review-surface.md" "intermediate|does not end the pipeline|not the pipeline finale"
assert_grep surface_then_engineer "skills/finish-plan/references/review-surface.md" "engineer-review"
assert_grep surface_create_pr_later "skills/finish-plan/references/review-surface.md" "create-pr"
assert_no_grep surface_no_mode "skills/finish-plan/references/review-surface.md" "mode:surface"
assert_grep surface_forbid_gh_create "skills/finish-plan/references/review-surface.md" "not.*gh pr create"
assert_grep surface_never_finale "skills/finish-plan/references/review-surface.md" "Do not ask Pipeline finale|do not ask Pipeline finale|Never ask Pipeline finale"
assert_grep surface_uncommitted "skills/finish-plan/references/review-surface.md" "git status|uncommitted|working tree"
assert_grep surface_no_placeholder "skills/finish-plan/references/review-surface.md" "placeholder commit|Do not.*placeholder"
assert_grep surface_propose "skills/finish-plan/references/review-surface.md" "propose-commit"
assert_grep surface_prefer_local_diff "skills/finish-plan/references/review-surface.md" "local-diff-review.md|review-local-diff"
assert_grep surface_never_vendor "skills/finish-plan/references/review-surface.md" "Never vendor|do not vendor"

assert_grep local_diff_skill_id "skills/finish-plan/references/local-diff-review.md" "review-local-diff"
assert_grep local_diff_kind "skills/finish-plan/references/local-diff-review.md" "local-diff-review/comments"
assert_grep local_diff_version "skills/finish-plan/references/local-diff-review.md" '"version": 1|version.*1'
assert_grep local_diff_outbound "skills/finish-plan/references/local-diff-review.md" "outbound|useCanvasState"
assert_grep local_diff_current_thread "skills/finish-plan/references/local-diff-review.md" "current-thread|Current thread"
assert_grep local_diff_apply_fixes "skills/finish-plan/references/local-diff-review.md" "apply-fixes"
assert_grep local_diff_software_dev "skills/finish-plan/references/local-diff-review.md" "csp-software-developer"
assert_grep local_diff_skill_missing "skills/finish-plan/references/local-diff-review.md" "skill_missing: review-local-diff"
assert_grep local_diff_escape "skills/finish-plan/references/local-diff-review.md" "no-local-diff-review"
assert_grep local_diff_no_vendor "skills/finish-plan/references/local-diff-review.md" "Do not vendor|do not vendor"
assert_grep local_diff_new_chat_out_of_scope "skills/finish-plan/references/local-diff-review.md" "newComposerChat"
assert_grep local_diff_out_of_scope_heading "skills/finish-plan/references/local-diff-review.md" "## Out of scope"

assert_no_grep create_pr_no_surface "skills/create-pr/SKILL.md" "mode:surface"

assert_grep branch_set_active "skills/software-developer/references/branch-setup.md" "SetActiveBranch"
assert_grep branch_open_folder "skills/software-developer/references/branch-setup.md" "human has open|open workspace folder"
assert_no_grep branch_no_draft_pr "skills/software-developer/references/branch-setup.md" "draft pull request"

assert_grep rule_surface "rules/after-plan-review-gate.mdc" "review-surface|SetActiveBranch"
assert_grep rule_local_diff "rules/after-plan-review-gate.mdc" "local-diff-review|Local Diff Review"
assert_grep hook_surface "hooks/post-plan-review-gate.sh" "review-surface|SetActiveBranch"
assert_grep hook_local_diff "hooks/post-plan-review-gate.sh" "review-local-diff|local-diff-review"
assert_grep_start_task start_task_surface "review-surface|SetActiveBranch"
assert_grep_start_task start_task_local_diff "local-diff-review|review-local-diff"
assert_grep hitl_local_diff "skills/hitl-choice/references/presets.md" "local-diff-review|Current thread"
assert_grep readme_surface "README.md" "review-surface|SetActiveBranch"
assert_grep readme_local_diff "README.md" "Local Diff Review|review-local-diff|local-diff-review"
assert_grep flow_md_surface "docs/superpowers/pipeline-flow.md" "SetActiveBranch|review-surface"
assert_grep flow_md_local_diff "docs/superpowers/pipeline-flow.md" "review-local-diff|local-diff-review"
assert_grep flow_html_surface "docs/superpowers/pipeline-flow.html" "SetActiveBranch|review-surface"
assert_grep flow_html_local_diff "docs/superpowers/pipeline-flow.html" "review-local-diff|local-diff-review"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
