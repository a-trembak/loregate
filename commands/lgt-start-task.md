---
description: Orchestrate the full pipeline from Acceptance Criteria to a reviewed draft PR — or lean --fast mode (no HITL planning) that implements, engineer-reviews, and opens a draft PR. Full mode stops only at established human-in-the-loop gates. Jira keys/URLs are fetched via MCP; Bug tickets route to the issue pipeline.
argument-hint: "[--fast] [ac-source]"
---

# /lgt-start-task

Feature-work entry. Short router: select the path, then load **one** mode file. Do not paste full or fast pipelines into chat until that file is opened.

## Arguments

- Optional `--fast` — lean path. May appear before or after the AC source.
- Optional AC source: a ticket id, a Jira/tracker URL, a file path, or inline text. If omitted, ask for it.
- Bug fixes with root-cause discipline → prefer `/lgt-start-issue-task` (this command auto-routes classified Bug tickets there).

## Mode selection

1. If args contain `--fast` → remember **fast intent** (strip the flag; remainder is AC source). Do **not** start implementing yet.
2. If AC source is omitted, ask for it and stop until provided.
3. **Jira fetch** — if the source looks like a Jira issue (skill `jira-fetch` / `jira_looks_like_issue`): invoke skill **`jira-fetch`**. On fetch failure, stop (paste text). Record and score `fetch-failure-stops` per skill `jira-fetch`; skip score if the ledger or kit is missing. On success, the assembled `ac_text` **is** the AC; the key/URL is the AC reference. Never treat a Jira URL as a stub.
4. **Jira In Progress** — if fetch succeeded with `jira_key` and `jira_cloud_id`: invoke skill **`jira-transition`** with target `in_progress`. Skip when already In Progress. If MCP/transition is missing or no matching destination exists, **report and continue** — do not stop the pipeline. `/lgt-write-tech-spec` does not transition.
5. **Route** (mechanical; never auto-select `--fast`):

   | Condition | Path |
   |-----------|------|
   | Fast intent **and** `jira_class` is `bug` | HITL via `hitl-choice` preset **Fast vs issue**: `issue` / `stay_fast`. Score `fast-bug-asks-human` |
   | Fast intent **and** not bug | **Fast mode** |
   | No fast intent **and** `jira_class` is `bug` | **Issue pipeline** — `/lgt-start-issue-task` from step 3; do not re-fetch. Score `route-bug-to-issue` |
   | No fast intent **and** `jira_class` is `unknown` | HITL **Pipeline route**: `full` / `fast` / `issue`. Score `route-unknown-asks-human` |
   | Otherwise (feature or non-Jira AC) | **Full mode** unless fast intent. After tech-spec-entry, score `route-feature-to-full` |

6. If AC still do not exist after fetch/paste, stop — writing AC themselves is out of scope.

## Execute the chosen path

| Path | Load and execute (only this file) |
|------|-----------------------------------|
| **Full** | [`references/lgt-start-task-full.md`](references/lgt-start-task-full.md) — includes bootstrap (Pipeline language, `pipeline-run-log.sh init`), tech-spec → plan → critic → `csp-software-developer` (**Wait for**; do not treat dispatch as the end) → finish-plan (`review-surface` / `SetActiveBranch` / local-diff-review) → engineer-review → `local-diff-review-gate` → `propose-commit` → `update-docs` (do not treat update-docs as the end; `create-pr` immediately) → Pipeline finale. Session `full-happy-path`. Pass `jira_status` into `create-pr`. |
| **Fast** | [`references/lgt-start-task-fast.md`](references/lgt-start-task-fast.md) — bootstrap + brief (`brief-upsert`) + `csp-software-developer` **`mode:fast`** (**Wait for**) → engineer-review → `local-diff-review-gate` → `propose-commit` → `create-pr`. Session `fast-skips-plan-layer`. |
| **Issue** | [`lgt-start-issue-task.md`](lgt-start-issue-task.md) from its step 3 |

Closed-set gates use skill `hitl-choice` (orientation strip). Humans may run `/lgt-pipeline-status` anytime. Mint `invocation_id` and dual-write `pipeline-run-log` per the loaded mode file. Never dump chat transcripts or ticket bodies into run-log notes. Prefer `promote` when the plan path is first known (full path).
