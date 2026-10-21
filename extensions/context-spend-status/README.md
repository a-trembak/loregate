# Loregate Context Spend

This Cursor extension shows the active Loregate pipeline stage and its context
spend in the status bar.

## Install

Run `lgt install` or `lgt update` from the Loregate kit. The installer compiles
the extension and copies it into `~/.cursor/extensions`.

After installation, run **Developer: Reload Window** in Cursor.

## Status item

The status item shows the current route and pipeline stage. It adds a warning
when the current stage has consumed at least 15 context percentage points.
Select the item to open details, including the largest stage increase and a
stage-specific hint.

Snapshots older than 24 hours are ignored, and metrics use only the latest
session recorded in the snapshot file.
