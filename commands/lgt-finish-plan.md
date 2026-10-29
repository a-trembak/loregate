---
description: Mark plan complete and enter engineer-review HITL gate
---

# /lgt-finish-plan

Run skill `finish-plan`:

1. Resolve the plan path, then write `.cursor/gates/review-gate/<slug>` (line 1 = plan path) via `pg_write_gate review-gate`.
2. Apply `skills/finish-plan/references/review-surface.md` **before** asking HITL: check out the feature branch in each folder the human has open and call `SetActiveBranch` for each. Do **not** run skill `review-local-diff` or build a Local Diff Review canvas. Do **not** invoke `create-pr` (pipeline is not finished; engineer-review still runs after `skip` / `approve` / `done`).
3. Stop and ask HITL via skill `hitl-choice` (AskQuestion required; typed tokens only after failed/missing tool). Prompt:

   > Plan done. Feature branches are checked out locally. This gate starts engineer-review — your full Local Diff look comes after that review. Answer:
   > - `skip` — start engineer-review now
   > - `approve` / `done` — start engineer-review
   > - `fixes` — describe fixes first (typed notes); developer applies them, then this gate is asked again

   `skip` / `approve` / `done` all start engineer-review (after deleting **this** plan's marker); `fixes` or typed fix description means fix first via `csp-software-developer`, re-run review-surface, then re-ask. If the user already sent one of those tokens after the gate was asked, do not re-ask — clear this plan's marker and continue.
4. After approval, run `multi-repo-protocol.md` routing before review using the **non-mutating probe** only (read graphify / existing parent `.cursor/multi-repo.json` / sibling scan in memory; do not write `multi-repo.json`):
   - **0 changed repos**: stop and say no changed repos were found.
   - **1 changed repo**: keep the current single-repo `csp-engineer-reviewer` path unchanged; optionally ask for Figma URLs on frontend via `hitl-choice` Figma preset.
   - **>= 2 changed repos**: start `csp-multi-repo-supervisor` with `hitl_already_approved: true`, and pass `figma_clarifications` if they were already collected. If none were collected, the supervisor asks once for the whole multi-repo task.
