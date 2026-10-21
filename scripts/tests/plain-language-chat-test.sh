#!/usr/bin/env bash
# Contract checks: user-facing chat must use full words (no abbreviations).
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

assert_file "skills/plain-language-chat/SKILL.md"
assert_file "skills/plain-language-chat/references/en.md"
assert_file "skills/plain-language-chat/references/uk.md"
assert_file "rules/plain-language-chat.mdc"
assert_file "rules/pipeline-language-no-russian.mdc"

assert_grep rule_always_apply "rules/plain-language-chat.mdc" "alwaysApply: true"
assert_grep rule_full_words "rules/plain-language-chat.mdc" "full words"
assert_grep rule_loads_skill "rules/plain-language-chat.mdc" "plain-language-chat"
assert_grep rule_pipeline_lang "rules/plain-language-chat.mdc" "csp-pipeline-language"
assert_grep rule_no_russian "rules/plain-language-chat.mdc" "Never use Russian"
assert_grep skill_no_abbrev "skills/plain-language-chat/SKILL.md" "No abbreviations"
assert_grep skill_pull_request "skills/plain-language-chat/SKILL.md" "pull request"
assert_grep skill_human_in_the_loop "skills/plain-language-chat/SKILL.md" "human-in-the-loop"
assert_grep skill_full_sentences "skills/plain-language-chat/SKILL.md" "full sentences"
assert_grep skill_proposal_shape "skills/plain-language-chat/SKILL.md" "Proposal / Decision / status shape"
assert_grep skill_bans_noun_stacks "skills/plain-language-chat/SKILL.md" "Noun-phrase stacks"
assert_grep skill_bans_slash_join "skills/plain-language-chat/SKILL.md" "Alternatives joined only by"
assert_grep skill_reads_lang "skills/plain-language-chat/SKILL.md" "csp-pipeline-language"
assert_grep skill_refuses_russian "skills/plain-language-chat/SKILL.md" "Russian absolute lockout|impossible"
assert_grep skill_outside_pipeline "skills/plain-language-chat/SKILL.md" "outside this pipeline"
assert_grep skill_mid_session "skills/plain-language-chat/SKILL.md" "Mid-session switch"
assert_grep skill_uk_optional "skills/plain-language-chat/SKILL.md" "references/uk.md"
assert_grep rule_full_sentences "rules/plain-language-chat.mdc" "full sentences"
assert_grep rule_bans_fragment_stacks "rules/plain-language-chat.mdc" "noun-phrase stacks"
assert_grep rule_outside_chat "rules/plain-language-chat.mdc" "outside this pipeline"
assert_grep question_discipline_sentences "skills/tech-spec/references/question-discipline.md" "full sentences of trade-off"
assert_grep hitl_decision_prose_bar "skills/hitl-choice/references/presets.md" "Prose bar"
assert_grep hitl_pipeline_language "skills/hitl-choice/references/presets.md" "### Pipeline language"
assert_grep hitl_no_ru_option "skills/hitl-choice/references/presets.md" "Never invent \`ru\`|impossible|Never.*offer or accept Russian|never.*Russian"
assert_grep hitl_outside "skills/hitl-choice/references/presets.md" "outside this pipeline"
assert_grep hitl_brief_full_sentences "skills/hitl-choice/SKILL.md" "brief full sentences"
assert_grep tech_spec_agent_plain_language "agents/csp-tech-spec.md" "plain-language-chat"
assert_grep installer_copies_rule "scripts/install-to-project.sh" "plain-language-chat.mdc"
assert_grep installer_copies_ru_ban "scripts/install-to-project.sh" "pipeline-language-no-russian.mdc"
assert_grep installer_user_rules "scripts/install-to-project.sh" "[.]cursor/rules/plain-language-chat"
assert_grep humanizer_points_to_skill "skills/english-humanizer/SKILL.md" "plain-language-chat"
assert_grep reviewer_loads_skill "agents/csp-engineer-reviewer.md" "plain-language-chat"
assert_grep pr_reviewer_loads_skill "agents/csp-pr-reviewer.md" "plain-language-chat"
assert_grep readme_lists_skill "README.md" "plain-language-chat"
assert_grep_start_task start_task_asks_lang "Pipeline language"
assert_grep start_issue_asks_lang "commands/lgt-start-issue-task.md" "Pipeline language"

# Installer must drop the always-on rule into user-global and project rules.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
PROJECT="$TMP/app"
mkdir -p "$FAKE_HOME" "$PROJECT"
git -C "$PROJECT" init -q

HOME="$FAKE_HOME" "$ROOT/scripts/install-to-project.sh" --agree-policy --user-only --skip-third-party-skills >/dev/null
if [[ -f "$FAKE_HOME/.cursor/rules/plain-language-chat.mdc" ]]; then
  echo "OK   user-global rule installed"
else
  echo "FAIL user-global rule missing at $FAKE_HOME/.cursor/rules/plain-language-chat.mdc" >&2
  fail=1
fi
if [[ -f "$FAKE_HOME/.cursor/rules/pipeline-language-no-russian.mdc" ]]; then
  echo "OK   user-global Russian-ban rule installed"
else
  echo "FAIL user-global Russian-ban rule missing" >&2
  fail=1
fi
if [[ -d "$FAKE_HOME/.cursor/skills/plain-language-chat" || -L "$FAKE_HOME/.cursor/skills/plain-language-chat" ]]; then
  echo "OK   user-global skill installed"
else
  echo "FAIL user-global skill missing" >&2
  fail=1
fi

HOME="$FAKE_HOME" "$ROOT/scripts/install-to-project.sh" --agree-policy "$PROJECT" --skip-third-party-skills >/dev/null
if [[ -f "$PROJECT/.cursor/rules/plain-language-chat.mdc" ]]; then
  echo "OK   project rule installed"
else
  echo "FAIL project rule missing at $PROJECT/.cursor/rules/plain-language-chat.mdc" >&2
  fail=1
fi
if [[ -f "$PROJECT/.cursor/rules/pipeline-language-no-russian.mdc" ]]; then
  echo "OK   project Russian-ban rule installed"
else
  echo "FAIL project Russian-ban rule missing" >&2
  fail=1
fi
if [[ -f "$PROJECT/scripts/lgt-pipeline-language.sh" ]]; then
  echo "OK   project language helper installed"
else
  echo "FAIL project language helper missing" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
