# Local Diff Review (plugin)

Optional Agent Window canvas for the human look at **local** (working tree + staged) changes during skill **`local-diff-review-gate`** (and residual kit docs). **Do not vendor** the skill body into this kit.

## Source

Cursor plugin **Local Diff Review** (`local-diff-review`) — skill id / command `review-local-diff`. Install via Cursor Plugins (local plugins tree or Marketplace). Companion: Cursor Canvas skill (`~/.cursor/skills-cursor/canvas/SKILL.md`).

Full outbound schema lives in the plugin: `skills/review-local-diff/references/payload.md`. This kit cites kind / version / fields only.

## When the pipeline runs it

Used after pipeline **engineer-review** on full plan, `/lgt-start-task --fast`, or `/lgt-start-issue-task` paths — via skill `local-diff-review-gate`. **Not** during finish-plan HITL (finish-plan uses checkout + `SetActiveBranch` only). Not on bare manual `/lgt-engineer-review` unless the human explicitly asks for the canvas.

During **local-diff-review-gate**, after checkout + `SetActiveBranch` when applicable:

1. Unless the human already sent `no-local-diff-review` in this gate turn.
2. Pass absolute git roots from the changed repos (each open-folder root) and, when known, the current agent `conversationId`.
3. Prefer this canvas over pasting the full `git diff` into chat. When the plugin is missing, skill `local-diff-review-gate` skips with run-log `skipped-missing-plugin` and returns `next_skill: propose-commit` (not a chat `git diff` primary path). Chat paste remains a **fallback** only for `no-local-diff-review` or canvas failure after the human opted out.

## How to run

1. Read and follow skill `review-local-diff` (and its canvas prerequisite). Do **not** paste the plugin skill body into this kit.
2. Let the skill collect local diffs (unstaged + staged) and write the `.canvas.tsx` under the IDE canvases directory per the Canvas skill (not into the repo).
3. Remember the canvas path returned by the save/write step and the current `outbound.sentAt` if any (or note absence).
4. Tell the human in plain language:
   - Open the canvas beside chat.
   - Leave comments on files (optional `line`).
   - Keep **Current thread** selected and press **Send**.
   - Or answer gate tokens with no comments when the gate allows it.
5. Do **not** open a GitHub pull request. Do **not** invoke `propose-commit` or `create-pr` here unless the gate protocol says otherwise.

## Outbound payload (sidecar)

Send always writes `useCanvasState("outbound")` **before** any chat action. Official Canvas host send only supports `newComposerChat` / `openAgent` / `openFile`; **current-thread** delivery is this sidecar, which glue reads in **this** thread.

Minimal shape (v1):

```json
{
  "kind": "local-diff-review/comments",
  "version": 1,
  "target": "current-thread",
  "conversationId": "<uuid>",
  "sentAt": "2026-09-25T10:13:00.000Z",
  "intent": "apply-fixes",
  "notes": "",
  "comments": [{ "path": "src/foo.ts", "body": "…", "line": 42 }]
}
```

| Field | Glue rule |
|-------|-----------|
| `kind` | Must be `local-diff-review/comments` |
| `version` | Must be `1` for this kit spine |
| `target` | Prefer `current-thread` on the pipeline path |
| `sentAt` | Treat as a new submit only when newer than the last handled `sentAt` |
| `intent` | `apply-fixes` → fix cycle (below) |
| `comments` | Array of `{ path, body, line? }`; empty + empty `notes` is not a fix cycle |
| `notes` | Optional free-text brief alongside per-file comments |

**Current thread (default in plugin v1.1+):** do not open a new chat; when `conversationId` is set, plugin may `openAgent` only to focus this thread.

**New chat:** same JSON may go to `newComposerChat` — **out of scope** for pipeline glue; do not rely on it for `local-diff-review-gate`.

## Wait and apply-fixes handoff

During skill **`local-diff-review-gate`** (not finish-plan review-gate — no finish-plan-style `fixes` re-ask):

1. Ask the gate HITL via skill `hitl-choice` when the gate requires it (`approve-diff` / `comment`).
2. On **`comment`**, follow plugin skill `review-local-diff`, link the canvas, and end the turn waiting for this thread (paste block or sidecar — do **not** poll `*.canvas.data.json`).
3. When the human sends **`local-diff-review/comments`** (paste or sidecar with `intent: apply-fixes` and non-empty `comments` and/or `notes`):
   - Build a brief for nested Task **`csp-software-developer`**: each `path` + optional `line` + `body`, plus `notes`.
   - Wait for `csp-software-developer` to return (no commit, push, or pull request).
   - Score per skill `trajectory-score` when the gate protocol requires it.
   - **Return immediately** to the pipeline caller with **`next_skill: engineer-review`** (Loop). Do **not** ask `approve-diff` / `comment` again in the same turn. Do **not** invoke `propose-commit`.
4. The **caller** re-runs engineer-review, Teach-review miss, then **`local-diff-review-gate`** again until the human answers `approve-diff` and the gate returns **`next_skill: propose-commit`**.

## Missing plugin

If skill `review-local-diff` (or Canvas) cannot be loaded: one sentence to the human, run-log note **`skipped-missing-plugin`**, record `skill_missing: review-local-diff` when Coverage-style notes are required, skip the canvas for that repo, and continue (return **`next_skill: propose-commit`** when all repos are handled — same as skill `local-diff-review-gate`). Do **not** treat chat `git status` / `git diff` as the primary substitute for the missing plugin on the pipeline path.

## Escape

If the human sends `no-local-diff-review`: skip the canvas step for this gate turn; use chat fallback only.

## Out of scope

- Finish-plan review-gate HITL (checkout + `SetActiveBranch` only — see [review-surface.md](review-surface.md)).
- Replacing engineer-review Findings with the canvas.
- Vendoring the plugin skill into this repository.
- Relying on Send → `newComposerChat` as the pipeline path.
- Placeholder commits to feed the merge-base tab.
