#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/statusline-loregate.sh"
TMP="$(mktemp -d)"
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

run_sl() {
  STATUSLINE_LOREGATE_ROOT="$1" "$SCRIPT" <<<"$2"
}

PAYLOAD_BASIC='{"session_id":"s1","cwd":"'"$TMP"'","model":{"display_name":"Opus"},"context_window":{"used_percentage":68.4},"render_width_chars":120}'

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL script_missing" >&2
  exit 1
fi

out="$(run_sl "$TMP" "$PAYLOAD_BASIC" || true)"
line1="$(printf '%s\n' "$out" | sed -n '1p')"
assert_contains line1_cursor "$line1" "cursor"
assert_contains line1_model "$line1" "Opus"
assert_contains line1_ctx "$line1" "ctx 68%"
assert_contains line1_ring "$line1" "ring"

PAYLOAD_NO_CTX='{"session_id":"s1","cwd":"'"$TMP"'","model":{"display_name":"Opus"},"context_window":{},"render_width_chars":120}'
out2="$(run_sl "$TMP" "$PAYLOAD_NO_CTX" || true)"
assert_contains no_ctx "$(printf '%s\n' "$out2" | sed -n '1p')" "ctx —"

PAYLOAD_BAD='not-json'
set +e
out3="$(run_sl "$TMP" "$PAYLOAD_BAD" 2>/dev/null)"
rc=$?
set -e
# Accept either non-zero with empty stdout OR a single short error line
if [[ "$rc" -ne 0 && -z "$out3" ]]; then
  echo "OK   bad_json_empty"
elif [[ "$out3" == statusline:* ]]; then
  echo "OK   bad_json_error_line"
else
  echo "FAIL bad_json handling rc=$rc out=[$out3]" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "FAILED" >&2
  exit 1
fi
echo "ALL PASS"
