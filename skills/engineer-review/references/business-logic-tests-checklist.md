# Business-logic tests only (T1)

## Role

Writers (`software-developer`, `bug-fixer`, frontend and backend) and reviewers (`csp-review-logic`, `csp-review-simplify`, `csp-pr-reviewer`) use this when the diff **adds or expands unit/integration tests**, or when a review would otherwise ask for more tests. **Parent / orchestrator prompts** that ask for tests must also obey T1 — do not instruct nested agents to pin chrome.

**Applies to every stack in scope:** Java/Spring services **and** React / TypeScript frontend (Jest, React Testing Library, hook tests). Same gate — not a backend-only rule.

When a **consumer** repo has its own testing conventions (for example `testing-conventions.mdc`) that still describe `describe("rendering")` / layout / `data-testid` chrome asserts, **T1 wins**. Prefer pure helpers and `renderHook` over full UI trees; if a component mount is required, assert **outcomes** (mutation args, alerts, guards) — not structure.

## T1 — Prefer business decisions; skip presentation cosmetics

**Trigger (any):**

- new or changed tests under `src/__tests__/` / `*.test.ts(x)` / `*Test.java`
- review finding that demands additional tests
- styling / chart / Excel / theme / layout / responsive chrome diffs paired with test files
- frontend assertions on `sx`, `style`, `className`, theme tokens, palette hex, `toHaveStyle`, Emotion class snapshots, ECharts/Apex option chrome
- frontend assertions on **layout chrome**: flex/gap/padding/minHeight, mobile vs desktop footer order, attach/paperclip spacing, avatar “beside” placement, icon-only vs labeled control presentation

**Gate:**

1. Keep or require tests that assert **business decisions**:
   - **Backend:** gates, domain transforms, offline/online rules, column inclusion, null/zero semantics, authz outcomes, error contracts with domain meaning.
   - **Frontend:** when bands/filters/params appear or disappear, transform outputs for domain fields, role/route guards, form validation rules, mutation payloads, error-mapping to user-facing **copy keys**, enabled/disabled from selection, fingerprint/refetch wait as a **state outcome**, capability absence (e.g. edit menu when window expired) — not mask color or footer order.
2. Do **not** add or demand tests that only pin **presentation constants**, **layout chrome**, or cosmetics:
   - **Backend:** hex/rgb fill colors, border width/style strings, fonts, opacity, stylesheet XML wiring for colors/borders.
   - **Frontend:** palette hex / `rgba(...)`, `markArea`/`markPoint` colors, MUI `sx` spacing/radius/shadow/padding, typography sizes, CSS module class name strings, Emotion generated class snapshots, `toHaveStyle({ … })`, chart legend chrome without a domain rule, **mobile button stack order**, **attach control spacing**, **avatar/meta column layout**, “icon-only on mobile” presentation unless it encodes a domain capability.
3. Flag over-testing when the body is only `expect(OFFLINE_COLOR).toBe("#D9D9D9")`, `toHaveStyle`, `stylesXml.contains(borderColor)`, a snapshot of visual chrome, or “Save is above Cancel on mobile” with no domain rule under test.
4. Visual correctness (colors, spacing, borders, chart chrome, responsive footer layout) is verified by **manual review, Figma/`ce-test-browser`, or opening the export** — not by proliferating unit tests.
5. **Refuse** writer prompts such as “add a Jest test for the mobile footer / attach spacing / spinner chrome” — rewrite as a business-decision assert or drop the test. Layout stays in browser/Figma QA.

**Anti-patterns:**

- Excel: every gray/border tweak gets a unit test asserting hex / `style="thin"` in `xl/styles.xml`.
- React: every Figma gray or palette pad tweak gets `expect(option.series[0].itemStyle.color).toBe("rgba(217,217,217,0.3)")` or Emotion snapshot churn.
- React: Journal/composer chrome — `expect` on footer `flexDirection`, paperclip padding, Cancel/Save DOM order, avatar beside body — after a visual-only edit.

**Severity:** `P1` clarify — drop or refuse the presentation-only test; keep business-behavior coverage.
