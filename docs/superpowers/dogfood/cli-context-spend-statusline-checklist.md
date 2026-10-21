# Dogfood: CLI context-spend status line

Manual checks for `~/.cursor/statusline-loregate.sh` in Cursor Agent CLI.

## Preconditions

- Kit checkout or consumer project with Loregate installed
- Cursor Agent CLI available (not IDE status bar)

## Steps

1. Run `lgt install --user-only --agree-policy` (or a full project install) and confirm the installer prints `copied: ~/.cursor/statusline-loregate.sh` and the enable hint.

2. Add a `statusLine` command block to `~/.cursor/cli-config.json` (see README). Do not expect install to rewrite your config.

3. Open Cursor Agent CLI in a **consumer** project that is mid-pipeline (active gate markers or run-log stage).

4. Confirm the status area shows **two lines** that update over time; `peak:` and `hint:` values look sensible for the current stage.

5. Open CLI in an empty project with no Loregate gates and confirm line 2 shows the no-gates message (`pipe  —  (no loregate gates)` or equivalent).

6. Temporarily break the script (bad shebang or `exit 1` at top), reload CLI, and confirm the prompt does not freeze — previous status text may remain or clear, but input stays responsive.

## Reference

- Design: [`docs/superpowers/specs/2026-10-21-cli-context-spend-statusline-design.md`](../specs/2026-10-21-cli-context-spend-statusline-design.md)
- Contract tests: `bash scripts/tests/statusline-loregate-test.sh`
