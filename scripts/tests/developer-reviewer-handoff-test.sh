#!/usr/bin/env bash
# Contract: after software-developer (or bug-fixer) returns, the parent
# pipeline must wait and launch engineer-reviewer. Fire-and-forget dispatch
# is the bug this file guards.
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

assert_file "skills/start-build/SKILL.md"
assert_file "commands/lgt-start-build.md"
assert_file "skills/software-developer/SKILL.md"
assert_file "agents/csp-software-developer.md"
assert_file "agents/csp-verifier.md"
assert_file "commands/lgt-start-task.md"
assert_file "commands/lgt-start-issue-task.md"
assert_file "agents/csp-bug-fixer.md"

# start-build must wait for the developer Task and continue to finish-plan.
assert_grep start_build_wait "skills/start-build/SKILL.md" "Wait for"
assert_grep start_build_finish "skills/start-build/SKILL.md" "finish-plan"
assert_grep start_build_reviewer "skills/start-build/SKILL.md" "csp-engineer-reviewer"
assert_grep start_build_no_forget "skills/start-build/SKILL.md" "Fire-and-forget"
assert_grep start_build_cmd_wait "commands/lgt-start-build.md" "Wait for"
assert_grep start_build_cmd_finish "commands/lgt-start-build.md" "finish-plan"
assert_grep start_build_cmd_reviewer "commands/lgt-start-build.md" "csp-engineer-reviewer"

# Nested developer must return next_skill, not AskQuestion in the Task.
assert_grep dev_skill_next "skills/software-developer/SKILL.md" "next_skill"
assert_grep dev_skill_nested "skills/software-developer/SKILL.md" "nested Task"
assert_grep dev_skill_no_ask "skills/software-developer/SKILL.md" "AskQuestion"
assert_grep dev_skill_verifier "skills/software-developer/SKILL.md" "csp-verifier"
assert_grep dev_skill_verdict "skills/software-developer/SKILL.md" "verifier_verdict"
assert_grep dev_agent_next "agents/csp-software-developer.md" "next_skill"
assert_grep dev_agent_nested "agents/csp-software-developer.md" "nested Task"
assert_grep dev_agent_no_ask "agents/csp-software-developer.md" "AskQuestion"
assert_grep dev_agent_verifier "agents/csp-software-developer.md" "csp-verifier"

# Readonly independent verifier before handoff.
assert_grep verifier_readonly "agents/csp-verifier.md" "readonly: true"
assert_grep verifier_no_edit "agents/csp-verifier.md" "Never edits files|Do not edit files|readonly"
assert_grep verifier_verdicts "agents/csp-verifier.md" "verified"
assert_grep bug_skill_verifier "skills/bug-fix/SKILL.md" "csp-verifier"
assert_grep bug_agent_verifier "agents/csp-bug-fixer.md" "csp-verifier"

# Nested Task returns must stay compact (no full artifact paste into parent).
assert_grep tech_spec_short_return "agents/csp-tech-spec.md" "Do not.*paste the full tech-spec|parent return"
assert_grep developer_short_return "agents/csp-software-developer.md" "Do not.*paste full diffs|compact handoff"
assert_grep bug_fixer_short_return "agents/csp-bug-fixer.md" "Do not.*paste full diffs|compact handoff"
assert_grep critic_short_return "agents/csp-implementation-critic.md" "Do not.*paste the full plan|parent return"

# /lgt-start-task full: wait then finish-plan; fast: wait then engineer-reviewer.
assert_grep_start_task start_task_wait "Wait for"
assert_grep_start_task start_task_not_end "Do not treat dispatch as the end"
assert_grep_start_task start_task_fast_wait "mode:fast"
assert_grep_start_task start_task_fast_review "Wait for .*csp-software-developer|after .*returns"

# /lgt-start-issue-task: wait for bug-fixer then engineer-reviewer.
assert_grep issue_wait "commands/lgt-start-issue-task.md" "Wait for"
assert_grep issue_reviewer "commands/lgt-start-issue-task.md" "csp-engineer-reviewer"
assert_grep fixer_next "agents/csp-bug-fixer.md" "next_skill"
assert_grep fixer_nested "agents/csp-bug-fixer.md" "nested Task"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
