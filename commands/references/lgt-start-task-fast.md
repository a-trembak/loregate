# /lgt-start-task — Fast mode (`--fast`)

Load **only after** mode selection chose **fast**. For small tasks that do not need tech-spec, plan approval, critic, finish-plan, or update-docs. Still runs engineer-review and opens a draft PR.

## Pipeline (in order)

1. **Bootstrap** — same as full mode (patterns + stack detect + **Pipeline language** HITL). Read bootstrap from [`lgt-start-task-full.md`](lgt-start-task-full.md) step 1 only — do not load the rest of full mode.
2. **AC required** — fetched `ac_text` or pasted/file source. If still empty, stop.
3. **Short task brief** (automatic, in chat only — not a tech-spec file): 3–6 bullets covering goal, touched areas if obvious, and done criteria from the AC. Do not run `tech-spec`, `writing-plans`, `approve-plan`, or `implementation-critic`. Optionally `pipeline-run-log.sh brief-upsert --root <project> --invocation <invocation_id> --route fast --goal "<one line>" --next "csp-software-developer"` (short brief under `.cursor/gates/run-log/briefs/` — not a fake plan under `docs/`). Do **not** require promote on fast/tiny runs.
4. **Execute** — create feature branch(es) per `software-developer` branch-setup; implement with skill **`software-developer`** via nested Task **`csp-software-developer`** using **`mode:fast`** (entry gates for tech-spec Status / critique-clear are skipped — see that skill). Prefer `subagent-driven-development` when available; verify with lint/test/typecheck before handoff. **Wait for** `csp-software-developer` to return. Do not treat dispatch as the end.
5. **Engineer review** — immediately after that return, run `csp-engineer-reviewer` (or `csp-multi-repo-supervisor` for 2+ repos). Skip `finish-plan` HITL. Skip Figma ask unless node URLs were already in the AC/context. HITL only for **Needs clarification**.
5b. **Local Diff Review gate** — invoke skill **`local-diff-review-gate`**.
5c. **Propose commit** — invoke skill **`propose-commit`**.
6. **Create PR** — invoke skill **`create-pr`** (push + draft + Pipeline finale). Do not expect `create-pr` to invent product commits.

## Fast-mode notes

- Do not silently upgrade fast mode into full mode. If mid-flight the work is clearly large (multi-service design, migrations, ambiguous product decisions), **stop** and recommend re-running without `--fast` or using `/lgt-start-issue-task` for bugs.
- Fast mode never invents AC. Closed-set HITL (clarify, Fast vs issue, Pipeline finale) still uses `hitl-choice` with AskQuestion required.
- Pass `jira_key` / `jira_cloud_id` / `jira_status` through to `create-pr`. Init and append `session-fast.json` (`fast-skips-plan-layer`) per skill `trajectory-score`.
- Keep the same `invocation_id` for the run; dual-write `append` at ledger stops; optional `brief-upsert` as above. No inventing `docs/**/plans` for fast.
- **Orientation:** every closed-set human gate uses skill `hitl-choice` (orientation strip). Humans may run `/lgt-pipeline-status` anytime.
