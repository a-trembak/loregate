#!/usr/bin/env bash
# Cursor CLI statusLine command — Loregate context-spend proxies (v1).
# Reads StatusLinePayload JSON on stdin; prints 1–2 lines on stdout.
set -euo pipefail

export STATUSLINE_LOREGATE_ROOT="${STATUSLINE_LOREGATE_ROOT:-}"
export STATUSLINE_LOREGATE_NOW_MS="${STATUSLINE_LOREGATE_NOW_MS:-}"

exec 3<&0

python3 - <<'PY'
import json, os, subprocess, sys, time
from pathlib import Path
from typing import Optional

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

def resolve_route_stage(root: Path) -> tuple[str, str, bool]:
    """Return route, stage, and whether Loregate has active pipeline state."""
    helper = root / "scripts" / "pipeline-status.sh"
    if not helper.is_file():
        return "unknown", "idle", False
    try:
        proc = subprocess.run(
            ["bash", str(helper), "--json", "--root", str(root)],
            capture_output=True,
            text=True,
            timeout=1.5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "unknown", "idle", False
    if proc.returncode != 0 or not proc.stdout.strip():
        return "unknown", "idle", False
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return "unknown", "idle", False
    if not isinstance(data, dict):
        return "unknown", "idle", False
    route = str(data.get("route") or "unknown")
    stage = str(data.get("stage") or "idle")
    pending = data.get("pending_gates") or []
    stages_entered = data.get("stages_entered") or []
    has_pipeline = bool(pending) or bool(stages_entered) or (
        route != "unknown" and stage != "idle"
    )
    return route, stage, has_pipeline

def hint_for(stage: str) -> Optional[str]:
    value = (stage or "").lower()
    for keys, hint in HINTS:
        if value in keys:
            return hint
    for keys, hint in HINTS:
        for key in keys:
            if value.startswith(key) or key in value:
                return hint
    return None

def truncate_line(
    line: str, width: int, protected: Optional[list[str]] = None
) -> str:
    if len(line) <= width:
        return line
    width = max(1, width)
    suffix = "".join(protected or [])
    if suffix and len(suffix) < width:
        main = line[:-len(suffix)]
        available = width - len(suffix) - 1
        if available > 0:
            return main[:available].rstrip() + "…" + suffix
    if width == 1:
        return "…"
    return line[: width - 1].rstrip() + "…"

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

def try_ensure_spend_dir(spend_dir: Path) -> bool:
    if spend_dir.is_dir():
        return True
    try:
        spend_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        return spend_dir.is_dir()
    return spend_dir.is_dir()

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
    snapshots_path = spend_dir / "snapshots.jsonl"
    state_path = spend_dir / "state.json"

    all_rows = load_snapshots(snapshots_path) if snapshots_path.is_file() else []
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
        if try_ensure_spend_dir(spend_dir):
            try:
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
            except OSError:
                pass

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
    stage_override = os.environ.get("STATUSLINE_LOREGATE_STAGE")
    route_override = os.environ.get("STATUSLINE_LOREGATE_ROUTE")
    if stage_override or route_override:
        stage = stage_override or "idle"
        route = route_override or "unknown"
        has_pipeline = True
    else:
        route, stage, has_pipeline = resolve_route_stage(Path(root))
    delta_stage_pp = 0
    peak_stage = ""
    peak_pp = 0
    if used is None:
        line1 = f"cursor  {model}  ctx —  ring"
    else:
        ctx_pct = float(used)
        pct = int(ctx_pct)
        line1 = f"cursor  {model}  ctx {pct}% {bar(pct)}  ring"
        if has_pipeline:
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

    try:
        render_width = int(payload.get("render_width_chars") or 120)
    except (TypeError, ValueError):
        render_width = 120
    protected = []
    if not has_pipeline:
        line2 = "pipe  —  (no loregate gates)"
    else:
        line2 = f"pipe  {route}·{stage}  {delta_stage_pp:+d}pp/stage"
        if peak_stage:
            line2 += f"  peak:{peak_stage}(+{peak_pp})"
        if delta_stage_pp >= 15:
            alert = f"  ⚠+{delta_stage_pp}"
            line2 += alert
            protected.append(alert)
        hint = hint_for(stage)
        if hint:
            hint_suffix = f"  hint:{hint}"
            line2 += hint_suffix
            protected.append(hint_suffix)
    line2 = truncate_line(line2, render_width, protected)
    print(line1)
    print(line2)
    return 0

sys.exit(main())
PY
