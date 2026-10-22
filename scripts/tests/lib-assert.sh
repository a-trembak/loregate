# Shared assert helpers for kit contract tests.
# Source from scripts/tests/*.sh after ROOT is set:
#   # shellcheck source=lib-assert.sh
#   source "$(dirname "$0")/lib-assert.sh"

assert_grep() {
  local name="$1" path="$2" pattern="$3"
  if grep -E -q -- "$pattern" "$ROOT/$path"; then
    echo "OK   $name"
  else
    echo "FAIL $name: /$pattern/ not in $path" >&2
    fail=1
  fi
}

assert_grep_any() {
  local name="$1" pattern="$2"
  shift 2
  local path
  for path in "$@"; do
    if grep -E -q -- "$pattern" "$ROOT/$path"; then
      echo "OK   $name"
      return 0
    fi
  done
  echo "FAIL $name: /$pattern/ not in $*" >&2
  fail=1
}

# Paths that together define /lgt-start-task after the thin-router split.
START_TASK_DOCS=(
  "commands/lgt-start-task.md"
  "commands/references/lgt-start-task-full.md"
  "commands/references/lgt-start-task-fast.md"
)

assert_grep_start_task() {
  local name="$1" pattern="$2"
  assert_grep_any "$name" "$pattern" "${START_TASK_DOCS[@]}"
}
