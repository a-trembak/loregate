# Pipeline Run Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each consumer repository a short on-disk pipeline run journal (not chat memory in the Spells kit) so agents and humans can recover stage/decision orientation after context loss, alongside existing gate markers and session ledgers.

**Architecture:** Bash helper `scripts/pipeline-run-log.sh` writes append-only journals under `.cursor/gates/run-log/` (`inv-<id>.md`, promote to `<slug>.md` only when the slug file is absent). `init` also writes `current-invocation` pointer. Fast / tiny runs use the inv journal plus an optional short brief — never a fake implementation plan or chat transcript dump. `pipeline-status.sh` enriches orientation via `--invocation` → pending plan slug → pointer → omit. Gates + trajectory ledgers remain authoritative for stage and scoring.

**Tech Stack:** Bash (sourcing `pipeline-gates.sh`, `flock`), Cursor skill/command markdown, shell contract tests, static docs.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-21-pipeline-run-memory-tech-spec.md` (Status: approved) — this revision is current truth after critique debate.
- Design: `docs/superpowers/specs/2026-09-21-pipeline-run-memory-system-design.md` (Status: merged); where this plan/spec disagree with older merge-on-promote text, **this plan + tech-spec win**.
- Runtime state only under the **consumer** project root.
- No kit-global conversation / vector memory (AC4). No chat transcript dumps in journals or briefs.
- Run-log never overrides `stage` / `layer`; never clears foreign gates.
- `--note` hard max **120 Unicode characters**; duplicate last `stage=`+`note=` skipped; writers use `flock` (missing `flock` → fail writes, reads still ok).
- **Promote:** target absent → `mv` + header refresh; target exists → **refuse-on-conflict** (exit non-zero, leave `inv-*.md` intact, no merge); I/O failure → leave source intact (test with a real mid-promote failure fixture, not missing `--plan`).
- **init:** refuse if `inv-<id>.md` exists unless `--reset`; always refresh `current-invocation` pointer on successful init.
- Helper path precedence: `--plan` when present for slug resolution after successful promote; else `--invocation`. Status enrichment order: `--invocation` → pending-gate plan slug → pointer → omit.
- Dual-write **allowlist only** (see File Structure / Task 3). Fast path: no required promote; optional `brief-upsert`.
- User-facing chat: skill `plain-language-chat`.
- Feature branch: `cursor/<descriptive-name>-c48a`. Nested fences: 4-backtick outer when embedding ```.
- After critique clear: nested Task `csp-software-developer` via `start-build`. Product commits only via `propose-commit` after engineer-review.

---

## File Structure

| Path | Responsibility |
|------|----------------|
| `scripts/pipeline-run-log.sh` | `init` / `append` / `promote` / `read-tail` / `path` / `brief-upsert` |
| `scripts/tests/pipeline-run-log-test.sh` | Isolation, refuse-on-conflict, real promote failure, Unicode note, re-init, pointer |
| `scripts/pipeline-status.sh` | `--invocation`; `run_log_path` / `run_log_tail`; pointer fallback |
| `scripts/tests/pipeline-status-test.sh` | Enrichment order; stage unchanged when journal missing |
| `scripts/install-to-project.sh` | Copy helper + gitignore recommendation |
| `skills/pipeline-status/SKILL.md` | Recent line + pass `--invocation` when known |
| `skills/hitl-choice/SKILL.md` | Append after token; pass invocation into status |
| `commands/csp-start-task.md` | Mint id, `init`, append, promote, optional brief on fast |
| `commands/csp-start-issue-task.md` | Same |
| `skills/tech-spec/SKILL.md` | Dual-write append at ledger stops |
| `skills/approve-plan/SKILL.md` | Promote when plan known (handle refuse); append |
| `skills/finish-plan/SKILL.md` | Append at review-gate |
| `skills/propose-commit/SKILL.md` | Append at commit gate |
| `skills/create-pr/SKILL.md` | Append at finale |
| `docs/superpowers/pipeline-flow.md` | Run-log / pointer / brief / refuse-on-conflict |
| `docs/superpowers/dogfood/pipeline-run-memory-checklist.md` | Manual dogfood |
| `README.md` | Short blurb |
| `scripts/tests/pipeline-run-log-wiring-test.sh` | Allowlist + installer greps |

---

### Task 1: Helper library + shell tests (TDD)

**Files:**
- Create: `scripts/pipeline-run-log.sh`
- Create: `scripts/tests/pipeline-run-log-test.sh`
- Modify: `scripts/install-to-project.sh`

**Interfaces:** CLI exactly as tech-spec §3.

- [x] **Step 1: Write failing tests** covering at least:
  - `init` B does not clear A’s `inv-*.md`
  - `init` writes `current-invocation` pointer
  - re-`init` same id without `--reset` refuses; with `--reset` rewrites only that file
  - promote when target absent (`mv` + header `plan` / `slug`)
  - promote when target exists → **non-zero**, source still present, target body unchanged (refuse-on-conflict)
  - promote **I/O failure** with source present and `--plan` set (e.g. target directory not writable) → source still readable; do **not** use “missing `--plan`” as the failure stand-in
  - `flock` serialization smoke; if `flock` absent in fixture, write path exits non-zero
  - duplicate stage+note skip
  - `--note` truncation at 120 **Unicode** characters (multi-byte fixture)
  - `brief-upsert` creates capped brief under `briefs/`

- [x] **Step 2: Implement helper until tests pass**

- [x] **Step 3: Installer copy + gitignore recommendation print**

- [x] **Step 4: Run** `bash scripts/tests/pipeline-run-log-test.sh` — `ALL PASS`

---

### Task 2: Status enrichment

**Files:**
- Modify: `scripts/pipeline-status.sh`, `scripts/tests/pipeline-status-test.sh`, `skills/pipeline-status/SKILL.md`

**Behavior:**
- Add `--invocation <id>`
- JSON: `run_log_path`, `run_log_tail` (default last 5 body lines)
- Resolve: `--invocation` → pending-gate plan slug → `current-invocation` pointer → omit
- Optional `Recent: <last note>`; missing journal never changes `stage` / `layer`

- [x] **Step 1: Extend status tests** (flag path, pointer path, omit, stage unchanged)
- [x] **Step 2: Implement enrichment**
- [x] **Step 3: Skill text**
- [x] **Step 4: Run status + run-log tests**

---

### Task 3: Allowlisted skill / command wire-ups

**Files:** exactly the allowlist in the File Structure table (start-task, start-issue-task, tech-spec, approve-plan, finish-plan, hitl-choice, propose-commit, create-pr) + `scripts/tests/pipeline-run-log-wiring-test.sh`

**Behavior:**
- Bootstrap: mint id → `init` (pointer + journal)
- Dual-write `append` only on allowlisted ledger stops
- Promote when plan path first known; on refuse-on-conflict: one-sentence skip, keep using `--invocation`
- Fast / tiny / no formal plan: optional `brief-upsert`; **do not** require promote or invent `docs/**/plans` artifacts
- Forbidden in notes/briefs: chat transcripts, full ticket bodies

- [x] **Step 1: Wiring greps** for helper name, `invocation_id`, `promote`, `brief-upsert`, allowlist paths
- [x] **Step 2: Edit spines**
- [x] **Step 3: Run wiring + helper + status tests**

---

### Task 4: Docs + dogfood

**Files:**
- Modify: `docs/superpowers/pipeline-flow.md`, `README.md`
- Create: `docs/superpowers/dogfood/pipeline-run-memory-checklist.md`

- [x] **Step 1: Document** consumer paths, pointer, brief, refuse-on-conflict, authority split, gitignore, no chat memory in kit
- [x] **Step 2: Dogfood** — two invocations; promote absent OK; promote conflict refuses; status via `--invocation` and pointer; fast path brief without plan; missing helper skip
- [x] **Step 3: Run full related suite** below

---

## Verification

```bash
bash scripts/tests/pipeline-run-log-test.sh
bash scripts/tests/pipeline-run-log-wiring-test.sh
bash scripts/tests/pipeline-status-test.sh
bash scripts/tests/pipeline-status-wiring-test.sh
```

## Out of scope

- Soft truncate / archival of orphan `inv-*.md`
- Newest-`inv-*`-by-mtime guessing
- `promote --force-merge` (revisit after dogfood)
- Vector / embedding chat memory
- Changing trajectory ledger schema beyond additive orientation
- Auto-committing journals into product git
