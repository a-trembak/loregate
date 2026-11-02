#!/usr/bin/env bash
# Write Agent Window canvas loregate-pipeline-status.canvas.tsx from pipeline-status.
# Zero agent tokens. Extension also does this on a ~3s poll after install.
set -euo pipefail

ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: pipeline-map-canvas.sh [--root <workspace>]"
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

if [[ ! -f "$CLI" ]]; then
  if [[ -f "$EXT_DIR/package.json" ]]; then
    (cd "$EXT_DIR" && npm run compile >/dev/null)
  fi
fi

if [[ ! -f "$CLI" ]]; then
  echo "error: missing $CLI (compile extensions/context-spend-status)" >&2
  exit 1
fi

exec node "$CLI" --root "$ROOT"
