# Loregate Pipeline Status

Cursor extension for Loregate: a live **Pipeline Map** for Agent Window (Canvas) and editor (Webview), plus an optional context-spend status chip when the system status bar is visible.

## Install

Run `lgt install` or `lgt update` from the Loregate kit. The installer compiles
this extension and copies it into `~/.cursor/extensions`.

After installation, run **Developer: Reload Window** in Cursor.

## Primary: Agent Window Canvas (zero tokens)

On activate and about every three seconds, the extension writes:

`~/.cursor/projects/<workspace-id>/canvases/loregate-pipeline-status.canvas.tsx`

Open that file as a Canvas beside the chat. Cursor hot-reloads when the file
changes on disk. No agent tokens are used for refresh.

**Agent Window note:** the VS Code extension poll often does not stay alive
there. Use the background watcher (no agent tokens):

```bash
bash scripts/pipeline-map-canvas-watch.sh --root /path/to/workspace
# stop later:
bash scripts/pipeline-map-canvas-watch.sh --stop --root /path/to/workspace
```

Each stage has a **Copy** button that puts a slash command or skill key on the
clipboard (for example `/lgt-engineer-review`). Paste into chat — Canvas cannot
type into the current chat for you.

You can also write once from a terminal:

```bash
bash scripts/pipeline-map-canvas.sh --root /path/to/workspace
```

## Secondary: Webview command

1. Open the Command Palette.
2. Run **Loregate: Show Pipeline Map**.

This opens an editor Webview with the same tree. If the Activity Bar is visible,
a **Loregate** icon may also show the map. Agent Window does not show that icon.

## Status chip (optional)

When Cursor’s system status bar is visible, a `pipe …` chip may appear there.
Select it to open the Pipeline Map. If the system status bar is missing, use the
Canvas or **Loregate: Show Pipeline Map**.

## Data

- Orientation: `scripts/pipeline-status.sh --json`
- Context-spend snapshots (optional): `.cursor/gates/context-spend/snapshots.jsonl`

Prefer a workspace folder that contains `.cursor/gates`.
