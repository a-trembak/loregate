# Auto-fix eligibility test

Replaces "P0/P1 = auto-apply" as a feel-based severity judgement with a hard test. Applies uniformly across every `engineer-review` phase, the comments policy (`skills/code-comments/`), and traceability checks.

## The test

Auto-fix is allowed only when **all four** hold:

1. **Deterministic check** — backed by a tool result, an explicit quoted spec value, **or a loaded kit/project checklist, skill, or rule that already mandates the fix** — not the agent's free-floating opinion.
2. **Single correct answer** — no reasonable alternative interpretation exists (`2+2=5` → `2+2=4`: there's no "maybe they meant 5"). **A kit or project rule that already states the required fix is a single correct answer** — do not treat "maybe the human prefers otherwise" as a second interpretation.
3. **No information loss** — the fix doesn't remove anything that could carry intent (dynamic usage, a future contract).
4. **Zero blast radius on data or user-facing behavior** — it's syntax/junk/a proven mistake, not business logic.

If any condition fails: `clarify`, never a silent apply — regardless of how "obvious" it looks. Severity (`P0`/`P1`/`P2`) still classifies how important a finding is; this test is the separate, stricter gate for whether it may be applied without asking.

## Rule-mandated answers (never HITL)

When a **loaded** kit checklist/skill/rule **or** consumer project rule already mandates the fix, classify as **Fixed now** / auto-apply (if `P0`/`P1` and the other three conditions hold) — **never** `Needs clarification` and **never** open Engineer-review clarify HITL to reconfirm that policy.

Applies to **every** finding class (comments, patterns, deadcode, simplify, logic, security, lint follow-ups, …), not only comments.

**Anti-pattern:** asking whether comments should be domain-only when `skills/code-comments/` already requires domain-only; asking whether to follow any other checklist/skill/rule the review already loaded; offering Options whose "recommended" choice is literally the rule text.

**Still clarify** when the rule names a goal but the concrete rewrite has multiple shapes that would drop intent (example: presentation-tied comment that also states a data invariant — rewrite shapes differ → existing "No — clarify" row below still applies).

## Worked examples

| Finding | Auto-fix? | Why |
|---|---|---|
| Lint/typecheck/compiler error | Yes | Tool-verified, not an opinion |
| Commented-out code | Yes | Removing it changes nothing about execution |
| Historical/changelog comment | Yes | Pure narrative, carries no behavior information |
| Service / backend comment that only names a screen/chart/Figma, or only cites a user-interface link/example, as the reason | Yes | Same as AI narrative — zero domain information; frontend presentation comments are out of scope for this auto-remove |
| Service / backend comment that names a screen/chart/Figma (or cites a user-interface link/example) and also states a data invariant | No — clarify | Rewrite has many shapes; deleting would lose the invariant (fails 2 and 3) |
| Statically-confirmed unused import/export (no reflection/DI path) | Yes | Deterministically proven unused |
| Diff contradicts an explicit spec value/formula | Yes | Spec gives one correct value; condition 2 holds |
| Diff deviates from spec but the reason is unclear (spec stale? scope intentionally grew?) | No — clarify | Two plausible explanations, fails condition 2 |
| Any migration/schema change, even "obviously better" | No — clarify | Always fails condition 4 (blast radius on data) |
| Dead code that might be used via reflection/DI/dynamic import | No — clarify | Fails condition 3 |
| Security or logic bug, even one that looks clearly wrong | No — clarify | May be undocumented intended behavior; condition 2 not guaranteed without domain knowledge |
| Simplify / YAGNI / “use existing approach instead” | No — clarify | Almost always 2+ plausible shapes; fails condition 2 (and often 4) |

Traceability drift (spec vs. diff mismatch) is `clarify`-only by construction — it structurally fails condition 2 (two plausible explanations: the spec is stale, or the diff scope drifted), not because it's arbitrarily out of scope.

This is a different case from the "Diff contradicts an explicit spec value/formula" row above: that row applies only when the spec states one exact value or formula and the code computes something else within the same declared scope — a single quoted correct answer exists, so condition 2 holds. Traceability drift is about scope itself (services/tables/seams present or missing relative to what the spec declares), where the cause of the mismatch cannot be determined from the diff alone — always `clarify`, never the "Yes" row above.

## How phases and orchestrators use this

Every phase's `apply` pass (per `phase-protocol.md`) checks a candidate fix against this test before setting `applied: true`, in addition to being `unambiguous: true` and `P0`/`P1` severity. Severity alone is necessary but not sufficient.

**Orchestrator merge:** before emitting **Needs clarification** or starting clarify HITL, re-run this test on every `clarify` item. If a loaded kit/project rule already answers the Ask, reclassify to **Fixed now** (apply when allowed; otherwise "Would fix") — do not escalate.
