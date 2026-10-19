---
name: local-diff-review-gate
description: >-
  Pipeline-only HITL before propose-commit: show Local Diff Review canvas for
  dirty working-tree / staged changes, apply human comments, never commit or
  open a pull request. Use from engineer-review step 15 after teach-review
  miss; also before residual propose-commit when the tree is dirty again.
disable-model-invocation: true
---

# Local Diff Review Gate

Thin kit gate around the **Local Diff Review** Cursor plugin. Canvas protocol stays in the plugin skill `review-local-diff` — **do not vendor** that skill body into this kit.

## When to Use

- **Pipeline path only**, after engineer-review (or multi-repo supervisor) report is settled and Teach-review miss is handled, **before** the next skill `propose-commit`.
- **Required next step after Teach-review miss** on a pipeline run — whether the answer was `no_miss`, `miss` (after `teach-review` returns), or `project_secret` (after capture settles). Do **not** open Propose commit / `approve-commit` first.
- Callers: `/lgt-start-task` (full), `finish-plan` → engineer-review, `/lgt-start-task --fast`, `/lgt-start-issue-task`.
- Full path residual: after `update-docs`, if the tree is dirty again, run this gate **once more** before residual `propose-commit`.
- **Not** for manual `/lgt-engineer-review` / `/lgt-pr-review` / bare `/lgt-multi-review` unless the human explicitly asks.

## Preconditions

- Plugin skill file resolvable as `review-local-diff` (typical install: `~/.cursor/plugins/local/local-diff-review/skills/review-local-diff/SKILL.md`). Payload contract: plugin `skills/review-local-diff/references/payload.md`.
- Canvas built by plugin script `~/.cursor/plugins/local/local-diff-review/bin/build-canvas.mjs` → `~/.cursor/projects/<workspace>/canvases/local-diff-review.canvas.tsx` with sidecar `local-diff-review.canvas.data.json` (`outbound` key).

## Steps (per dirty repo)

Inputs: `repo_branch_map` (ordered). If missing, use the current git root only.

For **each** repo in map order:

1. **Focus that repo only.** Prefer session tool `move_agent_to_root` (or equivalent) into that repo's absolute root. The canvas filename is shared — **never** open two Local Diff Review canvases at once.

2. **Plugin missing:** if skill `review-local-diff` cannot be loaded / skill file missing → one sentence to the human, run-log note `skipped-missing-plugin`, continue to the next repo (or to `propose-commit` when done). Do not invent a canvas.

3. **Clean tree:** if both `git diff HEAD` and `git diff --cached` are empty → skip quietly, run-log note `skipped-clean`, next repo.

4. **Ask HITL** via skill **`hitl-choice`** preset **Local Diff Review gate** (AskQuestion required):

   | id | meaning |
   |----|---------|
   | `approve-diff` | Diff is fine; leave this repo and continue |
   | `comment` | Open the canvas and wait for Send |

5. On **`approve-diff`:** run-log note `approve-diff`; next repo (or continue to `propose-commit`).

6. On **`comment`:**
   1. Follow plugin skill `review-local-diff`: run `bin/build-canvas.mjs` (do not hand-write the canvas or parse `git diff`). Link the canvas.
   2. Tell the human: **Prepare for this chat** → **copy the paste block** → **paste into this thread** (keeps pipeline context). Optional **Open new chat** only if losing history is OK. Agents do not auto-read the sidecar; Canvas cannot inject into this thread.
   3. **Do not poll** `*.canvas.data.json`. End the turn; wait for the human’s next reply here.
   4. When they paste `local-diff-review/comments` (or say apply local-diff comments), apply those comments here, then `build-canvas.mjs --refresh --fresh-ui`. Do **not** commit, push, or open a PR.
   5. Ask the same two tokens **once more** (`approve-diff` / `comment`).
   6. If the second answer is `comment` again: rebuild canvas via script, same paste-into-this-thread flow once more, then **continue** (do not loop further). Run-log note `comment`.
   7. If the second answer is `approve-diff`: run-log note `approve-diff`; continue.

7. After all repos: return to the caller so it can invoke `propose-commit`.

## Run-log

When `invocation_id` is known: `scripts/pipeline-run-log.sh append --root <project> --invocation <invocation_id> [--plan <path>] --stage local-diff-review --note "<approve-diff|comment|skipped-missing-plugin|skipped-clean>"`. Once the plan path is known, always pass `--plan`. Missing helper or missing `invocation_id` → one-sentence skip.

## Hard rules

- Never commit, push, or create/update a GitHub pull request inside this gate.
- Never replace engineer-review Findings, `finish-plan` review-gate, or `propose-commit`.
- Never skip this gate on a dirty pipeline tree by jumping to skill `propose-commit` (file list + `approve-commit` is not a substitute for `approve-diff` / canvas comments).
- Never render the review in Source Control or on GitHub as a substitute for this canvas.
- Never vendor the plugin skill body into this repository.
- Manual engineer-review does not auto-start this gate.
