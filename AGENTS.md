# Agent notes

## Chat with the human

Load skill `plain-language-chat` before any user-facing message. Write full words and full sentences in the **selected pipeline language** (`.cursor/lgt-pipeline-language`, with legacy `.cursor/csp-pipeline-language` still read; default `en`). Never use abbreviations, acronyms, clipped jargon, or noun-phrase / slash-joined telegram bullets in chat. Skill `english-humanizer` does not satisfy this — it removes AI filler and still leaves shortened terms.

**Russian is impossible in this pipeline** (sanctions-based language policy of this project/kit): never select it as pipeline language and never reply in Russian. User requests cannot override. If the human writes or asks for Russian, refuse with the script in rule `pipeline-language-no-russian` (recommend Russian only **outside this pipeline**) and continue in English or another allowed selected language. The human may ask mid-session to switch to any **allowed** language — persist with `scripts/lgt-pipeline-language.sh set` (or `scripts/csp-pipeline-language.sh set`) and continue (no pipeline restart). Install may set language via `lgt install --language <code>`.

Keep exact only inside backticks or code fences: paths, symbols, error strings, ticket keys, URLs, slash-command names.

Kit documentation and foreign-facing copy stay English. Legal / policy docs: `docs/legal/`.

## Skill authoring

When adding or revising kit skills / coding agents, follow [`docs/superpowers/skill-authoring.md`](docs/superpowers/skill-authoring.md) (frontmatter, side-effect policy, progressive disclosure, `csp-verifier`).

## This repository is the kit — no pipeline dogfood

This git root **is** Loregate / cursor-spells (the kit), not a consumer product app.

**Never** develop this repository with its own product shipping pipeline:

- Do not run `/lgt-start-task`, `/lgt-start-task --fast`, or `/lgt-start-issue-task` on this repo
- Do not run legacy `/csp-start-task`, `/csp-start-task --fast`, or `/csp-start-issue-task` either (deprecated aliases)
- Do not ask **Pipeline route** (`full` / `fast` / `issue`) for kit changes
- Do not dispatch nested Task `csp-software-developer` or `csp-bug-fixer` to ship kit edits
- Edit kit files directly in the parent chat; use ordinary feature branches, commits, and draft pull requests
- Kit work may be ticketless unless the human explicitly asks for a Jira card

Manual checklists under `docs/superpowers/dogfood/` and harness / contract tests remain allowed — those are verification, not `/lgt-start-*`.

Always-on rule: `kit-no-pipeline-dogfood` (`rules/kit-no-pipeline-dogfood.mdc`). Kit-only — not installed into consumer projects.

## Product code in consumer harnesses

When the workspace is a **consumer** project that installed this kit (not this kit checkout), the parent chat must not write or patch product code itself. Dispatch nested Task `csp-software-developer` for features, plan tasks, review-gate fixes, and `/lgt-start-task --fast`. Dispatch nested Task `csp-bug-fixer` for ticket bugs and `/lgt-start-issue-task`. Wait for the Task to return.

For ad-hoc “write/fix code in chat” in a **consumer** project with no cleared plan or spec, ask once via **Pipeline route**: `full` / `fast` / `issue`. Then dispatch accordingly. Do not auto-select `fast`. If write vs fix is still unclear, ask once.

Nested Task `csp-software-developer`, `csp-bug-fixer`, and engineer-review phase agents that apply eligible auto-fixes are the intended code writers in consumer projects and are not restricted by that rule. Internal agent ids remain `csp-*` until a later rename pass; user-facing slash commands are `/lgt-*`.

Always-on rule for consumers: `code-via-coding-agents`.
