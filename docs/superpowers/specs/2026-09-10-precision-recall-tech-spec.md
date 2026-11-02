# Precision / recall outcome ledger — Technical Spec

**Status:** draft
**AC:** AC-1, AC-2, AC-3, AC-4, AC-5
**System design:** `docs/superpowers/specs/2026-09-10-precision-recall-system-design.md`

## 1. AC references

Closes AC-1, AC-2, AC-3, AC-4, AC-5 (operator precision / recall outcomes for engineer-review, pr-review, and capture-escape; kit-local ledger + show; hard sensors untouched; indexing / lakehouse / full adversarial verifier out of scope).

## 2. Changes by layer

1. **Helper script** — add `scripts/precision-recall.py` (stdlib): `record` and `show` (`--json` optional). Atomic write via temp file + `os.replace`. Enforce `finding_` / `miss_` namespaces; reject kind/prefix mismatch (exit 2).
2. **Contract tests** — add `scripts/tests/precision-recall-test.sh` covering append, dedup bump, reclassify within namespace, separate maps for precision/recall math, missing/empty/corrupt ledger, namespace rejection, CLI exit codes. Wire into `scripts/harness-bench.sh` like other `scripts/tests/*.sh`.
3. **Skill** — add `skills/precision-recall/SKILL.md` with modes `record` and `show`; resolve kit root like `trajectory-score` / `harness-status`; never brick the pipeline on skip / `n/a`.
4. **Slash command** — add `commands/csp-precision-recall.md` (thin): default `show`; `record` when id + kind supplied.
5. **HITL** — extend `skills/hitl-choice/SKILL.md` with preset **Precision-recall outcome** (`false_positive` / `miss` / `skip`). Optional; must not block `propose-commit` (Assumption A4).
6. **Settle wiring** — update engineer-review / pr-review settle path (orchestrator skill + agent notes as needed): after validated report, mandatory auto-TP `record` for each evidence-gated Fixed/Clarify item via `derive_finding_id`; then existing Teach-review miss; then optional Precision-recall outcome ask.
7. **Capture-escape wiring** — after successful destination settle only (`teach-review` success coverage as that skill already emits, or `review_learn: appended|deduped`), `record` `kind=miss` with `miss_…` id.
8. **Harness orientation** — optional one-line mention in `scripts/harness-health.py` / `harness-status`: distinguish script `precision_recall: n/a` from `ledger: absent|empty|loaded`.
9. **Install surface** — ensure new skill/command/script are picked up by existing `csp install` / `csp update` globs; never copy project ledgers or `evals/`.
10. **Docs** — short README / dogfood note pointing at skill + command; keep system-design + this tech-spec.

## 3. Data model / contracts

### Ledger path

`<project>/.cursor/gates/precision-recall/ledger.json`

Trajectory-style telemetry directory (same family as `trajectory-run/`). **Not** a `pipeline-gates.sh` / `pg_list_gates` advancing kind.

### Entry shape

| Field | Type / rules |
|-------|----------------|
| `version` | `1` at file root |
| `entries[].id` | Namespaced kebab: `finding_…` or `miss_…` |
| `entries[].kind` | `true_positive` \| `false_positive` \| `miss` |
| `entries[].hits` | integer ≥ 1 |
| `entries[].first_seen` / `last_seen` | `YYYY-MM-DD` |
| `entries[].source` | `engineer-review` \| `pr-review` \| `capture-escape` \| `manual` |
| `entries[].note` | optional short English; no secrets / personal data |

### Id algorithms

**Finding (TP / FP):**

```text
finding_{phase}_{kebab(title_raw)}_{path_stem(path)}_L{start_line}
```

Inputs from phase JSON that survived the evidence gate (`phase-protocol-detail.md`): `phase`; `title_raw` = `fixed[].summary` or, for Clarify, prefer `clarify[].question` (stable JSON field), with the short user-facing heading title after `### C# — \`P#\` — ` only as fallback when `question` is empty; `path`; `start_line`. `kebab` / `path_stem` as in the system design (48-char body truncate). Report labels `F#` / `C#` are not part of the id.

**Miss:**

```text
miss_{kebab(miss_class)}
```

### Dedup

Same `id` + same `kind` → bump `hits` / `last_seen` (`deduped`). Same `id` + different allowed kind in the same namespace → append; latest wins inside that namespace (`reclassified`). New `id` → `appended`.

### Metrics

Separate maps: `finding_latest` and `miss_latest`.

- `TP` / `FP` from finding map; `Miss` from miss map
- `precision = TP / (TP + FP)` or ratio `n/a`
- `recall = TP / (TP + Miss)` or ratio `n/a`
- Print all three counts always; `hits` do not inflate denominators

### CLI

```bash
python3 scripts/precision-recall.py record \
  --ledger <path> --id <id> --kind true_positive|false_positive|miss \
  [--source engineer-review|pr-review|capture-escape|manual] [--note "..."]

python3 scripts/precision-recall.py show --ledger <path> [--json]
```

Coverage skeleton: `precision_recall: appended|deduped|reclassified|skipped|n/a` plus show tags `ledger: absent|empty|loaded`.

### Auto-TP batch

Sequential `record` per surviving finding. On a mid-batch failure: continue remaining ids; set coverage to `precision_recall: skipped` with a count of failures in the skill note (partial TP set is intentional). Do not roll back earlier successful atomic replaces.

## 4. Rollout sequence

1. Land helper + contract tests; green `precision-recall-test.sh`.
2. Land skill + slash command (show/record usable manually).
3. Wire auto-TP + optional outcome ask on engineer-review / pr-review settle (non-blocking for propose-commit).
4. Wire capture-escape miss record after successful destination settle.
5. Optional harness-health inventory line.
6. Update README / dogfood checklist row.
7. Run `bash scripts/harness-bench.sh` (or at least new + wiring tests) before merge.

## 5. Compatibility / migration / rollback

- **Migration:** none — new ledger created on first `record`.
- **Rollback:** remove skill/command/wiring commits; delete or ignore project ledger files. No schema migration of existing kit state.
- **Consumer projects:** absent script → `precision_recall: n/a` skip; pipelines keep working.

## 6. Rejected alternatives

- Semantic / hybrid indexing for miss similarity — out of scope (AC-5); stable ids suffice.
- Lakehouse / remote analytics — out of scope (AC-5); project-local JSON fits kit stack.
- Full adversarial verifier in this delivery — out of scope (AC-5); optional future candidate hook only.
- Replacing `trajectory-cases.py score` or `code-quality-cases.py score` with precision/recall — violates AC-4.
- Folding metric rows into `.cursor/review-learnings.md` — that store is instruction capture with Active cap, not outcome math.
- Single flat `id → latest kind` map across finding and miss — rejected; corrupts denominators when escape and finding classes share a slug.
- Mutating kind in place instead of append + latest-wins within namespace — rejected; loses history.
- Hit-weighted precision/recall — rejected for v1; `hits` stay frequency-only.
- Hard gate that blocks propose-commit on missing precision-recall ask — rejected; skip must stay safe.

## 7. Open questions / Assumptions

### Open questions

None.

### Assumptions

| Id | Claim | Why | How to revoke |
|----|-------|-----|---------------|
| A1 | True positives are mandatory auto-records from evidence-gated settled findings; operators only label `false_positive` and `miss` | AC-1 names those two operator outcomes; AC-3 needs TP | Add `confirm_true` / stop auto-append |
| A2 | Operator-scale volume; one JSON file per project is enough | Kit telemetry pattern; no warehouse AC | Month-split / compaction when show latency hurts |
| A3 | Denominators count distinct ids (latest kind per namespace), not sum of hits | Keeps ratios interpretable | Hit-weighted formula if owners require it |
| A4 | Precision-recall capture must not block `propose-commit` or Pipeline finale; `skip` is always safe | Settle spine must not regress | Promote to hard gate only with a new AC |
| A5 | `/csp-capture-escape` contributes metric `miss` only after successful destination settle; never `false_positive` | Escape is a production miss path | Allow FP on escape only with a new AC |
| A6 | Line/title drift creates a new `finding_…` id | Evidence fields are the stable key available today | Softer keys if fragmentation hurts |
| A7 | Concurrent manual record during settle is unsupported; last atomic replace wins | Single-writer settle order is enough for v1 | Add lock/queue if concurrent writers appear |
| A8 | Ledger is local operator telemetry (often gitignored under `.cursor/gates/`); no replica | Matches trajectory-run locality | Export / commit exception / sync if durability AC appears |
| A9 | Auto-TP without habitual FP labeling can overstate precision | Accept-risk from system-design critic | Revoke via A1 path |
| A10 | Clarify `title_raw` prefers `clarify[].question`; heading text is fallback only | One derivation function for auto-TP and FP listing | Change preference only with an explicit AC |
| A11 | Teach-review / review-learn success is detected via those skills’ **existing** coverage strings — this feature does not invent new teach-review tokens | Avoid token drift | Update wiring if those skills rename coverage |

### Future hook (not this delivery)

An adversarial verifier may later suggest `miss` / `false_positive` candidates for operator confirm before `record`. No indexing or lakehouse work in this change.
