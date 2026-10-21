# Dogfood: IDE context-spend status bar

Manual checks for the Loregate Context Spend extension in Cursor Agent Window / IDE status bar.

## Preconditions

- Kit checkout or consumer project with Loregate installed
- Cursor desktop with Agent Window (not Agent CLI status line)

## Steps

1. Run `lgt install --user-only --agree-policy` (or a full project install) and confirm the installer prints `copied: ~/.cursor/extensions/loregate-context-spend-status-<version>/` and the Reload Window hint.

2. **Developer: Reload Window** (Command Palette) so Cursor loads the copied extension.

3. Open a **consumer** project mid-pipeline (active gate markers or run-log stage). Confirm the IDE status bar shows compact `pipe …` text that updates every few seconds (route and stage even without snapshots).

4. With **CLI status line enabled** in that project (so `.cursor/gates/context-spend/snapshots.jsonl` exists), confirm peak / ⚠ can appear when deltas warrant it. Without that file, expect stage-only (no invented peak).

5. Click the status bar item and confirm the **Output** channel opens with hint, snapshot path, and the ring-% note for CLI.

6. Open an empty project with no Loregate gates and confirm the status text shows the no-gates message (no freeze, no endless spinner).

7. Temporarily rename `scripts/pipeline-status.sh` in the project (or point at a folder without helpers) and confirm the status bar still updates (fallback / timeout) — the IDE must not hang.

## Reference

- Design: [`docs/superpowers/specs/2026-10-21-ide-context-spend-statusbar-design.md`](../specs/2026-10-21-ide-context-spend-statusbar-design.md)
- Extension tests: `cd extensions/context-spend-status && npm test`
- Install grep test: `bash scripts/tests/ide-context-spend-statusbar-install-test.sh`
