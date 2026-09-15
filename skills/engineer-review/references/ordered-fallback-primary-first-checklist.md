# Ordered fallback — primary first

Canonical gate for `review-logic` when the diff introduces or changes an ordered fallback between a **primary** catalog / locale / translation key-set / dialog host and a **secondary** one.

Do **not** hardcode product names or ticket ids. Apply the rule; examples are illustration only.

---

## OF1 — Secondary wins only when primary has no real entry

**Trigger:** the diff builds, selects, or documents a fallback chain with a preferred primary and a secondary (locale A→B, catalog A→B, translation key-set A→B, dialog/host A→B), **or** chooses which host/resolver runs based on installation type, page context, device family, or an empty/stub primary translator.

**Required check:**

1. Name the ordered preference the product states (or that the helper name / comments / tests encode): which side is primary, which is secondary.
2. Trace every path that can select the secondary: missing primary key, empty stub for primary, page-scoped translator override, installation/device-type host switch, prefix rewrite that skips primary keys.
3. Flag any path where secondary wins while primary still has a real entry (non-empty translation, populated key, existing resolver result). Secondary is allowed **only** when primary has no entry — never the reverse.
4. Reject empty primary stubs whose only job is to force secondary on a commercial/secondary page or host. Prefer direct secondary keys, or "use secondary iff `!hasPrimaryEntry`".
5. Require tests (or equivalent evidence) for: primary present → primary wins; primary absent → secondary; and (when relevant) installation/page type must not override a present primary.

**Anti-pattern:** accepting an empty primary stub so secondary keys always win on secondary pages; or selecting a secondary dialog/host from installation type / page context while a primary translation or entry still exists.

**Illustration only:** a fallback helper that prefers locale/catalog A, then B only if A is missing; a dialog host that must open the secondary surface only when `!hasPrimaryTranslation`, not because the installation type is "commercial".
