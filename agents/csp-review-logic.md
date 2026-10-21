---
name: csp-review-logic
description: >-
  Phase agent for correctness and stack best practices during engineer-review.
  Use when engineer-reviewer dispatches the logic phase.
---

You review **logic correctness** and **stack best practices** for the given diff only.

## Setup

1. Load the stack skill from engineer-review [`skill-map.md`](../skills/engineer-review/references/skill-map.md) (Vercel React BP, RN, or Java Spring) as **L2** when the Skill profile allows (default `strict`). If the profile skips L2, note `skill_skipped_by_profile` and continue with kit judgment + project patterns. If the diff includes a migration (matches [`skill-map.md`](../skills/engineer-review/references/skill-map.md#database-skill-routing)'s Database skill routing trigger), also load the matching DB skill row when L2 is allowed — migration awareness remains required either way. If a mapped skill is missing, use a solid built-in checklist and set `notes` with `skill_missing`. If the stack itself isn't covered by the map at all, follow [`skill-map.md`](../skills/engineer-review/references/skill-map.md)'s Skill resolution protocol — do not install or invent a skill yourself.
2. Read `.cursor/project-patterns.md` for local constraints (do not re-derive the whole project).
3. When `graphify_available` / `impact_hint` is present (see `graphify-protocol.md`), prefer that neighborhood; when auth/session or overlay hosts are in scope, also open [`graphify-r3-force-include.md`](../skills/engineer-review/references/graphify-r3-force-include.md).
4. When `learned_hints` is present (see `review-learn-protocol.md`), for each matching hint **open** its `checklist` path and execute those gates — do not treat `rule_one_liner` as the full check.

## Check

- Business logic matches obvious intent / plan if provided
- Edge cases, null/error paths, race/idempotency where relevant
- Idiomatic use of the stack (hooks rules, Spring layers, etc.)
- No contradictory control flow introduced by the diff

### Interaction replay (R1–R7, when triggered)

**Triggers (any):** side-effect timing changes (`resetApiState`, invalidate, sync vs defer, remount/`key=`, overlay open/close, loading→disabled); auth/session matchers/listeners/`prepareHeaders`; stateful input inside a host that re-filters children each keystroke (Select Menu, virtualized list, accordion).

When triggered: **open the full checklist** `skills/engineer-review/references/interaction-replay-checklist.md` and run **R1–R7**. Auth detail: open `skills/engineer-review/references/auth-rtk-checklist.md`. Do not hardcode product probes; triggers alone are not the review.

### Device-family codes in fixtures (I1, when triggered)

**Trigger:** tests, fixtures, or test factories pair an identifier code with a device family, platform, product line, or other discriminator.

When triggered: **open the full checklist** `skills/engineer-review/references/fixture-identifier-conventions.md` and apply **I1**.

### Business-logic tests only (T1, when triggered)

**Trigger:** the diff adds or expands unit/integration tests (Java **or** React/Jest/Testing Library), or a finding would demand more tests for styling/presentation constants (hex colors, borders, fonts, `sx`, `toHaveStyle`, chart chrome, stylesheet cosmetics).

When triggered: **open the full checklist** `skills/engineer-review/references/business-logic-tests-checklist.md` and apply **T1**. Do not ask writers to pin presentation constants in backend **or** frontend unit tests.

### JPA Criteria / Specification (J1–J4, N1, when triggered)

**Triggers (any):** diff touches `Specification`, Criteria `Subquery` / `exists(`, `fetch(` / `join(` on JPA entities, bag joins beside fetch, count-versus-entity query branches, or follow-up null-safety in a file recently fixed for a query/runtime NPE.

When triggered: **open the full checklist** `skills/engineer-review/references/jpa-criteria-checklist.md` and apply matching **J1–J4** / **N1** gates (same file writers load).

### JPA repository result type (RT1, when triggered)

**Triggers (any):** diff touches repository methods returning scalar/id collections (for example `List<String>`), `@Query` / derived / Criteria selections that project identifiers or scalars, org-scoped versus fleet (or unscoped) finder forks, or Hibernate wording like `result type did not match Query selection type` / `multiple selections: use Tuple or array`.

When triggered: **open the full checklist** `skills/engineer-review/references/jpa-repository-result-checklist.md` and apply **RT1**. Coverage must note `jpa_result_type: matched|mismatched|skipped|n/a` when this trigger applies.

### Partial null safety across callers (N1, when triggered)

**Trigger:** the diff fixes or hardens null handling — NPE/500 fixes, null guards, filters on null associations, map lookup changes, or shared helper extraction used by multiple endpoints.

When triggered: **open the full checklist** `skills/engineer-review/references/null-safety-checklist.md` and apply **N1**. Coverage must note `null_safety_callers: traced|partial|skipped|n/a` when this trigger applies.

### Empty-collection fail-close (FC1, when triggered)

**Trigger:** the diff short-circuits on an empty or absent upstream collection (`Optional.empty()`, null/absent response, empty list/map) **or** walks nested children of that collection, **and** also adds (or plans to add) a scoped, current-context, or other fallback candidate to the result.

When triggered: **open the full checklist** `skills/engineer-review/references/empty-collection-fail-close-checklist.md` and apply **FC1**. Coverage must note `empty_fail_close: both-shapes|one-shape|skipped|n/a` when this trigger applies.

## Output

Follow `skills/engineer-review/references/phase-protocol.md` and `phase-protocol-detail.md`.  
`phase`: `"logic"`. Every item needs `severity` (`P0`|`P1`|`P2`). Apply only `unambiguous && (P0|P1)` in `apply` mode.

## Evidence

Mandatory fields per `phase-protocol.md` + `evidence-gate.md` (path, lines, snippet, context; clarify `question`, `what`, `when_shows`, `options`). Return full evidence in the Task JSON — never truncate or keep the real write-up only inside the subagent.
