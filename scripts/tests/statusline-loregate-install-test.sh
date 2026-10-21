#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
grep -q 'statusline-loregate.sh' "$ROOT/scripts/install-to-project.sh"
grep -q 'CLI context spend' "$ROOT/README.md" || grep -q 'statusline-loregate' "$ROOT/README.md"
echo "ALL PASS"
