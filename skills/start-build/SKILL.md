---
name: start-build
description: >-
  Use when an implementation plan already has Verdict clear from approve-plan
  (or an equivalent critique) and code should start. Creates no critique —
  dispatches csp-software-developer, waits for it to return, then finish-plan
  (engineer-reviewer). Fire-and-forget dispatch is a hard failure.
disable-model-invocation: true
---

# Start Build

Thin handoff into execution **and** the post-code review gate. **Does not** run `implementation-critic` — that happens earlier via `approve-plan` (HITL approve → auto critic). This skill starts coding once the plan is critique-clear, **waits** for `csp-software-developer` to finish, then invokes `finish-plan` so `csp-engineer-reviewer` actually starts.

## When to Use

- `/lgt-start-task` after `approve-plan` yields `Verdict: clear`
- Manual `/lgt-start-build` when this plan's `.cursor/gates/plan-critique-clear/<slug>` already matches the plan
- Not for first-time plan review — use `/lgt-approve-plan` instead

## Steps (mandatory order)

1. **Resolve plan path.** Argument, else from `pg_list_gates "$(pwd)" plan-critique-clear` if exactly one row, else most recently modified under `docs/**/plans/` (confirm if ambiguous).

2. **Require a clear critique for this plan only:**

   ```bash
   # Prefer (consumer project):
   #   source scripts/pipeline-gates.sh
   #   pg_migrate_legacy "$(pwd)" plan-critique-clear "<plan-path>"
   # .cursor/gates/plan-critique-clear/<slug> must exist and line 1 must equal the plan path
   ```

   If missing or mismatched: **stop** and tell the user to run `/lgt-approve-plan <plan-path>` first (HITL approve → auto critic). Do not re-run the critic from this skill unless the human explicitly asks for `/lgt-critique-plan` alone.

3. Stop only if **this slug** still has `plan-gate/<slug>` or `critique-gate/<slug>`. If either exists: **stop** — approval or critique is still open for this plan.

   Other slugs' pending gates **do not** block. Never delete or overwrite a foreign slug; if the human explicitly wants that, ask HITL via skill **`hitl-choice`** preset **Force-clear foreign gate** first.

4. **Dispatch** agent `csp-software-developer` / skill `software-developer` for the plan as a **nested Task** (creates feature branch(es) in every repo the plan will touch, routes stack/DB/`code-comments` skills, then drives `subagent-driven-development` by default) unless the user already specified `executing-plans` for a separate session.

5. **Wait for** that Task to return with verification evidence and the `repo → branch` map. **Fire-and-forget is a hard failure** — do not stop after dispatch, do not ask the human to run `/lgt-finish-plan` or `/lgt-engineer-review` by hand. If the Task errors, stop and report; do not skip review.

6. **Continue in this parent chat:** invoke skill `finish-plan` for the same plan path (it writes the review-gate, asks HITL via `hitl-choice`, then launches `csp-engineer-reviewer` or `csp-multi-repo-supervisor`). Use the returned `next_skill: finish-plan` block if present. Do not re-dispatch `csp-software-developer`.

7. Do **not** dispatch Task 1 without step 2 satisfied. Do **not** treat step 4 dispatch as the end of this skill.

## Notes

- Plan edits invalidate this plan's `plan-critique-clear/<slug>` when going back through `/lgt-approve-plan`.
- Manual `/lgt-critique-plan` remains for ad-hoc audits; wiring a clear result into build still goes through writing `.cursor/gates/plan-critique-clear/<slug>` (prefer `/lgt-approve-plan` so HITL plan approval is not skipped).
- `csp-software-developer` running as a nested Task must **not** call `AskQuestion` / `finish-plan` itself — that HITL belongs here after it returns.
- Append session ledger per skill `trajectory-score` (stages `start-build`, `csp-software-developer`; artifact `git` `feature-branch`).
