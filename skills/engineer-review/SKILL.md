---
name: engineer-review
description: >-
  Use when a plan just finished and human-in-the-loop review gate is next, when
  the user runs /lgt-engineer-review or asks for engineer-reviewer, or when
  approving automated post-plan code review across Java/Spring, React,
  TypeScript, or React Native changes. Findings must include Context,
  code snippets, clickable file:line links, english-humanizer prose, and
  structured clarify Options with a marked Recommendation (never invent
  recommended).
disable-model-invocation: true
icon: shield
color: blue
---

# Engineer Review

Thin orchestrator for multi-phase code review. **This file is the canonical spine.** Agent `csp-engineer-reviewer` is a short pointer plus hard rules. User-facing feedback must meet [references/feedback-format.md](references/feedback-format.md) — load that pack **at merge/report time only**.

## When to Use

- After plan execution, once the user answers the HITL gate (`skip` / `approve` / `done`) — usually via skill `finish-plan`
- Manual `/lgt-engineer-review` or `@csp-engineer-reviewer`
- Not for drive-by questions that are not a review of a diff/branch

## HITL gate (required before auto-review)

If this run was triggered because a **plan finished**, do **not** start phases until the user answers via skill **`hitl-choice`** (AskQuestion required; text only after failed/missing tool). Preset: **Finish-plan / engineer-review / multi-repo HITL**:

- `skip` — start review now
- `approve` or `done` — start after their own pass
- `fixes` / typed fix description — treat as “fix first”, then re-ask

Prefer skill/command `finish-plan` to set `.cursor/gates/review-gate/<slug>` reliably. If `skip` / `approve` / `done` already appear in chat after the gate was asked, clear this plan's marker and start — do not re-prompt.

Manual `/lgt-engineer-review` skips this gate.

## Early Figma ask (frontend)

After HITL approval (or at the start of manual review), if stack is `react-web` or `react-native`, ask **before** phase dispatch via skill **`hitl-choice`** preset **Figma ask** (AskQuestion required; text fallback only after failed/missing tool: paste links or `no figma`).

**Enable Figma MCP when tools are missing (mandatory):** probe the live catalog before **Figma ask**, before dispatching `csp-review-figma-markup`, and **again as soon as Figma URLs appear in chat** (paste after `have_urls` or unsolicited). If tools are unusable, ask preset **Enable Figma MCP** (`figma_enabled` / `skip_figma_mcp`) via `hitl-choice` — do not swallow the paste and continue. On `skip_figma_mcp` or persistent miss after `figma_enabled`, note `figma_mcp: unavailable` / `skill_missing: figma-mcp` and continue non-Figma phases (Coverage `figma_markup: skipped` or `source-only` as phase rules already allow). If a phase returns `figma_mcp_disabled`, ask **Enable Figma MCP** in the parent and re-dispatch figma only after tools exist or skip.

Pass URLs into clarifications for `csp-review-figma-markup`. Do not block other phases on the answer if the user already said `no figma` / `no_figma`; if they have not answered yet, run non-figma phases first and keep figma skipped until URLs arrive.

## Spine (do this in order)

1. Resolve review range (`base..head`, default current branch vs `main`/`master`/`origin/main`).
2. Detect stack → read [references/skill-map-orch.md](references/skill-map-orch.md) (full map is phase/installer-owned: [skill-map.md](references/skill-map.md)).
3. **Budget**: compute changed files / LOC (`git diff --name-only` + `--numstat`).
4. **Catastrophic abort** (see [phase-protocol.md](references/phase-protocol.md)): if files > **200** or LOC > **50_000**, stop and ask the user to narrow (path allow/deny list, smaller range, exclude generated/lockfile noise). Do not chunk-spam or sample randomly. Abort does **not** load the merge feedback pack.
5. **Graphify scoping** (preferred when present): load skill **`graphify-pipeline`** and apply [references/graphify-protocol.md](references/graphify-protocol.md) (detect + `impact_hint` only; use `scripts/graphify-pipeline.sh`). If graphify is absent or unqueryable, skip — behavior matches today’s diff-only path. **Never refresh** during review (implement agents refresh after verify). Phases load [graphify-r3-force-include.md](references/graphify-r3-force-include.md) when triggered.
6. **Learnings (thin):** dispatch `csp-review-learn` `mode:load` — orchestrator does **not** read ledgers or `learned-misses.md`. Forward ≤5 `learned_hints` only to listed phases. See [review-learn-protocol.md](references/review-learn-protocol.md). Coverage: `review_learnings: loaded N|absent`.
7. If changed files > 40 or changed LOC > 2500 (and under the catastrophic caps), split into chunks (prefer graph modules when graphify answered; otherwise directory/package — see [phase-protocol.md](references/phase-protocol.md)).
8. Ensure consumer `.cursor/project-patterns.md` exists (create via patterns agent + [patterns-template.md](references/patterns-template.md) on first run).
9. Early Figma ask when frontend (above).
10. Dispatch phase subagents per phase-protocol (pass `graphify_available` + optional `impact_hint` + per-phase `learned_hints`). Run `csp-review-lint` first; then parallel **find** for remaining heuristic phases (**including** `csp-review-simplify`); serialize **apply** for `unambiguous && (P0|P1)` only (eligibility: [auto-fix-eligibility.md](references/auto-fix-eligibility.md)). Apply **Tiny-diff heuristic phase skip** from [phase-protocol.md](references/phase-protocol.md) when the range qualifies — Coverage must note `phase_skip: tiny-diff (…)`. Phases own checklist bodies — orchestrator does not load them. Stack / third-party bodies are **L2** per [skill-map.md](references/skill-map.md) Skill profile (default `strict`).
11. After apply: verify `csp-review-lint` + `csp-review-simplify` once each in `find`; do not loop.

12. **Merge → report (lazy feedback pack):** load [evidence-gate.md](references/evidence-gate.md) → [feedback-format.md](references/feedback-format.md) + [forbidden-formats.md](references/forbidden-formats.md) + [output-schema.md](references/output-schema.md) **only now**; never *emit* formats banned by [forbidden-formats.md](references/forbidden-formats.md). Coverage: `graphify:…`, `review_learnings:…`, when in scope `interaction_replay:…` (**R7**), `figma_markup:…` (**F7**), `narrow_viewport:…` (**V4**), `null_safety_callers:…` (**N1**), and `jpa_result_type:…` (**RT1**). Validate with `scripts/validate-review-report.sh`. When the kit path is known, also append a live quality row: `python3 "$KIT"/scripts/pipeline-metrics.py append-review --kit-root "$KIT" --path <validated-report> [--ticket "<live ticket key>"]` (skip quietly if `pipeline-metrics.py` is missing). Then `english-humanizer` then `plain-language-chat` on prose.
13. Needs clarification → HITL **Engineer-review clarify**; each sequential question repeats Context, What, When it shows up, File, Lines, Jump, and numbered fence (lift phase JSON **verbatim** — do not re-summarize); re-dispatch affected phases. R1 timing/host answers also re-dispatch logic + architecture with `interaction_replay` (phases load checklists — orchestrator does not).
14. **Teach-review miss:** after the validated report is shown, ask via skill `hitl-choice` preset **Teach-review miss** (`miss` / `project_secret` / `no_miss`). Recommended: `miss`. **Never edit kit git** in this orchestrator. Do not auto-capture.
    - `no_miss` → do not invoke `teach-review`; do not dispatch `csp-review-learn` `mode:capture`.
    - `miss` → collect description (open-ended if needed), invoke skill `teach-review`. If `teach-review` fails, keep the report; tell the human to retry with `/lgt-teach-review`.
    - `project_secret` → collect description (open-ended if needed), dispatch `csp-review-learn` `mode:capture` with destination `project_secret`. Coverage: `review_learn: appended|deduped|skipped|n/a`. Do not ask **Review-learn promote**. Never edit kit files.
    Do not write both stores on the same miss. Production misses **without** a full review use slash command `/lgt-capture-escape` (destination `miss` or `project_secret`). Append session ledger per skill `trajectory-score` (stage `engineer-review`, gate `teach-review-miss`, artifact report `engineer-review`, end `review_report: evidence-gated`).
15. After a successful **pipeline** review (from `/lgt-start-task` / `finish-plan` / `/lgt-start-task --fast` / `/lgt-start-issue-task`), once the report is settled and teach-review-miss is handled: invoke skill **`local-diff-review-gate`** next (dirty working-tree / staged Local Diff Review; HITL `approve-diff` / `comment`). **Order is mandatory:** miss answer (`no_miss` / teach land / project capture) → `local-diff-review-gate` → only then the commit path. Never ask `approve-commit` right after `no_miss`. **After the gate returns:**
    - If `next_skill: engineer-review`: re-dispatch this review (or `csp-multi-repo-supervisor` when routing says multi-repo) with the same repo set / Figma clarifications rules; then Teach-review miss again; then **`local-diff-review-gate`** again. **Loop** until the gate returns `next_skill: propose-commit`.
    - If `next_skill: propose-commit`: invoke skill **`propose-commit`**. Then:
      - Full path: `update-docs` (existing destination HITL), then if the tree is still dirty invoke **`local-diff-review-gate`** once more, honor the same **Loop** contract when the gate returns (`next_skill: engineer-review` → re-dispatch review → miss → gate again; `next_skill: propose-commit` → **`propose-commit`** again for residual docs), then `create-pr`. Honor `next_skill` from `update-docs`; never end the pipeline turn on docs alone.
      - Fast / issue: `create-pr` (no `update-docs` unless the human asked).
    Manual `/lgt-engineer-review` does **not** auto-start `local-diff-review-gate`, `propose-commit`, or `update-docs` unless the human asks.

## Fix policy

- Apply immediately: unambiguous **P0/P1** that also passes [`references/auto-fix-eligibility.md`](references/auto-fix-eligibility.md) (bugs, dead code, obsolete historical comments, clear pattern violations, reinvented helpers).
- **P2** → Residual notes only.
- Clarify first: behavior/API/product/design/security tradeoffs, risky deletions, spec/diff traceability mismatches, anything without clear evidence or that fails the eligibility test.

## Phase agents

| Phase | Agent |
|-------|-------|
| Lint / typecheck / build (deterministic tooling) | `csp-review-lint` |
| Logic + stack best practices | `csp-review-logic` |
| Project patterns | `csp-review-patterns` |
| Dead code / unused / comments | `csp-review-deadcode` |
| Cleanliness / reuse / local efficiency | `csp-review-simplify` (`ce-simplify-code`) |
| Architecture | `csp-review-architecture` |
| Performance | `csp-review-performance` |
| Security (conditional) | `csp-review-security` |
| Figma markup (frontend + URLs) | `csp-review-figma-markup` (always opens [figma-markup-checklist.md](references/figma-markup-checklist.md) F1–F7 — phase-owned) |
| Learn / load hints (before phases); capture only after `project_secret` | `csp-review-learn` |

`csp-review-lint` runs actual project tooling rather than LLM judgment.

`csp-review-simplify` uses compound-engineering **`ce-simplify-code`**, then **Kit extensions** from [`references/simplify-checklist.md`](references/simplify-checklist.md). Lens A–C are fallback only ([`simplify-lenses-fallback.md`](references/simplify-lenses-fallback.md)).

`csp-review-learn`: **`load`** before phases (orchestrator never reads ledgers); **`capture`** only after `project_secret`. Matched hints require phases to open the linked checklist.

Orchestrator agent: `csp-engineer-reviewer`. Plan handoff: `finish-plan`.

## Multi-repo

If the caller is `csp-multi-repo-supervisor`, or discovery finds **2+ changed repos**, defer to [references/multi-repo-protocol.md](references/multi-repo-protocol.md) and agent `csp-multi-repo-supervisor`. If discovery finds 0 changed repos, stop with a no-changes message; if it finds 1 changed repo, the single-repo path above is unchanged.

## Context budget

### Always-on (orchestrator)

- This `SKILL.md` + agent `csp-engineer-reviewer` hard rules
- [phase-protocol.md](references/phase-protocol.md) (inputs / caps / order / merge / Coverage)
- [review-learn-protocol.md](references/review-learn-protocol.md) (thin load/dispatch)
- [graphify-protocol.md](references/graphify-protocol.md) (detect + `impact_hint`)
- [skill-map-orch.md](references/skill-map-orch.md)
- [auto-fix-eligibility.md](references/auto-fix-eligibility.md)
- [patterns-template.md](references/patterns-template.md) when creating patterns
- [multi-repo-protocol.md](references/multi-repo-protocol.md) only on the multi-repo path

### Phase-only (do **not** load bodies into orchestrator)

- [phase-protocol-detail.md](references/phase-protocol-detail.md), [skill-map.md](references/skill-map.md), [review-learn-capture.md](references/review-learn-capture.md), [graphify-r3-force-include.md](references/graphify-r3-force-include.md)

- Checklists: `interaction-replay-checklist.md`, `auth-rtk-checklist.md`, `figma-markup-checklist.md`, `responsive-layout-checklist.md`, `null-safety-checklist.md`, `jpa-criteria-checklist.md`, `jpa-repository-result-checklist.md`, `styling-checklist.md`, `fixture-identifier-conventions.md`, `simplify-checklist.md`, `simplify-lenses-fallback.md`, `security-hardening-checklist.md`
- [learned-misses.md](references/learned-misses.md) (except pointing `csp-review-learn` at it)
- Phase agent prompts (`agents/csp-review-*.md`)

### Merge-only (load at report time — not at start; skip on abort)

- [feedback-format.md](references/feedback-format.md), [evidence-gate.md](references/evidence-gate.md), [forbidden-formats.md](references/forbidden-formats.md), [output-schema.md](references/output-schema.md)
- skills `english-humanizer` then `plain-language-chat`

Pass only **structured JSON** phase summaries upward (not chat transcripts or full diffs). **Compact means shape, not truncated evidence:** every `clarify` / `fixed` item must keep full `context`, `what`, `when_shows`, `question`, `snippet`, and option labels — never shorten those fields to save tokens before the parent merge. The orchestrator must merge those fields **verbatim** into the report and into each sequential clarify question. Enforce file/LOC caps via chunking; abort on catastrophic budgets instead of unbounded chunk fan-out.

`learned_hints` in orchestrator context: ≤**~200 tokens** total (≤5 rows). Quality lives in the phase that opens `checklist` on a match.

When [graphify-protocol.md](references/graphify-protocol.md) detects a usable build, **prefer** short `GRAPH_REPORT.md` excerpts and `graphify query` answers over broad repo reads. Never paste full `graph.json`.
