#!/usr/bin/env bash
# Background rewriter for Agent Window loregate-pipeline-status.canvas.tsx.
# Cursor Agent Window often does not keep the Loregate VS Code extension poll
# alive — this loop does the same disk write without agent tokens.
#
# Usage:
#   pipeline-map-canvas-watch.sh --root <workspace> [--interval 5] [--once]
#   pipeline-map-canvas-watch.sh --stop --root <workspace>
set -euo pipefail

ROOT=""
INTERVAL=5
ONCE=0
STOP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="${2:-}"
      shift 2
      ;;
    --interval)
      INTERVAL="${2:-5}"
      shift 2
      ;;
    --once)
      ONCE=1
      shift
      ;;
    --stop)
      STOP=1
      shift
      ;;
    -h|--help)
      echo "Usage: pipeline-map-canvas-watch.sh --root <workspace> [--interval 5] [--once|--stop]"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ROOT" ]]; then
  ROOT="$(pwd)"
fi
ROOT="$(cd "$ROOT" && pwd)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXT_DIR="$KIT_ROOT/extensions/context-spend-status"
CLI="$EXT_DIR/out/writeCanvasCli.js"

STATE_DIR="${HOME}/.cursor/loregate-pipeline-map-watch"
mkdir -p "$STATE_DIR"
SAFE_ID="$(printf '%s' "$ROOT" | sed 's|/|-|g;s|^-||')"
PID_FILE="$STATE_DIR/${SAFE_ID}.pid"
LOG_FILE="$STATE_DIR/${SAFE_ID}.log"

is_alive() {
  local pid="$1"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

if [[ "$STOP" -eq 1 ]]; then
  if [[ -f "$PID_FILE" ]]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if is_alive "${old_pid:-}"; then
      kill "$old_pid" 2>/dev/null || true
      echo "stopped pid $old_pid for $ROOT"
    else
      echo "no running watcher for $ROOT"
    fi
    rm -f "$PID_FILE"
  else
    echo "no pid file for $ROOT"
  fi
  exit 0
fi

if [[ ! -f "$CLI" ]]; then
  if [[ -f "$EXT_DIR/package.json" ]]; then
    (cd "$EXT_DIR" && npm run compile >/dev/null)
  fi
fi
if [[ ! -f "$CLI" ]]; then
  echo "error: missing $CLI" >&2
  exit 1
fi

write_once() {
  node "$CLI" --root "$ROOT" >>"$LOG_FILE" 2>&1 || true
}

if [[ "$ONCE" -eq 1 ]]; then
  write_once
  exit 0
fi

# Parent (launcher) path — detect an existing daemon before forking.
if [[ "${LGT_MAP_WATCH_DAEMON:-}" != "1" ]]; then
  if [[ -f "$PID_FILE" ]]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if is_alive "${old_pid:-}"; then
      echo "already running pid $old_pid for $ROOT"
      echo "log: $LOG_FILE"
      exit 0
    fi
    rm -f "$PID_FILE"
  fi
  export LGT_MAP_WATCH_DAEMON=1
  nohup bash "$0" --root "$ROOT" --interval "$INTERVAL" >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  sleep 0.3
  if is_alive "$(cat "$PID_FILE")"; then
    echo "started pid $(cat "$PID_FILE") for $ROOT (every ${INTERVAL}s)"
    echo "log: $LOG_FILE"
    echo "stop: bash $0 --stop --root $ROOT"
    exit 0
  fi
  echo "error: watcher failed to stay up; see $LOG_FILE" >&2
  exit 1
fi

# Daemon path
echo $$ >"$PID_FILE"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) watch start root=$ROOT interval=${INTERVAL}s pid=$$" >>"$LOG_FILE"

while true; do
  write_once
  sleep "$INTERVAL"
done
