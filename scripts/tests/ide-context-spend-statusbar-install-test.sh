#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
grep -q 'loregate-context-spend-status' "$ROOT/scripts/install-to-project.sh"
grep -q 'context-spend-status' "$ROOT/README.md"
grep -q '^  if ! (cd "$ext_src" && npm install --no-fund --no-audit && npm run compile); then' \
  "$ROOT/scripts/install-to-project.sh"
test -f "$ROOT/extensions/context-spend-status/package.json"
test -f "$ROOT/extensions/context-spend-status/README.md"
grep -q 'loregate.pipelineMap.show' "$ROOT/extensions/context-spend-status/package.json"
grep -q 'viewsContainers' "$ROOT/extensions/context-spend-status/package.json"
test -f "$ROOT/extensions/context-spend-status/media/loregate.svg"
grep -q 'ext_src/media' "$ROOT/scripts/install-to-project.sh"
echo "ALL PASS"
