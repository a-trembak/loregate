---
name: hitl-choice
description: >-
  Use for every discrete human-in-the-loop (HITL) gate in this kit. Must call
  Cursor AskQuestion (or alias) first for closed-set choices; typed reply tokens
  are fallback only after the tool fails or is missing. Use from approve-plan,
  finish-plan, update-docs, tech-spec, engineer-review, multi-repo-supervisor,
  start-issue-task blocked critic, blocked implementation-critic gates,
  pipeline route / Fast vs issue, Pipeline language, create-pr Pipeline finale,
  Teach-review miss, Local Diff Review gate (`approve-diff` / `comment`),
  approve-commit, Capture-escape destination, and Enable Figma MCP when
  Figma tools are missing from the session.
---

# HITL Choice

Canonical UX for closed-set HITL questions. **Always attempt interactive buttons** via the session's question tool; keep typed tokens as the durable contract and last-resort fallback.

## When to Use

  - Any kit HITL gate with a fixed option set (`approve-plan` / `revise`, `skip` / `approve` / `done`, `docs_md` / `docs_repo` / `confluence`, **MCP skills update** (`mcp_skills` / `skip_mcp_skills`), `human` / `agent`, `light` / `full`, Decision-tier forks, blocked-critic next steps, **engineer-review / pr-review Needs clarification**, **force-clear / leave** for a foreign pipeline gate, **Review-learn promote**, **Teach-review miss** (`miss` / `project_secret` / `no_miss`), **Capture-escape destination** (`miss` / `project_secret`), **Pipeline language**, **Pipeline route**, **Fast vs issue**, **Local Diff Review gate** (`approve-diff` / `comment`), **Propose commit** (`approve-commit` / `revise`), **Pipeline finale**, **Enable Figma MCP** (`figma_enabled` / `skip_figma_mcp`))
- Not for open-ended answers alone (Figma URL paste, docs-repo path, Confluence space/URL, long revise notes, free-form clarification replies after `Ci:other`, missing Jira paste, typed language code after Pipeline language `other`) — those stay chat text after the closed choice, if any

## Protocol (mandatory)

0. **Orientation strip (before the question):** load skill `pipeline-status` (or run `scripts/pipeline-status.sh --root <project> [--invocation <invocation_id>]` when `invocation_id` is known) and include the adapted status strip in the **same** user-visible turn as the question. Missing or failing script → one-sentence skip (“orientation skipped”), then still ask the gate. Never invent a stage.
0b. **After the closed-set token is recorded** (same stop that appends the session ledger when applicable): dual-write `scripts/pipeline-run-log.sh append --root <project> --invocation <invocation_id> [--plan <path>] --stage <gate-stage> --note "<token>"`. Once the plan path is known, always pass `--plan`. Missing helper or missing `invocation_id` → one-sentence skip. Notes are short tokens only — no chat transcripts or ticket bodies.
1. **First action of every closed-set HITL gate: call the interactive question tool.** Do not open with a chat-only bullet list. Do not "prefer text". Do not skip the tool because you are unsure it exists — **attempt the call**.
2. **Resolve tool name** (first that exists in the session tool list / succeeds):
   1. `AskQuestion`
   2. `AskUserQuestion`
   3. `ask_question`
   4. `ask_user` / `request_user_input`
3. Set each option's **`id` to the canonical reply token** the calling skill already documents (`approve-plan`, `revise`, `skip`, `C1:A`, …). Labels may be **brief full sentences** (or a short clause with a verb); ids must stay the tokens. Fragment stacks and slash-joined jargon are forbidden — skill `plain-language-chat` proposal shape.
4. Treat a selected option `id` exactly as if the user typed that token.
5. **On tool error or cancel: retry once** with the same prompt and options. Only after a second failure (or a hard `unknown tool` / not-found error on the first attempt with no alias left) use the **text fallback**: ask with the calling skill's exact wording and accept the same typed tokens. State briefly that buttons failed / were unavailable.
6. **Forbidden voluntary skips:**
   - Pasting options as markdown bullets while assuming the tool is missing (without having attempted a call)
   - Combining the gate into a long prose message without a tool call
   - Choosing text "for speed" or "because cloud"
7. **Free-text follow-ups stay in chat** after a closed choice when needed:
   - `revise` → wait for change description (or file edit), then continue the calling skill
   - `skip` on tech-spec → wait for `<reason>` if not already provided
   - `fixes` (finish-plan) → wait for the fix description, implement/fix, re-ask the gate
   - `comment` (Local Diff Review gate) → follow skill `local-diff-review-gate` / plugin `review-local-diff` in this thread; wait for outbound Send or pasted JSON
   - `have_urls` (Figma) → wait for pasted node URLs
   - `figma_enabled` (Enable Figma MCP) → human toggles Customize → MCPs → figma, then continue; re-check tools once
   - `docs_repo` → wait for docs repo path or clone URL (optional branch / folder)
   - `confluence` → wait for space/parent or page URL
   - `accept F<id>` may be chosen via buttons; extra notes stay optional chat text
   - `Ci:other` (engineer-review clarify) → wait for free-text answer for that `Ci`, then continue the sequence
   - `other` (Pipeline language) → wait for typed ISO-ish code or `other:<tag>`; reject Russian per sanctions policy
8. If the user types a canonical token while buttons are showing, honor the typed token.
9. Never invent a HITL answer when the picker is skipped/cancelled — re-ask via retry or text fallback, or wait.
10. **Do not re-ask** when a canonical token for this gate is already present in a later user message (e.g. user sent `approve` while a stop-hook followup re-prompted). Honor that token and continue the calling skill.
11. **At most one question-tool call per assistant message.** For multi-item clarifies, ask sequentially (one `Ci` per turn).

## Gate presets (lazy load)

Option ids and per-gate rules live in [`references/presets.md`](references/presets.md). **Do not load the whole presets catalog into context.**

1. Resolve which preset the caller named (for example **Propose commit**, **Teach-review miss**, **Pipeline finale**).
2. Open **only** that `###` heading section from `references/presets.md` (from the heading through the next `###` or end of file).
3. Use those option ids and gate-specific rules with the Protocol above.
4. If the preset name is unknown, open the presets file index headings list only (heading lines), ask the caller to name a listed preset — do not paste every preset body.

Calling skills may add context in the question prompt. Labels are suggestions; ids stay the durable tokens.


## Notes

- Markers (`.cursor/gates/<kind>/<slug>`) and downstream skill steps are unchanged — only the ask UX changes. Never delete a foreign slug without this Force-clear preset.
- If the harness truly exposes no question tool, typed tokens still work **after** a hard missing-tool failure — goal is 100% attempt rate, not inventing UI.
- Slash commands and rules that restated HITL prompts should point here or say “use skill `hitl-choice` (AskQuestion required)”.
