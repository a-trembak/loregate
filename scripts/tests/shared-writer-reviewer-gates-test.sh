#!/usr/bin/env bash
# Writers (software-developer / bug-fixer) and reviewer phases must point at the
# same engineer-review checklist paths — no parallel prose bodies.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0

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
    echo "FAIL $name: /$pattern/ still in $path (must load shared checklist)" >&2
    fail=1
  else
    echo "OK   $name"
  fi
}

assert_stub_points() {
  local name="$1" stub="$2" target="$3"
  if grep -F -q "$target" "$ROOT/$stub"; then
    echo "OK   $name"
  else
    echo "FAIL $name: stub $stub missing pointer to $target" >&2
    fail=1
  fi
}

# Canonical checklists exist
assert_grep repo_checklist_exists "skills/engineer-review/references/jpa-repository-result-checklist.md" "RT1"
assert_grep criteria_checklist_exists "skills/engineer-review/references/jpa-criteria-checklist.md" "J3"
assert_grep criteria_j4 "skills/engineer-review/references/jpa-criteria-checklist.md" "J4"
assert_grep biz_tests "skills/engineer-review/references/business-logic-tests-checklist.md" "T1"
assert_grep security "skills/engineer-review/references/security-hardening-checklist.md" "S1–S11"

# Developer + bug-fixer + review-logic share checklist basenames
for path in \
  skills/software-developer/SKILL.md \
  agents/csp-software-developer.md \
  skills/bug-fix/SKILL.md \
  agents/csp-bug-fixer.md \
  agents/csp-review-logic.md
do
  assert_grep "shared_jpa_repo_${path##*/}" "$path" "jpa-repository-result-checklist\\.md"
done

for path in \
  skills/software-developer/SKILL.md \
  agents/csp-software-developer.md \
  skills/bug-fix/SKILL.md \
  agents/csp-bug-fixer.md \
  agents/csp-review-logic.md
do
  assert_grep "shared_jpa_criteria_${path##*/}" "$path" "jpa-criteria-checklist\\.md"
done

# Developer must not treat the old patterns paths as the load target in the spine
# (stubs may still exist for discoverability).
assert_grep dev_skill_loads_checklist "skills/software-developer/SKILL.md" \
  "engineer-review/references/jpa-repository-result-checklist"
assert_grep dev_skill_loads_criteria "skills/software-developer/SKILL.md" \
  "engineer-review/references/jpa-criteria-checklist"
assert_no_grep dev_agent_no_patterns_load "agents/csp-software-developer.md" \
  "software-developer/references/jpa-repository-result-patterns\\.md"
assert_no_grep dev_agent_no_criteria_patterns_load "agents/csp-software-developer.md" \
  "software-developer/references/jpa-criteria-patterns\\.md"

# Stubs redirect to the shared checklists
assert_stub_points stub_repo \
  "skills/software-developer/references/jpa-repository-result-patterns.md" \
  "jpa-repository-result-checklist.md"
assert_stub_points stub_criteria \
  "skills/software-developer/references/jpa-criteria-patterns.md" \
  "jpa-criteria-checklist.md"

# Stubs must stay thin (no duplicate WRONG/CORRECT bodies)
for stub in \
  skills/software-developer/references/jpa-repository-result-patterns.md \
  skills/software-developer/references/jpa-criteria-patterns.md
do
  lines="$(wc -l <"$ROOT/$stub" | tr -d ' ')"
  if [[ "$lines" -le 12 ]]; then
    echo "OK   stub_thin_${stub##*/}"
  else
    echo "FAIL stub_thin_${stub##*/}: expected ≤12 lines, got $lines" >&2
    fail=1
  fi
done

# Logic phase documents J1–J4 after writer merge
assert_grep logic_j1_j4 "agents/csp-review-logic.md" "J1–J4"

if [[ "$fail" -ne 0 ]]; then
  echo "FAILED" >&2
  exit 1
fi
echo "ALL PASS"
