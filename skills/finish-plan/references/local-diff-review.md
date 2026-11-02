# Local change review (gate)

Human look at **local** (working tree + staged) changes during skill **`local-diff-review-gate`**. **Primary UX:** Cursor **Local Git Changes** after checkout + `SetActiveBranch`. The Cursor plugin **Local Diff Review** (`local-diff-review` / skill `review-local-diff`) is **optional opt-in** only.

**Do not vendor** the plugin skill body into this kit.

## When

Used after pipeline **engineer-review** on full plan, `/lgt-start-task --fast`, or `/lgt-start-issue-task` paths — via skill `local-diff-review-gate`. **Not** during finish-plan HITL (finish-plan uses checkout + `SetActiveBranch` only). Not on bare manual `/lgt-engineer-review` unless the human explicitly asks.

## Default path (no plugin)

During **local-diff-review-gate**, after checkout + `SetActiveBranch` when applicable:

1. Point the human at **Local Git Changes** (Source Control / Changes) for the focused repo.
2. Ask HITL `approve-diff` / `comment` (skill `hitl-choice` preset **Local Diff Review gate**).
3. On `comment`, collect notes in **this chat** (paths, optional lines, what to change). Apply via nested Task `csp-software-developer`. Return `next_skill: engineer-review` (Loop).
4. On `approve-diff`, return toward `next_skill: propose-commit` when all dirty repos are done.

Do **not** auto-run `build-canvas.mjs`. Chat `git status` / short summaries are fine; do not dump a full `git diff` unless the human asks.

## Optional plugin path

Only when the human asks for the Local Diff Review canvas / sends `use-local-diff-plugin` / `have_local_diff_canvas`:

1. Read and follow skill `review-local-diff` (and its canvas prerequisite). Do **not** paste the plugin skill body into this kit.
2. Let the skill write `.canvas.tsx` under the IDE canvases directory.
3. Human: Prepare for this chat → Copy → paste into **this** thread.
4. Accept outbound kind `local-diff-review/comments` version `1` with `intent: apply-fixes`.

Escape: `no-local-diff-review` means stay on Local Git Changes + chat notes (never force the canvas).

If they asked for the plugin and it is missing: one sentence, run-log `skipped-missing-plugin`, `skill_missing: review-local-diff` when Coverage-style notes need it, then **chat notes** fallback — still continue the gate (do not treat missing plugin as green skip of the whole human look when the tree is dirty).

## Outbound schema (plugin only)

```json
{
  "kind": "local-diff-review/comments",
  "version": 1,
  "target": "current-thread",
  "intent": "apply-fixes",
  "notes": "",
  "comments": [{ "path": "src/a.ts", "line": 12, "body": "…" }]
}
```

| Field | Notes |
|-------|--------|
| `kind` | Must be `local-diff-review/comments` |
| `version` | `1` |
| `intent` | `apply-fixes` |
| `comments` / `notes` | At least one non-empty |
| Sidecar | Plugin `outbound` / `useCanvasState` — agents do not auto-read; prefer paste |

**New chat / `newComposerChat`:** **out of scope** for pipeline glue; do not rely on it for `local-diff-review-gate`.

## Out of scope

- Opening a GitHub pull request inside this gate
- Using the plugin canvas as the default surface
- Vendoring `review-local-diff` into the kit
