# Skill authoring (kit)

How to write and maintain Agent Skills in this repository. Kit documentation stays English. Chat language follows `.cursor/lgt-pipeline-language` and is out of scope here.

Aligned with [Cursor Agent Skills](https://cursor.com/docs/skills) and [Anthropic skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

## Layout

```text
skills/<name>/
├── SKILL.md          # required — overview + procedure
├── references/       # optional — load on demand from SKILL.md links
├── scripts/          # optional — deterministic helpers the agent runs
└── assets/           # optional — templates / static files
```

- Folder name must match frontmatter `name` (lowercase, hyphens).
- Keep `SKILL.md` under ~500 lines. Move checklists and long tables into `references/` and link them from the spine.
- Prefer one-level-deep links from `SKILL.md` into `references/` (progressive disclosure).

## Frontmatter

| Field | When to set |
|-------|-------------|
| `name` / `description` | Always. Description is the selection knob — say **what** and **when**, including likely user phrases and slash commands (`/lgt-…`). |
| `disable-model-invocation: true` | Side effects, pipeline gates, or work that must not auto-fire from ambient chat (commit, pull request, Jira transition, approve/start/finish gates, teach-review, coding/review spines). Parent still loads the file by path or `/skill-name`. |
| `paths` | File-scoped guidance only (for example React-only patterns). Omit for pipeline-wide skills. |
| `icon` / `color` | Long-running skills intended as Custom Modes (`engineer-review`, `software-developer`, `bug-fix`). |

Do **not** put always-on product constraints only in skills — use short rules for universal “never do X”. Skills carry procedures.

## Rules vs skills vs agents

| Mechanism | Load | Use for |
|-----------|------|---------|
| Rule (`.mdc`) | Every conversation (or globs) | Short always-on constraints |
| Skill (`SKILL.md`) | When relevant or `/name` | Repeatable workflows, checklists, scripts |
| Agent (`agents/csp-*.md`) | Nested Task / `@agent` | Role + thin pointer to a skill spine |

Internal agent ids stay `csp-*` until a rename pass. User-facing slash commands are `/lgt-*` (legacy `/csp-*` stubs still install).

## Side-effect policy

Skills that commit, push, open pull requests, transition tickets, write gate markers, or edit the kit from a consumer pipeline **must** set `disable-model-invocation: true`. Callers name them explicitly in the pipeline spine.

## Verification

Coding agents (`csp-software-developer`, `csp-bug-fixer`) run their own checks, then dispatch readonly **`csp-verifier`** before handoff. Do not treat the implementer’s self-report as sufficient for `verifier_verdict: verified`.

## Executable helpers

Prefer `skills/<name>/scripts/` for skill-local deterministic steps when the helper is only used by that skill. Kit-wide helpers stay under repository `scripts/` and are referenced by absolute path from the skill body.

## Descriptions that select well

Good description shape:

1. Trigger phrases and slash commands.
2. What the skill does in one sentence.
3. Hard exclusions (“Not for …”).

Bad: vague “helps with development” with no when-clause.

## Checklist before merge

- [ ] `name` matches folder
- [ ] Description has when-to-use + exclusions
- [ ] Side-effect skills have `disable-model-invocation: true`
- [ ] Long material lives in `references/`, linked from the spine
- [ ] Agent pointer (if any) stays thin and points at the skill as canonical spine
- [ ] User-facing commands mentioned as `/lgt-*` (legacy `/csp-*` optional)
- [ ] Kit docs remain English; no Russian in any pipeline-facing copy
