---
name: local-diff-review-gate
description: >-
  Pipeline-only HITL before propose-commit: show dirty working-tree / staged
  changes via Cursor Local Git Changes (SetActiveBranch), apply human comments
  from chat, never commit or open a pull request. Local Diff Review plugin
  canvas is optional opt-in only. Use from engineer-review step 15 after
  teach-review miss; also before residual propose-commit when the tree is dirty.
disable-model-invocation: true
---

# Local Diff Review Gate

Human look at **local** changes before `propose-commit`. **Primary surface:** Cursor **Local Git Changes** (Source Control / Changes) after checkout + `SetActiveBranch`. The Local Diff Review **plugin canvas** is **optional** — use only when the human asks (`use-local-diff-plugin` / “open the Local Diff canvas”).

Do **not** vendor plugin skill `review-local-diff` into this kit.

## When to Use

- **Pipeline path only**, after engineer-review (or multi-repo supervisor) report is settled and Teach-review miss is handled, **before** the next skill `propose-commit`.
- **Required next step after Teach-review miss** on a pipeline run — whether the answer was `no_miss`, `miss` (after `teach-review` returns), or `project_secret` (after capture settles). Do **not** open Propose commit / `approve-commit` first.
- Callers: `/lgt-start-task` (full), `finish-plan` → engineer-review, `/lgt-start-task --fast`, `/lgt-start-issue-task`.
- Full path residual: after `update-docs`, if the tree is dirty again, run this gate **once more** before residual `propose-commit`.
- **Not** for manual `/lgt-engineer-review` / `/lgt-pr-review` / bare `/lgt-multi-review` unless the human explicitly asks.

## Preconditions

- Git repo roots from `repo_branch_map` (or the current root).
- Session tool **`SetActiveBranch`** available when possible (same idea as skill `finish-plan` reference `review-surface`).
- Plugin skill `review-local-diff` / `build-canvas.mjs` — **optional**. Missing plugin is **not** a failure when using Local Git Changes.

## Steps (per dirty repo)

Inputs: `repo_branch_map` (ordered). If missing, use the current git root only.

For **each** repo in map order:

1. **Focus that repo only.** Prefer session tool `move_agent_to_root` into that repo's absolute root. Review **one dirty repo at a time**.

2. **Clean tree:** if both `git diff HEAD` and `git diff --cached` are empty → skip quietly, run-log note `skipped-clean`, next repo.

3. **Primary surface — Local Git Changes:**
   1. Check out the feature branch in the folder the human has open (same rules as `review-surface`: do not treat a linked worktree as the open folder; stop and ask if dirty on another branch).
   2. Call **`SetActiveBranch`** with that absolute root and branch name so Cursor shows the change set (Local Git Changes / merge-base tab when commits exist).
   3. Tell the human in plain words to open **Local Git Changes** (Source Control / Changes) for this repo and review the full files there — **not** a canvas by default.
   4. Do **not** auto-run `build-canvas.mjs` / skill `review-local-diff`.

4. **Ask HITL** via skill **`hitl-choice`** preset **Local Diff Review gate** (AskQuestion required):

   | id | meaning |
   |----|---------|
   | `approve-diff` | Diff is fine; leave this repo and continue |
   | `comment` | Human will send change notes in this chat (or optionally ask for the plugin canvas) |

5. On **`approve-diff`:** run-log note `approve-diff`; next repo. When all repos done with only approve-diff / skips → return `next_skill: propose-commit`.

6. On **`comment`:**
   1. **Default:** wait in this thread for free-text notes (path + what to change; line numbers when the human gives them). Prefer that over any canvas.
   2. **Optional plugin:** only if the human explicitly asks for the Local Diff Review canvas / `use-local-diff-plugin` / `have_local_diff_canvas` — then load skill `review-local-diff`, run `bin/build-canvas.mjs`, link the canvas, and accept paste `local-diff-review/comments`. If the plugin is missing after they asked for it → one sentence, run-log `skipped-missing-plugin`, fall back to chat notes (do **not** block the gate).
   3. Do not poll `*.canvas.data.json`. End the turn; wait for the human’s reply here.
   4. When notes arrive (chat prose **or** pasted `local-diff-review/comments`), dispatch nested Task `csp-software-developer` with a brief from each path / line / body plus global notes. Wait for it to return. Refresh canvas only if the optional plugin path was used (`--refresh --fresh-ui`). Do **not** `git commit`, push, or open a pull request.
   5. Run-log note `comment` (add `used-plugin` in the note only when the canvas path ran).
   6. **Return immediately** to the caller with `next_skill: engineer-review` (pipeline Loop). Do **not** ask `approve-diff` / `comment` again in this turn. Do **not** invoke `propose-commit`.

7. After all repos without a Loop return: return `next_skill: propose-commit` so the caller can invoke propose-commit.

## Run-log

When `invocation_id` is known: `scripts/pipeline-run-log.sh append --root <project> --invocation <invocation_id> [--plan <path>] --stage local-diff-review --note "<approve-diff|comment|skipped-missing-plugin|skipped-clean|used-plugin>"`. Once the plan path is known, always pass `--plan`. Missing helper or missing `invocation_id` → one-sentence skip.

## Hard rules

- Never commit, push, or create/update a GitHub pull request inside this gate.
- Never replace engineer-review Findings, `finish-plan` review-gate, or `propose-commit`.
- Never skip this gate on a dirty pipeline tree by jumping to skill `propose-commit` (file list + `approve-commit` is not a substitute for `approve-diff` / human change notes).
- **Prefer Local Git Changes** over the Local Diff Review plugin canvas. Do not auto-open the canvas.
- Never vendor the plugin skill body into this repository.
- Manual engineer-review does not auto-start this gate.
- Never continue to `propose-commit` after applying change notes; always return `next_skill: engineer-review`.
- Never use a second-comment “then continue” shortcut; Loop ends only on human `approve-diff` (or skip clean).
