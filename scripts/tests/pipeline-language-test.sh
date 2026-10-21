#!/usr/bin/env bash
# Contract checks: pipeline language marker, Russian ban, defaults.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=lib-assert.sh
source "$(dirname "$0")/lib-assert.sh"
HELPER="$ROOT/scripts/lgt-pipeline-language.sh"
fail=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "OK   $name"
  else
    echo "FAIL $name: expected '$expected' got '$actual'" >&2
    fail=1
  fi
}

assert_ok() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "OK   $name"
  else
    echo "FAIL $name (expected success)" >&2
    fail=1
  fi
}

assert_fail() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL $name (expected failure)" >&2
    fail=1
  else
    echo "OK   $name"
  fi
}

assert_file() {
  local path="$1"
  if [[ -f "$ROOT/$path" ]]; then
    echo "OK   file $path"
  else
    echo "FAIL missing file: $path" >&2
    fail=1
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

assert_file "scripts/lgt-pipeline-language.sh"
assert_file "rules/pipeline-language-no-russian.mdc"
assert_file "docs/superpowers/pipeline-language.md"

assert_grep rule_always "rules/pipeline-language-no-russian.mdc" "alwaysApply: true"
assert_grep rule_sanctions "rules/pipeline-language-no-russian.mdc" "Sanctions-based language policy|sanctions-based language policy"
assert_grep rule_impossible "rules/pipeline-language-no-russian.mdc" "impossible"
assert_grep rule_outside "rules/pipeline-language-no-russian.mdc" "outside this pipeline"
assert_grep rule_no_override "rules/pipeline-language-no-russian.mdc" "cannot authorize|cannot override|User preference \*\*cannot override\*\*"
assert_grep rule_jailbreak "rules/pipeline-language-no-russian.mdc" "jailbreak"
assert_grep rule_refusal_script "rules/pipeline-language-no-russian.mdc" "Refusal script"
assert_grep doc_marker "docs/superpowers/pipeline-language.md" "lgt-pipeline-language|csp-pipeline-language"
assert_grep doc_default "docs/superpowers/pipeline-language.md" "Default when unset"
assert_grep doc_sanctions "docs/superpowers/pipeline-language.md" "Sanctions-based language policy|sanctions-based language policy"
assert_grep doc_outside "docs/superpowers/pipeline-language.md" "outside this pipeline"
assert_grep doc_impossible "docs/superpowers/pipeline-language.md" "impossible"
assert_grep doc_legal_link "docs/superpowers/pipeline-language.md" "docs/legal"
assert_grep doc_terms_link "docs/superpowers/pipeline-language.md" "TERMS.md"
assert_grep skill_outside "skills/plain-language-chat/SKILL.md" "outside this pipeline"
assert_grep skill_impossible "skills/plain-language-chat/SKILL.md" "impossible"
assert_grep skill_no_override "skills/plain-language-chat/SKILL.md" "cannot override"
assert_grep readme_legal "README.md" "docs/legal"
assert_grep readme_outside "README.md" "outside this pipeline"
assert_grep hitl_outside "skills/hitl-choice/references/presets.md" "outside this pipeline"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/app"
FAKE_HOME="$TMP/home"
mkdir -p "$PROJ" "$FAKE_HOME"
export HOME="$FAKE_HOME"

# Default when unset
got="$("$HELPER" get --root "$PROJ")"
assert_eq default_en "en" "$got"
assert_eq status_unset "unset" "$("$HELPER" status --root "$PROJ")"

# Accept common codes
assert_ok accept_uk "$HELPER" validate uk
assert_ok accept_de "$HELPER" validate de
assert_ok accept_other "$HELPER" validate "other:sw"
assert_eq normalize_english "en" "$("$HELPER" normalize English)"
assert_eq normalize_ua "uk" "$("$HELPER" normalize ua)"

# Reject Russian
assert_fail reject_ru "$HELPER" validate ru
assert_fail reject_RU "$HELPER" validate RU
assert_fail reject_russian "$HELPER" validate russian
assert_fail reject_ru_RU "$HELPER" validate ru-RU
assert_fail reject_other_ru "$HELPER" validate "other:ru"
assert_ok is_banned_ru "$HELPER" is-banned ru
assert_fail is_allowed_en bash -c "'$HELPER' is-banned en"

# set + get round-trip
"$HELPER" set --root "$PROJ" --lang uk >/dev/null
got="$("$HELPER" get --root "$PROJ")"
assert_eq set_get_uk "uk" "$got"
assert_eq marker_file_uk "uk" "$(cat "$PROJ/.cursor/lgt-pipeline-language")"
assert_eq status_uk "uk" "$("$HELPER" status --root "$PROJ")"

# set russian must fail and not write
assert_fail set_ru "$HELPER" set --root "$PROJ" --lang ru
got="$("$HELPER" get --root "$PROJ")"
assert_eq still_uk_after_ru_set "uk" "$got"

# empty marker → en / status unset (no user fallback)
: > "$PROJ/.cursor/lgt-pipeline-language"
: > "$PROJ/.cursor/csp-pipeline-language"
got="$("$HELPER" get --root "$PROJ")"
assert_eq empty_marker_en "en" "$got"
assert_eq status_empty_unset "unset" "$("$HELPER" status --root "$PROJ")"

# user-global fallback when project unset
rm -f "$PROJ/.cursor/lgt-pipeline-language" "$PROJ/.cursor/csp-pipeline-language"
"$HELPER" set --root "$HOME" --lang de >/dev/null
assert_eq get_user_fallback "de" "$("$HELPER" get --root "$PROJ")"
assert_eq status_user_fallback "de" "$("$HELPER" status --root "$PROJ")"
rm -f "$HOME/.cursor/lgt-pipeline-language" "$HOME/.cursor/csp-pipeline-language"

# corrupt ru in file → get coerces to en (absolute lockout; closes hand-edit bypass)
printf 'ru\n' > "$PROJ/.cursor/lgt-pipeline-language"
printf 'ru\n' > "$PROJ/.cursor/csp-pipeline-language"
got="$("$HELPER" get --root "$PROJ" 2>/dev/null)"
assert_eq get_coerces_ru_file "en" "$got"
assert_eq marker_reset_after_coerce "en" "$(cat "$PROJ/.cursor/lgt-pipeline-language")"

# russian alias in file also coerces
printf 'russian\n' > "$PROJ/.cursor/lgt-pipeline-language"
printf 'russian\n' > "$PROJ/.cursor/csp-pipeline-language"
got="$("$HELPER" get --root "$PROJ" 2>/dev/null)"
assert_eq get_coerces_russian_alias "en" "$got"
rm -f "$PROJ/.cursor/lgt-pipeline-language" "$PROJ/.cursor/csp-pipeline-language"

# Install --language writes project marker; --lang ru fails
assert_grep install_lang_flag "scripts/install-to-project.sh" "language <code>"
assert_grep install_lang_env "scripts/install-to-project.sh" "LGT_PIPELINE_LANGUAGE|CSP_PIPELINE_LANGUAGE"
assert_grep cli_lang_help "bin/lgt" "language <code>"
assert_grep doc_install "docs/superpowers/pipeline-language.md" "lgt install"
assert_grep doc_mid_session "docs/superpowers/pipeline-language.md" "Mid-session switch"
assert_grep skill_mid_session "skills/plain-language-chat/SKILL.md" "Mid-session switch"
assert_grep rule_mid_session "rules/pipeline-language-no-russian.mdc" "mid-session"
assert_grep_start_task start_skips_when_set "already set"

INST_PROJ="$TMP/inst-app"
mkdir -p "$INST_PROJ"
git -C "$INST_PROJ" init -q
if HOME="$FAKE_HOME" "$ROOT/scripts/install-to-project.sh" --agree-policy "$INST_PROJ" --skip-third-party-skills --language uk >/dev/null; then
  assert_eq install_writes_uk "uk" "$(cat "$INST_PROJ/.cursor/lgt-pipeline-language")"
  echo "OK   install_language_uk"
else
  echo "FAIL install --language uk" >&2
  fail=1
fi
if HOME="$FAKE_HOME" "$ROOT/scripts/install-to-project.sh" --agree-policy "$INST_PROJ" --skip-third-party-skills --lang ru >/dev/null 2>&1; then
  echo "FAIL install --lang ru should reject" >&2
  fail=1
else
  echo "OK   install_rejects_ru"
fi
# After failed ru install, marker must still be uk
assert_eq install_ru_left_uk "uk" "$(cat "$INST_PROJ/.cursor/lgt-pipeline-language")"

if HOME="$FAKE_HOME" CSP_PIPELINE_LANGUAGE=de "$ROOT/scripts/install-to-project.sh" --agree-policy "$INST_PROJ" --skip-third-party-skills >/dev/null; then
  assert_eq install_env_de "de" "$(cat "$INST_PROJ/.cursor/lgt-pipeline-language")"
  echo "OK   install_env_language"
else
  echo "FAIL CSP_PIPELINE_LANGUAGE=de install" >&2
  fail=1
fi

USER_ONLY_HOME="$TMP/user-only-home"
mkdir -p "$USER_ONLY_HOME"
if HOME="$USER_ONLY_HOME" "$ROOT/scripts/install-to-project.sh" --agree-policy --user-only --skip-third-party-skills --language pl >/dev/null; then
  assert_eq user_only_lang "pl" "$(cat "$USER_ONLY_HOME/.cursor/lgt-pipeline-language")"
  echo "OK   install_user_only_language"
else
  echo "FAIL install --user-only --language pl" >&2
  fail=1
fi

# Wiring / docs presence
assert_grep hitl_preset "skills/hitl-choice/references/presets.md" "### Pipeline language"
assert_grep_start_task start_task "Pipeline language"
assert_grep start_issue "commands/lgt-start-issue-task.md" "Pipeline language"
assert_grep flow_doc "docs/superpowers/pipeline-flow.md" "lgt-pipeline-language|csp-pipeline-language"
assert_grep readme "README.md" "lgt-pipeline-language|csp-pipeline-language"
assert_grep no_ru_in_preset_ids "skills/hitl-choice/references/presets.md" '`en`'
# Ensure ru is not offered as an option id in the Pipeline language table
if awk '/### Pipeline language/,/^### /' "$ROOT/skills/hitl-choice/references/presets.md" | grep -E -q '\| `ru` \|'; then
  echo "FAIL Pipeline language preset must not offer ru" >&2
  fail=1
else
  echo "OK   preset_omits_ru"
fi

# Validator rejects Russian-only letters in review prose; allows Ukrainian digests only as shape fail
VAL="$ROOT/scripts/validate-review-report.sh"
RU_REPORT="$TMP/ru-report.md"
cat > "$RU_REPORT" <<'EOF'
### F1 — `P0` — Что-то сломалось
- **Context:** Пример
- **What:** Здесь есть буква ы в русском тексте
- **Where:**
  - File: [`x.java`](x.java)
  - Lines: **1–2**
  - Jump: [`x.java:1`](x.java#L1)
- **Why it matters:** test
- **Ask / fix:** fix

```java
1| class X {}
```
EOF
assert_fail validator_rejects_russian_letters "$VAL" "$RU_REPORT"

UK_DIGEST="$TMP/uk-digest.md"
cat > "$UK_DIGEST" <<'EOF'
### Блокери
1. Something without evidence
EOF
assert_fail validator_rejects_uk_digest_shape "$VAL" "$UK_DIGEST"

EN_OK="$TMP/en-ok.md"
cat > "$EN_OK" <<'EOF'
### F1 — `P0` — Missing org uuid on seed
- **Context:** Migration seeds default roles.
- **What:** Inserts NULL organization_uuid.
- **Where:**
  - File: [`V044.sql`](V044.sql)
  - Lines: **12–20**
  - Jump: [`V044.sql:12`](V044.sql#L12)
- **Why it matters:** Orgs never see seeded roles.
- **Ask / fix:** Seed a real uuid.

```sql
12| INSERT INTO custom_role ...
```
EOF
assert_ok validator_accepts_english_findings "$VAL" "$EN_OK"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
