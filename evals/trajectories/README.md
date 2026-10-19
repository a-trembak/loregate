# Agent trajectory golden set

Contracts for how the kit agent must behave on a given invocation. These files are **not** product tests and are **not** installed into consumer apps.

**Before changing skills or agents**, run the full kit harness bench (all `scripts/tests/*.sh` plus this validate/score pass):

```bash
bash scripts/harness-bench.sh
```

Reports land under `evals/harness/reports/` (see [`../harness/README.md`](../harness/README.md)). For inventory without a full bench: `python3 scripts/harness-health.py`.

Validate cases:

```bash
python3 scripts/trajectory-cases.py validate
bash scripts/tests/trajectory-cases-test.sh
```

Score a recorded run (hard sensors only — no language-model judge inside `score`; skill `trajectory-judge` writes actions then re-runs `score`):

```bash
python3 scripts/trajectory-cases.py score --run evals/trajectories/fixtures/pass/route-unknown-asks-human.json
python3 scripts/trajectory-cases.py score --runs-dir evals/trajectories/fixtures/pass
bash scripts/tests/trajectory-score-test.sh
```

Record a live ledger (stdlib; same run shape as the fixtures):

```bash
python3 scripts/trajectory-cases.py record init \
  --ledger evals/trajectories/runs/fetch-failure-stops.json \
  --case-id fetch-failure-stops \
  --invocation "/lgt-start-task PROJ-1" \
  --fetch fail
python3 scripts/trajectory-cases.py record stage --ledger evals/trajectories/runs/fetch-failure-stops.json jira-fetch
python3 scripts/trajectory-cases.py record artifact --ledger evals/trajectories/runs/fetch-failure-stops.json \
  --kind report --name stop-paste-ticket
python3 scripts/trajectory-cases.py record dump --ledger evals/trajectories/runs/fetch-failure-stops.json
python3 scripts/trajectory-cases.py score --run evals/trajectories/runs/fetch-failure-stops.json
```

Live files under `evals/trajectories/runs/*.json` are gitignored. Prefer `.cursor/gates/trajectory-run/<case_id>.json` in a consumer project.

## Add a case

1. Copy a close neighbor under `evals/trajectories/cases/`.
2. Set `id` to the new filename stem (`kebab-case.json`).
3. Point `source` at an existing kit file (dogfood checklist, spec, or command).
4. Use only the closed vocabularies in `scripts/trajectory-cases.py` (`pipeline`, stages, forbidden actions, human gates).
5. If the case covers a whole `full` / `fast` / `issue` path, set `end_to_end` to `true`. Route, gate, and fixture slices stay `false`.
6. If `required_stages` includes `create-pr`, `forbidden` must include `merge-pull-request`.
7. Run the two commands above.

Do not put live ticket secrets in `acceptance_criteria`. Prefer the fixtures already documented in dogfood checklists.

A later slice will execute the pipeline and write run records. This directory holds the corpus plus a deterministic scorer for those records.

## From a score fail to a new case

1. Keep the FAIL lines and the ledger JSON.
2. Ask Trajectory fail (`generalize` / `skip`). Do not skip this ask by inventing an answer.
3. On `generalize` in the kit repo: copy a neighbor under `evals/trajectories/cases/`, set `id` to the filename stem, point `source` at an existing kit file, run `python3 scripts/trajectory-cases.py validate`.
4. Display the validated case JSON (the file contents) in chat and wait for the human to confirm it is correct before `git commit`. Do not offer `git diff` as a substitute. Never auto-commit a case from a single score FAIL.
5. Do not add a case that only restates one unique incident. Hit-count an existing `id` in the title/source note instead.
