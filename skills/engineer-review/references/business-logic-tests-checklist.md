# Business-logic tests only (T1)

## Role

Writers (`software-developer`, frontend and backend) and reviewers (`csp-review-logic`, `csp-review-simplify`, `csp-pr-reviewer`) use this when the diff **adds or expands unit/integration tests**, or when a review would otherwise ask for more tests.

**Applies to every stack in scope:** Java/Spring services **and** React / TypeScript frontend (Jest, React Testing Library, hook tests). Same gate — not a backend-only rule.

## T1 — Prefer business decisions; skip presentation cosmetics

**Trigger (any):**

- new or changed tests under `src/__tests__/` / `*.test.ts(x)` / `*Test.java`
- review finding that demands additional tests
- styling / chart / Excel / theme diffs paired with test files
- frontend assertions on `sx`, `style`, `className`, theme tokens, palette hex, `toHaveStyle`, Emotion class snapshots, ECharts/Apex option chrome
- tests that lock layout / DS numeric tokens (`minWidth`, gap, spacing, padding, radius) via `expect(SOME_CONST).toBe(N)` after a design or clarify choice

**Gate:**

1. Keep or require tests that assert **business decisions**:
   - **Backend:** gates, domain transforms, offline/online rules, column inclusion, null/zero semantics, authz outcomes, error contracts with domain meaning.
   - **Frontend:** when bands/filters/params appear or disappear, transform outputs for domain fields, role/route guards, form validation rules, enabled/disabled Generate from selection, tooltip **copy keys** or presence of offline message — not the mask color. Packing / overflow **rules** (what is visible vs hidden, selected never demoted) are in scope; the **pixel floor** used as min-width is not.
2. Do **not** add or demand tests that only pin **presentation constants** or cosmetics:
   - **Backend:** hex/rgb fill colors, border width/style strings, fonts, opacity, stylesheet XML wiring for colors/borders.
   - **Frontend:** palette hex / `rgba(...)`, `markArea`/`markPoint` colors, MUI `sx` spacing/radius/shadow, typography sizes, CSS module class name strings, Emotion generated class snapshots, `toHaveStyle({ backgroundColor: … })`, chart legend chrome without a domain rule, **layout / DS tokens** (component `minWidth`, flex `gap`, spacing/padding/radius constants, Figma `min-w` numbers) locked with `expect(CONST).toBe(80|120|…)`.
3. Flag over-testing when the body is only `expect(OFFLINE_COLOR).toBe("#D9D9D9")`, `expect(SEGMENT_MIN_WIDTH).toBe(120)`, `toHaveStyle`, `stylesXml.contains(borderColor)`, or a snapshot of visual chrome with no decision under test. A clarify answer that picks a pixel value does **not** authorize a unit test that freezes that value.
4. Visual correctness (colors, spacing, borders, min-widths, chart chrome) is verified by **manual review, Figma/`ce-test-browser`, or opening the export** — not by proliferating unit tests.

**Anti-patterns:**

- Excel: every gray/border tweak gets a unit test asserting hex / `style="thin"` in `xl/styles.xml`.
- React: every Figma gray or palette pad tweak gets `expect(option.series[0].itemStyle.color).toBe("rgba(217,217,217,0.3)")` or Emotion snapshot churn.
- React: after a DS/clarify choice on tab min-width or gap, adding `it("exposes SEGMENT_MIN_WIDTH …") { expect(SEGMENT_MIN_WIDTH).toBe(120) }` (or equivalent) instead of testing only packing outcomes with injected widths.

**Severity:** `P1` clarify — drop or refuse the presentation-only test; keep business-behavior coverage.
