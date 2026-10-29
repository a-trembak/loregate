#!/usr/bin/env bash
# Contract: UI and backend explanation rules ship with install (screen / business outcome first).
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
  if grep -E -q "$pattern" "$ROOT/$path" 2>/dev/null; then
    echo "OK   $name"
  else
    echo "FAIL $name: /$pattern/ not in $path" >&2
    fail=1
  fi
}

assert_file "rules/ui-explanations-human-language.mdc"
assert_file "rules/backend-logic-explanations-human-language.mdc"
assert_file "AGENTS.md"

assert_grep ui_always_apply "rules/ui-explanations-human-language.mdc" "alwaysApply: true"
assert_grep ui_sees_first "rules/ui-explanations-human-language.mdc" "what the human sees first"
assert_grep ui_no_slash_stacks "rules/ui-explanations-human-language.mdc" "jargon stacks joined by slashes"
assert_grep be_always_apply "rules/backend-logic-explanations-human-language.mdc" "alwaysApply: true"
assert_grep be_outcome_first "rules/backend-logic-explanations-human-language.mdc" "outcome a human or operator cares about first"
assert_grep be_no_slash_stacks "rules/backend-logic-explanations-human-language.mdc" "jargon stacks joined by slashes"
assert_grep agents_ui "AGENTS.md" "ui-explanations-human-language"
assert_grep agents_be "AGENTS.md" "backend-logic-explanations-human-language"
assert_grep installer_project_ui "scripts/install-to-project.sh" "ui-explanations-human-language[.]mdc"
assert_grep installer_project_be "scripts/install-to-project.sh" "backend-logic-explanations-human-language[.]mdc"
assert_grep installer_user_ui "scripts/install-to-project.sh" "[.]cursor/rules/ui-explanations-human-language"
assert_grep installer_user_be "scripts/install-to-project.sh" "[.]cursor/rules/backend-logic-explanations-human-language"
assert_grep readme_user_ui "README.md" "~/[.]cursor/rules/ui-explanations-human-language"
assert_grep readme_user_be "README.md" "~/[.]cursor/rules/backend-logic-explanations-human-language"
assert_grep readme_project_ui "README.md" "<project>/[.]cursor/rules/ui-explanations-human-language"
assert_grep readme_project_be "README.md" "<project>/[.]cursor/rules/backend-logic-explanations-human-language"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
PROJECT="$TMP/app"
mkdir -p "$FAKE_HOME" "$PROJECT"
git -C "$PROJECT" init -q

if ! HOME="$FAKE_HOME" "$ROOT/scripts/install-to-project.sh" --agree-policy --user-only --skip-third-party-skills >/dev/null; then
  echo "FAIL user-only install exited non-zero" >&2
  fail=1
elif [[ -f "$FAKE_HOME/.cursor/rules/ui-explanations-human-language.mdc" \
  && -f "$FAKE_HOME/.cursor/rules/backend-logic-explanations-human-language.mdc" ]]; then
  echo "OK   user-global UI and backend explanation rules installed"
else
  echo "FAIL user-global UI/backend explanation rules missing under $FAKE_HOME/.cursor/rules/" >&2
  fail=1
fi

if ! HOME="$FAKE_HOME" "$ROOT/scripts/install-to-project.sh" --agree-policy "$PROJECT" --skip-third-party-skills >/dev/null; then
  echo "FAIL project install exited non-zero" >&2
  fail=1
elif [[ -f "$PROJECT/.cursor/rules/ui-explanations-human-language.mdc" \
  && -f "$PROJECT/.cursor/rules/backend-logic-explanations-human-language.mdc" ]]; then
  echo "OK   project UI and backend explanation rules installed"
else
  echo "FAIL project UI/backend explanation rules missing under $PROJECT/.cursor/rules/" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
