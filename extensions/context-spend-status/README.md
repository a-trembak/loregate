# Loregate Context Spend

This Cursor extension shows the active Loregate pipeline route and stage in the
IDE status bar (Agent Window / desktop chrome).

## Install

Run `lgt install` or `lgt update` from the Loregate kit. The installer compiles
the extension and copies it into `~/.cursor/extensions`.

After installation, run **Developer: Reload Window** in Cursor.

## Status item

The status item always shows the current route and pipeline stage when gates or
run history exist (`pipe <route>·<stage>`). Select it to open an Output channel
with details and a stage-specific hint.

**Peak and the 15pp warning need CLI snapshots.** This extension cannot read
Cursor’s context-ring percentage, so it does **not** write
`.cursor/gates/context-spend/snapshots.jsonl`. Enable the kit CLI status line
(`~/.cursor/statusline-loregate.sh` in `cli-config.json`) so that file is
populated. Then this status bar can show peak stage growth and `⚠+N` from the
same on-disk store. Without those snapshots, the bar still shows stage only.

Snapshots older than 24 hours are ignored, and metrics use only the latest
session recorded in the snapshot file.

## Related

- Kit README: CLI status line + IDE sections
- Design: `docs/superpowers/specs/2026-10-21-ide-context-spend-statusbar-design.md`
