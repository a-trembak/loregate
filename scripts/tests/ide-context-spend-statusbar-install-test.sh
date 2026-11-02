#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
grep -q 'loregate.loregate-context-spend-status' "$ROOT/scripts/install-to-project.sh"
grep -q 'context-spend-status' "$ROOT/README.md"
grep -q '^  if ! (cd "$ext_src" && npm install --no-fund --no-audit && npm run compile); then' \
  "$ROOT/scripts/install-to-project.sh"
test -f "$ROOT/extensions/context-spend-status/package.json"
test -f "$ROOT/extensions/context-spend-status/README.md"
grep -q 'loregate.pipelineMap.show' "$ROOT/extensions/context-spend-status/package.json"
grep -q 'viewsContainers' "$ROOT/extensions/context-spend-status/package.json"
test -f "$ROOT/extensions/context-spend-status/media/loregate.svg"
test -f "$ROOT/extensions/context-spend-status/src/pipelineMapCanvas.ts"
test -f "$ROOT/extensions/context-spend-status/src/writeCanvasCli.ts"
test -f "$ROOT/scripts/pipeline-map-canvas.sh"
grep -q 'loregate-pipeline-status.canvas.tsx' "$ROOT/extensions/context-spend-status/README.md"
grep -q 'Canvas' "$ROOT/docs/superpowers/specs/2026-10-29-pipeline-status-webview-panel-design.md"
grep -q 'ext_src/media' "$ROOT/scripts/install-to-project.sh"
echo "ALL PASS"
