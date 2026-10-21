# Learned misses (kit seed)

Curated miss classes that every engineer-review load. Consumer projects may add more in `.cursor/review-learnings.md` (see [review-learn-protocol.md](review-learn-protocol.md)). Prefer linking gates over restating them.

---

### `miss_side-effect-live-actor`

```yaml
id: miss_side-effect-live-actor
miss_class: side-effect × live actor
triggers:
  - resetApiState | cache invalidate | sync vs defer
  - remount / key= | overlay open/close | isLoading→disabled
  - stateful input inside host that re-filters children each keystroke
phases: [logic, architecture, security]
gate: R1
also: [R2, R3, R4, R5, R6, R7]
rule_one_liner: >-
  When the diff changes when something runs, replay still-mounted
  subscriptions and host widgets before closing; writers≠probes;
  competing-actor tests required.
anti_pattern: >-
  Review only the changed writer/filter and skip live shells or nested
  inputs that react to the side-effect.
hits: 2
last_seen: 2026-08-06
source: production-escape
```

Mechanism: a timing or list-re-render side-effect interacts with actors that stay mounted (RTK subscribers writing shared auth; Menu/Popover autofocus remounting search). Diff-only review misses both.

Required check: [interaction-replay-checklist.md](interaction-replay-checklist.md) R1–R7. Auth shape: [auth-rtk-checklist.md](auth-rtk-checklist.md).

Test shape: competing actor (active subscription **or** open menu with focused search) across the side-effect — not isolated unwrap/matcher-only tests.

---

### `miss_inline-sx-when-styled-used`

```yaml
id: miss_inline-sx-when-styled-used
miss_class: inline-sx-when-styled-used
triggers:
  - Box sx display flex gap minWidth
  - styled() Styled* layout wrapper same file
  - MUI Box display flexDirection gap shorthand
phases: [patterns]
gate: S1
also: [S2]
rule_one_liner: >-
  In files that use styled() for layout, new layout in the diff must be a
  named styled component — not inline sx or Box layout props.
anti_pattern: >-
  Reviewer accepts <Box sx={{ display: "flex", ... }}> or display/gap
  shorthand in a file that already defines Styled* wrappers for the same
  surface.
hits: 1
last_seen: 2026-08-28
source: teach-review
```

Required check: [styling-checklist.md](styling-checklist.md) S1–S2.

---

### `miss_device-family-specific-codes-in-fixtures`

```yaml
id: miss_device-family-specific-codes-in-fixtures
miss_class: device-family-specific codes in fixtures
triggers:
  - test fixture | test factory | table-driven test
  - identifier code paired with device family or platform
  - alert/error/protocol/SKU codes in tests
phases: [logic]
gate: I1
rule_one_liner: >-
  When tests bind identifier codes to a device family or platform, check
  those codes against that family's identifier conventions — not only that
  merge or aggregation logic is asserted.
anti_pattern: >-
  Pairing a family-restricted code with a fixture for a family that does
  not use that shape, while only reviewing merge or count assertions.
hits: 1
last_seen: 2026-08-27
source: engineer-review
```

Mechanism: tests can assert merge or aggregation correctly while the fixture binds a family-restricted identifier to the wrong family. Review that stops at assertion shape misses the invalid pairing.

Required check: [fixture-identifier-conventions.md](fixture-identifier-conventions.md) **I1**. Do not treat production filters that drop invalid family×code pairs as this miss class.

---

### `miss_narrow-viewport-layout`

```yaml
id: miss_narrow-viewport-layout
miss_class: narrow-viewport-layout
triggers:
  - table | DataGrid | columns | breakpoint | hide column
  - accordion | expandable | Collapse | nested table
  - Dialog | Modal | Drawer | Popover | overlay
phases: [figma, patterns]
gate: V2
also: [V1, V3, V4]
rule_one_liner: >-
  When the diff touches tables, expandable cards, dialogs, or overlays,
  verify tablet and phone layouts (or existing compact-table patterns)
  before closing; a desktop Figma frame is not enough.
anti_pattern: >-
  Review only the desktop design frame or desktop browser width while
  dense nested tables, expanders, or overlay chrome collide, clip, or
  overflow from tablet down to phone.
hits: 1
last_seen: 2026-08-27
source: engineer-review
```

Mechanism: markup review matches the desktop Figma frame; tablet and phone widths (and existing hide-column / stack / row-expander patterns) are never opened, so overlay chrome and nested tables break only on narrower viewports.

Required check: [responsive-layout-checklist.md](responsive-layout-checklist.md) V1–V4. Figma skip does not waive the gate — `csp-review-patterns` still runs it.

---

### `miss_figma-eyeball-skip`

```yaml
id: miss_figma-eyeball-skip
miss_class: figma eyeball skip
triggers:
  - figma.com/design | node-id | Figma URL
  - className | sx | theme token | CSS variable
  - accordion | tabs | table | dialog | modal
  - placeholder | empty cell | "--" | muted dashes
  - gap | padding | Stack | Grid | auto-layout
phases: [figma]
gate: F1
also: [F2, F3, F4, F5, F6, F7]
rule_one_liner: >-
  When Figma node URLs exist, walk F1–F7 against rendered UI and source;
  token and structure mismatches are P1, not nits.
anti_pattern: >-
  Treat "looks close enough" or pixel-perfect bikeshed as a pass while
  skipping auto-layout numbers, tokens, empty states, and DOM vs frames.
hits: 1
last_seen: 2026-08-27
source: production-escape
```

Mechanism: the phase compares a screenshot or JSX to Figma by vibe and skips readable token, spacing, hierarchy, and empty-placeholder misses.

Required check: [figma-markup-checklist.md](figma-markup-checklist.md) F1–F7.

---

### `miss_assumption-driven-bugfix`

```yaml
id: miss_assumption-driven-bugfix
miss_class: assumption-driven-bugfix
triggers:
  - bug fix | hotfix | NPE | 500 | production escape
  - defensive null | hardening | likely | probably
  - multiple fix commits | still failing after merge
phases: [logic]
gate: E2
also: [E1, E3, E4, E5]
rule_one_liner: >-
  Bug-fix must not ship without evidence (stack trace, failing integration
  test, or debug run) proving the throwing line; blockers not guess PRs.
anti_pattern: >-
  Patching from plausible stories, wrong auth context reproduction, or
  Mockito-only tests while QA still 500 without deploy/trace proof.
hits: 1
last_seen: 2026-09-01
source: production-escape
```

Mechanism: agent fixes from pattern matching or partial reproduction (wrong JWT scope, no stack trace), merges multiple commits, production stays broken.

Required check: [debug-evidence-gate.md](../../bug-fix/references/debug-evidence-gate.md) E1–E5 (bug-fix / bug-fixer).

---

### `miss_jpa-fetch-join-exists-correlation`

```yaml
id: miss_jpa-fetch-join-exists-correlation
miss_class: jpa-fetch-join-exists-correlation
triggers:
  - Specification | CriteriaBuilder | Subquery | exists(
  - fetch( | JoinType.INNER | JoinType.LEFT
  - root.get( | join( | bag join | @OneToMany
phases: [logic]
gate: J1
also: [J2]
rule_one_liner: >-
  When a spec fetch-joins an association and filters with EXISTS, correlate
  via the join handle — not root.get(association); mock tests must match.
anti_pattern: >-
  Approving a correlation rewrite to root.get("installation") while fetch
  join remains, or tests that stub root.get("installation") but production
  uses installationJoin.get("uuid").
hits: 1
last_seen: 2026-09-01
source: production-escape
```

Mechanism: Hibernate throws NPE at query execution when EXISTS subqueries correlate through `root.get(association)` while that association is fetch-joined. Mockito spec tests that stub the wrong path pass while QA fails on membership-scoped requests.

Required check: [jpa-criteria-checklist.md](jpa-criteria-checklist.md) J1–J2.

---

### `miss_partial-fix-regression`

```yaml
id: miss_partial-fix-regression
miss_class: partial-fix-regression
triggers:
  - null-safe | Optional.empty | groupBy | resolveLastResponsible
  - follow-up PR | hardening | align | refactor same file
  - membership scope | org-scoped | resolveScopeOrgUuid
phases: [logic]
gate: N1
rule_one_liner: >-
  Diff follow-up hardening against the prior fix commit; do not revert a
  working query/join line while adding null guards; smoke membership scope.
anti_pattern: >-
  Merging null-safe service mapping while reverting a Criteria correlation
  fix in the same PR, or closing review after fleet-scope curl only.
hits: 1
last_seen: 2026-09-01
source: production-escape
```

Mechanism: a second PR adds defensive null handling but restores an older Criteria or join line in the same hotspot, reintroducing the production 500. Review that compares only to main intent misses the regression against the immediate prior fix.

Required check: [jpa-criteria-checklist.md](jpa-criteria-checklist.md) N1. Shared callers: same file N1 bullet.

---

### `miss_partial-null-safety-shared-callers`

```yaml
id: miss_partial-null-safety-shared-callers
miss_class: partial-null-safety-shared-callers
triggers:
  - NPE | 500 | NullPointerException fix
  - null guard | filter null | optional association
  - getOrDefault | groupingBy | Collectors.toMap
  - shared helper | private extract | sibling endpoint
phases: [logic]
gate: N1
rule_one_liner: >-
  When reviewing NPE/500 fixes, trace every caller of touched helpers and
  every sibling endpoint on the same service path; do not approve if one
  path is hardened but another still uses the unsafe null pattern.
anti_pattern: >-
  Harden one endpoint or helper path while sibling endpoints and other
  callers still lack equivalent null guards (e.g. getOrDefault without
  null-value check, groupingBy on nullable keys, unfiltered associations).
hits: 1
last_seen: 2026-09-01
source: teach-review
```

Mechanism: a fix adds null guards to the reported endpoint but review never opens other callers of the same helper or sibling endpoints that share the mapping pipeline — so production still 500s on the untouched paths.

Required check: [null-safety-checklist.md](null-safety-checklist.md) **N1**.

---

### `miss_jpa-repository-result-type-mismatch`

```yaml
id: miss_jpa-repository-result-type-mismatch
miss_class: jpa-repository-result-type-mismatch
triggers:
  - List<String> | Set<UUID> | scalar / id collection return
  - @Query | derived finder | Criteria selection
  - org-scoped | fleet | unscoped sibling finder
  - result type did not match Query selection type
  - multiple selections: use Tuple or array
phases: [logic]
gate: RT1
checklist: jpa-repository-result-checklist.md
rule_one_liner: >-
  When a repository method declares a scalar/id collection, the query
  selection must match; compare scoped and fleet siblings before closing.
anti_pattern: >-
  Approving a scoped finder returning List<String> (or similar) while the
  query selects an entity or multiple columns, especially when fleet already
  has a matching scalar @Query.
hits: 1
last_seen: 2026-09-15
source: production-escape
```

Mechanism: Hibernate rejects a declared scalar/id collection when the query selects an entity type or multiple columns. Review that only opens the ticket-named scoped method misses a fleet sibling that already uses an explicit scalar `@Query`, so the scoped path ships a five-hundred while the unscoped path returns two-hundred.

Required check: [jpa-repository-result-checklist.md](jpa-repository-result-checklist.md) **RT1**.

---

### `miss_asymmetric-empty-collection-fail-close`

```yaml
id: miss_asymmetric-empty-collection-fail-close
miss_class: asymmetric-empty-collection-fail-close
triggers:
  - Optional.empty | empty list | absent response
  - empty children | nested collection walk
  - scoped candidate | fallback candidate | include current context
  - fail-close | early return empty
phases: [logic]
gate: FC1
rule_one_liner: >-
  When empty/absent upstream collections fail closed before adding a
  scoped/fallback candidate, require the same policy for present-but-empty
  children — both empty shapes must include or exclude candidates consistently.
anti_pattern: >-
  Early-returning empty on Optional.empty()/absent wrapper while still
  adding a scoped/fallback candidate when the collection exists with empty
  children.
hits: 1
last_seen: 2026-09-09
source: teach-review
```

Mechanism: review closes after checking the happy path or one empty shape; the other empty shape short-circuits earlier and drops the scoped/fallback candidate, so fail-close is inconsistent.

Required check: [empty-collection-fail-close-checklist.md](empty-collection-fail-close-checklist.md) **FC1**.

---

### `miss_prefixed-agent-unprefixed-skill`

```yaml
id: miss_prefixed-agent-unprefixed-skill
miss_class: prefixed-agent-unprefixed-skill
triggers:
  - commands/ rename | agents/ rename | shared prefix csp-
  - pipeline-flow.md | pipeline-flow.html | Mermaid agent label
  - skills/<name>/SKILL.md | harness-health | skill name:
  - Skill `/finish-plan` | Skill `/lgt-
phases: [patterns]
gate: P1
also: [P2, P3, P4]
rule_one_liner: >-
  When slash commands and agents share a prefix, update Mermaid and
  pipeline-canvas agent labels to the prefixed agent ids; keep skill
  folders and name fields unprefixed; never write Skill with a slash path;
  harness opens skills/<name>/ with unprefixed names.
anti_pattern: >-
  Prefixing commands/agents while leaving Mermaid or canvas labels on the
  old agent ids, inventing skills/lgt-…/, writing Skill `/lgt-…`, or
  pointing harness health at prefixed skill directories.
hits: 1
last_seen: 2026-09-09
source: teach-review
```

Mechanism: a shared command/agent prefix rename updates `commands/` and `agents/` but skips pipeline Mermaid/canvas labels, or mistakenly prefixes skill folders and harness paths — collapsing the skill vs slash-command distinction.

Required check: [kit-prefix-rename-checklist.md](kit-prefix-rename-checklist.md) **P1–P4**.

---

### `miss_security-checklist-skip`

```yaml
id: miss_security-checklist-skip
miss_class: security checklist skip
triggers:
  - SQL | JPQL | native query | Criteria | Mongo filter
  - auth | session | token | prepareHeaders | IDOR
  - dangerouslySetInnerHTML | innerHTML | SSRF | open redirect
  - multipart | upload | ObjectInputStream | secret | API key
  - resetApiState | security-review skill missing
phases: [security]
gate: S1
also: [S2, S3, S4, S5, S6, S7, S8, S9, S10, S11]
rule_one_liner: >-
  When auth, queries, uploads, secrets, or XSS/SSRF sinks change, open
  security-hardening-checklist.md and run S1–S11; writers load the same file.
anti_pattern: >-
  Skipping the kit checklist because third-party security-review is missing,
  or treating trigger bullets / a one-liner hint as the full security pass.
hits: 1
last_seen: 2026-09-15
source: teach-review
```

Mechanism: the security phase (or a writer) notes "no security-review skill" or relies on a one-line injection reminder and never opens S1–S11, so SQL concatenation, IDOR, or secret logging ships.

Required check: [security-hardening-checklist.md](security-hardening-checklist.md) **S1–S11**.

---

### `miss_auth-token-secure-storage-migration`

```yaml
id: miss_auth-token-secure-storage-migration
miss_class: auth-token-secure-storage-migration
triggers:
  - Keychain | Keystore | SecureStore | AsyncStorage | redux-persist
  - migrate token | secure storage | Remember-Me | splash restore
  - user.token | inbound transform | whitelist persist
  - logout Keychain | stuck splash | signed-in after logout
phases: [security]
gate: S11
rule_one_liner: >-
  When moving an auth token into platform secure storage, strip nested secrets
  from plain persist (not only top-level keys), keep token storage separate from
  Remember-Me credentials, and make logout/restore fail-safe around storage errors.
anti_pattern: >-
  Whitelisting a user slice while leaving nested token in plain storage; sharing
  Remember-Me Keychain entries with the JWT; logout/restore that can stick splash
  or leave in-memory signed-in state when secure storage throws.
hits: 1
last_seen: 2026-09-23
source: teach-review
```

Mechanism: reviewers treat top-level persist allowlist as enough, or treat secure-storage writes as fire-and-forget, so nested tokens remain on disk and Keychain errors leave a stuck splash or a still-signed-in session after logout.

Required check: [security-hardening-checklist.md](security-hardening-checklist.md) **S11**.

---

### `miss_tests-business-logic-only`

```yaml
id: miss_tests-business-logic-only
miss_class: tests-business-logic-only
triggers:
  - unit test | assertEquals hex | fillColor | borderStyle | styles.xml
  - presentation constant | OFFLINE_ROW_FILL | fontSize | opacity
  - "add test for" color | border | styling tweak
  - toHaveStyle | sx= | markArea | rgba( | Emotion snapshot | className string
  - React Testing Library | *.test.tsx | transformDataForCharts palette
  - expect(CONST).toBe | minWidth | SEGMENT_MIN_WIDTH | gap | spacing token | Figma min-w
phases: [logic, simplify]
gate: T1
rule_one_liner: >-
  Backend and frontend unit tests cover business decisions only; do not add
  or demand tests that only pin presentation constants (colors, borders,
  fonts, sx, chart chrome, layout/DS tokens such as min-width/gap) or
  cosmetic XML/snapshots — including after a clarify pixel choice.
anti_pattern: >-
  Writer adds fillColorIsF0F0F0 / thinBorder style XML tests, frontend
  expects palette hex / toHaveStyle / Emotion snapshots after a visual-only
  styling change, or locks a layout token with expect(MIN_WIDTH).toBe(N)
  after a DS/clarify pick; reviewer asks for more hex/border/sx/token coverage.
hits: 3
last_seen: 2026-10-21
source: teach-review
```

Mechanism: Excel and React styling fixes (lighter gray, borders, graph mask opacity, palette pad, tab min-width) invite hex-/stylesheet-/`sx`-/token-pinning tests that churn on every design tweak and do not protect domain rules (when to gray a row or show an offline band, omit a column, treat online=0, which tabs are visible vs hidden). Clarify answers that pick a pixel value are product UI choices — verify visually, do not freeze them in Jest.

Required check: [business-logic-tests-checklist.md](business-logic-tests-checklist.md) **T1** (explicitly includes React / Jest / Testing Library; writers load the same file via `software-developer`).
