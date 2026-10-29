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
3. Prefer this canvas over pasting the full `git diff` into chat. Chat paste remains the **fallback** when the plugin is missing or canvas fails.

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

After the canvas exists:

1. Ask the gate HITL via skill `hitl-choice` when the gate requires it.
2. Also watch the canvas sidecar at the **exact** path from the canvas save (and any `.canvas.data.json` beside it). Do **not** browse or glob the canvases store.
3. When a **new** valid outbound arrives with `intent: apply-fixes` and non-empty `comments` and/or non-empty `notes`:
   - Treat it like `fixes` on the gate (even if the human did not click the `fixes` button).
   - Build a brief for nested Task `csp-software-developer`: each `path` + optional `line` + `body`, plus `notes`.
   - Wait for `csp-software-developer` to return.
   - Score per skill `trajectory-score` when the gate protocol requires it.
   - **Re-run** the gate surface (new canvas / reset last-handled `sentAt`) and re-ask HITL when required.
4. Typed `fixes` / pasted comment text without sidecar still means the same fix cycle (chat fallback brief).

## Missing plugin

If `review-local-diff` (or Canvas) is unavailable: continue with the chat `git status` / `git diff` fallback; record `skill_missing: review-local-diff` in the gate turn (Coverage-style note in chat is enough). HITL tokens unchanged.

## Escape

If the human sends `no-local-diff-review`: skip the canvas step for this gate turn; use chat fallback only.

## Out of scope

- Finish-plan review-gate HITL (checkout + `SetActiveBranch` only — see [review-surface.md](review-surface.md)).
- Replacing engineer-review Findings with the canvas.
- Vendoring the plugin skill into this repository.
- Relying on Send → `newComposerChat` as the pipeline path.
- Placeholder commits to feed the merge-base tab.
