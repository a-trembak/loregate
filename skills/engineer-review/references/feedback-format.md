# Review feedback format

User-facing output for `engineer-review` / `csp-engineer-reviewer` (and the shared base for `pr-review`). Every finding must answer: **what broke / looks wrong**, **where exactly**, **why it matters**, **what to do** — plus enough **context** that a peer can act without guessing.

**Before emitting:** pass every item through [evidence-gate.md](evidence-gate.md) and reject anything in [forbidden-formats.md](forbidden-formats.md). No exception for “small” nits that still name a file.

**Do not** replace this template with a short Verdict / Blockers / Блокери digest. Class or migration names without File + Jump + code fence are not locations.

## Hard requirements per finding

1. **Context** — 1–2 sentences: what this code/scenario does and why the finding sits here (not a repeat of What).
2. **Clickable location (exact Where block)** — see evidence-gate.md. Must include File link, Lines, Jump (`path#L…`), and GitHub blob when known (`#Lstart-Lend`).
3. **Code snippet** — fenced, preferably `N| code` line prefixes matching `start_line`…`end_line`. Never “see file above” or empty fences. For Clarify, the fence must be the lines the question is about.
4. **Human wording** — `english-humanizer` then `plain-language-chat` (full words, no abbreviations). Never rewrite paths/code.
5. **What / Where / Why / Ask-or-fix** structure. Clarify items also need **Options** with a marked recommendation (or explicit “no recommendation”).

## Report template

```markdown
# Engineer Review

## Coverage
- range: `<BASE_SHA>..<HEAD_SHA>`
- stack: …
- patterns: created | reused | updated
- chunks: …
- phases: …
- skills_missing: …
- budget: …
- graphify: used | absent | unqueryable
- interaction_replay: auth | overlay-focus | both | skipped | n/a   <!-- R7: required when auth/session or overlay/filter in scope -->
- auth_flow_walk: …   <!-- optional detail when auth walked -->
- figma_markup: compared | source-only | skipped | n/a   <!-- F7: required when figma phase is in scope -->
- figma_nodes: …   <!-- optional node ids actually opened -->
- narrow_viewport: tablet+phone | source-only | skipped | n/a   <!-- V4: required when tables / expandable cards / dialogs / overlays in scope -->
- review_learnings: loaded N | absent
- review_learn: appended | deduped | skipped | n/a

## Fixed now

### F1 — `P0|P1` — <short concrete title>
- **Context:** …
- **What:** …
- **Where:**
  - File: [`src/foo.ts`](src/foo.ts)
  - Lines: **18–24**
  - Jump: [`src/foo.ts:18`](src/foo.ts#L18)
  - GitHub: [src/foo.ts#L18-L24](https://github.com/<owner>/<repo>/blob/<HEAD_SHA>/src/foo.ts#L18-L24)
- **Why it matters:** …
- **Fix applied:** …  <!-- or "Would fix:" -->

```ts
18|  const x = await load();
19|  if (!x) return;
20|  return x.value;
```

## Needs clarification

### C1 — `P0|P1` — <short concrete title>
- **Context:** …
- **What:** …
- **When it shows up:** …  <!-- concrete developer/user scenario -->
- **Where:**
  - File: [`src/bar.ts`](src/bar.ts)
  - Lines: **40–45**
  - Jump: [`src/bar.ts:40`](src/bar.ts#L40)
  - GitHub: [src/bar.ts#L40-L45](https://github.com/<owner>/<repo>/blob/<HEAD_SHA>/src/bar.ts#L40-L45)
- **Why it matters:** …
- **Ask:** …
- **Options:**
  - **A (recommended):** Use existing helper `loadUser` — matches patterns "Do not reinvent"
  - **B:** Keep the new helper — if the API surface is intentional
  - **C:** Need more product context
- **Recommendation:** A — <one-line why>

```ts
40|  // …
```

## Residual notes
Only nits that still include Where + snippet when they point at code. Max 5. Otherwise drop.
```

If a phase left `recommended` null, still list Options, omit `(recommended)` on any option, and write:

> **Recommendation:** none — pick based on product intent.

If **Needs clarification** is non-empty, end with the clarify HITL (skill `hitl-choice` preset **Engineer-review clarify**): sequential AskQuestion per `C#` required (recommended option labeled); text only after failed/missing tool. Each sequential `C#` question repeats that item’s **Context**, **What**, **When it shows up**, **Where** block, and numbered code fence — do not shorten to title + Jump. Never open with only a batch letter list (`C1: A; C2: B`); that shape is a **reply** the human may type, not the ask body:

> Prefer the buttons for each `C#` (one question at a time). Or reply in one message like `C1: A; C2: B` (or free text). I will re-run the affected phases and apply agreed fixes.

## Mapping from phase JSON

| Phase field | Feedback field |
|-------------|----------------|
| `severity` | badge on the heading |
| `path` + `start_line`/`end_line` | Where File / Lines / Jump |
| `snippet` | fenced body (orchestrator adds `N\|` prefixes if missing) |
| `context` / `what` / `when_shows` / `summary` / `question` | Context + What + When it shows up + Why + Ask/Fix after humanizer |
| `options` + `recommended` + `recommendation_why` | Options list + Recommendation line |

## Anti-patterns (block emit)

- Clarify / HITL whose Options only reconfirm a loaded kit or project rule (must be Fixed instead)
- Any finding without a code fence of real source
- Any finding without Jump / File links
- Any finding without **Context**
- Clarify without **Options** and **Recommendation** (or explicit “none”)
- One-liner `` `P1` `path`: summary ``
- “See `src/foo.ts`” without lines + snippet
- Executive digests: `Verdict:…`, `### Blockers (P0)`, `### Блокери`, `### Also (P1)` without per-finding Where + fences — see [forbidden-formats.md](forbidden-formats.md)
- Shipping a PR comment draft **instead of** the full Findings section

After drafting, run `scripts/validate-review-report.sh` on the markdown; fix until exit 0.
