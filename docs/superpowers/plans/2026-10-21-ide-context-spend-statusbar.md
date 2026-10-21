# IDE Context-Spend Status Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Cursor/VS Code extension under `extensions/context-spend-status/` that shows `pipe …` in the IDE status bar for Agent Window users, with click → Output channel, and copy that extension on `lgt install`.

**Architecture:** Pure TypeScript modules compute status text from `pipeline-status.sh --json` + snapshots JSONL; `extension.ts` owns StatusBarItem, 3s poll, and Output channel. Installer copies the built/extension folder into `~/.cursor/extensions/loregate-context-spend-status-<version>/`. CLI statusline remains separate.

**Tech Stack:** TypeScript, `@types/vscode`, Node 18+, kit Bash installer, Node built-in `node:test` (or kit-style shell wrapping `node --test`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-10-21-ide-context-spend-statusbar-design.md` (mark **approved** in docs task).
- Kit work: edit loregate directly; **do not** `/lgt-start-task` / Pipeline route on the kit (`kit-no-pipeline-dogfood`).
- Extension path: `extensions/context-spend-status/`.
- Status text: `pipe <route>·<stage>` + optional `⚠+N` when delta ≥ **15** pp; no gates → `pipe — (no gates)`.
- Data: hybrid JSON helper + snapshots; **do not** parse CLI statusline stdout; do not require `$KIT` when project has `scripts/pipeline-status.sh`.
- Helper timeout ~**1.5** s; refresh ~**3** s; hint **current stage only** (same dictionary as CLI design).
- Install: `lgt install` / `--user-only` **copies** extension to `~/.cursor/extensions/loregate-context-spend-status-<version>/` + Reload Window hint.
- No marketplace publish, no webview, no HITL changes, no live ring % in IDE.
- Snapshot policy v1: **read** snapshots when present; **also write** snapshots on poll when the extension can obtain a ctx percentage proxy — if IDE has no ring API, v1 writes are **skipped** (stage-only UI) unless a future setting supplies ctx; do **not** invent fake ctx %. Document this clearly in extension README.

---

## File Structure

| Path | Responsibility |
|------|----------------|
| `extensions/context-spend-status/package.json` | Extension manifest (`name`, `version` `0.0.1`, `engines`, `activationEvents`, `main`) |
| `extensions/context-spend-status/tsconfig.json` | Compile to `out/` |
| `extensions/context-spend-status/src/hints.ts` | Hint dictionary |
| `extensions/context-spend-status/src/snapshots.ts` | Load JSONL; compute delta/peak/alert |
| `extensions/context-spend-status/src/format.ts` | `formatStatusText`, `formatOutput` |
| `extensions/context-spend-status/src/resolveFolder.ts` | Multi-root folder pick |
| `extensions/context-spend-status/src/pipelineStatus.ts` | Resolve helper path + run `--json` |
| `extensions/context-spend-status/src/extension.ts` | activate / StatusBarItem / Output / timer |
| `extensions/context-spend-status/src/*.test.ts` | `node:test` unit tests |
| `extensions/context-spend-status/README.md` | Manual install + Reload |
| `scripts/install-to-project.sh` | `install_user_bits` copy extension |
| `scripts/tests/ide-context-spend-statusbar-install-test.sh` | Grep installer + path exists |
| `docs/superpowers/dogfood/ide-context-spend-statusbar-checklist.md` | Manual Agent Window checks |
| `README.md` (kit) | Short pointer to extension |
| Design spec | Status → `approved` |

---

### Task 1: Pure modules + unit tests (TDD)

**Files:**
- Create: `extensions/context-spend-status/package.json`, `tsconfig.json`
- Create: `src/hints.ts`, `src/snapshots.ts`, `src/format.ts`
- Create: `src/hints.test.ts`, `src/snapshots.test.ts`, `src/format.test.ts`

**Interfaces:**

```typescript
export function hintForStage(stage: string): string | undefined;

export type Snapshot = {
  ts: string;
  session_id: string;
  ctx_pct: number;
  stage: string;
  route: string;
  invocation_id?: string;
};

export type SpendMetrics = {
  deltaStagePp: number | null;
  peakStage: string | null;
  peakPp: number | null;
  alert: boolean; // deltaStagePp >= 15
};

export function loadSnapshots(jsonl: string): Snapshot[];
export function metricsForSession(snapshots: Snapshot[], sessionId: string, currentStage: string, currentCtx: number | null): SpendMetrics;

export function formatStatusText(input: {
  hasPipeline: boolean;
  route: string;
  stage: string;
  alertPp: number | null; // if alert, the N for ⚠+N
}): string;

export function formatOutput(input: {
  route: string;
  stage: string;
  deltaStagePp: number | null;
  peakStage: string | null;
  peakPp: number | null;
  hint: string | null;
  snapshotsPath: string;
}): string;
```

Hint map (exact tokens from CLI design):

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

- [x] **Step 1: Scaffold `package.json` + `tsconfig.json`**

`package.json` essentials:

```json
{
  "name": "loregate-context-spend-status",
  "displayName": "Loregate Context Spend",
  "version": "0.0.1",
  "publisher": "loregate",
  "engines": { "vscode": "^1.85.0" },
  "categories": ["Other"],
  "activationEvents": ["onStartupFinished"],
  "main": "./out/extension.js",
  "scripts": {
    "compile": "tsc -p .",
    "test": "npm run compile && node --test out/**/*.test.js"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/vscode": "^1.85.0",
    "typescript": "^5.4.0"
  }
}
```

`tsconfig.json`: `rootDir` `src`, `outDir` `out`, `module` `commonjs`, `target` `ES2022`, `strict` true. Exclude nothing needed for tests co-located in `src/`.

- [x] **Step 2: Write failing tests** for `hintForStage('review-gate') === 'cut-clarify'`, `formatStatusText` no-gates / with alert, `metricsForSession` peak and alert ≥15.

Example `format.test.ts`:

```typescript
import test from "node:test";
import assert from "node:assert/strict";
import { formatStatusText } from "./format";

test("no gates", () => {
  assert.equal(
    formatStatusText({ hasPipeline: false, route: "unknown", stage: "idle", alertPp: null }),
    "pipe — (no gates)"
  );
});

test("with alert", () => {
  assert.equal(
    formatStatusText({
      hasPipeline: true,
      route: "full",
      stage: "review-gate",
      alertPp: 17,
    }),
    "pipe full·review-gate ⚠+17"
  );
});
```

- [x] **Step 3: Run tests — expect FAIL**

```bash
cd extensions/context-spend-status && npm install && npm test
```

- [x] **Step 4: Implement modules until PASS**

`hasPipeline` false → no-gates string. Alert only when `alertPp != null`. Prefer exact stage match before substring in `hintForStage`.

Peak algorithm: for one `session_id`, group contiguous same-`stage` runs; each run’s pp = last.ctx_pct − first.ctx_pct; peak = max positive run; current `deltaStagePp` = current ctx − first ctx of current stage run (if `currentCtx` null, deltas null, alert false).

- [x] **Step 5: Commit**

```bash
git add extensions/context-spend-status
git commit -m "$(cat <<'EOF'
feat: add context-spend status bar pure modules

Unit-tested hint map, snapshot metrics, and status/output formatters for the IDE extension.
EOF
)"
```

---

### Task 2: Extension activate — StatusBarItem + Output + poll skeleton

**Files:**
- Create: `src/resolveFolder.ts`, `src/pipelineStatus.ts`, `src/extension.ts`
- Modify: `package.json` (`contributes.commands` optional `loregate.contextSpend.show`)

**Interfaces:**

```typescript
export function pickWorkspaceFolder(
  folders: { uri: { fsPath: string } }[],
  gatesExists: (folderPath: string) => boolean
): string | null;

export type PipelineOrientation = {
  route: string;
  stage: string;
  hasPipeline: boolean;
};

export async function fetchPipelineOrientation(
  root: string,
  opts: { timeoutMs?: number; homedir: string; readFile: (p: string) => string | null }
): Promise<PipelineOrientation | { error: string }>;
```

`hasPipeline`: true when pending gates non-empty OR `stages_entered` non-empty OR (`route !== 'unknown'` && `stage !== 'idle'`) — match CLI statusline resolver spirit.

Helper path order:
1. `<root>/scripts/pipeline-status.sh`
2. kit root from `<root>/.cursor/cursor-spells-kit-path` then `scripts/pipeline-status.sh`
3. kit root from `homedir/.cursor/cursor-spells-kit-path`

Run: `bash <helper> --json --root <root>` with timeout 1500ms via `AbortSignal` / kill.

- [x] **Step 1: Tests for `pickWorkspaceFolder` and helper path resolution** (fake fs)

- [x] **Step 2: Implement resolve + fetch**

- [x] **Step 3: Implement `extension.ts`**

```typescript
import * as vscode from "vscode";
// on activate:
// - create StatusBarItem (Right or Left — prefer Right, priority high enough to be visible)
// - create OutputChannel "Loregate Context Spend"
// - command on click → show channel with formatOutput(...)
// - setInterval 3000 refresh
// - onDidChangeWorkspaceFolders → refresh
// - dispose on deactivate
```

Refresh body:
1. `root = pickWorkspaceFolder(...)`
2. If null → `pipe — (no gates)`
3. `orient = await fetchPipelineOrientation`
4. Read snapshots file if exists; `metricsForSession` with `currentCtx: null` in v1 (no ring) → no ⚠ unless snapshots already have history **and** we can compute from last snapshot ctx as current (use **last snapshot ctx_pct** as currentCtx when file exists so peak/alert still work for CLI-written snapshots)
5. `item.text = "$(dashboard) " + formatStatusText(...)` (or without icon if preferred)
6. `item.tooltip = ...`
7. Store last `formatOutput` payload for click

- [x] **Step 4: `npm run compile` succeeds; manual smoke optional**

- [x] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: wire IDE StatusBarItem for Loregate context spend

Poll pipeline-status JSON and snapshots; click opens the Output channel.
EOF
)"
```

---

### Task 3: Installer copy + kit README + dogfood + design approved

**Files:**
- Modify: `scripts/install-to-project.sh` (`install_user_bits`)
- Create: `scripts/tests/ide-context-spend-statusbar-install-test.sh`
- Create: `docs/superpowers/dogfood/ide-context-spend-statusbar-checklist.md`
- Modify: kit `README.md` (short section under CLI statusline or nearby)
- Modify: design spec Status → `approved`
- Ensure `extensions/context-spend-status/.vscodeignore` excludes `src/`, `node_modules` appropriately for copy (copy **compiled** `out/` + `package.json` + README; run `npm run compile` before install copy, or copy sources and compile in installer — **prefer:** installer copies tree that already includes `out/` after compile in CI/dev; installer runs `npm run compile` in extension dir if `out/extension.js` missing)

**Install copy algorithm:**

```bash
EXT_SRC="$KIT_ROOT/extensions/context-spend-status"
EXT_VER="$(python3 -c 'import json;print(json.load(open("'"$EXT_SRC"'/package.json"))["version"])')"
EXT_DEST="$HOME/.cursor/extensions/loregate-context-spend-status-$EXT_VER"
# compile if needed
if [[ ! -f "$EXT_SRC/out/extension.js" ]]; then
  (cd "$EXT_SRC" && npm install --omit=dev --no-fund --no-audit && npx tsc -p .) || true
fi
# Actually need typescript to compile — prefer: always `npm ci && npm run compile` when network allowed; on failure print skill_missing-style warning and skip copy
rm -rf "$EXT_DEST"
mkdir -p "$EXT_DEST"
# copy package.json, README.md, out/
cp "$EXT_SRC/package.json" "$EXT_DEST/"
cp "$EXT_SRC/README.md" "$EXT_DEST/" 2>/dev/null || true
cp -R "$EXT_SRC/out" "$EXT_DEST/out"
echo "copied: $EXT_DEST"
echo "hint: Reload Window to enable Loregate Context Spend status bar (Agent Window / IDE)"
```

If compile fails: one warning line; do not fail entire `lgt install`.

- [x] **Step 1: Failing install grep test**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
grep -q 'loregate-context-spend-status' "$ROOT/scripts/install-to-project.sh"
grep -q 'context-spend-status' "$ROOT/README.md"
test -f "$ROOT/extensions/context-spend-status/package.json"
echo "ALL PASS"
```

- [x] **Step 2: Implement installer + README + dogfood checklist**

Dogfood steps: install → Reload → mid-pipeline status text → click Output → empty project no-gates → missing helper does not freeze.

- [x] **Step 3: Mark design `approved`**

- [x] **Step 4: Run**

```bash
bash scripts/tests/ide-context-spend-statusbar-install-test.sh
cd extensions/context-spend-status && npm test
```

- [x] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: install Loregate context-spend IDE extension on lgt install

Copy the status bar extension into ~/.cursor/extensions and document Agent Window dogfood.
EOF
)"
```

---

## Spec coverage self-check

| Spec item | Task |
|-----------|------|
| StatusBarItem `pipe …` / ⚠ / no gates | 1–2 |
| Output on click | 2 |
| Hybrid pipeline-status + snapshots | 2 |
| Helper resolution / timeout / multi-root | 2 |
| Hint map / 15pp | 1 |
| `lgt install` copy + Reload hint | 3 |
| README + dogfood | 3 |
| No marketplace / no ring % / no HITL | honored |

## Placeholder scan

None intentional — implementers use the signatures and copy blocks above.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-10-21-ide-context-spend-statusbar.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task  
2. **Inline Execution** — this session with checkpoints  

Which approach?
