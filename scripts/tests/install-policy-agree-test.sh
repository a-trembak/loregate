#!/usr/bin/env bash
# Policy agreement gate for lgt install / update.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAIL=0

assert_eq() {
  local name="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then
    echo "OK   $name"
  else
    echo "FAIL $name: want='$want' got='$got'" >&2
    FAIL=1
  fi
}

assert_grep() {
  local name="$1" file="$2" pat="$3"
  if grep -qE "$pat" "$ROOT/$file"; then
    echo "OK   $name"
  else
    echo "FAIL $name: /$pat/ not in $file" >&2
    FAIL=1
  fi
}

assert_file() {
  local name="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "OK   $name"
  else
    echo "FAIL $name: missing $path" >&2
    FAIL=1
  fi
}

assert_grep help_agree "scripts/install-to-project.sh" "agree-policy"
assert_grep help_i_agree "scripts/install-to-project.sh" "i-agree"
assert_grep help_env "scripts/install-to-project.sh" "LGT_AGREE_POLICY|CSP_AGREE_POLICY"
assert_grep cli_help "bin/lgt" "agree-policy"
assert_grep hasher "scripts/csp-policy-hash.sh" "PRIVACY.md"
assert_grep name_opts "docs/legal/NAME-OPTIONS.md" "a-trembak/loregate"
assert_grep readme_agree "README.md" "agree-policy"

HASH="$("$ROOT/scripts/csp-policy-hash.sh" --kit-root "$ROOT")"
assert_eq hash_len "64" "${#HASH}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
PROJECT="$TMP/proj"
mkdir -p "$FAKE_HOME" "$PROJECT/.git"
git -C "$PROJECT" init -q

# Non-interactive without flag → abort
set +e
OUT="$(HOME="$FAKE_HOME" "$ROOT/scripts/install-to-project.sh" "$PROJECT" --skip-third-party-skills 2>&1)"
RC=$?
set -e
if [[ "$RC" -ne 0 ]] && echo "$OUT" | grep -q "agree-policy"; then
  echo "OK   refuse_without_agree"
else
  echo "FAIL refuse_without_agree rc=$RC out=$OUT" >&2
  FAIL=1
fi
if [[ -f "$PROJECT/.cursor/lgt-policy-accepted" || -f "$FAKE_HOME/.cursor/lgt-policy-accepted" ]]; then
  echo "FAIL marker_should_not_exist_yet" >&2
  FAIL=1
else
  echo "OK   no_marker_before_agree"
fi

# --agree-policy writes project + user markers
if HOME="$FAKE_HOME" "$ROOT/scripts/install-to-project.sh" "$PROJECT" --agree-policy --skip-third-party-skills >/dev/null; then
  echo "OK   install_with_agree"
else
  echo "FAIL install_with_agree" >&2
  FAIL=1
fi
assert_file project_marker "$PROJECT/.cursor/lgt-policy-accepted"
assert_file user_marker_from_project "$FAKE_HOME/.cursor/lgt-policy-accepted"
GOT_HASH="$(awk -F= '/^policy_hash=/{print $2; exit}' "$PROJECT/.cursor/lgt-policy-accepted")"
assert_eq marker_hash "$HASH" "$GOT_HASH"
grep -q '^accepted_at=' "$PROJECT/.cursor/lgt-policy-accepted" && echo "OK   marker_accepted_at" || {
  echo "FAIL marker_accepted_at" >&2
  FAIL=1
}
grep -q '^agree_via=flag$' "$PROJECT/.cursor/lgt-policy-accepted" && echo "OK   marker_agree_via" || {
  echo "FAIL marker_agree_via" >&2
  FAIL=1
}
grep -q '^policy_docs=PRIVACY.md,TERMS.md,DISCLAIMER.md,NOTICE.md' "$PROJECT/.cursor/lgt-policy-accepted" && echo "OK   marker_docs" || {
  echo "FAIL marker_docs" >&2
  FAIL=1
}
grep -q '^kit_commit=' "$PROJECT/.cursor/lgt-policy-accepted" && echo "OK   marker_kit_commit" || {
  echo "FAIL marker_kit_commit" >&2
  FAIL=1
}

# Second install without flag succeeds (hash match)
if HOME="$FAKE_HOME" "$ROOT/scripts/install-to-project.sh" "$PROJECT" --skip-third-party-skills >/dev/null; then
  echo "OK   reinstall_skips_prompt"
else
  echo "FAIL reinstall_skips_prompt" >&2
  FAIL=1
fi

# Stale project + valid user → refresh project from prior-user
echo "policy_hash=deadbeef" >"$PROJECT/.cursor/lgt-policy-accepted"
echo "policy_hash=deadbeef" >"$PROJECT/.cursor/csp-policy-accepted"
if HOME="$FAKE_HOME" "$ROOT/scripts/install-to-project.sh" "$PROJECT" --skip-third-party-skills >/dev/null; then
  echo "OK   prior_user_seeds_project"
else
  echo "FAIL prior_user_seeds_project" >&2
  FAIL=1
fi
GOT2="$(awk -F= '/^policy_hash=/{print $2; exit}' "$PROJECT/.cursor/lgt-policy-accepted")"
assert_eq prior_user_hash "$HASH" "$GOT2"
grep -q '^agree_via=prior-user$' "$PROJECT/.cursor/lgt-policy-accepted" && echo "OK   prior_user_via" || {
  echo "FAIL prior_user_via" >&2
  FAIL=1
}

# --i-agree alias + user-only marker
USER_HOME="$TMP/home2"
mkdir -p "$USER_HOME"
if HOME="$USER_HOME" "$ROOT/scripts/install-to-project.sh" --user-only --i-agree --skip-third-party-skills >/dev/null; then
  echo "OK   user_only_i_agree"
else
  echo "FAIL user_only_i_agree" >&2
  FAIL=1
fi
assert_file user_marker "$USER_HOME/.cursor/lgt-policy-accepted"

# Env var path
USER_HOME3="$TMP/home3"
mkdir -p "$USER_HOME3"
if HOME="$USER_HOME3" CSP_AGREE_POLICY=1 "$ROOT/scripts/install-to-project.sh" --user-only --skip-third-party-skills >/dev/null; then
  echo "OK   env_agree"
else
  echo "FAIL env_agree" >&2
  FAIL=1
fi

# Both markers stale → refuse
STALE_HOME="$TMP/home_stale"
STALE_PROJ="$TMP/proj_stale"
mkdir -p "$STALE_HOME/.cursor" "$STALE_PROJ/.git" "$STALE_PROJ/.cursor"
git -C "$STALE_PROJ" init -q
echo "policy_hash=deadbeef" >"$STALE_HOME/.cursor/lgt-policy-accepted"
echo "policy_hash=deadbeef" >"$STALE_HOME/.cursor/csp-policy-accepted"
echo "policy_hash=deadbeef" >"$STALE_PROJ/.cursor/lgt-policy-accepted"
echo "policy_hash=deadbeef" >"$STALE_PROJ/.cursor/csp-policy-accepted"
set +e
OUT2="$(HOME="$STALE_HOME" "$ROOT/scripts/install-to-project.sh" "$STALE_PROJ" --skip-third-party-skills 2>&1)"
RC2=$?
set -e
if [[ "$RC2" -ne 0 ]] && echo "$OUT2" | grep -q "agree-policy"; then
  echo "OK   stale_hash_refuses"
else
  echo "FAIL stale_hash_refuses rc=$RC2 out=$OUT2" >&2
  FAIL=1
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED" >&2
  exit 1
fi
echo "ALL PASS"
