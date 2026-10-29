# Pipeline status Webview panel (Agent Window)

## Status

`approved` — human approved in chat (command-first panel for Agent Window; Activity Bar icon optional).

## Goal

Show a live green / here / waiting / blocked pipeline tree in Cursor without spending agent tokens. Humans working mainly in Agent Window open the map via a command; an Activity Bar icon is a convenience when the side bar is visible.

Success: after `lgt install` / Reload Window, **Loregate: Show Pipeline Map** opens a Webview that polls `pipeline-status.sh --json` ~every 3s and paints layer/stage state. No Canvas. No dependency on the system status bar (`Mem` / `FPS`).

## Decisions

| Decision | Choice |
|----------|--------|
| Primary UX | Command `loregate.pipelineMap.show` → editor Webview panel (works when Activity Bar is hidden) |
| Secondary UX | Activity Bar container **Loregate** + Webview view `loregate.pipelineMap` |
| Status bar chip | Keep existing context-spend chip when the system status bar is visible; not required for this feature |
| Location | Extend `extensions/context-spend-status/` (same install path) |
| Data | `pipeline-status.sh --json` (route, layer, stage, `stages_entered`, `pending_gates`); optional run-log tail later |
| Refresh | ~3s poll + workspace folder change; extension-only (zero model tokens) |
| Tree states | `done` (green), `here` (current), `waiting` (ahead), `blocked` (pending human gate when stage matches pending) |
| Loop (v1) | Current stage `local-diff-review-gate` (and similar) shown as `here`; blocked styling when a pending gate matches; full Loop counter can wait for richer run-log |
| Install | Existing `lgt install` copy to `~/.cursor/extensions/loregate.loregate-context-spend-status-<ver>/` |
| Out of scope | Native macOS menu bar; Canvas status; changing pipeline gate order |

## Rejected alternatives

- Status-bar-only UI — rejected: Agent Window users often hide or miss the system status bar.
- Canvas map refreshed by the agent — rejected: burns tokens.
- Separate extension package — rejected for v1; extend the existing installable extension.

## Test plan

- Unit: tree model from orientation JSON → expected node states.
- Unit: HTML/render helpers stay free of agent calls.
- Manual: Reload Window → run **Loregate: Show Pipeline Map** in a project with `.cursor/gates` → tree updates without chat turns.
