#!/usr/bin/env bash
# Cursor CLI statusLine command — Loregate context-spend proxies (v1).
# Reads StatusLinePayload JSON on stdin; prints 1–2 lines on stdout.
set -euo pipefail

export STATUSLINE_LOREGATE_ROOT="${STATUSLINE_LOREGATE_ROOT:-}"
export STATUSLINE_LOREGATE_NOW_MS="${STATUSLINE_LOREGATE_NOW_MS:-}"

exec 3<&0

python3 - <<'PY'
import json, os, sys, time
from pathlib import Path

def bar(pct: int, width: int = 10) -> str:
    pct = max(0, min(100, pct))
    filled = pct * width // 100
    return "█" * filled + "░" * (width - filled)

def load_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}

def load_snapshots(path: Path) -> list[dict]:
    rows = []
    try:
        for line in path.read_text().splitlines():
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(row, dict):
                rows.append(row)
    except OSError:
        pass
    return rows

def stage_metrics(rows: list[dict], ctx_pct: int, stage: str) -> tuple[int, str, int]:
    if not rows:
        return 0, "", 0

    current_run_start = int(float(rows[-1].get("ctx_pct", ctx_pct)))
    for row in reversed(rows):
        if row.get("stage") != stage:
            break
        current_run_start = int(float(row.get("ctx_pct", current_run_start)))

    if rows[-1].get("stage") != stage:
        current_run_start = int(float(rows[-1].get("ctx_pct", ctx_pct)))
    delta_stage_pp = ctx_pct - current_run_start

    peak_stage = ""
    peak_pp = 0
    run_stage = str(rows[0].get("stage", "idle"))
    run_start = int(float(rows[0].get("ctx_pct", 0)))
    for row in rows[1:]:
        next_stage = str(row.get("stage", "idle"))
        next_ctx = int(float(row.get("ctx_pct", 0)))
        if next_stage != run_stage:
            completed_delta = next_ctx - run_start
            if completed_delta > peak_pp:
                peak_stage = run_stage
                peak_pp = completed_delta
            run_stage = next_stage
            run_start = next_ctx

    if rows[-1].get("stage") != stage:
        completed_delta = ctx_pct - run_start
        if completed_delta > peak_pp:
            peak_stage = run_stage
            peak_pp = completed_delta

    return delta_stage_pp, peak_stage, peak_pp

def record_snapshot(
    root: str,
    session_id: str,
    ctx_pct: float,
    stage: str,
    route: str,
    invocation_id: str,
    now_ms: int,
) -> tuple[int, str, int]:
    spend_dir = Path(root) / ".cursor" / "gates" / "context-spend"
    spend_dir.mkdir(parents=True, exist_ok=True)
    snapshots_path = spend_dir / "snapshots.jsonl"
    state_path = spend_dir / "state.json"

    all_rows = load_snapshots(snapshots_path)
    session_rows = [
        row for row in all_rows if str(row.get("session_id", "")) == session_id
    ]
    ctx_int = int(ctx_pct)
    delta_stage_pp, peak_stage, peak_pp = stage_metrics(
        session_rows, ctx_int, stage
    )

    state = load_json(state_path)
    same_session = str(state.get("session_id", "")) == session_id
    stage_changed = (
        same_session and bool(session_rows) and str(state.get("last_stage", "")) != stage
    )
    try:
        ctx_changed = abs(ctx_pct - float(state.get("last_ctx_pct", ctx_pct))) >= 1
        elapsed_ms = now_ms - int(state.get("last_write_ms", 0))
    except (TypeError, ValueError):
        ctx_changed = True
        elapsed_ms = 2000

    should_write = (
        not same_session
        or not session_rows
        or stage_changed
        or (ctx_changed and elapsed_ms >= 2000)
    )
    if should_write:
        row = {
            "ts": now_ms,
            "session_id": session_id,
            "ctx_pct": ctx_pct,
            "stage": stage,
            "route": route,
            "invocation_id": invocation_id,
        }
        all_rows.append(row)
        snapshots_path.write_text(
            "".join(
                json.dumps(item, separators=(",", ":")) + "\n"
                for item in all_rows[-500:]
            )
        )
        state_path.write_text(
            json.dumps(
                {
                    "last_write_ms": now_ms,
                    "last_ctx_pct": ctx_pct,
                    "last_stage": stage,
                    "session_id": session_id,
                },
                separators=(",", ":"),
            )
            + "\n"
        )

    return delta_stage_pp, peak_stage, peak_pp

def main() -> int:
    with os.fdopen(3) as stdin_payload:
        raw = stdin_payload.read()
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
    stage = os.environ.get("STATUSLINE_LOREGATE_STAGE") or "idle"
    route = os.environ.get("STATUSLINE_LOREGATE_ROUTE") or "unknown"
    delta_stage_pp = 0
    peak_stage = ""
    peak_pp = 0
    if used is None:
        line1 = f"cursor  {model}  ctx —  ring"
    else:
        ctx_pct = float(used)
        pct = int(ctx_pct)
        line1 = f"cursor  {model}  ctx {pct}% {bar(pct)}  ring"
        now_ms = int(os.environ.get("STATUSLINE_LOREGATE_NOW_MS") or time.time() * 1000)
        delta_stage_pp, peak_stage, peak_pp = record_snapshot(
            root=root,
            session_id=str(payload.get("session_id") or ""),
            ctx_pct=ctx_pct,
            stage=stage,
            route=route,
            invocation_id=str(payload.get("invocation_id") or ""),
            now_ms=now_ms,
        )

    line2 = f"pipe  {route}·{stage}  {delta_stage_pp:+d}pp/stage"
    if peak_stage:
        line2 += f"  peak:{peak_stage}(+{peak_pp})"
    if delta_stage_pp >= 15:
        line2 += f"  ⚠+{delta_stage_pp}"
    print(line1)
    print(line2)
    return 0

sys.exit(main())
PY
