# Engineer Review before Local Diff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put engineer-review before the human Local Diff Review on the Loregate pipeline, and Loop (fixes → engineer-review → Local Diff) until every dirty repo is `approve-diff`.

**Architecture:** Thin `finish-plan` keeps branch checkout + HITL (`skip` / `approve` / `done` / `fixes`) but never builds the Local Diff canvas. After Teach-review miss, `local-diff-review-gate` owns the canvas; on comments it returns `next_skill: engineer-review` so the caller re-runs review + miss + Local Diff. Docs, presets, rules, hooks, and harness greps lock the new order.

**Tech Stack:** Kit Markdown skills/commands/rules/hooks, bash contract tests under `scripts/tests/`, `docs/superpowers/pipeline-flow.md` + `pipeline-flow.html`.

**Spec:** `docs/superpowers/specs/2026-10-28-engineer-review-before-local-diff-design.md`

## Global Constraints

- Full path: thin `finish-plan` HITL → engineer-review → Teach-review miss → `local-diff-review-gate` → (Loop) → `propose-commit` → docs → residual Local Diff Loop → `create-pr`.
- Fast / issue: skip `finish-plan` review-gate; same Loop after engineer-review.
- Local Diff canvas is **not** built on `finish-plan` / review-gate.
- Finish-plan tokens stay `skip` / `approve` / `done` / `fixes` (typed fixes only at that gate).
- Comment on Local Diff → `csp-software-developer` → `next_skill: engineer-review` (no “second comment then continue to propose-commit”).
- Green exit only: `approve-diff` (or `skipped-clean` / `skipped-missing-plugin`).
- No numeric agent Loop cap; no zero-token status Webview in this plan (follow-up branch).
- Kit checkout: edit files in the parent chat; do **not** run `/lgt-start-task` on this repo.
- User-facing chat follows `plain-language-chat` when talking to humans; kit docs stay English.

## File map

| Path | Responsibility |
|------|----------------|
| `scripts/tests/review-surface-test.sh` | Assert finish-plan has **no** pre-review Local Diff canvas; still requires review-surface checkout |
| `scripts/tests/local-diff-review-gate-test.sh` | Assert Loop return `next_skill: engineer-review`; forbid second-comment-continue |
| `skills/finish-plan/SKILL.md` | Thin HITL; no canvas build |
| `skills/finish-plan/references/review-surface.md` | Checkout / SetActiveBranch only; no prefer-canvas |
| `skills/finish-plan/references/local-diff-review.md` | Protocol for **post-review** gate only |
| `commands/lgt-finish-plan.md` | Match thin finish-plan |
| `rules/after-plan-review-gate.mdc` | No Local Diff before engineer-review |
| `hooks/post-plan-review-gate.sh` | Followup text: start review, not canvas-first look |
| `skills/local-diff-review-gate/SKILL.md` | Comment → apply → return engineer-review Loop |
| `skills/hitl-choice/references/presets.md` | Finish-plan + Local Diff + Teach-review miss copy |
| `skills/engineer-review/SKILL.md` | Step 15 Loop on `next_skill: engineer-review` |
| `agents/csp-engineer-reviewer.md` | Same handoff / Loop |
| `agents/csp-multi-repo-supervisor.md` | Same handoff / Loop |
| `docs/superpowers/pipeline-flow.md` | Mermaid + prose order |
| `docs/superpowers/pipeline-flow.html` | Overview + detail views |
| `README.md` | One-line order if it still says human look then engineer-review |
| `skills/propose-commit/SKILL.md` | Precondition: Local Diff settled **green** (not Loop pending) |

---

### Task 1: Contract tests (RED)

**Files:**
- Modify: `scripts/tests/review-surface-test.sh`
- Modify: `scripts/tests/local-diff-review-gate-test.sh`
- Test: same files

**Interfaces:**
- Consumes: existing assert helpers in those scripts
- Produces: failing greps until Tasks 2–5 land

- [ ] **Step 1: Update `review-surface-test.sh` for thin finish-plan**

Replace assertions that require a Local Diff canvas on finish-plan / review-surface with forbids. Keep checkout / SetActiveBranch asserts.

In `scripts/tests/review-surface-test.sh`:

1. Change the file header comment to say review-surface is branch checkout before thin HITL that **starts engineer-review**; Local Diff canvas belongs to `local-diff-review-gate` after review.

2. Replace these asserts (delete old versions if present):

```bash
# finish-plan must NOT build Local Diff canvas before engineer-review
assert_no_grep finish_no_canvas_build "skills/finish-plan/SKILL.md" "review-local-diff|build-canvas"
assert_grep finish_thin_prompt "skills/finish-plan/SKILL.md" "start engineer-review|After you answer, engineer-review"
assert_grep finish_fixes_typed "skills/finish-plan/SKILL.md" "fixes"
assert_no_grep finish_no_outbound_canvas "skills/finish-plan/SKILL.md" "local-diff-review/comments"

assert_no_grep surface_no_prefer_canvas "skills/finish-plan/references/review-surface.md" "Prefer Local Diff Review canvas|prefer Local Diff Review canvas"
assert_grep surface_no_canvas_before_er "skills/finish-plan/references/review-surface.md" "Do not.*Local Diff|not.*build.*canvas|local-diff-review-gate"
assert_grep surface_then_engineer "skills/finish-plan/references/review-surface.md" "engineer-review"

# Protocol doc still exists but is for post-review gate
assert_grep local_diff_when_post "skills/finish-plan/references/local-diff-review.md" "local-diff-review-gate"
assert_no_grep local_diff_not_finish_hitl "skills/finish-plan/references/local-diff-review.md" "before engineer-review|Before engineer-review"

assert_no_grep rule_no_canvas_before "rules/after-plan-review-gate.mdc" "Local Diff Review when available|prefer.*local-diff-review.md for uncommitted"
assert_grep rule_thin "rules/after-plan-review-gate.mdc" "engineer-review starts after you answer|start engineer-review"
assert_no_grep hook_no_canvas "hooks/post-plan-review-gate.sh" "review-local-diff|Local Diff Review canvas"
```

3. Remove or rewrite these **old** asserts so they no longer require canvas on finish-plan (delete the lines if they conflict):

- `finish_skill_local_diff` requiring `local-diff-review.md` **only if** finish-plan still links the protocol file — if the skill drops the link, assert the protocol file from `local-diff-review-gate` instead and drop `finish_skill_local_diff` / `finish_cmd_local_diff`.
- `finish_outbound_fixes` requiring `local-diff-review/comments` on finish-plan — **delete**.
- `surface_prefer_local_diff` — **delete** (replaced by `surface_no_prefer_canvas` / `surface_no_canvas_before_er`).
- `rule_local_diff` / `hook_local_diff` requiring Local Diff on review-gate — **delete** (replaced by forbids above).
- Keep `flow_md_local_diff` / `flow_html_local_diff` / `readme_local_diff` / `start_task_local_diff` — those may still mention Local Diff for the **post-review** gate.

- [ ] **Step 2: Update `local-diff-review-gate-test.sh` for Loop**

Append (and remove conflicting “second comment then continue” expectations if any):

```bash
assert_grep gate_loop_return "skills/local-diff-review-gate/SKILL.md" "next_skill: engineer-review"
assert_grep gate_green_return "skills/local-diff-review-gate/SKILL.md" "next_skill: propose-commit"
assert_no_grep gate_no_second_continue "skills/local-diff-review-gate/SKILL.md" "do not loop further|second answer is \`comment\` again.*continue"
assert_grep gate_apply_dev "skills/local-diff-review-gate/SKILL.md" "csp-software-developer"
assert_grep er_loop "skills/engineer-review/SKILL.md" "next_skill: engineer-review|Loop"
assert_grep er_loop_miss "skills/engineer-review/SKILL.md" "local-diff-review-gate.*engineer-review|re-dispatch|again"
assert_grep multi_loop "agents/csp-multi-repo-supervisor.md" "next_skill: engineer-review|Loop"
assert_grep hitl_loop "skills/hitl-choice/references/presets.md" "engineer-review|Loop|next_skill: engineer-review"
assert_grep propose_green "skills/propose-commit/SKILL.md" "approve-diff|next_skill: propose-commit|green|Loop"
assert_grep flow_loop "docs/superpowers/pipeline-flow.md" "Loop|next_skill: engineer-review|approve-diff"
assert_grep flow_html_loop "docs/superpowers/pipeline-flow.html" "Loop|local-diff-review-gate.*engineer-review|approve-diff"
```

- [ ] **Step 3: Run tests — expect FAIL**

```bash
bash scripts/tests/review-surface-test.sh
bash scripts/tests/local-diff-review-gate-test.sh
```

Expected: at least one `FAIL` in each script (new greps not yet in skills/docs).

- [ ] **Step 4: Commit**

```bash
git add scripts/tests/review-surface-test.sh scripts/tests/local-diff-review-gate-test.sh
git commit -m "$(cat <<'EOF'
test: lock engineer-review before Local Diff Loop contracts

EOF
)"
```

---

### Task 2: Thin finish-plan (no canvas)

**Files:**
- Modify: `skills/finish-plan/SKILL.md`
- Modify: `skills/finish-plan/references/review-surface.md`
- Modify: `skills/finish-plan/references/local-diff-review.md`
- Modify: `commands/lgt-finish-plan.md`
- Modify: `rules/after-plan-review-gate.mdc`
- Modify: `hooks/post-plan-review-gate.sh`
- Test: `scripts/tests/review-surface-test.sh`

**Interfaces:**
- Consumes: Task 1 failing greps for finish-plan / surface / rule / hook
- Produces: thin gate prose; protocol doc scoped to `local-diff-review-gate`

- [ ] **Step 1: Rewrite finish-plan steps 3–5**

In `skills/finish-plan/SKILL.md`:

- Step 3: apply review-surface (checkout / SetActiveBranch only). Explicit: **Do not** invoke `review-local-diff` or build a Local Diff canvas.
- Step 4 HITL prompt (English kit docs):

```text
Plan done. Feature branches are checked out locally. This gate starts engineer-review — your full Local Diff look comes after that review. Answer:
- skip — start engineer-review now
- approve / done — start engineer-review
- fixes — describe fixes first (typed notes); developer applies them, then this gate is asked again
```

- Remove any instruction to open Local Diff canvas or accept `local-diff-review/comments` outbound at this gate.
- Keep `fixes` → `csp-software-developer` → re-run review-surface → re-ask.
- Keep step 6 routing into engineer-review / multi-repo as today.
- Notes: drop “Escape `no-local-diff-review`” for this skill (canvas not used here). Point readers to `local-diff-review-gate` for canvas escape.

- [ ] **Step 2: Rewrite `review-surface.md`**

Keep checkout / SetActiveBranch / no create-pr / intermediate gate. Replace “Prefer Local Diff Review canvas” with:

```markdown
### No Local Diff canvas here

Do **not** run skill `review-local-diff` or build the Local Diff Review canvas during finish-plan. Human canvas review belongs to skill `local-diff-review-gate` after engineer-review. For zero-ahead / uncommitted trees, the pull request tab may be empty — that is expected; do not paste a full `git diff` unless the human asks. After `skip` / `approve` / `done`, engineer-review runs.
```

Update the closing bullets so they do not say “comment on Local Diff canvas then start engineer-review”.

- [ ] **Step 3: Retarget `local-diff-review.md`**

Change the “When” / intro so this file is the kit protocol for **`local-diff-review-gate`** (and residual docs), **not** finish-plan HITL. Keep payload schema, Current thread, `apply-fixes`, `csp-software-developer`, `no-local-diff-review`, out of scope. Remove “Not for `/lgt-start-task --fast`…” if wrong; state: used after pipeline engineer-review on full / fast / issue; not on bare manual engineer-review unless asked.

- [ ] **Step 4: Align command, rule, hook**

`commands/lgt-finish-plan.md` — same thin prompt; no canvas.

`rules/after-plan-review-gate.mdc` — invoke finish-plan with review-surface only; HITL text matches thin prompt; no “prefer local-diff-review.md for uncommitted”.

`hooks/post-plan-review-gate.sh` — followup_message must mention review-gate / start engineer-review and must **not** mention `review-local-diff` or “Local Diff Review canvas”.

- [ ] **Step 5: Re-run review-surface test (partial green)**

```bash
bash scripts/tests/review-surface-test.sh
```

Expected: finish-plan / surface / rule / hook asserts PASS. Other scripts may still fail.

- [ ] **Step 6: Commit**

```bash
git add skills/finish-plan/SKILL.md skills/finish-plan/references/review-surface.md skills/finish-plan/references/local-diff-review.md commands/lgt-finish-plan.md rules/after-plan-review-gate.mdc hooks/post-plan-review-gate.sh
git commit -m "$(cat <<'EOF'
feat: thin finish-plan gate without Local Diff canvas

EOF
)"
```

---

### Task 3: Local Diff gate Loop return

**Files:**
- Modify: `skills/local-diff-review-gate/SKILL.md`
- Modify: `skills/hitl-choice/references/presets.md` (sections **Local Diff Review gate**, **Finish-plan / engineer-review / multi-repo HITL**, **Teach-review miss**)
- Modify: `skills/propose-commit/SKILL.md` (precondition wording only)
- Test: `scripts/tests/local-diff-review-gate-test.sh`

**Interfaces:**
- Consumes: plugin `review-local-diff` unchanged
- Produces: return contract `next_skill: engineer-review` | `next_skill: propose-commit`

- [ ] **Step 1: Replace comment steps in `local-diff-review-gate`**

Replace current steps 5–7 (including “ask once more” / “second comment then continue”) with:

```markdown
5. On **`approve-diff`:** run-log note `approve-diff`; next repo. When all repos done with only approve-diff / skips → return `next_skill: propose-commit`.

6. On **`comment`:**
   1. Follow plugin skill `review-local-diff`: run `bin/build-canvas.mjs`. Link the canvas.
   2. Tell the human: Prepare for this chat → copy paste block → paste into this thread.
   3. Do not poll `*.canvas.data.json`. End the turn; wait for the human’s reply here.
   4. When they paste `local-diff-review/comments` (or ask to apply local-diff comments), dispatch nested Task `csp-software-developer` with a brief from each `{ path, line?, body }` plus `notes`. Wait for it to return. Refresh canvas via `build-canvas.mjs --refresh --fresh-ui` if useful. Do **not** commit, push, or open a pull request.
   5. Run-log note `comment`.
   6. **Return immediately** to the caller with `next_skill: engineer-review` (pipeline Loop). Do **not** ask `approve-diff` / `comment` again in this turn. Do **not** invoke `propose-commit`.

7. After all repos without a Loop return: return `next_skill: propose-commit` so the caller can invoke propose-commit.
```

Hard rules — add:

```markdown
- Never continue to `propose-commit` after applying Local Diff comments; always return `next_skill: engineer-review`.
- Never use a second-comment “then continue” shortcut; Loop ends only on human `approve-diff` (or skip clean / missing plugin).
```

- [ ] **Step 2: Update HITL presets**

**Finish-plan / engineer-review / multi-repo HITL** — prompt: thin start-review / fixes; state Local Diff comes after engineer-review; remove “If a Local Diff Review canvas is open…” as the primary path.

**Local Diff Review gate** — on `comment`, after apply: caller must re-run engineer-review (not “ask once more then continue”). Green: `approve-diff` → propose-commit path.

**Teach-review miss** — after miss settles: `local-diff-review-gate`; if that returns `next_skill: engineer-review`, caller Loops; `no_miss` still does not authorize propose-commit.

- [ ] **Step 3: Tighten propose-commit precondition**

In `skills/propose-commit/SKILL.md`, state Local Diff Review gate must have returned `next_skill: propose-commit` (all dirty repos `approve-diff` or skipped). Jumping while Loop is pending (`next_skill: engineer-review`) is forbidden.

- [ ] **Step 4: Run gate test (expect remaining FAIL on engineer-review Loop greps)**

```bash
bash scripts/tests/local-diff-review-gate-test.sh
```

- [ ] **Step 5: Commit**

```bash
git add skills/local-diff-review-gate/SKILL.md skills/hitl-choice/references/presets.md skills/propose-commit/SKILL.md
git commit -m "$(cat <<'EOF'
feat: Local Diff comments restart engineer-review Loop

EOF
)"
```

---

### Task 4: Engineer-review / multi-repo Loop handoff

**Files:**
- Modify: `skills/engineer-review/SKILL.md` (step 15)
- Modify: `agents/csp-engineer-reviewer.md`
- Modify: `agents/csp-multi-repo-supervisor.md`
- Test: `scripts/tests/local-diff-review-gate-test.sh`

**Interfaces:**
- Consumes: `local-diff-review-gate` return `next_skill`
- Produces: caller Loop until green then `propose-commit`

- [ ] **Step 1: Expand engineer-review step 15**

Keep miss → `local-diff-review-gate` order. After the gate returns:

```markdown
- If `next_skill: engineer-review`: re-dispatch this review (or `csp-multi-repo-supervisor` when routing says multi-repo) with the same repo set / Figma clarifications rules; then Teach-review miss again; then `local-diff-review-gate` again. Repeat until the gate returns `next_skill: propose-commit`.
- If `next_skill: propose-commit`: invoke skill `propose-commit`, then full-path `update-docs` / residual Local Diff Loop / residual propose-commit / `create-pr`, or fast/issue `create-pr`, as today.
```

Residual after docs: same Loop contract when invoking `local-diff-review-gate` again.

- [ ] **Step 2: Mirror in agents**

`csp-engineer-reviewer.md` and `csp-multi-repo-supervisor.md` pipeline handoff bullets must match step 15 (Loop on `next_skill: engineer-review`; never jump from `no_miss` to `approve-commit`).

- [ ] **Step 3: Run**

```bash
bash scripts/tests/local-diff-review-gate-test.sh
```

Expected: engineer-review / agent Loop greps PASS (flow docs may still FAIL).

- [ ] **Step 4: Commit**

```bash
git add skills/engineer-review/SKILL.md agents/csp-engineer-reviewer.md agents/csp-multi-repo-supervisor.md
git commit -m "$(cat <<'EOF'
feat: pipeline handoff Loops engineer-review after Local Diff comments

EOF
)"
```

---

### Task 5: Pipeline flow docs + README

**Files:**
- Modify: `docs/superpowers/pipeline-flow.md`
- Modify: `docs/superpowers/pipeline-flow.html`
- Modify: `README.md` (only lines that still say human Local Diff before engineer-review)
- Test: `scripts/tests/local-diff-review-gate-test.sh`, `scripts/tests/review-surface-test.sh`, `scripts/tests/pipeline-flow-graph-test.sh`, `scripts/tests/teach-review-contract-test.sh`

**Interfaces:**
- Consumes: Tasks 2–4 behavior as current truth
- Produces: diagrams/prose matching Loop order

- [ ] **Step 1: Update `pipeline-flow.md`**

In layers / review subgraph / section 6 review-gate / section 8–9 handoff:

- `review-gate`: thin HITL; no Local Diff canvas; then engineer-review.
- After miss: `local-diff-review-gate`; dotted Loop arrow `comment` → engineer-review → miss → Local Diff.
- Thick happy path: `approve-diff` → `propose-commit`.
- State machine: `LocalDiffGate --> Reviewing` on comment Loop; `LocalDiffGate --> CommitGate` on approve-diff.
- Remove prose that puts Local Diff canvas inside finish-plan review-surface as the human’s first look.

- [ ] **Step 2: Update `pipeline-flow.html`**

Overview nodes stay, but detail `view-review-gate`: remove “start with the Local Diff Review canvas” as the primary uncommitted path; say canvas is after engineer-review via `local-diff-review-gate`.

Detail for propose-commit / local-diff: document Loop until `approve-diff`.

Add a short Loop note in the engineer-review or local-diff detail view (English).

- [ ] **Step 3: README**

If README still describes finish-plan as “human looks at Local Diff then engineer-review”, rewrite that sentence to thin gate → engineer-review → Local Diff Loop.

- [ ] **Step 4: Run full related harness**

```bash
bash scripts/tests/review-surface-test.sh
bash scripts/tests/local-diff-review-gate-test.sh
bash scripts/tests/pipeline-flow-graph-test.sh
bash scripts/tests/teach-review-contract-test.sh
bash scripts/tests/propose-commit-test.sh
bash scripts/tests/developer-reviewer-handoff-test.sh
```

Expected: `ALL PASS` on each. If teach-review or propose-commit greps fail on old “then propose-commit” wording, adjust presets/skills to still say miss → local-diff → (Loop) → propose-commit without claiming comment continues to propose.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/pipeline-flow.md docs/superpowers/pipeline-flow.html README.md
git commit -m "$(cat <<'EOF'
docs: pipeline flow shows engineer-review before Local Diff Loop

EOF
)"
```

---

### Task 6: Spec status + dogfood note

**Files:**
- Modify: `docs/superpowers/specs/2026-10-28-engineer-review-before-local-diff-design.md` (Status already `approved` if set; ensure plan path is correct)
- Optional: one bullet under `docs/superpowers/dogfood/` only if an existing checklist mentions finish-plan Local Diff order — update that bullet; do not invent a new dogfood doc unless one already covers this path

**Interfaces:**
- Consumes: implemented behavior
- Produces: docs status consistent with shipped plan

- [ ] **Step 1: Confirm spec Status points at this plan path**

- [ ] **Step 2: Grep kit for stale “Local Diff then engineer-review” on finish-plan**

```bash
rg -n "Local Diff Review canvas.*engineer-review|prefer Local Diff Review canvas|your look at the changes — the pipeline is not finished. After you answer, engineer-review" skills commands rules hooks docs/superpowers README.md || true
```

Fix any remaining kit-owned stale lines (not historical specs/plans).

- [ ] **Step 3: Final test sweep**

```bash
bash scripts/tests/review-surface-test.sh && bash scripts/tests/local-diff-review-gate-test.sh && bash scripts/tests/pipeline-flow-graph-test.sh
```

Expected: all `ALL PASS`.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-10-28-engineer-review-before-local-diff-design.md
# plus any stale-line fixes from Step 2
git commit -m "$(cat <<'EOF'
docs: mark engineer-review-before-local-diff spec approved against plan

EOF
)"
```

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Thin finish-plan, no canvas | Task 2 |
| Tokens skip/approve/done/fixes | Task 2 |
| Engineer-review then Local Diff | Tasks 4–5 |
| Comment → developer → engineer-review Loop | Tasks 3–4 |
| approve-diff only green exit | Task 3 |
| Fast/issue same Loop | Task 4 (step 15 already covers those callers) |
| Residual docs Loop | Task 4 |
| Manual engineer-review no auto Local Diff | unchanged; keep asserts in Task 1/3 |
| Harness contracts | Task 1 + 5 |
| Zero-token status UI | out of scope (no task) |

## Placeholder scan

No TBD / “similar to Task N” / “add appropriate tests” without commands. Return token names fixed: `next_skill: engineer-review` and `next_skill: propose-commit`.
