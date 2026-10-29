#!/usr/bin/env bash
# Contract: Enable Figma MCP HITL when Figma tools are missing from the session.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
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

assert_grep preset_heading "skills/hitl-choice/references/presets.md" "### Enable Figma MCP"
assert_grep token_enabled "skills/hitl-choice/references/presets.md" '`figma_enabled`'
assert_grep token_skip "skills/hitl-choice/references/presets.md" '`skip_figma_mcp`'
assert_grep customize_hint "skills/hitl-choice/references/presets.md" "Customize"
assert_grep not_oauth "skills/hitl-choice/references/presets.md" "not.*OAuth|not OAuth"
assert_grep paste_trigger "skills/hitl-choice/references/presets.md" "pasted Figma URLs|Unsolicited Figma URL|as soon as URLs"
assert_grep probe_hint "skills/hitl-choice/references/presets.md" "GetDynamicTools|live tool catalog"
assert_grep er_wire "skills/engineer-review/SKILL.md" "Enable Figma MCP"
assert_grep er_paste "skills/engineer-review/SKILL.md" "as soon as Figma URLs|URLs appear"
assert_grep sd_wire "skills/software-developer/SKILL.md" "Enable Figma MCP"
assert_grep sd_paste "skills/software-developer/SKILL.md" "pastes links|chat paste"
assert_grep finish_wire "skills/finish-plan/SKILL.md" "Enable Figma MCP"
assert_grep phase_gate "agents/csp-review-figma-markup.md" "figma_mcp_disabled"
assert_grep hitl_skill "skills/hitl-choice/SKILL.md" "figma_enabled"
assert_grep hitl_paste "skills/hitl-choice/SKILL.md" "Unsolicited Figma URL|as soon as URLs|when they arrive"
assert_grep rule_tokens "rules/hitl-askquestion.mdc" "figma_enabled"
assert_grep multi_wire "agents/csp-multi-repo-supervisor.md" "Enable Figma MCP"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
