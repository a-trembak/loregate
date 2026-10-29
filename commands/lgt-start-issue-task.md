---
description: Orchestrate a bug-fix pipeline from a Jira ticket — fetch issue, write fix plan, auto-critique (incl. regression/root-cause), fix via bug-fixer, engineer-review, draft PR. HITL only when critic is blocked or pending accept (plus review clarifications).
argument-hint: "[jira-key|jira-url]"
---

# /lgt-start-issue-task

Bug-fix entry point. Chains diagnose → plan → critic → fix → review → draft PR. Does **not** run tech-spec, approve-plan HITL, finish-plan HITL, or update-docs.

## Arguments

- Jira issue key (`PROJ-123`) or browse URL. If omitted, ask for it (typed chat — not a closed-set HITL gate).

## Pipeline (in order)

1. **Bootstrap** (automatic):
   - Read `.cursor/project-patterns.md` in the current project if present.
   - Detect stack mechanically via `skills/engineer-review/references/skill-map.md`.
   - **Pipeline language:** same as `/lgt-start-task` — `status --root <project>`; ask **Pipeline language** only when `unset`; skip re-ask when already set. Persist with `set`. **Russian is impossible**; refuse with rule `pipeline-language-no-russian` (outside this pipeline). See `docs/superpowers/pipeline-language.md`. If `/lgt-start-task` already set language in this chat, do not re-ask.
   - **Run-log:** mint `invocation_id`; `scripts/pipeline-run-log.sh init --root <project> --invocation <id> --route issue` (pointer + `inv-<id>.md`). Missing helper → one-sentence skip. No chat transcripts or ticket-body dumps in notes/briefs.

2. **Fetch Jira** (automatic):
   - Invoke skill **`jira-fetch`** (key or browse URL). Reuse an already-fetched payload if `/lgt-start-task` routed here.
   - Use `ac_text` / summary, description, type, and status as the bug source of truth.
   - If MCP is missing, unauthenticated, or the fetch fails: **stop**. Ask the human to paste the ticket text (and optionally retry MCP). Do not invent ticket contents. Do not continue on a URL-only stub.
   - After a successful fetch (or reused payload) with `jira_key` and `jira_cloud_id`: invoke skill **`jira-transition`** with target `in_progress`. Already In Progress is a skip. If `/lgt-start-task` already moved the issue, this is a no-op. Report and continue on skip/failure — do not stop the pipeline.

3. **Fix plan** (automatic):
   - Investigate enough to draft a root-cause-oriented fix plan (read-only exploration + ticket facts). Prefer loading `systematic-debugging` / `ce-debug mode:pipeline` while diagnosing for the plan.
   - Write English plan to `docs/superpowers/plans/YYYY-MM-DD-<jira-key>-fix.md` following `clean-decision-docs` (final-form only).
   - Plan must include: reported failure, reproduction, hypothesized root cause, proposed minimal fix, regression/blast-radius notes, test plan that would catch the bug, rejected alternatives (one line each).
   - When the plan path is first known: `pipeline-run-log.sh promote --root <project> --invocation <invocation_id> --plan <path> --route issue`. On refuse-on-conflict: one-sentence skip; keep using `--invocation` (pointer is not rewritten). Also `append` at this and later ledger stops — once the plan path is known, always pass `--plan`.

4. **Critic** (automatic — no plan-approve HITL):
   - `pg_write_gate` critique-gate for this plan path; `pg_clear_gate` plan-critique-clear for a prior revision of **this** plan only.
   - Run `implementation-critic` / agent `csp-implementation-critic` with **Pass A, B, and C** (bug-fix plan).
   - On `Verdict: clear`: `pg_clear_gate` critique-gate; `pg_write_gate` plan-critique-clear (plan path); continue.
   - On `blocked` or `clear pending accept`: keep this plan's `critique-gate/<slug>`; **stop** and ask via skill **`hitl-choice`** preset **Blocked / pending-accept critic** (AskQuestion required; text only after failed/missing tool). On `revise`, rewrite the plan (`clean-decision-docs`) and re-run from step 4. On `accept F<id>` until clear, continue.

5. **Fix** (automatic on clear): dispatch agent **`csp-bug-fixer`** / skill **`bug-fix`** for that plan as a nested Task (feature branch, reproduce, root cause, regression test, minimal fix, verify). **Wait for** it to return. Do not treat dispatch as the end.

6. **Engineer review** (automatic): immediately after `csp-bug-fixer` returns, run agent **`csp-engineer-reviewer`** (or `csp-multi-repo-supervisor` when 2+ repos changed per multi-repo probe). Skip `finish-plan` HITL. Skip Figma ask unless node URLs were already in the ticket/context. HITL only for **Needs clarification** via `hitl-choice`.

6b. **Local Diff Review gate** — invoke skill **`local-diff-review-gate`** (HITL `approve-diff` / `comment`). If the gate returns **`next_skill: engineer-review`**, re-run engineer-review and Teach-review miss, then skill **`local-diff-review-gate`** again (**Loop** until the gate returns **`next_skill: propose-commit`**).
6c. **Propose commit** — invoke skill **`propose-commit`** (HITL `approve-commit` / `revise`) only after the local-diff gate returns **`next_skill: propose-commit`**.

7. **Create PR** (automatic): invoke skill **`create-pr`** (push + draft + Pipeline finale). Do not expect `create-pr` to invent product commits. Draft PR title includes the Jira key; body links the ticket and fix plan path. Pass `jira_key` / `jira_cloud_id` for the Pipeline finale HITL.

## Notes

- **On-demand / pay-as-you-go budget:** use **`/lgt-start-issue-task-on-demand`** — same pipeline with a built-in model + graphify + scope contract (Flash orchestrator, Composer bug-fixer). No need to paste a custom prompt each run.
- This command never invents answers at critic/clarify HITL gates.
- Full feature work with AC → use `/lgt-start-task` (it fetches Jira and routes Bugs here). Small non-bug tasks without Jira → `/lgt-start-task --fast`.
- Explicit `/lgt-start-issue-task` always stays on the issue pipeline even if the Jira type is Story/Task.
- After fix-plan + critic on an explicit `/lgt-start-issue-task` whose `jira_class` is `feature` (Story/Task), score `start-issue-story-stays-issue` per skill `trajectory-score`.
- When `jira_class` is `bug`, init `.cursor/gates/trajectory-run/session-issue.json` for case `issue-happy-path` (exact invocation `/lgt-start-issue-task PROJ-1`) and append stages/gates; `create-pr` scores it. Do not init the issue session ledger for a Story/Task slice.
- **Run-log:** dual-write `pipeline-run-log.sh append` with the run’s `invocation_id` at the same ledger stops; once the plan path is known, always pass `--plan`; pass `--invocation` into orientation when known.
