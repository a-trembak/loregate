#!/usr/bin/env bash
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

assert_not_grep() {
  local name="$1" path="$2" pattern="$3"
  if grep -E -q -- "$pattern" "$ROOT/$path"; then
    echo "FAIL $name: /$pattern/ unexpectedly in $path" >&2
    fail=1
  else
    echo "OK   $name"
  fi
}

assert_grep fetch_score "skills/jira-fetch/SKILL.md" "trajectory-cases.py score"
assert_grep fetch_case "skills/jira-fetch/SKILL.md" "fetch-failure-stops"
assert_grep fetch_skip "skills/jira-fetch/SKILL.md" "skip score"
assert_grep fetch_exact_input "skills/jira-fetch/SKILL.md" '--invocation "/lgt-start-task PROJ-1"'
assert_not_grep fetch_no_live_input "skills/jira-fetch/SKILL.md" "(live|real) invocation string"
assert_grep_start_task start_score "fetch-failure-stops"
assert_grep cpr_score "skills/create-pr/SKILL.md" "trajectory-cases.py score"
assert_grep cpr_case "skills/create-pr/SKILL.md" "create-pr-draft-never-merge"
assert_grep cpr_before_ready "skills/create-pr/SKILL.md" "before.*gh pr ready|before applying"
assert_grep cpr_after_ask "skills/create-pr/SKILL.md" "after.*Pipeline finale"
assert_grep cpr_four_tokens "skills/create-pr/SKILL.md" "keep_draft,ready,keep_draft_jira,ready_jira"
assert_grep cpr_two_token_case "skills/create-pr/SKILL.md" "create-pr-draft-never-merge-no-jira"
assert_not_grep cpr_no_skip_two_token "skills/create-pr/SKILL.md" "skip score because this case does not apply"
assert_grep cpr_observe_pr_state "skills/create-pr/SKILL.md" 'gh pr view.*--json isDraft,state'
assert_grep cpr_record_ready "skills/create-pr/SKILL.md" 'record end.*--pull-request ready'
assert_grep cpr_skip_empty_urls "skills/create-pr/SKILL.md" 'no pull request URL|empty.*observation|no opened pull request'
assert_grep cpr_open_required "skills/create-pr/SKILL.md" 'state.*OPEN|OPEN.*isDraft'
assert_grep cpr_merged_action "skills/create-pr/SKILL.md" 'merge-pull-request'
assert_grep cpr_skip_review_like "skills/create-pr/SKILL.md" 'already Review-like.*skip score|skip score.*already Review-like'
assert_grep cpr_skip_unknown_jira "skills/create-pr/SKILL.md" 'jira_status.*In Progress|skip score.*jira_status'
assert_grep cpr_progress_only_when_scoring "skills/create-pr/SKILL.md" '--jira-status "In Progress".*only when scoring'
assert_grep_start_task start_pass_status "jira_status"
assert_grep dogfood "docs/superpowers/dogfood/jira-ac-router-finale-checklist.md" "trajectory-wiring-test.sh"
assert_grep readme "README.md" "fetch-failure-stops"
assert_grep hitl_heading "skills/hitl-choice/references/presets.md" "### Trajectory fail"
assert_grep token_gen "skills/hitl-choice/references/presets.md" '`generalize`'
assert_grep token_skip "skills/hitl-choice/references/presets.md" '`skip`'
assert_grep fetch_ask "skills/jira-fetch/SKILL.md" "Trajectory fail"
assert_grep cpr_ask "skills/create-pr/SKILL.md" "Trajectory fail"
assert_grep capture_fail "commands/lgt-capture-escape.md" "FAIL "
assert_grep readme_gen "evals/trajectories/README.md" "generalize"
assert_grep readme_human_confirm "evals/trajectories/README.md" "wait for the human to confirm.*before.*git commit"
assert_grep readme_show_json "evals/trajectories/README.md" "[Ss]how.*validated case JSON|[Dd]isplay.*validated case JSON"
assert_not_grep readme_no_diff_alt "evals/trajectories/README.md" "case JSON or"
assert_grep fetch_show_json "skills/jira-fetch/SKILL.md" "[Ss]how.*validated case JSON|[Dd]isplay.*validated case JSON"
assert_not_grep fetch_no_diff_alt "skills/jira-fetch/SKILL.md" "case JSON or"
assert_grep cpr_show_json "skills/create-pr/SKILL.md" "[Ss]how.*validated case JSON|[Dd]isplay.*validated case JSON"
assert_not_grep cpr_no_diff_alt "skills/create-pr/SKILL.md" "case JSON or"

assert_grep score_skill_exists "skills/trajectory-score/SKILL.md" "trajectory-cases.py score"
assert_grep score_skill_fail "skills/trajectory-score/SKILL.md" "Trajectory fail"
assert_grep score_session "skills/trajectory-score/SKILL.md" "session-full|session-fast|session-issue"
assert_grep judge_skill "skills/trajectory-judge/SKILL.md" "invent-business-facts"
assert_grep judge_archaeology "skills/trajectory-judge/SKILL.md" "archaeology-in-decision-docs"
assert_grep judge_not_developer "skills/trajectory-judge/SKILL.md" "csp-software-developer"
assert_grep judge_re_score "skills/trajectory-judge/SKILL.md" "record action"
assert_grep judge_agent "agents/csp-trajectory-judge.md" "csp-trajectory-judge"

assert_grep_start_task route_unknown "route-unknown-asks-human"
assert_grep_start_task route_feature "route-feature-to-full"
assert_grep_start_task route_bug "route-bug-to-issue"
assert_grep_start_task fast_bug "fast-bug-asks-human"
assert_grep_start_task full_e2e "full-happy-path"
assert_grep_start_task fast_e2e "fast-skips-plan-layer"
assert_grep story_stays "commands/lgt-start-issue-task.md" "start-issue-story-stays-issue"
assert_grep issue_e2e "commands/lgt-start-issue-task.md" "issue-happy-path"
assert_grep review_fixes "skills/finish-plan/SKILL.md" "review-gate-fixes-to-build"
assert_grep critic_case "skills/implementation-critic/SKILL.md" "critic-blocks-flawed-plan"
assert_grep critic_cmd "commands/lgt-critique-plan.md" "critic-blocks-flawed-plan"
assert_grep capture_typical "commands/lgt-capture-escape.md" "capture-escape-no-review"
assert_grep capture_promote "commands/lgt-capture-escape.md" "capture-escape-promote-new-gate"
assert_grep tech_spec_case "skills/tech-spec/SKILL.md" "tech-spec-no-invented-facts"
assert_grep tech_spec_judge "skills/tech-spec/SKILL.md" "trajectory-judge"
assert_grep write_spec_case "commands/lgt-write-tech-spec.md" "tech-spec-no-invented-facts"
assert_grep clean_case "skills/clean-decision-docs/SKILL.md" "clean-revise-no-archaeology"
assert_grep clean_judge "skills/clean-decision-docs/SKILL.md" "trajectory-judge"
assert_grep create_pr_session "skills/create-pr/SKILL.md" "session-"
assert_grep install_no_evals "scripts/install-to-project.sh" "evals"
assert_not_grep install_copy_evals "scripts/install-to-project.sh" 'link_or_copy.*evals|cp .*evals/'

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FETCH_LEDGER="$TMP/fetch-failure-stops.json"
CREATE_PR_LEDGER="$TMP/create-pr-draft-never-merge.json"

python3 "$ROOT/scripts/trajectory-cases.py" record init \
  --ledger "$FETCH_LEDGER" --case-id fetch-failure-stops \
  --invocation "/lgt-start-task PROJ-1" --fetch fail
python3 "$ROOT/scripts/trajectory-cases.py" record stage \
  --ledger "$FETCH_LEDGER" jira-fetch
python3 "$ROOT/scripts/trajectory-cases.py" record artifact \
  --ledger "$FETCH_LEDGER" --kind report --name stop-paste-ticket
python3 "$ROOT/scripts/trajectory-cases.py" record dump --ledger "$FETCH_LEDGER"
fetch_score="$(
  python3 "$ROOT/scripts/trajectory-cases.py" score \
    --kit-root "$ROOT" --run "$FETCH_LEDGER"
)"
echo "$fetch_score"
if [[ "$fetch_score" != *"PASS fetch-failure-stops"* ]]; then
  echo "FAIL fetch executable score did not pass" >&2
  exit 1
fi

python3 "$ROOT/scripts/trajectory-cases.py" record init \
  --ledger "$CREATE_PR_LEDGER" --case-id create-pr-draft-never-merge \
  --invocation "skill create-pr" --fetch ok --jira-class feature
python3 "$ROOT/scripts/trajectory-cases.py" record stage \
  --ledger "$CREATE_PR_LEDGER" create-pr
python3 "$ROOT/scripts/trajectory-cases.py" record stage \
  --ledger "$CREATE_PR_LEDGER" pipeline-finale-hitl
python3 "$ROOT/scripts/trajectory-cases.py" record artifact \
  --ledger "$CREATE_PR_LEDGER" --kind github --name draft-pull-request
python3 "$ROOT/scripts/trajectory-cases.py" record gate \
  --ledger "$CREATE_PR_LEDGER" --gate pipeline-finale \
  --tokens keep_draft,ready,keep_draft_jira,ready_jira
python3 "$ROOT/scripts/trajectory-cases.py" record end \
  --ledger "$CREATE_PR_LEDGER" --pull-request draft \
  --review-report absent --jira-status "In Progress"
python3 "$ROOT/scripts/trajectory-cases.py" record dump --ledger "$CREATE_PR_LEDGER"
create_pr_score="$(
  python3 "$ROOT/scripts/trajectory-cases.py" score \
    --kit-root "$ROOT" --run "$CREATE_PR_LEDGER"
)"
echo "$create_pr_score"
if [[ "$create_pr_score" != *"PASS create-pr-draft-never-merge"* ]]; then
  echo "FAIL create-pr executable score did not pass" >&2
  exit 1
fi

NO_JIRA_LEDGER="$TMP/create-pr-draft-never-merge-no-jira.json"
python3 "$ROOT/scripts/trajectory-cases.py" record init \
  --ledger "$NO_JIRA_LEDGER" --case-id create-pr-draft-never-merge-no-jira \
  --invocation "skill create-pr" --fetch skip
python3 "$ROOT/scripts/trajectory-cases.py" record stage \
  --ledger "$NO_JIRA_LEDGER" create-pr
python3 "$ROOT/scripts/trajectory-cases.py" record stage \
  --ledger "$NO_JIRA_LEDGER" pipeline-finale-hitl
python3 "$ROOT/scripts/trajectory-cases.py" record artifact \
  --ledger "$NO_JIRA_LEDGER" --kind github --name draft-pull-request
python3 "$ROOT/scripts/trajectory-cases.py" record gate \
  --ledger "$NO_JIRA_LEDGER" --gate pipeline-finale \
  --tokens keep_draft,ready
python3 "$ROOT/scripts/trajectory-cases.py" record end \
  --ledger "$NO_JIRA_LEDGER" --pull-request draft \
  --review-report absent --jira-status null
python3 "$ROOT/scripts/trajectory-cases.py" record dump --ledger "$NO_JIRA_LEDGER"
no_jira_score="$(
  python3 "$ROOT/scripts/trajectory-cases.py" score \
    --kit-root "$ROOT" --run "$NO_JIRA_LEDGER"
)"
echo "$no_jira_score"
if [[ "$no_jira_score" != *"PASS create-pr-draft-never-merge-no-jira"* ]]; then
  echo "FAIL create-pr no-jira executable score did not pass" >&2
  exit 1
fi

echo "ALL PASS"
