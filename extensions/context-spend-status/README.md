# Loregate Pipeline Status

Cursor extension for Loregate: a **Pipeline Map** Webview (green / here / waiting / blocked) plus an optional context-spend status chip when the system status bar is visible.

## Install

Run `lgt install` or `lgt update` from the Loregate kit. The installer compiles
this extension and copies it into `~/.cursor/extensions`.

After installation, run **Developer: Reload Window** in Cursor.

## Primary: Pipeline Map (Agent Window friendly)

1. Open the Command Palette.
2. Run **Loregate: Show Pipeline Map**.

This opens an editor Webview that polls `pipeline-status.sh --json` about every
three seconds. No agent tokens are used for refresh.

If the Activity Bar / Primary Side Bar is visible, a **Loregate** icon may also
appear; it shows the same map. The command works even when that icon is hidden.

## Status chip (optional)

When Cursor’s system status bar is visible, a `pipe …` chip may appear there.
Select it to open the Pipeline Map. If the system status bar is missing (known
Cursor layout bugs), rely on **Loregate: Show Pipeline Map** instead.

## Data

- Orientation: `scripts/pipeline-status.sh --json`
- Context-spend snapshots (optional): `.cursor/gates/context-spend/snapshots.jsonl`

Prefer a workspace folder that contains `.cursor/gates`.
