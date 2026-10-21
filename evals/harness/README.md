# Kit harness bench

Machine-checkable health for the cursor-spells kit. **Not** installed into consumer apps (`lgt install` never copies `evals/`).

## Inventory (no bench required)

```bash
python3 scripts/harness-health.py
python3 scripts/harness-health.py --json
python3 scripts/harness-health.py --bench-report evals/harness/reports/<timestamp>.json
```

Shows skill/command/agent/rule inventory, trajectory wiring vs `skills/trajectory-score/SKILL.md`, context-size proxies, and optional last bench summary.

## Full bench (before changing skills or agents)

```bash
bash scripts/harness-bench.sh
```

Runs every `scripts/tests/*.sh` with durations, then trajectory `validate` + `score --runs-dir evals/trajectories/fixtures/pass`. Writes `evals/harness/reports/<timestamp>.json` including a **`metrics`** block:

- **quality** — overall and contract pass rates; trajectory validate / fixture-score status
- **speed** — total duration, p50 / p95 / max step duration, and the slowest steps
- **review_response_quality** — hard sensors on phase JSON / markdown fixtures (evidence completeness, clarify options, markdown validator); `python3 scripts/review-response-quality.py score-fixtures`

`python3 scripts/harness-health.py` prints those metrics when a bench report is attached or auto-discovered.

Slash command `/lgt-harness-status` and skill `harness-status` are orientation only — they do not advance pipeline gates.


## Pictures (what the two systems look like)

Human-oriented guide (Ukrainian, plain names): [`../../docs/superpowers/pipeline-metrics-guide.md`](../../docs/superpowers/pipeline-metrics-guide.md).

**Whole kit vs live ticket (two lanes):**

![Architecture: live ticket pipeline above, kit harness bench below](../../docs/superpowers/images/pipeline-overview.png)

**How a live metrics row is written (“pipeline metrics path”):**

![Detail path: mark-start → record stages → append-score / append-review → history.jsonl → summary/export](../../docs/superpowers/images/pipeline-metrics-path.png)

| Name you may hear | Meaning |
|-------------------|---------|
| Live pipeline metrics / journal | Rows in the consumer project’s `.cursor/gates/pipeline-metrics/history.jsonl` from real ticket runs |
| Pipeline metrics path | The sequence `mark-start` → `append-score` / `append-review` → `summary` / `export` |
| Harness reports | JSON under `evals/harness/reports/` from `harness-bench` (kit only) |
| Harness health | Inventory + wiring + last bench summary (`harness-health.py`) — does not run the full bench by itself |

## Live pipeline metrics (consumer projects)

Bench metrics above are for **kit** changes. For **real ticket runs** in a consumer project, agents append rows to a local JSONL history so you can graph quality and speed over time:

```bash
# After trajectory ledger init (agents do this via skills/trajectory-score):
python3 "$KIT"/scripts/pipeline-metrics.py mark-start --ledger .cursor/gates/trajectory-run/<case>.json [--ticket PROJ-123]

# At each score stop (preferred over bare trajectory score):
python3 "$KIT"/scripts/pipeline-metrics.py append-score --kit-root "$KIT" --run .cursor/gates/trajectory-run/<case>.json [--ticket PROJ-123]

# After a validated engineer-review report:
python3 "$KIT"/scripts/pipeline-metrics.py append-review --kit-root "$KIT" --path /tmp/review-report.md [--ticket PROJ-123]

# Inspect / export for charts:
python3 "$KIT"/scripts/pipeline-metrics.py summary
python3 "$KIT"/scripts/pipeline-metrics.py export --format csv --out /tmp/pipeline-metrics.csv
```

Default history path (consumer project, gitignored with other gates): `.cursor/gates/pipeline-metrics/history.jsonl`. Contract test: `bash scripts/tests/pipeline-metrics-test.sh`.

## Related

- Plain-language guide + diagrams: [`../../docs/superpowers/pipeline-metrics-guide.md`](../../docs/superpowers/pipeline-metrics-guide.md)
- Trajectory corpus: [`../trajectories/README.md`](../trajectories/README.md)
- Code-quality evals: [`../code-quality/`](../code-quality/) (when present)
- Dogfood: [`../../docs/superpowers/dogfood/harness-health-checklist.md`](../../docs/superpowers/dogfood/harness-health-checklist.md)
- Security checklist contract (S1–S11 shared by reviewer + writers): `bash scripts/tests/security-hardening-checklist-test.sh`
- Shared writer/reviewer JPA gates: `bash scripts/tests/shared-writer-reviewer-gates-test.sh`
