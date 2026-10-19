---
description: HITL gate — choose product-docs destination (skip / docs MD / docs repo / Confluence), then write dual-audience docs; when escloud-mcp-server/skills exists, also ask about MCP skills
---

# /lgt-update-docs

Run skill `update-docs`:

1. Resolve the plan path, then write `.cursor/gates/docs-gate/<slug>` (line 1 = plan path) via `pg_write_gate docs-gate`.
2. Stop and ask HITL via skill `hitl-choice` (AskQuestion required; text only after failed/missing tool). Preset **Docs update destination**:
   - `skip` — no docs this run
   - `docs_md` — Markdown under `docs/` in the current repo
   - `docs_repo` — separate documentation repository (path/URL next)
   - `confluence` — Confluence page (space/parent or URL next)
3. On a non-skip choice, run **style resolution** first (especially for `docs_repo` / `confluence`): match existing house docs, or a human custom style for user and/or engineer audiences; kit dual-audience default only as fallback. Then draft per `skills/update-docs/references/writing-guide.md`, polish with `english-humanizer` without fighting house voice, and publish
4. Clear this plan's docs-gate via `pg_clear_gate` when done or skipped. If clear fails, report the path; on a pipeline full-path caller still continue to residual `propose-commit` / `create-pr`. Do not delete another slug's docs-gate without HITL `force-clear`.
5. **MCP skills (conditional):** if any workspace root has `escloud-mcp-server/skills/` with at least one `SKILL.md`, ask a second HITL via preset **MCP skills update** (`mcp_skills` / `skip_mcp_skills`). On `mcp_skills`, update relevant skill markdown under that tree and leave uncommitted (extend `repo_branch_map`). If the path is absent, skip this ask (`mcp_skills_update: not_applicable`).
6. On a pipeline full-path run, return `next_skill: propose-commit` or `next_skill: create-pr` — never stop the ship sequence on this command alone. Dirty files in `escloud-mcp-server` after `mcp_skills` require residual `propose-commit` the same way as `docs_repo`.