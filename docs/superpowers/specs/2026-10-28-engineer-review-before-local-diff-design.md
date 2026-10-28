# Engineer Review before Local Diff (pipeline Loop)

## Status

`approved` — human reviewed; implementation plan `docs/superpowers/plans/2026-10-28-engineer-review-before-local-diff.md`.

## Goal

On the Loregate quality pipeline, automated engineer-review runs before the human Local Diff Review. Human comments re-enter a Loop: apply fixes → engineer-review again → Local Diff again, until every dirty repo is `approve-diff` (green). Only then does the pipeline propose a commit.

Success: after implementation, a full-path run never opens the Local Diff Review canvas before the first engineer-review; after Teach-review miss, Local Diff is the human look; any comment path restarts engineer-review before another Local Diff; `approve-diff` is the only happy-path exit to `propose-commit`.

## Pipeline order (full path)

1. Plan work finishes → skill `finish-plan`.
2. Review-surface: check out feature branches / `SetActiveBranch` so merge-base tabs work. **Do not** build the Local Diff Review canvas at this gate.
3. Thin human gate (skill `hitl-choice` preset **Finish-plan / engineer-review / multi-repo HITL**):
   - `skip` / `approve` / `done` — start engineer-review (or multi-repo supervisor).
   - `fixes` (typed notes) — `csp-software-developer` applies fixes, re-run review-surface without canvas, re-ask this gate.
4. Engineer-review (or `csp-multi-repo-supervisor`) → Needs clarification as today → Teach-review miss as today.
5. Skill `local-diff-review-gate` — primary human look at dirty working-tree / staged changes.
6. Loop until green:
   - `approve-diff` per dirty repo → continue.
   - `comment` / canvas outbound apply-fixes → apply via `csp-software-developer` → return to step 4 (full engineer-review + miss as needed) → step 5 again.
7. After all dirty repos are `approve-diff` (or skipped clean / missing plugin) → `propose-commit` → `update-docs` → residual Local Diff + Loop if docs left the tree dirty → residual `propose-commit` → `create-pr`.

```text
finish-plan (thin HITL, no canvas)
    → engineer-review (+ miss)
    → local-diff-review-gate
         ├─ approve-diff → propose-commit …
         └─ comment → developer fixes → engineer-review (+ miss) → local-diff-review-gate …
```

## Fast and issue paths

`/lgt-start-task --fast` and `/lgt-start-issue-task` skip the `finish-plan` review-gate. They still run engineer-review, then `local-diff-review-gate`, then `propose-commit`. The Loop rule in step 6 applies the same way: comments restart engineer-review; they do not walk straight to `propose-commit`.

Manual `/lgt-engineer-review`, `/lgt-pr-review`, and bare `/lgt-multi-review` do not auto-start Local Diff or the Loop unless the human asks.

## Component behavior

### `finish-plan`

- Writes and clears `.cursor/gates/review-gate/<slug>` as today.
- Applies review-surface (branch checkout / `SetActiveBranch`).
- Does **not** invoke plugin `review-local-diff` / build Local Diff canvas on this gate.
- Prompt states this gate starts engineer-review; the human’s full diff look is Local Diff after review.
- Tokens unchanged: `skip` / `approve` / `done` / `fixes`.
- Escape `no-local-diff-review` is irrelevant here (no canvas). Keep it documented only for `local-diff-review-gate` / residual paths that still use the plugin.

### `local-diff-review-gate`

- Remains pipeline-only, after Teach-review miss, before each `propose-commit` while the tree is dirty (and again for residual docs).
- HITL tokens stay `approve-diff` / `comment`.
- On `comment`: build canvas via plugin script, wait for paste/Send in this thread, apply comments without commit/push/PR.
- After applying comments: signal the **caller** that engineer-review must re-run (Loop). Do **not** treat a second `comment` as permission to continue to `propose-commit`.
- Green exit: `approve-diff` (or skip clean tree / skip missing plugin with run-log note).
- No artificial comment-round cap — Loop ends only on human `approve-diff` (or explicit human stop in chat).

### `engineer-review` / multi-repo supervisor (pipeline handoff)

- After miss settles: invoke `local-diff-review-gate`.
- If the gate reports Loop restart (comments applied): re-dispatch engineer-review (same routing / Figma clarifications rules), then miss again if the pipeline path requires it, then `local-diff-review-gate` again.
- Only after green Local Diff: invoke `propose-commit`.
- Never ask `approve-commit` immediately after `no_miss`.

### Docs and presets

Update so diagrams and gate copy match this order:

- `docs/superpowers/pipeline-flow.md` (+ HTML canvas source of truth for overview arrows)
- `skills/finish-plan/references/review-surface.md`
- `skills/finish-plan/references/local-diff-review.md` (point human canvas use at post-review gate; finish-plan no longer prefers canvas)
- `skills/hitl-choice/references/presets.md` (Finish-plan prompt meaning; Local Diff gate Loop; Teach-review miss “what comes next”)
- Agent pointers that still say human look then engineer-review (for example `csp-multi-repo-supervisor` pipeline handoff text)

### Harness / contracts

Extend or add shell tests that lock:

- finish-plan / review-surface text: no mandatory Local Diff canvas before engineer-review
- engineer-review step order: miss → local-diff → (Loop) → propose-commit
- local-diff-review-gate: comment path requires engineer-review restart (not “second comment then continue”)

## Edge cases

| Case | Behavior |
|------|----------|
| Clean tree after review | Skip Local Diff quietly; run-log `skipped-clean`; proceed to propose-commit |
| Plugin missing | One sentence to human; run-log `skipped-missing-plugin`; proceed (no invented canvas) |
| Residual docs dirty | Local Diff + same Loop before residual propose-commit |
| Multi-repo dirty map | One repo at a time in gate; any comment on a repo restarts engineer-review for the pipeline handoff (supervisor or single-repo as routing dictates) |
| Agent “tired of looping” | Forbidden — only human `approve-diff` or explicit stop ends Loop |

## Out of scope (follow-up branch)

Live green/red pipeline tree UI for Agent Window:

- Prefer a **Cursor/VS Code extension Webview panel** (plus optional status-bar chip) that polls `pipeline-status.sh --json` and on-disk gates/run-log **without** agent turns — zero model tokens for UI refresh.
- Reject Canvas-as-status for this follow-up: canvas work usually burns agent tokens.
- Native macOS menu bar outside Cursor is optional later, not required for Agent Window.
- Existing `extensions/context-spend-status/` may be extended or paired; this reorder design does not implement that UI.

## Rejected alternatives

- **Human Local Diff before engineer-review (canvas on finish-plan)** — rejected: human looks at code the automated review has not yet cleaned; desired order is engineer-review first.
- **Thin finish-plan gate without `fixes`** — rejected: human may still want a short fix pass before the first engineer-review.
- **Auto-start engineer-review with no finish-plan HITL** — rejected: human wants an explicit “start review” confirmation.
- **One re-run of engineer-review after comments then force propose-commit** — rejected: Loop must stay red until `approve-diff`.
- **Numeric agent loop cap** — rejected: green exit is human-owned; cap would smuggle unreviewed fixes into commit.

## Test plan

- Unit/harness: assert finish-plan / review-surface forbid pre-review Local Diff canvas; assert local-diff comment → engineer-review restart contract; assert pipeline-flow / skill text mentions Loop until `approve-diff`.
- Manual dogfood (consumer or kit checklist): full path after build → thin gate → engineer-review → Local Diff → leave a comment → confirm engineer-review runs again → `approve-diff` → propose-commit appears only then.
- Fast path dogfood: same Loop after engineer-review without finish-plan gate.
