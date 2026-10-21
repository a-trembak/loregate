---
name: trajectory-score
description: >-
  Record a kit trajectory ledger and score it against a golden case at the
  natural stop. Use from /lgt-start-task, /lgt-start-issue-task, create-pr, finish-plan,
  critique-plan, capture-escape, tech-spec, and other wired pipeline stops.
  Never invents human-gate answers. Never replaces engineer-reviewer.
---

# Trajectory score

Kit-owned **harness loop**: golden case → session or slice ledger → hard-sensor `score` at the moment the contract is provable → on `FAIL`, ask **Trajectory fail**. Evaluation measures the **agent path**, not product-code taste. `csp-engineer-reviewer` stays the diff reviewer.

## When to Use

- A wired stop below says to score a named case
- After a language-model **trajectory-judge** writes `actions_taken` and you must re-score
- Not for scoring chat logs. Not a sixth engineer-review phase named “eval”

## Resolve kit

```bash
KIT="$(tr -d '\n' < .cursor/cursor-spells-kit-path 2>/dev/null || true)"
if [[ -z "$KIT" ]]; then
  KIT="$(tr -d '\n' < "$HOME/.cursor/cursor-spells-kit-path" 2>/dev/null || true)"
fi
LEDGER=".cursor/gates/trajectory-run/<case_id>.json"
```

Skip score when the kit path, scorer, or ledger dump is missing. Continue the existing pipeline stop. In chat, say in one full sentence that trajectory score was skipped. Do not brick old chats.

Never substitute a live ticket key for the case `input.invocation`. Exact strings come from `evals/trajectories/cases/<id>.json`.

## Record then score

Init a **fresh** slice ledger at the stop (do not reuse a full-path ledger for a slice case):

```bash
python3 "$KIT"/scripts/trajectory-cases.py record init \
  --ledger "$LEDGER" --case-id <case_id> \
  --invocation "<exact case invocation>" --fetch <ok|fail|skip> [--jira-class <feature|bug|unknown>]
# Start the live metrics clock (consumer project history; safe to skip if the script is missing)
python3 "$KIT"/scripts/pipeline-metrics.py mark-start --ledger "$LEDGER" [--ticket "<live ticket key>"]
# then record stage / artifact / gate / action / end as the case requires
python3 "$KIT"/scripts/trajectory-cases.py record dump --ledger "$LEDGER"
# Score and append one history row (quality + duration) for later graphs
python3 "$KIT"/scripts/pipeline-metrics.py append-score --kit-root "$KIT" --run "$LEDGER" [--ticket "<live ticket key>"]
# If pipeline-metrics.py is missing, fall back to:
# python3 "$KIT"/scripts/trajectory-cases.py score --kit-root "$KIT" --run "$LEDGER"
```

If `record dump` fails, skip score. Missing `pipeline-metrics.py` → score only; do not invent history rows.

History default path (consumer project, not the kit): `.cursor/gates/pipeline-metrics/history.jsonl`. Summarize later with `python3 "$KIT"/scripts/pipeline-metrics.py summary`. Export for graphing with `export --format csv`.

## On FAIL

Print the `FAIL` lines and **stop**. Ask skill `hitl-choice` preset **Trajectory fail**. On `skip`, mention `/lgt-capture-escape` with the `FAIL` lines and do not start `csp-engineer-reviewer`. On `generalize`, follow `evals/trajectories/README.md` “Add a case” only when the current git root contains both `skills/engineer-review` and `agents/csp-engineer-reviewer.md`; otherwise print the `FAIL` log and stop. After validate, display the validated case JSON (the file contents) in chat and wait for the human to confirm it is correct before `git commit`. Do not offer `git diff` as a substitute. Do not invent `approve-spec` / `skip` / `ready`. Do not run `gh pr ready`. Do not merge.

## On PASS or skipped score

Continue the existing stop (wait for pasted text, wait for the human's already-chosen token, or continue the pipeline).

## Session ledger (end-to-end)

Path: `.cursor/gates/trajectory-run/session-full.json`, `session-fast.json`, or `session-issue.json`.

1. **Init once** at pipeline start with the matching end-to-end case input (`full-happy-path`, `fast-skips-plan-layer`, `issue-happy-path`). Use the case's exact invocation (`/lgt-start-task PROJ-1`, `/lgt-start-task --fast PROJ-1`, `/lgt-start-issue-task PROJ-1`) — not the live ticket key.
2. **Append** after every named stage, artifact, or human gate on that path (`record stage` / `record artifact` / `record gate`). Do not re-init.
3. **Score** at `create-pr` after Pipeline finale was asked and an OPEN draft exists — in addition to the slice `create-pr-draft-never-merge` / `create-pr-draft-never-merge-no-jira` ledger. Missing session ledger → skip the end-to-end score only.
4. Init `session-issue` only when `jira_class` is `bug` (matches `issue-happy-path`). Explicit `/lgt-start-issue-task` on a Story/Task (`jira_class` feature) scores the slice `start-issue-story-stays-issue` instead.

A dishonest agent can still write a canned PASS ledger. First slice is orchestrator-appended records, not a chat parser.

## Slice cases (lazy load)

When a wired stop names a case, open **only** that row in [`references/slice-cases.md`](references/slice-cases.md). Do not load the full table into context. Session end-to-end cases stay under **Session ledger** above (`session-full` / `session-fast` / `session-issue`).

## Hard rules

- Do not add a review phase named “eval”.
- Do not jump to overnight unsupervised loops (Eledath 7) or agent-to-agent teams without an orchestrator (Eledath 8).
- Do not copy `evals/` into consumer apps (`lgt install` never copies it).
- Missing kit/ledger → skip score; do not invent Jira `In Progress`.
- `evals/` is kit-only. Dogfood does not require live `/lgt-start-task` inside kit continuous integration.
