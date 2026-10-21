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

assert_max_chars() {
  local name="$1" value="$2" maximum="$3"
  local length
  length="$(python3 -c 'import sys; print(len(sys.argv[1]))' "$value")"
  if (( length <= maximum )); then
    echo "OK   $name"
  else
    echo "FAIL $name: length [$length] exceeds [$maximum] in [$value]" >&2
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

# --- Snapshot / peak / alert (force stage via env for Task 2) ---
# Implementation must honor STATUSLINE_LOREGATE_STAGE and STATUSLINE_LOREGATE_ROUTE when set (test hooks; Task 3 sets them from pipeline-status).

SPEND="$TMP/spendproj"
mkdir -p "$SPEND"
export STATUSLINE_LOREGATE_STAGE=tech-spec
export STATUSLINE_LOREGATE_ROUTE=full
export STATUSLINE_LOREGATE_NOW_MS=1000000

p50='{"session_id":"sessA","cwd":"'"$SPEND"'","model":{"display_name":"Opus"},"context_window":{"used_percentage":50},"render_width_chars":120}'
run_sl "$SPEND" "$p50" >/dev/null
assert_eq snap_exists "1" "$([[ -f "$SPEND/.cursor/gates/context-spend/snapshots.jsonl" ]] && echo 1 || echo 0)"

export STATUSLINE_LOREGATE_NOW_MS=1005000
export STATUSLINE_LOREGATE_STAGE=eng-review
p68='{"session_id":"sessA","cwd":"'"$SPEND"'","model":{"display_name":"Opus"},"context_window":{"used_percentage":68},"render_width_chars":120}'
out_peak="$(run_sl "$SPEND" "$p68")"
assert_contains peak_tech "$out_peak" "peak:tech-spec(+18)"
assert_contains alert_warn "$out_peak" "⚠+18"
assert_contains delta_stage "$out_peak" "+18pp/stage"
assert_contains hint_clarify_override "$out_peak" "hint:cut-clarify"

p84_narrow='{"session_id":"sessA","cwd":"'"$SPEND"'","model":{"display_name":"Opus"},"context_window":{"used_percentage":84},"render_width_chars":48}'
out_narrow="$(run_sl "$SPEND" "$p84_narrow")"
line2_narrow="$(printf '%s\n' "$out_narrow" | sed -n '2p')"
assert_max_chars narrow_line2_width "$line2_narrow" 48
assert_contains narrow_keeps_alert "$line2_narrow" "⚠+16"
assert_contains narrow_keeps_hint "$line2_narrow" "hint:cut-clarify"

export STATUSLINE_LOREGATE_STAGE=finish-plan
out_finish_hint="$(run_sl "$SPEND" "$PAYLOAD_NO_CTX")"
assert_contains hint_finish_plan "$out_finish_hint" "hint:less-diff-paste"

# Same stage, +0.5pp within debounce — no extra snapshot line required; line still renders
export STATUSLINE_LOREGATE_NOW_MS=1005500
export STATUSLINE_LOREGATE_STAGE=eng-review
p68b='{"session_id":"sessA","cwd":"'"$SPEND"'","model":{"display_name":"Opus"},"context_window":{"used_percentage":68.5},"render_width_chars":120}'
lines_before="$(wc -l <"$SPEND/.cursor/gates/context-spend/snapshots.jsonl" | tr -d ' ')"
run_sl "$SPEND" "$p68b" >/dev/null
lines_after="$(wc -l <"$SPEND/.cursor/gates/context-spend/snapshots.jsonl" | tr -d ' ')"
assert_eq debounce_no_write "$lines_before" "$lines_after"

# New session resets peak attribution
export STATUSLINE_LOREGATE_NOW_MS=2000000
export STATUSLINE_LOREGATE_STAGE=plan
p40='{"session_id":"sessB","cwd":"'"$SPEND"'","model":{"display_name":"Opus"},"context_window":{"used_percentage":40},"render_width_chars":120}'
out_b="$(run_sl "$SPEND" "$p40")"
# peak for sessB should not cite tech-spec(+18) from sessA
if [[ "$out_b" == *'peak:tech-spec(+18)'* ]]; then
  echo "FAIL session_isolation: peak leaked from sessA" >&2
  fail=1
else
  echo "OK   session_isolation"
fi

unset STATUSLINE_LOREGATE_STAGE STATUSLINE_LOREGATE_ROUTE STATUSLINE_LOREGATE_NOW_MS

# Resolve stage and route from the consumer helper when overrides are absent.
FAKE="$TMP/fakepipe"
mkdir -p "$FAKE/scripts" "$FAKE/.cursor/gates"
cat >"$FAKE/scripts/pipeline-status.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"route":"full","stage":"review-gate","pending_gates":[{"kind":"review-gate"}]}'
EOF
chmod +x "$FAKE/scripts/pipeline-status.sh"

export STATUSLINE_LOREGATE_NOW_MS=3000000
p55='{"session_id":"sFake","cwd":"'"$FAKE"'","model":{"display_name":"Opus"},"context_window":{"used_percentage":55},"render_width_chars":80}'
out_f="$(run_sl "$FAKE" "$p55")"
assert_contains resolved_stage "$out_f" "full·review-gate"
assert_contains hint_clarify "$out_f" "hint:cut-clarify"

EMPTY="$TMP/emptyproj"
mkdir -p "$EMPTY"
out_e="$(run_sl "$EMPTY" '{"session_id":"e1","cwd":"'"$EMPTY"'","model":{"display_name":"X"},"context_window":{"used_percentage":10},"render_width_chars":120}')"
assert_contains no_gates "$out_e" "(no loregate gates)"
unset STATUSLINE_LOREGATE_NOW_MS

if [[ "$fail" -ne 0 ]]; then
  echo "FAILED" >&2
  exit 1
fi
echo "ALL PASS"
