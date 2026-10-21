---
name: bug-fix
description: >-
  Use when fixing a bug from a Jira/issue ticket or a cleared fix plan: find
  root cause before changing code, apply a minimal fix with a regression test,
  verify, then dispatch readonly csp-verifier before handoff. Never patch on
  assumptions — only after debug evidence confirms the causal line. Use from
  /lgt-start-issue-task after implementation-critic Verdict clear, or when asked
  to fix a diagnosed bug. Not for feature work (use software-developer). Invoke
  explicitly — do not auto-start fixes from ambient chat.
disable-model-invocation: true
icon: bug
color: orange
---

# Bug Fix

Implements a **minimal, root-cause fix** from a critiqued-clear fix plan (or an equivalent diagnosed bug brief). Diagnosis-first; **no fixes on assumptions**.

## When to Use

- `/lgt-start-issue-task` after `implementation-critic` yields `Verdict: clear`
- Human asks to implement an already-cleared bug-fix plan
- Not for greenfield features (`csp-software-developer`) and not for writing/critiquing the plan itself

## Entry conditions

1. Fix plan exists (typically `docs/superpowers/plans/YYYY-MM-DD-<jira-key>-fix.md`) **or** the caller passed an equivalent root-cause brief with reproduction steps.
2. For `/lgt-start-issue-task`: `.cursor/gates/plan-critique-clear/<slug>` matches that plan path (critic `Verdict: clear`).
3. Ticket / bug description is available (Jira fields already fetched by the orchestrator, or pasted text).

If a gate is missing: **stop** and name it. Do not code.

## Skill routing (required)

Load when available; note `skill_missing: <id>` and continue on built-in discipline — do not block the run, do not auto-install Tier-2 skills:

| Skill | Role |
|-------|------|
| [debug-evidence-gate.md](references/debug-evidence-gate.md) | **Always load** — E1–E5; no fix without verified evidence |
| `systematic-debugging` | No fix without root-cause investigation |
| `ce-debug` with `mode:pipeline` | Non-interactive diagnosis loop when installed |
| `verification-before-completion` | Evidence before claiming done |
| `code-comments` | Keep/Remove taxonomy; English-only comments; services forbid presentation; React / frontend UI may reference the user interface |
| [`skill-map.md`](../engineer-review/references/skill-map.md) stack (+ DB rows if migrations) | Same mechanical lookup as `csp-software-developer` |
| [security-hardening-checklist.md](../engineer-review/references/security-hardening-checklist.md) (**S1–S11**) | Load when the fix touches Trigger surfaces (auth, queries, uploads, secrets, SSRF/XSS sinks, etc.) — same gates as `csp-review-security`; optional `security-review` enrichment only |

| [jpa-repository-result-checklist.md](../engineer-review/references/jpa-repository-result-checklist.md) (**RT1**) | Load when the defect is result-type mismatch (`result type did not match Query selection type`, `multiple selections: use Tuple or array`) or the fix touches repository methods, `@Query`, projections, or org-scoped versus fleet identifier queries — same file as `csp-review-logic` / `csp-software-developer` |
| [jpa-criteria-checklist.md](../engineer-review/references/jpa-criteria-checklist.md) (**J1–J4**, **N1**) | Load when the fix touches `Specification`, Criteria fetch/join/subquery, bag joins, or count-versus-entity query branches — same file as `csp-review-logic` / `csp-software-developer` |
| `tdd` / project test conventions | Failing test that proves the bug **before** the fix |
| **`graphify-pipeline`** | After root cause: caller/callee queries; after verify: `refresh` per [stages.md](../graphify-pipeline/references/stages.md) |

## Spine

0. **Evidence gate** — follow [debug-evidence-gate.md](references/debug-evidence-gate.md) E1–E5. **Do not skip to step 5** without confirmed evidence for the throwing line.
1. **Branch setup** — follow `skills/software-developer/references/branch-setup.md`. Prefer `fix/<jira-key>-<short-topic>` when a ticket id exists.
2. **Reproduce** — confirm the failure (test, script, or documented steps) in the **same context as production/QA**. If unreproducible: stop and report blockers; **do not guess a fix**.
3. **Root cause** — complete systematic-debugging / `ce-debug mode:pipeline` until the causal chain has **evidence** (stack trace, failing integration test, or debug run). Do not propose a patch before this.
   - When graphify is available: run compact caller/callee queries for the confirmed symbol or file (skill `graphify-pipeline`).
4. **Regression test first** — add or extend a test that fails for the bug and would pass after the fix (prefer real stack/integration over Mockito-only when the bug is runtime/SQL/Hibernate).
5. **Minimal fix** — change only what the **confirmed** root cause requires. No “while I’m here” refactors. No defensive null-check scatter without a proven null site.
6. **Verify** — run the new/updated test plus relevant project lint/test/typecheck (`verification-before-completion`). Keep evidence.
6a. **Independent verifier** — dispatch nested Task **`csp-verifier`** (readonly) with the claim, regression-test name, and checks already run. **Wait for** the report. On Verdict **`blocked`**: fix gaps and re-run `csp-verifier`; do **not** hand off while blocked. On **`implemented but unverified`**: record gaps in the handoff. On **`verified`**: proceed. Never skip this agent to save a turn.
6b. **Graphify refresh** — after verify (and a non-blocked verifier verdict), `graphify-pipeline.sh refresh` per target repo (skip if absent).
7. **Handoff** — return `next_skill: csp-engineer-reviewer`, `repo → branch` map, root-cause summary with **evidence citation** (file:line or test name), verification evidence, `verifier_verdict`, and any `skill_missing` notes. **nested Task:** stop after that block (no `AskQuestion` / `csp-engineer-reviewer` from the Task). Callers **Wait for** the return then run `csp-engineer-reviewer`, then skill **`local-diff-review-gate`**, then skill **`propose-commit`**, then **`create-pr`** (do not skip those for `/lgt-start-issue-task`).
8. **Review-learn on escapes** — if this defect was a **production escape** (or the plan states prior review should have caught it), after the fix is verified invoke agent `csp-review-learn` with `source: production-escape` per `skills/engineer-review/references/review-learn-protocol.md` so the miss class strengthens future reviews. Do not block the fix handoff on HITL promote.

## Hard rules

- **Never fix on assumption.** Hypothesis → verify → then patch. If verification is missing, stop and list blockers.
- **Never stack “likely” fixes** across commits when QA/production still fails — treat prior hypothesis as falsified; re-gather evidence.
- **Never `git commit`** during pipeline fix work. Leave changes uncommitted for skill `propose-commit` after engineer-review. Nested `csp-bug-fixer` / task agents inherit this forbid
- Never expand scope beyond the fix plan / diagnosed bug.
- Never ship a symptom-only patch when the root cause is known and in-repo.
- If Jira/MCP facts conflict with repo evidence: **stop and ask** (HITL via `hitl-choice` when a closed choice exists).
- Never implement on `main` / `master` / the default branch.
- Source-code comments: English only; apply `code-comments`. Services forbid presentation (chart, screen, widget, Figma, user-interface link/example); React / frontend UI may reference the user interface.

## Output

Working tree changes on the feature branch, failing-then-passing regression coverage, verification evidence, `verifier_verdict` from `csp-verifier`, and the handoff fields above.
