#!/usr/bin/env bash
# Cursor CLI statusLine command — Loregate context-spend proxies (v1).
# Reads StatusLinePayload JSON on stdin; prints 1–2 lines on stdout.
set -euo pipefail

export STATUSLINE_LOREGATE_ROOT="${STATUSLINE_LOREGATE_ROOT:-}"
export STATUSLINE_LOREGATE_NOW_MS="${STATUSLINE_LOREGATE_NOW_MS:-}"

exec 3<&0

python3 - <<'PY'
import json, os, sys
from pathlib import Path

def bar(pct: int, width: int = 10) -> str:
    pct = max(0, min(100, pct))
    filled = pct * width // 100
    return "█" * filled + "░" * (width - filled)

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
