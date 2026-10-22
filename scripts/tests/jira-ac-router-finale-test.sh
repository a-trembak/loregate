#!/usr/bin/env bash
# Contract checks for Jira fetch / router / Pipeline finale / capture-escape.
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

assert_file "skills/jira-fetch/SKILL.md"
assert_file "skills/jira-transition/SKILL.md"
assert_file "commands/lgt-capture-escape.md"
assert_file "scripts/jira-issue.sh"
assert_file "scripts/pr-merge-ci.sh"

assert_grep hitl_pipeline_route "skills/hitl-choice/references/presets.md" "### Pipeline route"
assert_grep hitl_fast_vs_issue "skills/hitl-choice/references/presets.md" "### Fast vs issue"
assert_grep hitl_finale "skills/hitl-choice/references/presets.md" "### Pipeline finale"
assert_grep token_full "skills/hitl-choice/references/presets.md" '`full`'
assert_grep token_fast "skills/hitl-choice/references/presets.md" '`fast`'
assert_grep token_issue "skills/hitl-choice/references/presets.md" '`issue`'
assert_grep token_stay_fast "skills/hitl-choice/references/presets.md" '`stay_fast`'
assert_grep token_keep_draft "skills/hitl-choice/references/presets.md" '`keep_draft`'
assert_grep token_ready "skills/hitl-choice/references/presets.md" '`ready`'
assert_grep token_keep_draft_jira "skills/hitl-choice/references/presets.md" '`keep_draft_jira`'
assert_grep token_ready_jira "skills/hitl-choice/references/presets.md" '`ready_jira`'

assert_grep_start_task start_task_fetch "jira-fetch"
assert_grep_start_task start_task_never_auto_fast "never auto-select"
assert_grep_start_task start_task_bug_route "jira_class.*bug"
assert_grep start_issue_reuse "commands/lgt-start-issue-task.md" "do not re-fetch|already-fetched"
assert_grep write_spec_fetch "commands/lgt-write-tech-spec.md" "jira-fetch"
assert_grep create_pr_draft_first "skills/create-pr/SKILL.md" "Draft first"
assert_grep create_pr_gh_ready "skills/create-pr/SKILL.md" "gh pr ready"
assert_grep create_pr_comment "skills/create-pr/SKILL.md" "addCommentToJiraIssue"
assert_grep create_pr_review_transition "skills/create-pr/SKILL.md" "jira-transition"
assert_grep create_pr_review_target "skills/create-pr/SKILL.md" "target \`review\`"
assert_grep create_pr_verdict "skills/create-pr/SKILL.md" "pr_merge_ci_verdict"
assert_grep create_pr_all_merged "skills/create-pr/SKILL.md" "all_merged_ci_success"
assert_grep create_pr_observe_checks "skills/create-pr/SKILL.md" "statusCheckRollup"
assert_grep create_pr_subscribe_pr "skills/create-pr/SKILL.md" "subscribe_github_pr"
assert_grep create_pr_subscribe_ci "skills/create-pr/SKILL.md" "subscribe_github_ci"
assert_grep create_pr_source_helper "skills/create-pr/SKILL.md" "source scripts/pr-merge-ci.sh"
assert_grep create_pr_resume "skills/create-pr/SKILL.md" "Resume after merge or builds"
assert_grep create_pr_closed "skills/create-pr/SKILL.md" "closed_unmerged"
assert_grep create_pr_never_merge "skills/create-pr/SKILL.md" "Never merge"
assert_no_grep create_pr_no_ready_column "skills/create-pr/SKILL.md" "while the GitHub PR is ready for review"
assert_grep_start_task start_task_in_progress "jira-transition"
assert_grep_start_task start_task_in_progress_target "in_progress"
assert_grep start_issue_in_progress "commands/lgt-start-issue-task.md" "jira-transition"
assert_grep hitl_ready_review "skills/hitl-choice/references/presets.md" "jira-transition"
assert_grep hitl_review_after_merge "skills/hitl-choice/references/presets.md" "all_merged_ci_success"
assert_no_grep hitl_no_immediate_review "skills/hitl-choice/references/presets.md" "On \`ready\` / \`ready_jira\` when \`jira_key\` is known: skill"
assert_grep jira_transition_get "skills/jira-transition/SKILL.md" "getTransitionsForJiraIssue"
assert_grep jira_transition_do "skills/jira-transition/SKILL.md" "transitionJiraIssue"
assert_grep jira_transition_in_progress "skills/jira-transition/SKILL.md" "in_progress"
assert_grep jira_transition_review "skills/jira-transition/SKILL.md" '`review`'
assert_grep jira_transition_merge_gate "skills/jira-transition/SKILL.md" "all_merged_ci_success"
assert_no_grep write_spec_no_transition "commands/lgt-write-tech-spec.md" "jira-transition"
assert_grep capture_mode "commands/lgt-capture-escape.md" "mode: capture"
assert_grep capture_source "commands/lgt-capture-escape.md" "source: production-escape"
assert_grep capture_dest "commands/lgt-capture-escape.md" "Capture-escape destination"
assert_grep capture_secret "commands/lgt-capture-escape.md" "project_secret"
assert_grep capture_teach "commands/lgt-capture-escape.md" "teach-review"
assert_grep install_jira_helper "scripts/install-to-project.sh" "jira-issue.sh"
assert_grep install_pr_merge_ci "scripts/install-to-project.sh" "pr-merge-ci.sh"
assert_grep readme_create_pr "README.md" "skills/create-pr"
assert_grep readme_jira_fetch "README.md" "skills/jira-fetch"
assert_grep readme_jira_transition "README.md" "skills/jira-transition"
assert_grep flow_jira_transition "docs/superpowers/pipeline-flow.md" "jira-transition"
assert_grep flow_review_after_merge "docs/superpowers/pipeline-flow.md" "all_merged_ci_success"
assert_grep dogfood_pr_merge "docs/superpowers/dogfood/jira-ac-router-finale-checklist.md" "pr-merge-ci-test.sh"
assert_no_grep readme_no_stub "README.md" "URL is a stub"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
