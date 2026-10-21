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
assert_grep er_wire "skills/engineer-review/SKILL.md" "Enable Figma MCP"
assert_grep sd_wire "skills/software-developer/SKILL.md" "Enable Figma MCP"
assert_grep finish_wire "skills/finish-plan/SKILL.md" "Enable Figma MCP"
assert_grep hitl_skill "skills/hitl-choice/SKILL.md" "figma_enabled"
assert_grep rule_tokens "rules/hitl-askquestion.mdc" "figma_enabled"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
