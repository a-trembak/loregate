# Pipeline status map (Agent Window Canvas + Webview)

## Status

`approved` — human approved command-first Webview, then approved **Canvas pivot** for Agent Window (chat: Canvas path / “yes”).

## Goal

Show a live green / here / waiting / blocked pipeline tree in Cursor without spending agent tokens. Agent Window does not host extension Activity Bar icons, so the **primary** surface there is an Agent Window **Canvas** file rewritten on disk. The Webview command remains for the editor layout.

Success: after `lgt install` / Reload Window, the extension (or `scripts/pipeline-map-canvas.sh`) writes `loregate-pipeline-status.canvas.tsx` under `~/.cursor/projects/<workspace-id>/canvases/`. Opening that canvas beside chat shows the map; disk rewrites hot-reload with **no agent tokens**. Optional: **Loregate: Show Pipeline Map** still opens the Webview panel. Legacy filename `loregate-pipeline-map.canvas.tsx` may remain from older hosts — ignore it.

## Decisions

| Decision | Choice |
|----------|--------|
| Primary UX (Agent Window) | Canvas `loregate-pipeline-status.canvas.tsx` with embedded STATE; rewrite on change (~3s poll) |
| Secondary UX | Command `loregate.pipelineMap.show` → editor Webview panel + optional Activity Bar view |
| Status bar chip | Keep existing context-spend chip when the system status bar is visible; not required |
| Location | Extend `extensions/context-spend-status/` (same install path); CLI `out/writeCanvasCli.js` + `scripts/pipeline-map-canvas.sh` |
| Data | `pipeline-status.sh --json` → `buildPipelineTree` → canvas / HTML |
| Refresh | ~3s extension poll + workspace folder change; fingerprint skip when tree unchanged |
| Tree states | `done` (success), `here` (warning), `waiting` (info), `blocked` (danger) via Canvas `Stat` tones |
| Loop (v1) | Current stage `local-diff-review-gate` shown as `here`; blocked when pending gate matches |
| Install | `lgt install` → `~/.cursor/extensions/loregate.loregate-context-spend-status-<ver>/` |
| Out of scope | Native macOS menu bar; agent-driven canvas edits; changing pipeline gate order |

## Rejected alternatives

- Status-bar-only UI — rejected: Agent Window users often hide or miss the system status bar.
- Canvas refreshed by the **agent** each turn — rejected: burns tokens; disk rewrite from the extension/script is the fix.
- Activity Bar icon as sole Agent Window entry — rejected: Agent Window reserves that chrome; icons do not appear.
- Separate extension package — rejected for v1; extend the existing installable extension.

## Canvas path

`~/.cursor/projects/<sanitized-absolute-workspace>/canvases/loregate-pipeline-status.canvas.tsx`

Example: workspace `/Users/ukad/loregate` → project id `Users-ukad-loregate`.

## Test plan

- Unit: tree model from orientation JSON → expected node states.
- Unit: canvas source embeds STATE, imports only `cursor/canvas`, no `fetch`.
- Unit: canvases dir sanitization; write skip when fingerprint unchanged.
- Manual: Reload Window → open the canvas link → tree updates without chat turns; optional Webview command still works.
