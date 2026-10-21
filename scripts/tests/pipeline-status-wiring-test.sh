#!/usr/bin/env bash
# Lightweight wiring contract for pipeline orientation surfaces.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=lib-assert.sh
source "$(dirname "$0")/lib-assert.sh"
fail=0

assert_contains() {
  local name="$1" path="$2" needle="$3"
  if grep -F -q "$needle" "$path"; then
    echo "OK   $name"
  else
    echo "FAIL $name: [$needle] not in ${path#$ROOT/}" >&2
    fail=1
  fi
}

assert_file() {
  local name="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "OK   $name"
  else
    echo "FAIL $name: missing ${path#$ROOT/}" >&2
    fail=1
  fi
}

assert_contains hitl_mentions_pipeline_status "$ROOT/skills/hitl-choice/SKILL.md" "pipeline-status"
assert_file command_pipeline_status_exists "$ROOT/commands/lgt-pipeline-status.md"
assert_grep_start_task start_task_orientation "/lgt-pipeline-status"
assert_grep_start_task start_task_strip "orientation strip"
assert_file skill_pipeline_status_exists "$ROOT/skills/pipeline-status/SKILL.md"
assert_file resolver_exists "$ROOT/scripts/pipeline-status.sh"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
