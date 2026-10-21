# Graphify usage in live pipeline-metrics — Technical Spec

**Status:** draft  
**AC:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-6  
**System design:** `docs/superpowers/specs/2026-09-16-graphify-pipeline-metrics-system-design.md`

---

## 1. AC references

Closes AC-1, AC-2, AC-3, AC-4, AC-5, AC-6 (Graphify usage + token-savings proxy — absolute **and percentage** — on live `pipeline-metrics` journal for local consumer runs).

---

## 2. Changes by layer

Order of touch (kit repo `cursor-spells`):

1. **`scripts/pipeline-metrics.py`**
   - Add `collect_graphify_metrics(...)` (same file; stdlib only).
   - Call it from `cmd_append_review` before JSONL append; nest result under `graphify` on the existing `kind: review_response_quality` event.
   - Extend `cmd_summary` with Graphify state rollups, Coverage-echo rollups, proxy sums, **budget-weighted `window_proxy_savings_pct`** as the primary rate (optional unweighted average of per-row `proxy_savings_pct`), and a one-line proxy ≠ Cursor-tokens disclaimer.
   - Extend `cmd_export` CSV `fieldnames` with flat Graphify columns (including `graphify_proxy_savings_pct`); JSON/JSONL keep full nested objects.
   - Add optional non-breaking CLI flags on `append-review`: `--repo-root`, `--graphify-log`, `--review-started-at`, `--review-ended-at`, `--skip-graphify-metrics`.
2. **`scripts/tests/pipeline-metrics-test.sh`** + fixtures under `scripts/tests/fixtures/pipeline-metrics/graphify/`
   - Cover used / absent / unqueryable / skip / null-Coverage / capped window / **pct math + zero-budget → null pct** / summary / export (no real user cache).
3. **`docs/superpowers/pipeline-metrics-guide.md`**
   - Ukrainian section: Graphify fields, absolute vs **відсоток** економії, does-not-measure list, preferred-when-present soft-fail, Coverage vs `state`, multi-project contamination caveat, append-only journal note.
4. **Caller skills (day-one defaults)**
   - `skills/engineer-review/SKILL.md` keeps calling `append-review` as today; new flags optional. No Graphify rebuild during review.

No consumer product services, tables, HTTP endpoints, or jobs.

---

## 3. Data model / contracts

### History event (additive, append-only)

Same consumer path: `.cursor/gates/pipeline-metrics/history.jsonl`. Keep `SCHEMA_VERSION = 1`. Nested object on review rows. Journal is **append-only** (new events; do not rewrite past rows) — same discipline as an event log for metrics history.

| Field | Type | Notes |
|-------|------|--------|
| `graphify.state` | string | `used` \| `absent` \| `unqueryable` \| `skip` (always present when collection runs) |
| `graphify.coverage` | string \| null | Echo of Coverage token `used` \| `absent` \| `unqueryable`, or `null` if missing |
| `graphify.artifacts_present` | bool | Detect: repo root then workspace parent for `graphify-out/GRAPH_REPORT.md` or `graphify-out/graph.json` |
| `graphify.log_path` | string \| null | Resolved log path |
| `graphify.log_found` | bool | |
| `graphify.window_started_at` / `window_ended_at` | ISO8601 strings \| null | |
| `graphify.query_count` | int \| null | |
| `graphify.sum_result_chars` | int \| null | |
| `graphify.sum_nodes_returned` | int \| null | |
| `graphify.sum_duration_ms` | number \| null | |
| `graphify.sum_token_budget` | int \| null | |
| `graphify.proxy_retrieved_tokens` | int \| null | `ceil(sum_result_chars / 4)` |
| `graphify.proxy_savings_vs_budget_tokens` | int \| null | `max(0, sum_token_budget − proxy_retrieved_tokens)` |
| `graphify.proxy_savings_pct` | number \| null | When `sum_token_budget > 0`: `round(100.0 * proxy_savings_vs_budget_tokens / sum_token_budget, 1)`; else `null` |
| `graphify.proxy_definition` | string \| null | `"chars_div4_vs_budget"` when proxy computed |
| `graphify.reason` | string \| null | e.g. `no_queries_in_window`, `log_missing`, `collection_error` |

Legacy rows without `graphify` remain valid (`missing` in summary rollups).

### State resolution

| `coverage` | In-window queries | `artifacts_present` | `state` |
|------------|-------------------|---------------------|---------|
| `used` | ≥1 | * | `used` |
| `used` | 0 | * | `unqueryable` (not `absent`) |
| `absent` | * | * | `absent` (numerics null; skip log aggregates) |
| `unqueryable` | * | * | `unqueryable` |
| `null` | ≥1 | * | `used` |
| `null` | 0 | `false` | `absent` |
| `null` | 0 | `true` | `unqueryable` |

When Coverage is `unqueryable` and the log still has in-window queries: keep `state: unqueryable` and **still fill** windowed aggregates / proxy (including pct) when present. When Coverage is `absent`, numerics stay null.

### Review window (capped)

- `LOOKBACK` default = 2 hours.
- `window_ended_at` = `--review-ended-at` or `recorded_at`.
- Default `window_started_at` = `recorded_at − LOOKBACK`.
- Optional tighten only (no `--review-started-at`): `max(report_mtime, recorded_at − LOOKBACK)`.
- Stale `report_mtime` must not open a window older than `LOOKBACK`; only `--review-started-at` may widen.

### Query log

- Default: `~/.cache/graphify-queries.log`.
- JSONL; resilient parse; filter by timestamp window; optional cwd filter when path fields exist.
- Never call Graphify CLI or rebuild during collection.

### Proxy (not Cursor tokens)

Named `chars_div4_vs_budget`:

| Field | Answers |
|-------|---------|
| `proxy_retrieved_tokens` | How many proxy tokens of Graphify **returned** context |
| `proxy_savings_vs_budget_tokens` | How many proxy tokens of Graphify **budget** were not consumed by returned context |
| `proxy_savings_pct` | What **percent** of the summed Graphify query budgets that unused portion is |

Does **not** measure Cursor conversation tokens, avoided repo walks, full `graph.json` size, money, or “% cheaper Cursor chats.”

### CLI / export contract

CSV columns: `graphify_state`, `graphify_coverage`, `graphify_query_count`, `graphify_sum_result_chars`, `graphify_sum_nodes_returned`, `graphify_sum_duration_ms`, `graphify_sum_token_budget`, `graphify_proxy_retrieved_tokens`, `graphify_proxy_savings_vs_budget_tokens`, `graphify_proxy_savings_pct`, `graphify_proxy_definition`.

`append-review` exit code remains quality-scorer only; Graphify never forces non-zero.

### Methodology alignment (adopted vs out of scope)

From mentor notes under `Documents/Mentor-learning/llm-extraction-pipeline` (quality harness / budgets / append-only):

| Adopt into this change | Out of scope for this change |
|------------------------|------------------------------|
| Prefer **rates** alongside absolute counts (`proxy_savings_pct` + absolute savings) | Field-level precision/recall golden harness for extraction |
| Keep metrics journal **append-only**; graph over time | Overwrite-in-place “current scoreboard” only |
| Treat Graphify budgets as a measurable **budget** signal | Full `$/doc` product cost accounting |
| Soft programmatic gates: missing Graphify must not fail quality exit | LLM-as-judge as the Graphify savings meter |
| Contract fixtures = tier-1 deterministic asserts | Expanding golden trajectory cases solely for Graphify |

---

## 4. Rollout sequence

1. Land helper + `append-review` / `summary` / `export` changes and contract tests in the kit.
2. Update Ukrainian metrics guide in the same change set.
3. Consumers pick up the kit on next install/sync; existing history files gain Graphify fields only on **new** `append-review` rows.
4. Optional later: engineer-review passes `--review-started-at` / `mark-stage` for tighter windows; optional **Δ vs prior week** rollup in `summary` (baseline delta from harness practice — not required for first ship).

---

## 5. Compatibility / migration / rollback

| Step | Compatibility | Rollback |
|------|---------------|----------|
| Additive `graphify` on new rows | Old rows / old readers ignore unknown keys | Revert kit commit; leave history as-is |
| CSV new columns including pct | Spreadsheet consumers may need header remap | Revert export fieldnames with kit |
| Soft-fail collection | Pipeline behavior matches pre-change when Graphify missing | N/A — failure isolation is the feature |

No database migration. History files are local / not committed by design.

---

## 6. Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Separate `kind: graphify_usage` JSONL events | Harder joins; AC wants the review history row to also carry Graphify |
| Claim Cursor conversation token savings (absolute or %) | Cursor does not expose those counts |
| Absolute-only proxy without `proxy_savings_pct` | Harder for humans to answer “яка економія?” at a glance; contradicts rate/Δ readability |
| Unbounded window from stale report mtime | Attributes unrelated Graphify queries to the wrong review |
| Require Coverage token for `state: used` | Conflicts with preferred-when-present + real log evidence |
| Hard-fail `append-review` when Graphify missing | Violates AC-4 and preferred-when-present |
| Parallel metrics product / second CLI | Extend `pipeline-metrics` instead |
| Bump `SCHEMA_VERSION` to 2 for optional keys | Unnecessary break |

---

## 7. Open questions / Assumptions

### Open questions

None blocking approval.

### Assumptions

| ID | Claim | Why | How to revoke |
|----|-------|-----|---------------|
| A1 | Query log is JSONL with AC field names when present | Matches known Graphify cache log | Adjust parser when samples differ |
| A2 | `CHARS_PER_TOKEN = 4` is an acceptable public heuristic | Labeled via `proxy_definition` | Change constant + bump `proxy_definition` |
| A3 | Default capped 2h window is enough for one engineer-review | Typical local duration; stale mtime cannot widen past LOOKBACK | Change LOOKBACK or require `--review-started-at` |
| A4 | Timestamp-only filter OK without cwd fields | Common single-review machine | Default-on cwd filter when schema allows; guide states contamination risk |
| A5 | `SCHEMA_VERSION = 1` + optional `graphify` is enough | Additive | Bump if tooling requires a version gate |
| A6 | Reporting `proxy_savings_pct` as share of Graphify **query budget** unused by returned chars is the right denominator for “економія %” | Matches available log fields and budget thinking; no Cursor totals exist | Change formula + bump `proxy_definition` if a better denominator appears |

### Accept-risk (human reviews at approve-spec)

- Multi-project contamination when log entries lack cwd/repo path fields.
- Proxy absolute **and** percentage are heuristics, not product token cost.
- Log field aliases remain best-effort until fixtures / a captured sample pin production shape.
