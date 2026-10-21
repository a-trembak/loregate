#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
grep -q 'loregate-context-spend-status' "$ROOT/scripts/install-to-project.sh"
grep -q 'context-spend-status' "$ROOT/README.md"
test -f "$ROOT/extensions/context-spend-status/package.json"
echo "ALL PASS"
