# Product name — Loregate (CHOSEN)

**Status:** **Loregate** is the **chosen product name**. Short mark / monogram: **LGT**. Tagline: **From lore to merge through gates.**

The GitHub repository is **`a-trembak/loregate`** (renamed from `cursor-spells`). Old clone URLs redirect. In-repo product strings, CLI (`lgt`), and slash commands (`/lgt-*`) use Loregate / LGT.

**Do not use “Cursor”, “Claude”, “Codex”, “OpenAI”, or “Anthropic” in the product title** (third-party marks).

Author attribution stays: **Andrey Trembak** (`a-trembak`).

### Typo variant (not the brand)

**Lordgate** appeared once in chat and is a typo for **Loregate**. Do not use it.

## Brand meaning

| Piece | Meaning for this kit |
|-------|----------------------|
| **Lore** | Kit knowledge: plans, skills, checklists, policy, and project standards the pipeline teaches and enforces |
| **Gate** | Quality, policy, and review gates that must pass before merge |
| **LGT** | Short code / logo mark for Loregate (preferred over `LG`) |

**Tagline:** From lore to merge through gates.

Pipeline shape the name fits: task → plan → build → review → pull request.

## Logo

Primary mark: [`lgt-logo.png`](lgt-logo.png) (also [`assets/lgt-logo.png`](../../assets/lgt-logo.png)).

## Command surface

| Surface | Primary | Legacy (deprecated, still works) |
|---------|---------|----------------------------------|
| CLI | `lgt` (`bin/lgt`) | `csp` → warns and forwards to `lgt` |
| Slash commands | `/lgt-start-task`, `/lgt-approve-plan`, … | `/csp-*` stubs load `/lgt-*` |
| Env vars | `LGT_PIPELINE_LANGUAGE`, `LGT_AGREE_POLICY`, `LGT_SKIP_THIRD_PARTY_SKILLS` | `CSP_*` aliases still accepted |
| Markers | `.cursor/lgt-pipeline-language`, `.cursor/lgt-policy-accepted` | `.cursor/csp-*` twins still read/written |

**Internal agent filenames** (`agents/csp-software-developer.md`, `csp-bug-fixer`, …) stay `csp-*` for now — renaming those ids is a later pass. User-facing commands and CLI are `lgt`.

## Other options (rejected / deferred)

Kept for history only.

| # | Name | Why it was considered | Status |
|---|------|----------------------|--------|
| 1 | Spellpath | A path of spells (skills) through quality gates | Deferred |
| 2 | Runeflow | Runes as skills flowing through a pipeline | Deferred |
| 3 | Hexrail | A rail of hexes/stages; strong, short brand | Deferred |
| 4 | Sigilworks | Workshop of sigils (skills) and gates | Deferred |
| 5 | **Loregate** | Gates that enforce project lore/standards | **CHOSEN** |
| 6 | Charmline | Charms lined into an ordered delivery line | Deferred |
| 7 | Arcanaforge | Forging arcane tooling into reliable runs | Deferred |
| 8 | Weavewell | A well of woven spells/skills | Deferred |

## Abbreviations

| Code | Status |
|------|--------|
| `LGT` | **Chosen** short mark / logo monogram |
| `LG` | Rejected for logo (too generic / ambiguous) |
| `LRG` | Deferred |

Legacy CLI name `csp` remains only as a deprecated wrapper; do not invent new `csp` expansions for marketing.

## Human rename step (GitHub) — done

Remote is `https://github.com/a-trembak/loregate`. After a local folder rename, point clones at the new URL and path:

```bash
git remote set-url origin https://github.com/a-trembak/loregate.git
# optional local folder: mv ~/cursor-spells ~/loregate
```

Keep README / NOTICE display URLs on `a-trembak/loregate`.
