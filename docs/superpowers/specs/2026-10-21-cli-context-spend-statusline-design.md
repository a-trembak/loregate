# CLI context-spend status line (pipeline proxies)

## Status

`approved` — human reviewed; implementation plan `docs/superpowers/plans/2026-10-21-cli-context-spend-statusline.md`.

## Goal

While working in **Cursor Agent CLI**, show a live two-line status area that separates:

1. **Cursor ring** — context window usage from the CLI status-line payload (not API billing).
2. **Loregate pipeline proxy spend** — how much that ring grew across pipeline **stages**, so humans can see which stages to optimize first.

Success: after a pipeline session, the human can read `peak:<stage>(+N)` and a short `hint:…` and know which part of the kit to thin (spec, handoff, clarify, etc.) without a background “watch” agent.

## Decisions

| Decision | Choice |
|----------|--------|
| Approach | Local CLI `statusLine` command + on-disk snapshots (no LLM watcher) |
| Surface | Cursor Agent CLI only (not IDE Agent UI status bar) |
| Script | Single file `~/.cursor/statusline-loregate.sh` — **no** separate runtime kit helper |
| Kit packaging | Optional: `lgt install` (or equivalent) **copies** the script template into `~/.cursor/`; runtime must not require `$KIT` |
| Config | `~/.cursor/cli-config.json` → `statusLine.type=command`, `command=~/.cursor/statusline-loregate.sh`, `updateIntervalMs=500`, `timeoutMs=2000`, `padding=2` |
| Snapshot store | Consumer project: `.cursor/gates/context-spend/snapshots.jsonl` |
| Snapshot fields | `ts`, `session_id`, `ctx_pct`, `stage`, `route`, `invocation_id` (optional) |
| Snapshot write rules | Append when `stage` changes **or** `ctx_pct` moves by ≥ **1** percentage point; debounce ~**2s**; trim to last ~**500** lines |
| Stage / route source | Existing orientation signals only: gates + `current-invocation` + run-log tail (same family as `pipeline-status`). Never invent stages; never advance or clear gates |
| Measurement | **Proxies only**: CLI `context_window.used_percentage` deltas between stages (**pp** = percentage points on the ring scale) |
| Alert threshold | `⚠` when per-stage delta ≥ **15** pp |
| Hint | Fixed dictionary in the script; show **`hint:…` only for the current stage** (not peak) |
| Line 1 (Cursor) | `cursor  <model>  ctx <N>%  <bar>  ring` |
| Line 2 (Pipeline) | `pipe  <route>·<stage>  +<N>pp/stage  peak:<stage>(+N)  [⚠+N]  [hint:<token>]` |
| Missing pipeline | Line 2: `pipe  —  (no loregate gates)` |
| Missing ctx % | Line 1: `ctx —`; skip deltas / alert / peak math |
| Session boundary | New `session_id` resets peak / per-session delta aggregation |
| Errors | On bad JSON / missing tools: one short error line or non-zero exit with empty stdout so CLI keeps previous text; never hang the prompt |
| Docs | README blurb: how to enable, how to read `pp` / `peak` / `hint`, stage→optimization legend |

### Hint dictionary (v1)

| Stage id / prefix match | `hint` token |
|-------------------------|--------------|
| `tech-spec`, `spec` | `thin-spec` |
| `plan`, `approve-plan`, `writing-plans` | `thin-plan` |
| `critic`, `implementation-critic`, `critique` | `compact-critic` |
| `build`, `start-build`, `software-developer` | `slim-handoff` |
| `eng-review`, `engineer-review`, `review-gate`, `clarify` | `cut-clarify` |
| `finish-plan`, `local-diff` | `less-diff-paste` |
| `docs`, `update-docs` | `short-docs` |
| `create-pr`, `finale` | `short-pr` |
| unknown / no gates | omit `hint:` |

### How humans use this for optimization

1. Prefer **`peak:<stage>(+N)`** as the first optimization candidate for the session.
2. Treat **`⚠` + `hint:`** on the current stage as “this stage is bloating the ring now.”
3. Compare line 1 vs line 2: ring rising with flat `pipe` deltas → Cursor baseline (rules, open files, MCP); large `pipe` stage deltas → kit path for that stage.
4. Hints are **levers**, not root-cause analysis: e.g. `cut-clarify` → thin engineer-review clarify / phase return size; `slim-handoff` → reduce parent-chat paste from nested Task returns.

**pp** means percentage points: `50%` → `68%` is **+18pp**, not “+18% of 50.”

## Example render

```text
cursor  Opus  ctx 68% ███████░░░  ring
pipe  full·eng-review  +12pp/stage  peak:tech-spec(+28)  ⚠+18  hint:cut-clarify
```

Truncate line 2 to `render_width_chars` when needed; prefer keeping `⚠` and `hint` when an alert is active.

## Non-goals (v1)

- Exact API / billing token counts per agent or tool call
- Parent-chat vs nested-Task attribution beyond what stage proxies already imply
- IDE UI status bar or Canvas dashboard
- Background watch agent / `/loop` that spends model tokens
- Writing spend fields into `pipeline-run-log` or changing HITL / skills
- Drill-down slash command (e.g. `/lgt-context-spend`) — possible later
- Claiming kit byte proxies from `harness-health` equal the live ring

## Relationship to existing kit pieces

| Existing | Role vs this design |
|----------|---------------------|
| CLI `statusLine` payload | Source of live `ctx %` / model / cwd / `session_id` |
| `pipeline-status` / run-log / gates | Read-only stage/route orientation for line 2 |
| `harness-health` context proxies | Static skill/rule size — complementary, not a substitute |
| `pipeline-metrics` | Quality/speed journal — out of scope for v1 merge |
| `graphify-pipeline` / skill context budgets | Optimization **targets** once peak/hint points at a stage |

## Test plan

- Mock CLI stdin JSON → expected two-line stdout (model, ctx bar, labels)
- Fixture snapshots + current ctx/stage → correct `+Npp/stage`, `peak`, `⚠`, `hint`
- `cwd` without `.cursor/gates` → line 2 no-gates message; no crash
- `session_id` change → peak reset
- Debounce / trim behavior covered with a small shell or Python test beside the script (kit `scripts/tests/` if the template lives in-repo)
- Manual: enable in `cli-config.json`, run CLI in a consumer project mid-pipeline, confirm updates without blocking the prompt

## Open follow-ups (explicitly not v1)

- Optionally dual-write stage ctx deltas into run-log at HITL stops
- Optional `/lgt-context-spend` summary from `snapshots.jsonl`
- Richer parent vs Task proxies if Cursor exposes more session metrics later
