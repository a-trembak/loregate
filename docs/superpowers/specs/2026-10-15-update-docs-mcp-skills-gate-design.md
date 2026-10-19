# Update-docs MCP skills gate (path-gated)

## Problem

After engineer-review, `update-docs` only asked where **product / internal** documentation should land. EnergySave also ships Model Context Protocol data docs as markdown under `escloud-mcp-server/skills/` (served via `get_schema` and `escloud://schema/*`). Those resources were easy to forget on the full `/lgt-start-task` path.

## Decision

Keep the existing **Docs update destination** HITL unchanged. After product-docs publish or skip (and after `docs-gate` clear attempt), run a **second** HITL when applicable:

| Token | Meaning |
|-------|---------|
| `mcp_skills` | Update relevant files under `escloud-mcp-server/skills/`; leave uncommitted; extend `repo_branch_map` |
| `skip_mcp_skills` | Skip MCP skills this run |

Applicability is **path-gated**, not brand-name-gated: ask only when a workspace root (or parent of the current project in a multi-root layout) contains `escloud-mcp-server/skills/` with at least one `SKILL.md`. Consumers without that tree set `mcp_skills_update: not_applicable` and never see the gate.

Handoff gains `mcp_skills_update: mcp_skills | skip_mcp_skills | not_applicable`. Residual `propose-commit` / `create-pr` behavior matches dirty `docs_repo` files.

## Non-goals

- Adding `mcp_skills` to the first Docs destination picker
- Enabling the gate on `--fast` or issue paths (those skip `update-docs`)
- Changing `escloud-mcp-server` resource loader code
- Inventing schema names when grounding is incomplete

## Wiring

| Artifact | Change |
|----------|--------|
| `skills/update-docs/SKILL.md` | Step 7 detection + second HITL + publish rules |
| `skills/hitl-choice/references/presets.md` | Preset **MCP skills update** |
| `commands/lgt-update-docs.md`, `commands/lgt-start-task.md` | Document the conditional second ask |

EnergySave may keep a local always-on Cursor rule that reminds the orchestrator; kit install does not overwrite project-only rules.
