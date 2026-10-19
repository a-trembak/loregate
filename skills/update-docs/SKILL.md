---
name: update-docs
description: >-
  Use after engineer-review (or when the human asks to update product docs) to
  ask where documentation should land — skip, docs/ markdown in the current
  repo, a separate docs repository, or Confluence — then write dual-audience
  product docs (user + engineer). Prefer this over dumping the tech spec into
  README or inventing a docs destination.
disable-model-invocation: true
---

# Update Docs

Post-review HITL gate for **product / internal documentation** that a human can read — not the kit's tech-spec or plan files. Destination is always a human choice.

## When to Use

- End of `/lgt-start-task` after engineer-review (or multi-repo-supervisor) finishes
- Human asks to document what just shipped
- Not a substitute for `tech-spec`, `clean-decision-docs`, or `ce-compound` (solutions/learnings) — those stay separate

## Related skills (composition)

| Skill | Role here |
|-------|-----------|
| **`hitl-choice`** | Destination picker (buttons / typed tokens) |
| **`english-humanizer`** | Prose pass on engineer-facing sections |
| **`ce-compound`** (optional, third-party) | Durable *solved-problem* write-ups in `docs/solutions/` — offer only when the session produced a reusable learning, not for ordinary feature docs |
| **`ce-explain`** (optional, third-party) | Visual teaching artifact for the human's own learning — **not** a product-docs destination |
| **`ce-promote`** (optional, third-party) | Launch/announcement copy — different job; do not mix into the product doc body |

Load **`references/writing-guide.md`** before drafting.

## Steps (mandatory order)

1. **Resolve plan path.** Argument, plan referenced in this session, or ask. Required — do not write a bare `pending` line.

2. **Write marker** in the **current project** (not the kit):

   ```bash
   # Prefer (consumer project):
   #   source scripts/pipeline-gates.sh
   #   pg_write_gate "$(pwd)" docs-gate "<plan-path>"
   # Line 1 = plan path (not the word pending)
   ```

3. **Stop.** Ask the HITL gate via skill **`hitl-choice`** (AskQuestion required; text only after failed/missing tool). Preset: **Docs update destination**. Prompt/text fallback:

   > Update product docs for what shipped?
   > - `skip` — no docs this run
   > - `docs_md` — Markdown under `docs/` in the **current** repo
   > - `docs_repo` — separate documentation repository (path/URL next)
   > - `confluence` — Confluence page (space/parent or URL next)

4. Do **not** invent a destination. On picker cancel/skip-without-token, re-ask.

5. **On `skip`:**
   - `pg_clear_gate "$(pwd)" docs-gate "<plan-path>"`. If clear exits non-zero: report the path in one sentence (orientation may stay on docs), then **still** continue the handoff below — do not treat clear failure as end of the pipeline.
   - Report that docs were skipped.
   - **Never treat this skill as terminal** on a full `/lgt-start-task` run.

6. **On `docs_md` | `docs_repo` | `confluence`:**
   - Keep this plan's docs-gate until the write (or explicit human abort) completes. Never delete another slug's docs-gate; HITL **Force-clear foreign gate** first if the human explicitly asks.
   - Collect free-text follow-ups in chat when needed:
     - `docs_repo` → wait for local path or clone URL (+ optional branch / folder)
     - `confluence` → wait for space key + parent page title/id, or a full page URL
     - Optional for any choice: language override, page title, "update existing page X", or a **custom style** for user docs, engineer docs, or both (path/link/paste)
   - **Style resolution (required, especially for `docs_repo` / `confluence`):** before drafting, follow `references/writing-guide.md` → Style resolution. Sample existing sibling docs / Confluence parent pages; prefer (1) human custom style for user and/or engineer, else (2) destination house style, else (3) project style files, else (4) kit default dual-audience skeleton. Never overwrite an established house template with the kit default.
   - Ground content in the shipped change: plan path, tech spec, diff/`gh pr view`, and review outcome already in context. Do not invent user-facing capabilities.
   - Draft to the resolved style (kit default only when nothing stronger applies).
   - Run an `english-humanizer` pass on engineer-facing prose (and on user-facing prose if it drifted into AI filler), without fighting the house voice (terminology and section shape stay as resolved).
   - **Publish** to the chosen destination:
     - `docs_md` — write/update the Markdown file under `docs/` (never under `docs/superpowers/` for product docs). Leave uncommitted for `propose-commit`; do not bypass the gate. Report the path.
     - `docs_repo` — work in the named docs repo; follow its existing doc style. Write/update files on disk only — **leave uncommitted**. Do **not** `git commit`, do **not** open or update a pull request from this skill. Include that docs repo (and its branch) in the handoff `repo_branch_map` so the caller runs residual skill **`propose-commit`** before `create-pr`.
     - `confluence` — use Atlassian/Confluence MCP tools when authenticated; otherwise present the final Markdown for paste and optionally stage a local draft under `docs/` marked as Confluence staging. Match space/sibling page style. Never overwrite an unrelated page.
   - `pg_clear_gate "$(pwd)" docs-gate "<plan-path>"` when the publish step finishes or the human aborts after seeing the draft. If clear exits non-zero: report the path; still continue the handoff.

7. **Handoff (required on pipeline full path):** emit and return control to the caller with:

   ```
   next_skill: propose-commit | create-pr
   plan_path: <path>
   docs_destination: skip | docs_md | docs_repo | confluence
   repo_branch_map:   # extend when docs_repo left dirty files
     - <repo> → <branch>
   ```

   - If intentional files remain uncommitted in **any** touched repo → `next_skill: propose-commit` (residual), then the caller runs `create-pr`.
   - If the tree is clean → `next_skill: create-pr`.
   - Manual `/lgt-update-docs` alone may stop after the report when the human did not ask for ship; on `/lgt-start-task` the **caller must** invoke residual `propose-commit` (when needed) then **`create-pr` in the same chat** — do not end the turn on this skill.

8. **Optional compound learning:** If the run produced a durable debugging/architecture learning worth `docs/solutions/`, briefly offer `ce-compound` as a *separate* follow-up — do not block the product-docs handoff on it.

## Notes

- After publish on the **full** `/lgt-start-task` path: if intentional files remain uncommitted in **any** repo touched (product repo and/or separate docs repo), the caller must run skill **`propose-commit`** again before `create-pr`. This skill must not `git commit` in any repo to bypass the gate (leave files on disk; report paths and extend `repo_branch_map`).
- Manual `/lgt-update-docs` may run without a preceding review; still use the same HITL destination gate.
- This skill never auto-selects Confluence vs repo from heuristics — wrong destination is worse than `skip`.
- Markers live under the consumer gates base (usually `.cursor/gates/<kind>/<slug>`; `pipeline-gates.sh` may use a writable fallback under `~/.cursor/spells-gates/` when the project path is not writable).
- Append session ledger per skill `trajectory-score` (stage `update-docs`, gate `docs-update`). Prefer `LEDGER="$(pg_gates_base "$(pwd)")/trajectory-run/session-full.json"` when the helper is sourced.
- **`pg_write_gate` / `pg_clear_gate` failures are hard signals** — print stderr; never pretend the marker updated. Clear failure must not cancel `next_skill: create-pr` on the full path.