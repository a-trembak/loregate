# IDE context-spend status bar (Cursor Agent Window)

## Status

`draft` — awaiting human review before implementation plan.

## Goal

Show Loregate pipeline context-spend **proxies** in the Cursor **IDE status bar** (the chrome where version / Memory / fps appear), so humans working in **Agent Window** can see which pipeline stage is bloating context without opening Agent CLI.

Success: one compact status-bar item such as `pipe full·review-gate ⚠+17`; click opens an Output channel with peak, hint, and snapshot paths. Same semantic proxies as the CLI status line design — **not** API billing.

## Relationship to CLI status line

| Surface | Deliverable | Ring % |
|---------|-------------|--------|
| Cursor Agent CLI | `scripts/statusline-loregate.sh` + `cli-config.json` `statusLine` | Yes (CLI payload) |
| Cursor IDE / Agent Window | This extension’s `StatusBarItem` | **No** (not exposed to extensions) |

Both read the same on-disk orientation and snapshot stores. Neither replaces the other.

Spec for CLI: [`2026-10-21-cli-context-spend-statusline-design.md`](2026-10-21-cli-context-spend-statusline-design.md).

## Decisions

| Decision | Choice |
|----------|--------|
| Approach | VS Code / Cursor **extension** with `StatusBarItem` + Output channel on click |
| Location in kit | `extensions/context-spend-status/` |
| Not a Cursor Plugin | Skills/rules plugins cannot own the IDE status bar |
| Status text | Single item: `pipe <route>·<stage>` plus optional `⚠+N` when per-stage delta ≥ **15** pp |
| Click | Open Output channel **Loregate Context Spend** with details (route, stage, `+Npp/stage`, peak, hint, snapshot path, note that ring % is CLI-only) |
| Hover | Tooltip with peak / hint / short help |
| No gates | Always show `pipe — (no gates)` (visible placeholder, same idea as CLI) |
| Data source | **Hybrid:** `scripts/pipeline-status.sh --json --root <folder>` for route/stage; `.cursor/gates/context-spend/snapshots.jsonl` (+ optional `state.json`) for deltas / peak / alert |
| Do not parse | CLI statusline stdout (fragile); do not require `$KIT` at runtime when project has installed helpers |
| Helper resolution | Prefer `<workspaceFolder>/scripts/pipeline-status.sh`; else kit path from `<workspaceFolder>/.cursor/cursor-spells-kit-path` or `~/.cursor/cursor-spells-kit-path` |
| Snapshot writes | Extension is **read-mostly**. Prefer reading snapshots written by CLI statusline when present. If snapshots are missing, still show stage; optionally (implementation detail) append snapshots on poll using the **same rules** as the CLI design (1pp / stage change / 2s debounce / trim 500) so Agent-Window-only users still get peak/⚠ over time |
| Refresh | ~**3** seconds + refresh on workspace folder change |
| Multi-root | Prefer the folder that contains `.cursor/gates`; else first workspace folder |
| Subprocess timeout | ~**1.5** s for `pipeline-status.sh`; never block the UI thread |
| Hint dictionary | Same tokens as CLI design; **current stage only** |
| Alert threshold | **15** pp (percentage points on stored ctx snapshots — only when snapshots exist) |
| Install | README documents local install; **`lgt install` / `lgt install --user-only` copies** (or refreshes) the extension under `~/.cursor/extensions/loregate-context-spend-status-<version>/` and prints **Reload Window** |
| Marketplace | Out of scope for v1 |
| Activation | `onStartupFinished` (and/or workspaceContains `.cursor/gates` if useful) |

### Status bar example

```text
pipe full·review-gate ⚠+17
```

### Output channel example (on click)

```text
Loregate context spend (proxies — not billing)
route: full
stage: review-gate
+17pp/stage
peak: tech-spec(+28)
hint: cut-clarify
snapshots: <folder>/.cursor/gates/context-spend/snapshots.jsonl
ring %: n/a in IDE (use Agent CLI statusLine)
```

## Non-goals (v1)

- Plugging into Cursor’s built-in Memory / fps / version indicators via undocumented hooks
- Exact API token billing or parent vs nested-Task attribution
- Webview panel, Canvas, or chat strip changes (optional later: enrich `/lgt-pipeline-status`)
- Changing HITL skills or advancing gates
- Publishing to Open VSX / Marketplace
- Showing live Cursor context-ring percentage in the IDE status bar

## Test plan

- Unit: format status text; parse snapshot peak/alert; hint map; no-gates string
- Integration-style: fixture workspace with fake `pipeline-status.sh` + snapshots → expected status text
- Manual dogfood: install via `lgt install --user-only`, Reload Window, open Agent Window in a consumer project mid-pipeline, confirm status item + Output channel; empty project shows no-gates; kill helper path → `pipe ?` or error text without freezing IDE
- Contract: installer greps / copies extension directory on user install

## Open follow-ups

- Enrich `/lgt-pipeline-status` chat strip with the same spend line
- VSIX build in continuous integration
- If Cursor later exposes ring % to extensions, add a second status item or prefix
