---
name: finish-plan
description: >-
  Use when an implementation plan has just been fully executed or you are about
  to declare plan work complete — before engineer-review or any post-plan wrap-up.
disable-model-invocation: true
---

# Finish Plan

Reliable handoff into the engineer-review HITL gate. Prefer this over hoping a global rule fires.

## When to Use

- Last task of a plan is done
- User says the plan is complete
- Before claiming “ready for review/PR” after planned work

## Steps (mandatory order)

1. **Resolve plan path.** Argument, plan referenced in this session, or ask. Required — do not write a bare `pending` line.

2. **Write marker** in the **current project** (not the kit):

   ```bash
   # Prefer (consumer project):
   #   source scripts/pipeline-gates.sh
   #   pg_write_gate "$(pwd)" review-gate "<plan-path>"
   # Line 1 = plan path (not the word pending)
   ```

3. **Apply review-surface** ([references/review-surface.md](references/review-surface.md)) **before** asking HITL: check out the feature branch in each folder the human has open and call `SetActiveBranch` for each so the merge-base diff tab is visible. Do **not** build a Local Diff Review canvas at this gate. Do **not** invoke `create-pr`. Do **not** open a GitHub pull request. This does not end the pipeline. Do not ask the gate while open folders are still on the default branch.

4. **Stop.** Ask the HITL gate via skill **`hitl-choice`** (AskQuestion required; text only after failed/missing tool). Preset: **Finish-plan / engineer-review / multi-repo HITL**. Prompt/text fallback (include each `repo → branch` from review-surface):

   > Plan done. Feature branches are checked out locally. This gate starts engineer-review — your full Local Diff look comes after that review. Answer:
   > - `skip` — start engineer-review now
   > - `approve` / `done` — start engineer-review
   > - `fixes` — describe fixes first (typed notes); developer applies them, then this gate is asked again

   All three of `skip` / `approve` / `done` mean **start review** after deleting the marker. Do not invent other meanings (e.g. “skip review” or “close without review”).

5. Do **not** start review until `skip` | `approve` | `done`. (`fixes` or a typed fix description means implement/fix first, then re-ask this gate.)

   **Already answered (mandatory):** If the user already sent `skip`, `approve`, or `done` in this chat after the gate was asked — including while a stop-hook followup was looping — treat that as the answer. Delete this plan's review-gate marker and continue step 6 immediately. Do **not** re-ask.

   On `fixes` or a typed fix description: implement/fix via `csp-software-developer` (wait for it to return). Then score `review-gate-fixes-to-build` per skill `trajectory-score` (stages `review-gate` then `csp-software-developer`; gate tokens `skip,approve,done,fixes`). Then **re-run review-surface** and re-ask this HITL question (keep or rewrite this plan's `review-gate/<slug>` until review starts).

6. On `skip` | `approve` | `done`:
   - `pg_clear_gate "$(pwd)" review-gate "<plan-path>"` **first** (before any review work). If delete fails, stop and report the path — do not re-ask HITL. Never delete another slug's review-gate; HITL **Force-clear foreign gate** first if the human explicitly asks.
   - Before starting review, read and apply `skills/engineer-review/references/multi-repo-protocol.md` routing with its **non-mutating probe** mode. This probe may read graphify, read an existing parent `.cursor/multi-repo.json`, or scan siblings in memory, but it **MUST NOT** write or refresh `multi-repo.json`.
   - Detect changed repos with the protocol.
   - If changed repo count is **0**, stop and say no changed repos were found.
   - If changed repo count is **>= 2**, invoke agent `csp-multi-repo-supervisor` and pass:
     - `hitl_already_approved: true`
     - `figma_clarifications` only if Figma URLs were already collected in this flow
     The supervisor owns Figma clarification collection when none were already collected.
   - If changed repo count is **1**, keep the existing single-repo path unchanged:
     - If frontend stack (`react-web` / `react-native`): if Figma Model Context Protocol tools are missing from the session, ask **Enable Figma MCP** first; then ask Figma via skill **`hitl-choice`** preset **Figma ask** (or text: paste links / `no figma`).
     - Then run skill `engineer-review` / agent `csp-engineer-reviewer` for the changed repo (pass Figma URLs in clarifications if provided).

## Notes

- Manual `/lgt-engineer-review` does not need this skill.
- If the user describes fixes first (typed notes), implement/fix, then re-run review-surface, then re-ask the HITL question (keep or rewrite this plan's `review-gate/<slug>` until review starts).
- Local Diff Review canvas and escape `no-local-diff-review` belong to skill `local-diff-review-gate` after engineer-review — see [references/local-diff-review.md](references/local-diff-review.md).
- Append session ledger per skill `trajectory-score` (stage `review-gate`, artifact gate `review-gate`).
- **Run-log:** dual-write `scripts/pipeline-run-log.sh append --root <project> --invocation <invocation_id> [--plan <path>] --stage review-gate --note "<token>"` when the session ledger is appended at this gate. Once the plan path is known, always pass `--plan`. Missing helper → skip.
