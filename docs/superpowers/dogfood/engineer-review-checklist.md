# Engineer-review dogfood fixture

Manual checklist to verify the kit behaves. Do not require CI to execute agents.

## Setup

1. From kit root:

```bash
chmod +x scripts/*.sh
./scripts/install-to-project.sh --agree-policy /tmp/er-dogfood --hooks --rule
# or create a tiny git repo and point the script at it
bash scripts/tests/developer-reviewer-handoff-test.sh   # parent wait + next_skill contract
bash scripts/tests/code-comments-test.sh                # no design-tied comments, including backend
bash scripts/tests/clarify-question-evidence-test.sh    # clarify questions include file + snippet
bash scripts/tests/pipeline-flow-graph-test.sh          # canvas layers + review-gate naming
bash scripts/tests/review-surface-test.sh               # finish-plan surfaces diff before HITL; not create-pr
bash scripts/tests/security-hardening-checklist-test.sh # S1–S11 shared by security phase + writers
bash scripts/tests/shared-writer-reviewer-gates-test.sh # JPA / Criteria checklists shared by logic phase + writers
bash scripts/tests/engineer-review-context-budget-test.sh  # orch must not load checklist bodies; security opens full S1–S11
```

2. In the consumer repo, add a deliberate smell file, e.g. `src/smells.ts`:

```ts
import { readFileSync } from "fs"; // unused after edit — leave unused import

export function greet(name: string) {
  // previously returned Hello, now we return Hi (historical comment — should be removed)
  return `Hi, ${name}`;
}

export function unusedHelper() {
  return 1;
}
```

And a used import of `greet` from another file so only the unused import / historical comment / unused export are the targets.

3. Add a deliberate **mechanical lint smell** the project's own `eslint` config would catch on its own (e.g. an `import` statement placed after other statements in the module body, which trips `eslint import/first` — "Import in body of module; reorder to top."). This is a regression fixture: a real heuristic-phase miss that motivated adding `csp-review-lint`.

```ts
export const feature = "enabled";

import { helper } from "./helper"; // eslint: import/first — placed after a statement
```

4. Optional **simplify smell** (kit extension): a strategy/plugin wrapper or always-true flag not justified by any plan/AC in the fixture — `csp-review-simplify` should clarify, not silent-apply.
## Expected review behavior

| Step | Expect |
|------|--------|
| `/csp-finish-plan` after fake plan | Creates `.cursor/gates/review-gate/<slug>`, asks HITL |
| After `csp-software-developer` Task returns | Parent (`start-build` / `/csp-start-task`) invokes `finish-plan` (full) or `csp-engineer-reviewer` (`--fast`); nested Task does not `AskQuestion` |
| User `skip` | Starts engineer-reviewer; deletes marker |
| Frontend stack | Asks for Figma URLs or `no figma` early |
| Figma URLs pasted | `csp-review-figma-markup` loads [figma-markup-checklist.md](../../../skills/engineer-review/references/figma-markup-checklist.md) **F1–F7**; Coverage `figma_markup: compared` (or `source-only` if no browser); token/structure/empty-placeholder misses are `P1` clarify, not Residual nits |
| Diff touches auth / queries / uploads / secrets / XSS–SSRF sinks | `csp-review-security` opens [security-hardening-checklist.md](../../../skills/engineer-review/references/security-hardening-checklist.md) **S1–S11** (triggers alone are not enough); `csp-software-developer` / `csp-bug-fixer` load the same file when writing those surfaces; missing third-party `security-review` is not a skip |
| First run | Creates `.cursor/project-patterns.md` |
| `lint` phase (runs first) | Runs the project's real `eslint`/`tsc`; flags `import/first` as `P1` unambiguous and auto-fixes it with `eslint --fix` — this must not depend on any heuristic phase noticing it |
| deadcode phase | Flags unused import + historical comment as `P1` unambiguous; unused export may clarify if unsure of public API |
| simplify phase | Loads `ce-simplify-code` personas (or notes `skill_missing`) + **Kit extensions**; flags workable-but-poor solutions (YAGNI vs plan, alternate approach, error-handling theater, etc.) mostly as `clarify` |
| Lint verify pass | After the apply step, `csp-review-lint` re-runs once; report shows no remaining lint findings |
| Simplify quality verify | After apply, `csp-review-simplify` re-runs once in `find` over the final diff; new leftovers go to clarify/residual |
| Fixed now | Lists applied P0/P1 fixes, including the `lint` phase's `import/first` fix |
| Needs clarification | Separate from Fixed now |
| `P2` nits | Residual only |
| Large synthetic diff (>40 files) | Coverage mentions chunking |
| Catastrophic diff (>200 files or >50k LOC) | Orchestrator aborts before phase spam; asks to narrow scope |
| No lint config in fixture repo | `lint` phase reports `skipped: true` / `no_lint_config` in Coverage instead of silently disappearing |
| Auth/session clarify that picks sync `resetApiState` | Logic + architecture re-dispatched with R1 `interaction_replay`; Coverage shows `interaction_replay: auth` (or `both`); must name live competing shell subscriptions before closing |
| Overlay/filter clarify that keeps filter-in-menu | Logic + architecture check **R4** (host focus/remount); Coverage `interaction_replay: overlay-focus` (or `both`); competing-actor note or test for typing N chars |
| Table / expandable card / dialog in a frontend diff | Figma and/or patterns run **V1–V4**; Coverage `narrow_viewport: tablet+phone` (or `source-only` if no browser); desktop Figma frame alone is not enough |
| P0 correctness finding settled | Does **not** auto-write `.cursor/review-learnings.md`. HITL **Teach-review miss** still runs |
| Next review with matching triggers | `csp-review-learn` `mode:load` returns hints from kit seed + local ledger if present; orchestrator stays thin; matching phases **open** linked checklist (not one-liner-only) |
| Human chose `project_secret` | `csp-review-learn` `mode:capture` appends or dedupes; Coverage `review_learn: appended\|deduped`; no **Review-learn promote** |
| Clarify HITL (`C#`) | Each AskQuestion repeats Context, What, When it shows up, File, Lines, Jump, and the numbered fence from that item — not title-only; never a batch letter list as the ask |
| Phase → parent handoff | Each phase Task returns full clarify phase JSON (`context`, `what`, `when_shows`, `question`, `snippet`, options) — not a short private note that stays inside the subagent |
| Validated report shown | HITL **Teach-review miss**; `no_miss` writes nothing; `miss` + description runs `teach-review`; `project_secret` writes this project only |
| Pipeline miss handled (`no_miss` / teach land / `project_secret`) | Next user-visible gate is **Propose commit** with orientation strip — not a silent end after the teach land report |

## Patterns CI helper

```bash
BASE_REF=HEAD~1 ./scripts/check-project-patterns.sh --strict
```

With src changes and no `.cursor/project-patterns.md` → exit 1 in strict mode.

## Hook reminder

With marker present, agent `stop` should receive followup reminding HITL (does not auto-start review).
