# Task 2 report: Extension activation and polling

## Status

Complete on `feat/ide-context-spend-statusbar`.

## Delivered behavior

- The extension creates a visible status bar item and the `Loregate Context Spend` output channel.
- Selecting the status item runs `loregate.contextSpend.show` and opens the latest formatted details.
- The extension refreshes every three seconds and when workspace folders change.
- Multi-root selection prefers the first folder containing `.cursor/gates`, then falls back to the first folder.
- Pipeline helper resolution checks the workspace helper, the workspace kit marker, and the user kit marker in that order.
- Pipeline status execution uses a 1.5-second abort timeout and derives `hasPipeline` from pending gates, entered stages, or a known active route and stage.
- Snapshot metrics use the latest stored snapshot percentage as current context. No synthetic context percentage is created.
- Activation resources and the polling timer are disposed during deactivation.

## Test-driven development evidence

1. Added tests for workspace-folder selection and helper-path resolution before the production modules existed.
2. Ran `npm test` and confirmed compilation failed because `resolveFolder` and `pipelineStatus` did not exist.
3. Implemented the minimum helper modules and reran the complete suite successfully.

## Verification

Commands:

```text
cd extensions/context-spend-status && npm run compile && npm test
git diff --check
```

Results:

- TypeScript compilation passed in strict mode.
- All 23 tests passed and none failed.
- Cursor reported no linter errors in the changed extension files.
- `git diff --check` passed.

## Scope confirmation

- No installer work was included.
- The pre-existing local change in `scripts/pipeline-status.sh` was not modified or staged.

## Concerns

The local npm configuration emits an unrelated warning about the deprecated `devdir` setting. Compilation and tests are unaffected.
# Task 2 report — Snapshots, per-stage delta, peak, alert

## Status

**DONE**

## TDD steps

1. Appended the snapshot, peak, alert, debounce, and session-isolation tests from the task brief.
2. Ran `bash scripts/tests/statusline-loregate-test.sh`.
3. Confirmed the expected red state: `snap_exists`, `peak_tech`, `alert_warn`, and `delta_stage` failed because Task 1 still had the placeholder worker.
4. Implemented snapshot persistence and stage metrics in the inline Python worker while preserving the file-descriptor-3 stdin pattern.
5. Ran the tests again and confirmed `ALL PASS`.
6. Committed only the two requested script files.

## Commit

- `0090e39` — `feat: snapshot stage context deltas for statusline-loregate`

## Test summary

`bash scripts/tests/statusline-loregate-test.sh` → `ALL PASS` (12 checks covering the existing status line, snapshots, stage peak, alert, debounce, and session isolation).

`bash -n scripts/statusline-loregate.sh scripts/tests/statusline-loregate-test.sh` → passed.

`git diff --check` → passed.

Cursor diagnostics reported no linter errors in either changed file.

## Implementation summary

- Reads the command-line interface payload from file descriptor 3, preserving Task 1 behavior.
- Uses `STATUSLINE_LOREGATE_STAGE` and `STATUSLINE_LOREGATE_ROUTE` when set; otherwise uses `idle` and `unknown`.
- Writes `snapshots.jsonl` and `state.json` under `.cursor/gates/context-spend/`.
- Writes on stage changes or context movement of at least one percentage point, with a two-second debounce except for stage changes.
- Trims snapshot history to the latest 500 rows.
- Calculates current-stage delta and the largest completed positive stage growth for the current session only.
- Adds the warning marker when the current-stage delta reaches 15 percentage points.
- Leaves pipeline-status resolution and the hint dictionary for Task 3.

## Concerns

No blockers. The task tests use a temporary directory outside the repository, so the final test run required execution outside the restricted filesystem sandbox. No unrelated dirty files or language markers were staged or committed.
