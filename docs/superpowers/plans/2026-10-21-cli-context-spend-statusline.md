# CLI Context-Spend Status Line Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a single Cursor Agent CLI `statusLine` script (kit template + optional install copy) that shows two live lines — Cursor ring vs Loregate stage context-growth proxies — with peak, alert, and current-stage hint.

**Architecture:** One bash entrypoint embeds a Python 3 worker (stdlib only) that reads CLI JSON from stdin, resolves `route`/`stage` via the consumer’s `scripts/pipeline-status.sh --json` when present, appends debounced snapshots under `.cursor/gates/context-spend/`, and prints two truncated lines. No separate runtime kit helper; no HITL/skill changes; never advances gates.

**Tech Stack:** Bash, Python 3 (stdlib `json`), Cursor `cli-config.json` `statusLine`, existing `pipeline-status.sh`, shell contract tests under `scripts/tests/`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-10-21-cli-context-spend-statusline-design.md` (treat as **approved** after this plan’s docs task updates Status).
- **Kit work:** edit loregate directly; do **not** run `/lgt-start-task` / Pipeline route / nested `csp-software-developer` on the kit itself (`kit-no-pipeline-dogfood`).
- Single deliverable script path in kit: `scripts/statusline-loregate.sh` (copied to `~/.cursor/statusline-loregate.sh` on user install).
- Runtime must **not** require `$KIT` or sourcing kit paths; may call **`$cwd/scripts/pipeline-status.sh`** only.
- Snapshots: `<cwd>/.cursor/gates/context-spend/snapshots.jsonl` + `state.json` for debounce.
- Alert ≥ **15** pp; snapshot write on stage change or ≥ **1** pp ctx move; debounce ~**2s**; trim ~**500** lines.
- Hint dictionary and UI labels exactly as spec; `hint:` **current stage only**.
- Errors: never hang; prefer empty stdout + non-zero **or** one short error line — do not corrupt CLI.
- User-facing kit docs stay English; chat with humans still follows `plain-language-chat`.

---

## File Structure

| Path | Responsibility |
|------|----------------|
| `scripts/statusline-loregate.sh` | CLI `statusLine` entry: stdin JSON → two-line stdout; snapshots; hints |
| `scripts/tests/statusline-loregate-test.sh` | Contract tests with mock stdin + temp project fixtures |
| `scripts/install-to-project.sh` | In `install_user_bits`: copy script to `~/.cursor/statusline-loregate.sh` + print enable hint |
| `scripts/tests/install-policy-agree-test.sh` or new wiring grep | Assert installer copies statusline (extend existing install test if greps already live there) |
| `README.md` | Short “CLI context spend status line” section |
| `docs/superpowers/specs/2026-10-21-cli-context-spend-statusline-design.md` | Status → `approved` |
| `docs/superpowers/dogfood/cli-context-spend-statusline-checklist.md` | Optional manual dogfood steps |

---

### Task 1: Statusline script — Cursor line + payload parse (TDD)

**Files:**
- Create: `scripts/statusline-loregate.sh`
- Create: `scripts/tests/statusline-loregate-test.sh`

**Interfaces:**
- Consumes: CLI stdin JSON (`model.display_name`, `context_window.used_percentage`, `cwd` / `workspace.current_dir`, `session_id`, `render_width_chars`)
- Produces: line 1 shape `cursor  <model>  ctx <N>%  <bar>  ring` (or `ctx —`); temporary line 2 may be `pipe  —  (no loregate gates)` until Task 3
- Env overrides for tests: `STATUSLINE_LOREGATE_ROOT` (force project root instead of payload cwd), `STATUSLINE_LOREGATE_NOW_MS` (fake clock for debounce later)

- [ ] **Step 1: Write the failing test file**

Create `scripts/tests/statusline-loregate-test.sh`:

```bash
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
```

- [ ] **Step 2: Run test — expect FAIL (script missing)**

Run: `bash scripts/tests/statusline-loregate-test.sh`  
Expected: `FAIL script_missing` or missing executable.

- [ ] **Step 3: Implement minimal `scripts/statusline-loregate.sh`**

```bash
#!/usr/bin/env bash
# Cursor CLI statusLine command — Loregate context-spend proxies (v1).
# Reads StatusLinePayload JSON on stdin; prints 1–2 lines on stdout.
set -euo pipefail

export STATUSLINE_LOREGATE_ROOT="${STATUSLINE_LOREGATE_ROOT:-}"
export STATUSLINE_LOREGATE_NOW_MS="${STATUSLINE_LOREGATE_NOW_MS:-}"

python3 - <<'PY'
import json, os, sys, time
from pathlib import Path

def bar(pct: int, width: int = 10) -> str:
    pct = max(0, min(100, pct))
    filled = pct * width // 100
    return "█" * filled + "░" * (width - filled)

def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        print("statusline: bad json", file=sys.stderr)
        return 1

    root = os.environ.get("STATUSLINE_LOREGATE_ROOT") or payload.get("cwd") or (
        (payload.get("workspace") or {}).get("current_dir")
    ) or os.getcwd()
    root = str(Path(root).resolve())

    model = ((payload.get("model") or {}).get("display_name")) or "?"
    cw = payload.get("context_window") or {}
    used = cw.get("used_percentage")
    if used is None:
        line1 = f"cursor  {model}  ctx —  ring"
    else:
        pct = int(float(used))
        line1 = f"cursor  {model}  ctx {pct}% {bar(pct)}  ring"

    # Task 1 placeholder for line 2 — Task 3 replaces
    line2 = "pipe  —  (no loregate gates)"
    print(line1)
    print(line2)
    return 0

sys.exit(main())
PY
```

`chmod +x scripts/statusline-loregate.sh`

- [ ] **Step 4: Run tests — expect PASS for Task 1 assertions**

Run: `bash scripts/tests/statusline-loregate-test.sh`  
Expected: `ALL PASS`

- [ ] **Step 5: Commit**

```bash
git add scripts/statusline-loregate.sh scripts/tests/statusline-loregate-test.sh
git commit -m "$(cat <<'EOF'
feat: add statusline-loregate Cursor line scaffold

Parse CLI statusLine JSON and render the cursor ring line for context-spend v1.
EOF
)"
```

---

### Task 2: Snapshots, per-stage delta, peak, alert

**Files:**
- Modify: `scripts/statusline-loregate.sh`
- Modify: `scripts/tests/statusline-loregate-test.sh`

**Interfaces:**
- Consumes: `session_id`, `ctx_pct`, current `stage` string (may be `idle` / empty in this task — pass `"idle"` until Task 3 wires resolver)
- Produces: under `<root>/.cursor/gates/context-spend/`:
  - `snapshots.jsonl` rows: `{"ts","session_id","ctx_pct","stage","route","invocation_id"}`
  - `state.json`: `{"last_write_ms","last_ctx_pct","last_stage","session_id"}`
- Produces metrics for line 2 later: `delta_stage_pp`, `peak_stage`, `peak_pp`, `alert` bool
- Rules: write if stage changed OR `|ctx - last_ctx| >= 1`; debounce if `now_ms - last_write_ms < 2000` unless stage changed; on write trim file to last 500 lines; new `session_id` ignores prior session rows for peak/delta

- [ ] **Step 1: Extend tests**

Append to `scripts/tests/statusline-loregate-test.sh` (keep prior asserts):

```bash
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

# Same stage, +0.5pp within debounce — no extra snapshot line required; line still renders
export STATUSLINE_LOREGATE_NOW_MS=1005500
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
```

- [ ] **Step 2: Run tests — expect FAIL on missing peak/snapshot behavior**

Run: `bash scripts/tests/statusline-loregate-test.sh`  
Expected: FAIL on `peak_tech` / `snap_exists` until implemented.

- [ ] **Step 3: Implement snapshot + metrics inside the Python worker**

Replace the placeholder worker with logic that:

1. Resolves `stage`/`route` from env overrides if set, else `"idle"` / `"unknown"` (Task 3 fills real resolver).
2. Ensures `Path(root)/.cursor/gates/context-spend` exists.
3. Loads `state.json` and `snapshots.jsonl`; filters rows by `session_id`.
4. Computes `delta_stage_pp` = current ctx int − ctx at start of current stage (first snapshot in session with this stage, or previous stage’s last ctx).
5. Tracks per-stage deltas when stage transitions: when writing a transition, record completed stage’s `(end_ctx - start_ctx)` into an in-memory peak map for the session (also persist by scanning snapshots: for each contiguous stage run, delta = last.ctx − first.ctx; peak = max abs or max positive delta — **use max positive pp growth**).
6. Alert if `delta_stage_pp >= 15`.
7. Debounced append as specified; trim to 500 lines.
8. Line 2 format (hint still omitted or empty until Task 3):

```text
pipe  {route}·{stage}  +{delta}pp/stage  peak:{peak_stage}(+{peak_pp})  [⚠+{delta}]
```

Omit `peak:…` if no completed stage delta yet; omit `⚠` when below threshold.

Include exact Python in the script (no second file). Keep `bar()` and line 1 behavior from Task 1.

- [ ] **Step 4: Run tests — expect ALL PASS**

Run: `bash scripts/tests/statusline-loregate-test.sh`  
Expected: `ALL PASS`

- [ ] **Step 5: Commit**

```bash
git add scripts/statusline-loregate.sh scripts/tests/statusline-loregate-test.sh
git commit -m "$(cat <<'EOF'
feat: snapshot stage context deltas for statusline-loregate

Record debounced ctx snapshots and surface per-stage peak and alert proxies.
EOF
)"
```

---

### Task 3: Resolve pipeline stage + hint dictionary + truncation

**Files:**
- Modify: `scripts/statusline-loregate.sh`
- Modify: `scripts/tests/statusline-loregate-test.sh`

**Interfaces:**
- Consumes: `<root>/scripts/pipeline-status.sh --json --root <root>` → `route`, `stage` (and optional invocation from run-log — ignore if costly)
- If helper missing or non-zero: treat as no loregate gates → line 2 `pipe  —  (no loregate gates)` (and skip spend math / still allow line 1)
- If stage is `idle` and route `unknown` with no pending gates: same no-gates message **or** show `unknown·idle` without hint — **prefer** `pipe  —  (no loregate gates)` when `stage==idle` and `route==unknown` and no snapshots intent; if ledger exists with real stages, show them
- Hint map (current stage only; first matching prefix/token wins):

| match | hint |
|-------|------|
| tech-spec, spec | thin-spec |
| plan, approve-plan, writing-plans | thin-plan |
| critic, implementation-critic, critique | compact-critic |
| build, start-build, software-developer, csp-software-developer | slim-handoff |
| eng-review, engineer-review, review-gate, clarify | cut-clarify |
| finish-plan, local-diff | less-diff-paste |
| docs, update-docs, docs-gate | short-docs |
| create-pr, finale | short-pr |

- Truncate line 2 to `render_width_chars` (default 120); if truncating under alert, keep `⚠` and `hint` suffixes preferentially.

- [ ] **Step 1: Extend tests with a fake `pipeline-status.sh`**

```bash
FAKE="$TMP/fakepipe"
mkdir -p "$FAKE/scripts" "$FAKE/.cursor/gates"
cat >"$FAKE/scripts/pipeline-status.sh" <<'EOF'
#!/usr/bin/env bash
# minimal fake
echo '{"route":"full","stage":"review-gate","pending_gates":[{"kind":"review-gate"}]}'
EOF
chmod +x "$FAKE/scripts/pipeline-status.sh"

export STATUSLINE_LOREGATE_NOW_MS=3000000
# clear env stage overrides so resolver runs
unset STATUSLINE_LOREGATE_STAGE STATUSLINE_LOREGATE_ROUTE
p55='{"session_id":"sFake","cwd":"'"$FAKE"'","model":{"display_name":"Opus"},"context_window":{"used_percentage":55},"render_width_chars":80}'
out_f="$(run_sl "$FAKE" "$p55")"
assert_contains resolved_stage "$out_f" "full·review-gate"
assert_contains hint_clarify "$out_f" "hint:cut-clarify"

EMPTY="$TMP/emptyproj"
mkdir -p "$EMPTY"
out_e="$(run_sl "$EMPTY" '{"session_id":"e1","cwd":"'"$EMPTY"'","model":{"display_name":"X"},"context_window":{"used_percentage":10},"render_width_chars":120}')"
assert_contains no_gates "$out_e" "(no loregate gates)"
```

- [ ] **Step 2: Run — expect FAIL until resolver/hints exist**

- [ ] **Step 3: Implement resolver + hints in the Python worker**

```python
def resolve_route_stage(root: Path) -> tuple[str, str, bool]:
    """Return (route, stage, has_pipeline). has_pipeline False → no-gates line."""
    helper = root / "scripts" / "pipeline-status.sh"
    if not helper.is_file():
        return "unknown", "idle", False
    import subprocess
    try:
        proc = subprocess.run(
            ["bash", str(helper), "--json", "--root", str(root)],
            capture_output=True, text=True, timeout=1.5, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "unknown", "idle", False
    if proc.returncode != 0 or not proc.stdout.strip():
        return "unknown", "idle", False
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return "unknown", "idle", False
    route = data.get("route") or "unknown"
    stage = data.get("stage") or "idle"
    pending = data.get("pending_gates") or []
    stages_entered = data.get("stages_entered") or []
    has = bool(pending) or bool(stages_entered) or (route != "unknown" and stage != "idle")
    return route, stage, has

HINTS = [
    (("tech-spec", "spec"), "thin-spec"),
    (("plan", "approve-plan", "writing-plans"), "thin-plan"),
    (("critic", "implementation-critic", "critique"), "compact-critic"),
    (("build", "start-build", "software-developer", "csp-software-developer"), "slim-handoff"),
    (("eng-review", "engineer-review", "review-gate", "clarify"), "cut-clarify"),
    (("finish-plan", "local-diff"), "less-diff-paste"),
    (("docs", "update-docs", "docs-gate"), "short-docs"),
    (("create-pr", "finale"), "short-pr"),
]

def hint_for(stage: str) -> str | None:
    s = (stage or "").lower()
    for keys, token in HINTS:
        for k in keys:
            if s == k or s.startswith(k) or k in s:
                return token
    return None
```

Honor `STATUSLINE_LOREGATE_STAGE` / `ROUTE` when set (tests). Subprocess only when overrides absent.

Wire line 2 + truncation. Cap subprocess at 1.5s so CLI `timeoutMs=2000` still has margin.

- [ ] **Step 4: Run full test file — ALL PASS**

Run: `bash scripts/tests/statusline-loregate-test.sh`

- [ ] **Step 5: Commit**

```bash
git add scripts/statusline-loregate.sh scripts/tests/statusline-loregate-test.sh
git commit -m "$(cat <<'EOF'
feat: resolve pipeline stage and hints in statusline-loregate

Call consumer pipeline-status JSON and append current-stage optimization hints.
EOF
)"
```

---

### Task 4: Install copy, README, design status, dogfood checklist

**Files:**
- Modify: `scripts/install-to-project.sh` (`install_user_bits`)
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-10-21-cli-context-spend-statusline-design.md` (Status → `approved`)
- Create: `docs/superpowers/dogfood/cli-context-spend-statusline-checklist.md`
- Modify: install wiring test — grep that `install_user_bits` copies `statusline-loregate.sh` (add asserts to `scripts/tests/install-policy-agree-test.sh` **or** a tiny new `scripts/tests/statusline-loregate-install-test.sh` that greps the installer)

**Interfaces:**
- `install_user_bits` always refreshes `~/.cursor/statusline-loregate.sh` from kit (like rules copy)
- Print one English line: how to set `statusLine` in `~/.cursor/cli-config.json` (do **not** silently rewrite user’s cli-config)
- README: enable snippet, example two lines, meaning of `pp` / `peak` / `⚠` / `hint`, pointer to design spec

- [ ] **Step 1: Failing install grep test**

```bash
# scripts/tests/statusline-loregate-install-test.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
grep -q 'statusline-loregate.sh' "$ROOT/scripts/install-to-project.sh"
grep -q 'CLI context spend' "$ROOT/README.md" || grep -q 'statusline-loregate' "$ROOT/README.md"
echo "ALL PASS"
```

Run — expect FAIL until installer/README updated.

- [ ] **Step 2: Patch `install_user_bits`**

Inside `install_user_bits`, after rules copies:

```bash
  cp "$KIT_ROOT/scripts/statusline-loregate.sh" "$HOME/.cursor/statusline-loregate.sh"
  chmod +x "$HOME/.cursor/statusline-loregate.sh"
  echo "copied: $HOME/.cursor/statusline-loregate.sh"
  echo "hint: enable Cursor CLI statusLine → command ~/.cursor/statusline-loregate.sh (see README)"
```

- [ ] **Step 3: README section** (English), ~15–25 lines: enable JSON, example render, `pp` definition, hint legend table (short), link to design spec. State proxies ≠ billing.

- [ ] **Step 4: Design Status `approved` + dogfood checklist**

Dogfood checklist bullets:
1. `lgt install --user-only` (or project install) copies script
2. Add `statusLine` to `cli-config.json`
3. Open CLI in a consumer project mid-pipeline
4. Confirm two lines update; peak/hint sensible
5. Confirm empty project shows no-gates line
6. Confirm script failure does not freeze prompt

- [ ] **Step 5: Run tests**

```bash
bash scripts/tests/statusline-loregate-test.sh
bash scripts/tests/statusline-loregate-install-test.sh
```

Expected: both `ALL PASS`

- [ ] **Step 6: Commit**

```bash
git add scripts/install-to-project.sh scripts/tests/statusline-loregate-install-test.sh README.md \
  docs/superpowers/specs/2026-10-21-cli-context-spend-statusline-design.md \
  docs/superpowers/dogfood/cli-context-spend-statusline-checklist.md
git commit -m "$(cat <<'EOF'
docs: wire statusline-loregate install and README

Copy the CLI context-spend status line on user install and document enablement.
EOF
)"
```

---

## Spec coverage self-check

| Spec requirement | Task |
|------------------|------|
| CLI two-line statusLine | 1–3 |
| Single script, no runtime kit helper | 1–4 |
| Snapshots under project gates | 2 |
| Debounce / trim / session boundary | 2 |
| Alert ≥15pp, hint current only | 2–3 |
| Stage from pipeline-status family | 3 |
| Optional install copy to `~/.cursor` | 4 |
| README + pp/hint legend | 4 |
| Tests mock stdin / fixtures | 1–3 |
| Non-goals (no HITL/run-log/billing) | honored (no tasks) |

## Placeholder scan

None intentional — implementers must paste/adapt the code blocks above into the real script rather than leaving “TBD”.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-10-21-cli-context-spend-statusline.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — execute tasks in this session with checkpoints  

Which approach?
