#!/usr/bin/env bash
# Contract: engineer-review orchestrator context budget — always vs phase-only
# vs merge-only; never instruct loading checklist bodies into orch context;
# phases with triggers still open full checklists.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
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

assert_absent() {
  local name="$1" path="$2" pattern="$3"
  if grep -E -q "$pattern" "$ROOT/$path"; then
    echo "FAIL $name: /$pattern/ still in $path" >&2
    fail=1
  else
    echo "OK   $name"
  fi
}

SKILL="skills/engineer-review/SKILL.md"
ORCH="agents/csp-engineer-reviewer.md"
LOGIC="agents/csp-review-logic.md"
ARCH="agents/csp-review-architecture.md"
SECURITY="agents/csp-review-security.md"

assert_file "$SKILL"
assert_file "$ORCH"
assert_file "skills/engineer-review/references/phase-protocol.md"
assert_file "skills/engineer-review/references/phase-protocol-detail.md"
assert_file "skills/engineer-review/references/skill-map-orch.md"
assert_file "skills/engineer-review/references/review-learn-capture.md"
assert_file "skills/engineer-review/references/graphify-r3-force-include.md"
assert_file "docs/superpowers/specs/2026-09-09-slim-engineer-review-context-design.md"
assert_file "docs/superpowers/dogfood/slim-engineer-review-context-checklist.md"

# Context budget section lists the three load classes
assert_grep budget_heading "$SKILL" "## Context budget"
assert_grep budget_always "$SKILL" "Always-on"
assert_grep budget_phase "$SKILL" "Phase-only"
assert_grep budget_merge "$SKILL" "Merge-only"

# Tiny-diff skip + skill profile / load levels stay documented
assert_grep tiny_diff_skip "skills/engineer-review/references/phase-protocol.md" "Tiny-diff heuristic phase skip"
assert_grep skill_classes "skills/engineer-review/references/skill-map.md" "## Skill classes"
assert_grep load_levels "skills/engineer-review/references/skill-map.md" "## Load levels"
assert_grep skill_profile "skills/engineer-review/references/skill-map.md" "## Skill profile"
assert_grep hitl_lazy "skills/hitl-choice/SKILL.md" "lazy load"
assert_file "skills/hitl-choice/references/presets.md"

# Always-on files named in budget
assert_grep always_phase_proto "$SKILL" "phase-protocol\\.md"
assert_grep always_skill_map_orch "$SKILL" "skill-map-orch\\.md"
assert_grep always_graphify "$SKILL" "graphify-protocol\\.md"
assert_grep always_learn "$SKILL" "review-learn-protocol\\.md"

# Merge-only pack named
assert_grep merge_feedback "$SKILL" "feedback-format\\.md"
assert_grep merge_evidence "$SKILL" "evidence-gate\\.md"
assert_grep merge_forbidden "$SKILL" "forbidden-formats\\.md"
assert_grep merge_lazy "$SKILL" "merge/report|Merge-only|lazy"

# Orchestrator must NOT instruct loading checklist bodies into orch context
CHECKLISTS=(
  interaction-replay-checklist
  auth-rtk-checklist
  figma-markup-checklist
  responsive-layout-checklist
  null-safety-checklist
  jpa-criteria-checklist
  jpa-repository-result-checklist
  styling-checklist
  learned-misses
  security-hardening-checklist
)

for base in "${CHECKLISTS[@]}"; do
  # Forbid "read/load/open <file> into orchestrator" style; allow "phases … open" / "do not load"
  if grep -E -i "(read|load|open|paste).{0,40}${base}" "$ROOT/$SKILL" "$ROOT/$ORCH" \
    | grep -E -iv "(do not|never|not|phase|phases|review-learn|point|owned|except)" \
    | grep -E -q "${base}"; then
    echo "FAIL orch_no_load_body_${base}: orchestrator still instructs loading ${base} body" >&2
    grep -E -i "(read|load|open|paste).{0,40}${base}" "$ROOT/$SKILL" "$ROOT/$ORCH" >&2 || true
    fail=1
  else
    echo "OK   orch_no_load_body_${base}"
  fi
done

# Agent lazy-loads feedback pack; does not require it in preconditions at start
assert_grep orch_lazy_merge "$ORCH" "Merge / report|lazy load|lazy"
assert_absent orch_precond_no_feedback_start "$ORCH" "Preconditions[\\s\\S]{0,800}feedback-format\\.md"
# Abort must not require merge pack
assert_grep abort_no_pack "$SKILL" "Abort does \\*\\*not\\*\\* load|abort.*not.*feedback|must not load this pack"

# Phase agents with triggers still require opening full checklist
assert_grep logic_open_replay "$LOGIC" "open the full checklist"
assert_grep logic_replay_path "$LOGIC" "interaction-replay-checklist\\.md"
assert_grep logic_open_null "$LOGIC" "null-safety-checklist\\.md"
assert_grep logic_open_jpa_result "$LOGIC" "jpa-repository-result-checklist\\.md"
assert_grep arch_open_replay "$ARCH" "open the full checklist"
assert_grep arch_replay_path "$ARCH" "interaction-replay-checklist\\.md"
assert_grep security_open_checklist "$SECURITY" "open the full checklist"
assert_grep security_checklist_path "$SECURITY" "security-hardening-checklist\\.md"

# Canonical spine lives in skill; agent points at it
assert_grep skill_canonical "$SKILL" "canonical spine"
assert_grep agent_pointer "$ORCH" "Canonical spine|skill \\*\\*\`engineer-review\`\\*\\*"

# Checklist bodies still exist (do not delete)
for base in \
  interaction-replay-checklist \
  auth-rtk-checklist \
  figma-markup-checklist \
  responsive-layout-checklist \
  null-safety-checklist \
  jpa-criteria-checklist \
  jpa-repository-result-checklist \
  styling-checklist \
  security-hardening-checklist
do
  assert_file "skills/engineer-review/references/${base}.md"
done
assert_file "skills/engineer-review/references/learned-misses.md"

# JPA repository result-type wiring (RT1 / jpa_result_type)
assert_file "skills/engineer-review/references/jpa-repository-result-checklist.md"
assert_grep phase_proto_jpa_result "skills/engineer-review/references/phase-protocol.md" \
  "jpa_result_type: matched\\|mismatched\\|skipped\\|n/a"
assert_grep developer_jpa_repo_checklist "skills/software-developer/SKILL.md" \
  "jpa-repository-result-checklist\\.md"
assert_grep developer_jpa_criteria_checklist "skills/software-developer/SKILL.md" \
  "jpa-criteria-checklist\\.md"
assert_grep bugfix_jpa_checklist "skills/bug-fix/SKILL.md" \
  "jpa-repository-result-checklist\\.md"
assert_grep bugfix_jpa_criteria_checklist "skills/bug-fix/SKILL.md" \
  "jpa-criteria-checklist\\.md"

# Call-graph load routing: every listed phase agent must carry the canonical Follow
# sentence so models load phase-protocol-detail (neighbors / call graph / graphify walk).
FOLLOW_SENTENCE='Follow skills/engineer-review/references/phase-protocol.md and phase-protocol-detail.md.'
FOLLOW_AGENTS=(
  agents/csp-review-patterns.md
  agents/csp-review-deadcode.md
  agents/csp-review-simplify.md
  agents/csp-review-performance.md
  agents/csp-review-security.md
  agents/csp-review-figma-markup.md
  agents/csp-review-cross-repo.md
  agents/csp-review-architecture.md
)
for path in "${FOLLOW_AGENTS[@]}"; do
  if grep -F -q "$FOLLOW_SENTENCE" "$ROOT/$path"; then
    echo "OK   follow_sentence_${path##*/}"
  else
    echo "FAIL follow_sentence_${path##*/}: exact Follow sentence missing" >&2
    fail=1
  fi
done

# Dispatch hardening: parent Task prompts must require loading phase-protocol-detail.
# engineer-reviewer: need both "Task prompt" and "phase-protocol-detail" (weak
# parenthetical alone is insufficient — it already contained the detail path).
assert_grep orch_dispatch_task_prompt "$ORCH" "Task prompt"
assert_grep orch_dispatch_detail "$ORCH" "phase-protocol-detail"
if grep -E -q "Task prompt" "$ROOT/$ORCH" && grep -E -q "phase-protocol-detail" "$ROOT/$ORCH"; then
  echo "OK   orch_dispatch_task_prompt_and_detail"
else
  echo "FAIL orch_dispatch_task_prompt_and_detail: need Task prompt + phase-protocol-detail" >&2
  fail=1
fi

PR_REV="agents/csp-pr-reviewer.md"
MULTI="agents/csp-multi-repo-supervisor.md"
assert_file "$PR_REV"
assert_file "$MULTI"
assert_grep pr_dispatch_detail "$PR_REV" "phase-protocol-detail"
assert_grep multi_cross_repo_detail "$MULTI" "phase-protocol-detail"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
