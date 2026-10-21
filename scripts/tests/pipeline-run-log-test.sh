#!/usr/bin/env bash
# Contract tests for scripts/pipeline-run-log.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/pipeline-run-log.sh"
# Prefer an explicit template under the kit (or TMPDIR) so sandboxed agents can
# create `.cursor/` fixtures; bare `mktemp -d` on macOS often lands outside the workspace.
_LGT_TMP_BASE="${LGT_TEST_TMP:-${TMPDIR:-/tmp}}"
mkdir -p "$_LGT_TMP_BASE"
TMP="$(mktemp -d "${_LGT_TMP_BASE%/}/lgt-run-log.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL $name: expected [$expected] got [$actual]" >&2
    fail=1
  else
    echo "OK   $name"
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "OK   $name"
  else
    echo "FAIL $name: [$needle] not in [$haystack]" >&2
    fail=1
  fi
}

assert_file() {
  local name="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "OK   $name"
  else
    echo "FAIL $name: missing $path" >&2
    fail=1
  fi
}

assert_no_file() {
  local name="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "FAIL $name: unexpected file $path" >&2
    fail=1
  else
    echo "OK   $name"
  fi
}

assert_nonzero() {
  local name="$1" rc="$2"
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL $name: expected non-zero exit" >&2
    fail=1
  else
    echo "OK   $name (rc=$rc)"
  fi
}

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL script_missing: $SCRIPT" >&2
  exit 1
fi

PROJ="$TMP/proj"
mkdir -p "$PROJ"
# Sandbox agents often cannot mkdir `.cursor/`; use PG_GATES_BASE under the fixture.
GATES="$PROJ/gates"
export PG_GATES_BASE="$GATES"
mkdir -p "$GATES"

# --- init isolation: B does not clear A ---
rc=0
"$SCRIPT" init --root "$PROJ" --invocation invA --route full || rc=$?
assert_eq init_a_rc "0" "$rc"
assert_file init_a_exists "$GATES/run-log/inv-invA.md"
"$SCRIPT" init --root "$PROJ" --invocation invB --route fast || rc=$?
assert_eq init_b_rc "0" "$rc"
assert_file init_a_still "$GATES/run-log/inv-invA.md"
assert_file init_b_exists "$GATES/run-log/inv-invB.md"
assert_contains init_a_body "$(cat "$GATES/run-log/inv-invA.md")" "invocation: invA"
assert_contains init_b_body "$(cat "$GATES/run-log/inv-invB.md")" "invocation: invB"

# --- pointer written on init ---
assert_file pointer_exists "$GATES/run-log/current-invocation"
ptr="$(cat "$GATES/run-log/current-invocation")"
assert_contains pointer_id "$ptr" "invocation: invB"
assert_contains pointer_updated "$ptr" "updated: "

# --- re-init without --reset refuses ---
rc=0
"$SCRIPT" init --root "$PROJ" --invocation invA --route full || rc=$?
assert_nonzero reinit_refuse "$rc"
assert_contains reinit_a_intact "$(cat "$GATES/run-log/inv-invA.md")" "invocation: invA"

# --- re-init with --reset rewrites only that file ---
"$SCRIPT" append --root "$PROJ" --invocation invA --stage bootstrap --note "keep-me" || true
"$SCRIPT" append --root "$PROJ" --invocation invB --stage bootstrap --note "b-note" || true
rc=0
"$SCRIPT" init --root "$PROJ" --invocation invA --route full --reset || rc=$?
assert_eq reinit_reset_rc "0" "$rc"
body_a="$(cat "$GATES/run-log/inv-invA.md")"
if [[ "$body_a" == *"keep-me"* ]]; then
  echo "FAIL reinit_reset_clears_body: old note still present" >&2
  fail=1
else
  echo "OK   reinit_reset_clears_body"
fi
assert_contains reinit_b_intact "$(cat "$GATES/run-log/inv-invB.md")" "b-note"
assert_contains pointer_after_reset "$(cat "$GATES/run-log/current-invocation")" "invocation: invA"

# --- append + path while inv exists ---
"$SCRIPT" append --root "$PROJ" --invocation invA --stage route --note "chose full"
path_out="$("$SCRIPT" path --root "$PROJ" --invocation invA)"
assert_eq path_inv "$GATES/run-log/inv-invA.md" "$path_out"

# While inv exists, --plan must still resolve to inv (not slug)
mkdir -p "$PROJ/docs/plans"
printf '# plan\n' >"$PROJ/docs/plans/demo.md"
path_with_plan="$("$SCRIPT" path --root "$PROJ" --invocation invA --plan "docs/plans/demo.md")"
assert_eq path_inv_despite_plan "$GATES/run-log/inv-invA.md" "$path_with_plan"
"$SCRIPT" append --root "$PROJ" --invocation invA --plan "docs/plans/demo.md" --stage tech-spec --note "drafted"
assert_no_file no_slug_yet "$GATES/run-log/DEMO"
assert_contains append_on_inv "$(cat "$GATES/run-log/inv-invA.md")" "stage=tech-spec"

# --- duplicate stage+note skip ---
before_lines="$(grep -c '^\- ' "$GATES/run-log/inv-invA.md" || true)"
rc=0
"$SCRIPT" append --root "$PROJ" --invocation invA --stage tech-spec --note "drafted" || rc=$?
assert_eq dup_skip_rc "0" "$rc"
after_lines="$(grep -c '^\- ' "$GATES/run-log/inv-invA.md" || true)"
assert_eq dup_skip_lines "$before_lines" "$after_lines"

# --- Unicode note truncation at 120 characters ---
# 130 Unicode chars (multi-byte: "ä" is 2 bytes, still 1 character)
unicode_note="$(python3 -c 'print("ä" * 130)')"
"$SCRIPT" append --root "$PROJ" --invocation invA --stage unicode-test --note "$unicode_note"
last_note="$(grep 'stage=unicode-test' "$GATES/run-log/inv-invA.md" | tail -1)"
note_val="$(python3 -c 'import re,sys; m=re.search(r"note=(.*)$", sys.argv[1]); print(m.group(1) if m else "")' "$last_note")"
note_len="$(python3 -c 'import sys; print(len(sys.argv[1]))' "$note_val")"
assert_eq unicode_note_len "120" "$note_len"

# --- promote when target absent ---
rc=0
"$SCRIPT" promote --root "$PROJ" --invocation invA --plan "docs/plans/demo.md" --route full || rc=$?
assert_eq promote_absent_rc "0" "$rc"
assert_no_file promote_source_gone "$GATES/run-log/inv-invA.md"
# slug from ticket-less path is hash12
slug_path="$("$SCRIPT" path --root "$PROJ" --plan "docs/plans/demo.md")"
assert_file promote_target_exists "$slug_path"
assert_contains promote_header_plan "$(cat "$slug_path")" "plan: docs/plans/demo.md"
assert_contains promote_header_slug "$(cat "$slug_path")" "slug: "
assert_contains promote_header_route "$(cat "$slug_path")" "route: full"
assert_contains promote_kept_body "$(cat "$slug_path")" "stage=unicode-test"

# After promote, path/append with --plan use slug; --invocation alone finds slug via pointer
path_after="$("$SCRIPT" path --root "$PROJ" --plan "docs/plans/demo.md")"
assert_eq path_after_promote "$slug_path" "$path_after"

# Pointer refreshed on successful promote with plan/slug/journal
ptr_promoted="$(cat "$GATES/run-log/current-invocation")"
assert_contains ptr_after_promote_id "$ptr_promoted" "invocation: invA"
assert_contains ptr_after_promote_plan "$ptr_promoted" "plan: docs/plans/demo.md"
assert_contains ptr_after_promote_slug "$ptr_promoted" "slug: "
assert_contains ptr_after_promote_journal "$ptr_promoted" "journal: "

# --invocation only (no --plan) still hits the slug journal via pointer
path_inv_only="$("$SCRIPT" path --root "$PROJ" --invocation invA)"
assert_eq path_inv_only_slug "$slug_path" "$path_inv_only"
"$SCRIPT" append --root "$PROJ" --invocation invA --stage post-promote --note "via-pointer"
assert_contains append_inv_only_slug "$(cat "$slug_path")" "stage=post-promote"
assert_contains append_inv_only_note "$(cat "$slug_path")" "via-pointer"
tail_inv_only="$("$SCRIPT" read-tail --root "$PROJ" --invocation invA --lines 1)"
assert_contains read_tail_inv_only "$tail_inv_only" "via-pointer"

# --- promote refuse-on-conflict ---
"$SCRIPT" init --root "$PROJ" --invocation conflict1 --route full
"$SCRIPT" append --root "$PROJ" --invocation conflict1 --stage bootstrap --note "fresh"
# leave existing slug journal from prior promote
target_before="$(cat "$slug_path")"
ptr_before_refuse="$(cat "$GATES/run-log/current-invocation")"
rc=0
"$SCRIPT" promote --root "$PROJ" --invocation conflict1 --plan "docs/plans/demo.md" || rc=$?
assert_nonzero promote_conflict "$rc"
assert_file promote_conflict_source "$GATES/run-log/inv-conflict1.md"
assert_eq promote_conflict_target_unchanged "$target_before" "$(cat "$slug_path")"
# refuse must not point writers at the foreign slug via pointer
ptr_after_refuse="$(cat "$GATES/run-log/current-invocation")"
assert_eq ptr_unchanged_on_refuse "$ptr_before_refuse" "$ptr_after_refuse"
assert_contains ptr_refuse_stays_conflict "$ptr_after_refuse" "invocation: conflict1"
if grep -q 'plan: docs/plans/demo.md' <<<"$ptr_after_refuse"; then
  echo "FAIL ptr_refuse_no_foreign_plan: refuse rewrote pointer with foreign plan" >&2
  fail=1
else
  echo "OK   ptr_refuse_no_foreign_plan"
fi
if grep -Eq 'journal: .+\.md' <<<"$ptr_after_refuse"; then
  echo "FAIL ptr_refuse_no_foreign_journal: refuse pointed at foreign journal" >&2
  fail=1
else
  echo "OK   ptr_refuse_no_foreign_journal"
fi

# After refuse, append/path with --invocation stay on inv even if --plan passed
path_conflict="$("$SCRIPT" path --root "$PROJ" --invocation conflict1 --plan "docs/plans/demo.md")"
assert_eq path_conflict_inv "$GATES/run-log/inv-conflict1.md" "$path_conflict"
"$SCRIPT" append --root "$PROJ" --invocation conflict1 --plan "docs/plans/demo.md" --stage continue --note "still-inv"
assert_contains append_after_refuse "$(cat "$GATES/run-log/inv-conflict1.md")" "stage=continue"
assert_eq target_still_unchanged "$target_before" "$(cat "$slug_path")"

# --- promote I/O failure (real): run-log dir not writable ---
IO="$TMP/io-fail"
IO_GATES="$IO/gates"
mkdir -p "$IO_GATES/run-log" "$IO/docs/plans"
printf '# p\n' >"$IO/docs/plans/io.md"
_saved_pg="$PG_GATES_BASE"
export PG_GATES_BASE="$IO_GATES"
"$SCRIPT" init --root "$IO" --invocation io1 --route full
"$SCRIPT" append --root "$IO" --invocation io1 --stage bootstrap --note "io-body"
# Make directory non-writable so mv into a new slug file fails
chmod a-w "$IO_GATES/run-log"
rc=0
"$SCRIPT" promote --root "$IO" --invocation io1 --plan "docs/plans/io.md" || rc=$?
chmod a+w "$IO_GATES/run-log"
assert_nonzero promote_io_fail "$rc"
assert_file promote_io_source_intact "$IO_GATES/run-log/inv-io1.md"
assert_contains promote_io_readable "$(cat "$IO_GATES/run-log/inv-io1.md")" "io-body"
export PG_GATES_BASE="$_saved_pg"

# --- read-tail ---
tail_out="$("$SCRIPT" read-tail --root "$PROJ" --plan "docs/plans/demo.md" --lines 2)"
assert_contains read_tail_has_line "$tail_out" "stage="
missing_tail="$("$SCRIPT" read-tail --root "$PROJ" --invocation does-not-exist)"
assert_eq read_tail_missing "" "$missing_tail"

# --- brief-upsert ---
rc=0
"$SCRIPT" brief-upsert --root "$PROJ" --invocation brief1 --route fast \
  --goal "Ship a tiny fix" --next "engineer-review" || rc=$?
assert_eq brief_rc "0" "$rc"
brief="$GATES/run-log/briefs/inv-brief1.brief.md"
assert_file brief_exists "$brief"
brief_body="$(cat "$brief")"
assert_contains brief_goal "$brief_body" "Ship a tiny fix"
assert_contains brief_next "$brief_body" "engineer-review"
line_count="$(wc -l <"$brief" | tr -d ' ')"
if [[ "$line_count" -gt 40 ]]; then
  echo "FAIL brief_cap: $line_count lines > 40" >&2
  fail=1
else
  echo "OK   brief_cap ($line_count lines)"
fi

# --- lock: serialization smoke (flock when present; otherwise mkdir lock) ---
"$SCRIPT" init --root "$PROJ" --invocation flock1 --route full --reset 2>/dev/null \
  || "$SCRIPT" init --root "$PROJ" --invocation flock1 --route full
(
  "$SCRIPT" append --root "$PROJ" --invocation flock1 --stage a --note "one" &
  "$SCRIPT" append --root "$PROJ" --invocation flock1 --stage b --note "two" &
  wait
)
flock_body="$(cat "$GATES/run-log/inv-flock1.md")"
assert_contains flock_a "$flock_body" "stage=a"
assert_contains flock_b "$flock_body" "stage=b"

# Writes still work when flock is absent from PATH (mkdir-lock fallback for macOS).
NOFLOCK_PATH="$TMP/path-noflock"
mkdir -p "$NOFLOCK_PATH"
for bin in bash sh mkdir mv rm rmdir cat chmod head tail grep awk sed tr printf python3 date mktemp dirname basename pwd cd true false sleep touch; do
  src="$(command -v "$bin" 2>/dev/null || true)"
  if [[ -n "$src" && -x "$src" ]]; then
    ln -sf "$src" "$NOFLOCK_PATH/$bin" 2>/dev/null || cp "$src" "$NOFLOCK_PATH/$bin" 2>/dev/null || true
  fi
done
# Do NOT link flock — fallback must cover this host path.
"$SCRIPT" init --root "$PROJ" --invocation noflock --route full --reset 2>/dev/null \
  || env PATH="$NOFLOCK_PATH" "$SCRIPT" init --root "$PROJ" --invocation noflock --route full --reset \
  || env PATH="$NOFLOCK_PATH" "$SCRIPT" init --root "$PROJ" --invocation noflock --route full
rc=0
env PATH="$NOFLOCK_PATH" "$SCRIPT" append --root "$PROJ" --invocation noflock --stage x --note "y" || rc=$?
assert_eq flock_missing_write_ok "0" "$rc"
assert_contains flock_missing_note "$(cat "$GATES/run-log/inv-noflock.md")" "stage=x"
rc=0
env PATH="$NOFLOCK_PATH" "$SCRIPT" path --root "$PROJ" --invocation noflock >/dev/null || rc=$?
assert_eq flock_missing_path_ok "0" "$rc"
rc=0
env PATH="$NOFLOCK_PATH" "$SCRIPT" read-tail --root "$PROJ" --invocation noflock >/dev/null || rc=$?
assert_eq flock_missing_read_ok "0" "$rc"

# --- invalid invocation id ---
rc=0
"$SCRIPT" init --root "$PROJ" --invocation 'bad id!' || rc=$?
assert_eq invalid_id_exit "2" "$rc"

# --- unknown args ---
rc=0
"$SCRIPT" init --root "$PROJ" --invocation ok --bogus || rc=$?
assert_eq unknown_arg_exit "2" "$rc"

if [[ "$fail" -ne 0 ]]; then
  echo "SOME TESTS FAILED" >&2
  exit 1
fi
echo "ALL PASS"
