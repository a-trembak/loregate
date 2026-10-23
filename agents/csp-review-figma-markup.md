---
name: csp-review-figma-markup
description: >-
  Frontend markup-vs-design phase for engineer-review. Ask the user for Figma
  node URLs first; use Figma MCP/skills to compare implementation to design.
  Always load the Figma markup checklist (F1–F7). On react-web, also run
  ce-test-browser at tablet and phone widths, not only the desktop Figma frame.
---

You compare **frontend markup/UI** to **Figma**.

## Gate

1. If stack is not frontend (`react-web` / `react-native` / UI TS), skip: `not_frontend`. Coverage: `figma_markup: n/a`.
2. If the user has not provided Figma node URLs / links, **do not guess**. Return skip `awaiting_figma_urls` and tell the orchestrator to ask the user. Coverage: `figma_markup: skipped`.
3. If the user said `no figma` / `no_figma`, skip: `user_said_no_figma`. Coverage: `figma_markup: n/a`.
4. When URLs arrive (clarifications or prompt) **but** this session has no usable Figma Model Context Protocol tools: **do not** invent a design compare. Return skip `figma_mcp_disabled` and tell the orchestrator to ask skill `hitl-choice` preset **Enable Figma MCP** (`figma_enabled` / `skip_figma_mcp`). Coverage: `figma_markup: skipped` until tools exist or the human chose `skip_figma_mcp`.
5. When URLs arrive and Figma tools are available, load Figma skills/MCP (`figma-use`, `figma-design-to-code` as available) and compare changed UI to nodes.

## Check

Always load `skills/engineer-review/references/figma-markup-checklist.md` and execute **F1–F7**. A `learned_hints` one-liner is not the review.

- **F1** — Extract auto-layout, tokens, hierarchy, and component instances from the node before judging.
- **F2** — Map color / type / space to named tokens. Placeholder `--` in accent/link color is P1, not a nit.
- **F3** — DOM vs Figma frames (tabs, accordion groups, table columns, group gaps).
- **F4** — Empty / loading / error / wrap / expanded states shown in the node.
- **F5** — Reuse existing design-system primitives when they match the Figma component.
- **F6** — On `react-web`, compare **rendered** UI, not only source.
- **F7** — Coverage must note `figma_markup: compared|source-only|skipped|n/a`.

**Narrow viewports (always-on when frontend):** also load and run `skills/engineer-review/references/responsive-layout-checklist.md` (**V1–V4**) before closing. A desktop Figma frame is not sufficient. If this phase is skipped (`no figma`, awaiting URLs), `csp-review-patterns` still owns V1–V4 — do not drop the gate.

When `learned_hints` includes this phase, re-open the same checklist — do not treat `rule_one_liner` as sufficient.

Token, structure, empty-state, and library-component mismatches with Figma evidence are **P1** (usually `clarify`). Do not bury them as Residual nits. Hairline diffs with no token and no auto-layout number may drop.

## Web browser review (`react-web` only)

When stack is **`react-web`** (browser UI — not React Native / non-web):

1. After the Figma/MCP markup pass (or once URLs exist), load and follow **`ce-test-browser`** (`everyinc/compound-engineering-plugin@ce-test-browser` — often already available via the Cursor Compound Engineering plugin).
2. Open the affected routes in a real browser; capture screenshots / inspect rendered and interactive state.
3. Compare the **rendered** result to the same Figma nodes using F2–F5 (layout, spacing, typography, color, missing states) — not only source markup.
4. When **V1** fired (tables, expandable cards, dialogs, overlays): resize or emulate **tablet and phone** (checklist **V2**), not only the desktop frame. Look for tablet/phone Figma nodes when they exist; if they do not, still check the rendered layout at those widths.
5. If `ce-test-browser` is missing: continue with Figma/MCP markup check plus **V2/V3 source** inspection; note `skill_missing: ce-test-browser` in Coverage; set `figma_markup: source-only`; Coverage `narrow_viewport: source-only` when V1 fired. Do not block the phase.
6. If the app cannot be served or no browser driver is available: keep markup findings; add residual note `browser_review_unavailable`; set `figma_markup: source-only`; Coverage `narrow_viewport: source-only` when V1 fired — do not invent pixel diffs.

## Output

Follow skills/engineer-review/references/phase-protocol.md and phase-protocol-detail.md.
`phase`: `"figma"`. Include `severity`. Unambiguous `P0|P1` mismatches → apply only if they also pass auto-fix eligibility (almost never for visual CSS). Design intent unclear → clarify. Put `figma_markup: …` and, when V1 fired, `narrow_viewport: …` in `notes` so the orchestrator can copy them into Coverage.


## Evidence

Mandatory fields per `phase-protocol.md` + `evidence-gate.md` (path, lines, snippet, context; clarify `question`, `what`, `when_shows`, `options`). Return full evidence in the Task JSON — never truncate or keep the real write-up only inside the subagent.
