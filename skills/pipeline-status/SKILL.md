---
name: pipeline-status
description: >-
  Use before every hitl-choice closed-set ask, and when the human runs
  /lgt-pipeline-status. Resolves where-am-I from disk gates + session ledger,
  prints a chat orientation strip and canvas link. Never advances gates.
---

# Pipeline status

Thin orientation skill. Derives route / layer / stage from existing
`.cursor/gates/*` markers and optional trajectory session ledgers. Does **not**
write gates or invent a new gate kind.

## When to Use

- **Required** before every `hitl-choice` closed-set ask (same user-visible turn as the question)
- When the human runs `/lgt-pipeline-status`
- Anytime an orchestrator needs a “where am I” strip without advancing the pipeline

## How to run

1. Resolve the consumer project root (cwd of the active workspace folder).
2. Find the resolver script (first that exists):
   - `$KIT/scripts/pipeline-status.sh` when kit path is known (`.cursor/cursor-spells-kit-path` or `$KIT`)
   - `scripts/pipeline-status.sh` in the project (after install)
3. Run:

```bash
bash scripts/pipeline-status.sh --root <project-root>
# optional machine record:
bash scripts/pipeline-status.sh --json --root <project-root>
# optional canvas path with query + hash:
bash scripts/pipeline-status.sh --canvas-url --root <project-root> [--kit-root <kit-or-project>]
# optional run-log enrichment for a known invocation:
bash scripts/pipeline-status.sh --root <project-root> --invocation <id>
bash scripts/pipeline-status.sh --json --root <project-root> --invocation <id>
```

4. Print the strip (and canvas link) in the user-facing turn. Do **not** advance, clear, or invent gates.
5. When `invocation_id` is known for this chat, pass `--invocation <id>` so the strip can include a `Recent:` line from the run-log. Resolution order when the flag is omitted: pending-gate plan slug journal → `current-invocation` pointer (including post-promote `journal` / `slug`) → omit. Invalid `--invocation` or invalid pointer id omit enrichment only — never hard-exit the strip. Missing journal never changes `stage` / `layer`.
6. **Canvas clickability (mandatory):** the `Canvas:` line is a **bare absolute file path** (prefer `<project>/docs/superpowers/pipeline-flow.html`, else `~/.cursor/pipeline-canvases/pipeline-flow.html`, else kit). In chat, link **only that bare path**. Never append `?route=&layer=&stage=` or `#stage` to a markdown file link — Cursor treats the query as part of the filename and shows File not found. Put highlight params from `Canvas highlight:` in prose, or use `--canvas-url` for a browser open. `lgt install` copies the HTML into the consumer project so the path stays inside the workspace.

## Language contract

- Script stdout is a **machine / English skeleton** only (stable field labels for agents and tests).
- The orchestrator **must** adapt the strip into the human’s language using skill `plain-language-chat` (full words; Ukrainian when the human writes Ukrainian). Do not paste jargon-heavy skeleton text unchanged when the human is not writing English.

## Strip template (after adapting language)

- Route · layer · current stage
- Next stages (one short line, 1–3 names)
- Legal returns (or “none — happy path only”) — **informational only** in v1; no `/pipeline-back`
- Optional `Recent: <last note>` when a run-log tail exists
- Canvas: bare absolute path to `pipeline-flow.html` (clickable in chat)
- Optional Canvas highlight: `?route=&layer=&stage=` (+ hash) — browser / `--canvas-url` only, not for file links

## Failure

If the script is missing or exits non-zero: say in **one sentence** that orientation was skipped, then continue the calling skill (still ask the human gate). Never invent a stage id.

## Hard rules

- Never invent `stage` / `layer` when the resolver fails
- Never mutate `.cursor/gates/`
- Legal returns are prose for humans — not actions that rewind the pipeline
- Never paste a canvas path with `?` or `#` into a chat file link
