---
description: Bug-fix issue pipeline with on-demand budget defaults — Flash orchestrator, Composer 2.5 nested Tasks, graphify scope/refresh, narrow context.
argument-hint: "[jira-key|jira-url]"
---

# /lgt-start-issue-task-on-demand

Pay-as-you-go issue pipeline when included Cursor usage is exhausted. Same steps as **`/lgt-start-issue-task`**, with a fixed budget contract.

**Do not** ask the human to paste the contract — it is binding for this invocation unless they override in the same message.

## Run

1. Read **only** [`references/on-demand-orchestration-contract.md`](references/on-demand-orchestration-contract.md) (models, nested Task `model: "composer-2.5"`, graphify, scope).
2. **Load and execute** [`lgt-start-issue-task.md`](lgt-start-issue-task.md) **in full**. The contract takes precedence over default model habits for the entire run.
3. Do not duplicate or replace the issue-task steps — only add the contract constraints.

## Arguments

- Jira issue key (`PROJ-123`) or browse URL. If omitted, ask for it (typed chat).

## Notes

- Full-price / default models → `/lgt-start-issue-task` (nested Tasks may inherit the parent model).
- Feature work → `/lgt-start-task` or `/lgt-start-task --fast`, not this command.
