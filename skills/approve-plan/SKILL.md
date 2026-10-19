---
name: approve-plan
description: >-
  Use right after writing-plans produces an implementation plan, before any
  critique or code. HITL approve-plan/revise, then auto-runs implementation-
  critic. On Verdict clear, hands off to start-build. Use from /lgt-start-task or
  /lgt-approve-plan.
disable-model-invocation: true
---

# Approve Plan

Human reads and accepts the implementation plan **before** the critic runs. Critique starts automatically after `approve-plan` — no second permission to start the critic. Build starts only after `Verdict: clear`.

## When to Use

- `/lgt-start-task` after `writing-plans` finishes
- Manual `/lgt-approve-plan` when a plan exists and has not been approved for this revision
- Not for ad-hoc critique alone (`/lgt-critique-plan`) and not for starting code (`/lgt-start-build`)

## Steps (mandatory order)

1. **Resolve plan path.** Argument, else most recently modified under `docs/**/plans/`, confirm with the user if ambiguous.

2. **Write HITL marker** in the **current project** (not the kit), per-plan only:

   ```bash
   # Prefer (consumer project):
   #   source scripts/pipeline-gates.sh
   #   pg_write_gate "$(pwd)" plan-gate "<plan-path>"
   #   pg_clear_gate "$(pwd)" plan-critique-clear "<plan-path>"
   # Equivalent: .cursor/gates/plan-gate/<slug> line 1 = plan path
   # (slug = ticket from path, else SHA-256 prefix — see pipeline-gates.sh)
   ```

   Never delete or overwrite another slug's gate. If the human explicitly wants to remove a **foreign** chat's marker, ask HITL via skill **`hitl-choice`** preset **Force-clear foreign gate** (`force-clear` / `leave`) first.

3. **Stop.** Ask the HITL gate via skill **`hitl-choice`** (AskQuestion required; text only after failed/missing tool). Preset: **Approve-plan gate**. Prompt/text fallback:

   > Plan ready. Review it, then reply:
   > - `approve-plan` — accept this plan; critic runs next automatically
   > - `revise` — describe changes (or edit the file); re-run this skill after

4. Do **not** run the critic or start build until `approve-plan`.

5. **On `approve-plan`:**
   - `pg_clear_gate "$(pwd)" plan-gate "<plan-path>"`
   - `pg_write_gate "$(pwd)" critique-gate "<plan-path>"`
   - Auto-run `implementation-critic` / `/lgt-critique-plan` against the plan (read-only — no permission needed to start it)
6. **On `Verdict: clear`:**
   - `pg_clear_gate "$(pwd)" critique-gate "<plan-path>"`
   - `pg_write_gate "$(pwd)" plan-critique-clear "<plan-path>"`
   - Proceed automatically to skill `start-build` for that plan (branches + `csp-software-developer`; `start-build` waits, then `finish-plan` → `csp-engineer-reviewer`)
7. **On `Verdict: blocked` or `clear pending accept`:**
   - Keep this plan's `critique-gate/<slug>` (do not touch other slugs)
   - **Stop** and show the critic's report. Ask next steps via skill **`hitl-choice`** preset **Blocked / pending-accept critic** (`revise` + `accept F<id>` per open finding). Wait for a plan revision (then re-run this skill from step 1) or `accept F<id>` for open findings. After accepts yield `clear`, continue from step 6. If the plan is the fixture notification-plugin file, score `critic-blocks-flawed-plan` per skill `trajectory-score` after that ask.
8. **On `revise`:** `pg_write_gate "$(pwd)" plan-gate "<plan-path>"`; `pg_clear_gate "$(pwd)" plan-critique-clear "<plan-path>"`. When you (or the plan author) update the plan file, follow skill **`clean-decision-docs`**: rewrite the plan as current truth only — no "fixed/changed to", What-changed sections, or strikethrough of the prior draft inside the file; chat may list what changed for the human's verify step. Then re-ask step 3.
9. **On plan edits after a blocked critique:** same `clean-decision-docs` rewrite rule — the next draft the human (re-)approves must not carry critic archaeology (`after F3`, dual old+new text, etc.).

## Notes

- Critic is **not** a HITL start — only plan approval and blocked/accept-risk findings are HITL.
- Manual `/lgt-critique-plan` still works ad-hoc; it does not replace this gate for `/lgt-start-task`.
- Re-approving after a plan edit always re-runs the critic (clear marker was deleted in step 2 / revise).
- Critic *reports* may narrate findings; the plan file itself must stay final-form (`clean-decision-docs`).
- Append session ledger per skill `trajectory-score` (stages `approve-plan`, `implementation-critic`; gates `approve-plan` / `critic-blocked`; artifact `plan-critique-clear` on Verdict clear).
- **Run-log:** when `invocation_id` and plan path are known, `scripts/pipeline-run-log.sh promote --root <project> --invocation <invocation_id> --plan <plan-path>` on first knowledge of the plan (if not already promoted). On refuse-on-conflict: one-sentence skip; keep appending with `--invocation` (pointer is not rewritten). Dual-write `append` at ledger stops for this skill (`approve-plan`, critic outcomes) and once the plan path is known always pass `--plan` on append. Missing helper → skip.
