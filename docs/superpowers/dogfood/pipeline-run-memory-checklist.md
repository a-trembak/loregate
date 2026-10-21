# Dogfood: pipeline run memory

Manual checks for consumer run-log journals, promote refuse-on-conflict, status enrichment, and fast-path brief.

## Preconditions

- Kit has `scripts/pipeline-run-log.sh` and `scripts/pipeline-status.sh`
- Prefer a scratch temp root (do not pollute a real consumer unless intended)
- If the agent sandbox blocks `mkdir .cursor`, export `PG_GATES_BASE="$ROOT/gates"` (and `mkdir -p` that path) before running helper commands — same override the contract tests use

## Steps

1. **Two invocations stay isolated**

   ```bash
   ROOT=$(mktemp -d)
   bash scripts/pipeline-run-log.sh init --root "$ROOT" --invocation dogA --route full
   bash scripts/pipeline-run-log.sh init --root "$ROOT" --invocation dogB --route fast
   test -f "$ROOT/.cursor/gates/run-log/inv-dogA.md"
   test -f "$ROOT/.cursor/gates/run-log/inv-dogB.md"
   grep -q 'invocation: dogB' "$ROOT/.cursor/gates/run-log/current-invocation"
   ```

2. **Promote when target absent**

   ```bash
   mkdir -p "$ROOT/docs/plans"
   printf '# plan\n' >"$ROOT/docs/plans/dogfood.md"
   bash scripts/pipeline-run-log.sh append --root "$ROOT" --invocation dogA --stage bootstrap --note "ok"
   bash scripts/pipeline-run-log.sh promote --root "$ROOT" --invocation dogA --plan docs/plans/dogfood.md --route full
   test ! -f "$ROOT/.cursor/gates/run-log/inv-dogA.md"
   bash scripts/pipeline-run-log.sh path --root "$ROOT" --plan docs/plans/dogfood.md
   ```

3. **Promote conflict refuses**

   ```bash
   bash scripts/pipeline-run-log.sh init --root "$ROOT" --invocation dogC --route full
   bash scripts/pipeline-run-log.sh append --root "$ROOT" --invocation dogC --stage bootstrap --note "later"
   if bash scripts/pipeline-run-log.sh promote --root "$ROOT" --invocation dogC --plan docs/plans/dogfood.md; then
     echo "FAIL expected refuse-on-conflict"; exit 1
   fi
   test -f "$ROOT/.cursor/gates/run-log/inv-dogC.md"
   ```

4. **Status via `--invocation` and pointer**

   ```bash
   bash scripts/pipeline-status.sh --json --root "$ROOT" --invocation dogC | grep run_log_path
   # pointer points at last init (dogC); strip may show Recent when journal has notes
   bash scripts/pipeline-status.sh --root "$ROOT" --invocation dogC
   ```

5. **Fast path brief without inventing a plan**

   ```bash
   bash scripts/pipeline-run-log.sh brief-upsert --root "$ROOT" --invocation dogB --route fast \
     --goal "Tiny fix" --next "csp-software-developer"
   test -f "$ROOT/.cursor/gates/run-log/briefs/inv-dogB.brief.md"
   # Do not create a fake docs/**/plans file for this path
   ```

6. **Missing helper skip** — in chat skills, when `pipeline-run-log.sh` is absent, expect a one-sentence skip and continued pipeline (no invented stage).

7. **Cleanup:** `rm -rf "$ROOT"`

## Contract tests

```bash
bash scripts/tests/pipeline-run-log-test.sh
bash scripts/tests/pipeline-run-log-wiring-test.sh
bash scripts/tests/pipeline-status-test.sh
bash scripts/tests/pipeline-status-wiring-test.sh
```

## Pass criteria

- [ ] Two `inv-*` journals coexist; pointer refreshes on `init`
- [ ] Promote absent succeeds; promote conflict leaves source intact
- [ ] Status enrichment via `--invocation` / pointer; missing journal does not change `stage`
- [ ] Fast brief under `briefs/` without a fake plan under `docs/`
- [ ] Recommend gitignore `.cursor/gates/run-log/` after install
- [ ] No chat transcripts or ticket bodies stored in journals
