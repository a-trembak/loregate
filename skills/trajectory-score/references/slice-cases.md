# Slice cases (score when the contract is provable)

Load **only** the row for the case you are scoring — do not re-read this whole table into chat.

| Case | When | Init notes |
|------|------|------------|
| `fetch-failure-stops` | Jira fetch failed; stop for pasted text | `--invocation "/lgt-start-task PROJ-1" --fetch fail`. Skip if caller was `/lgt-start-issue-task` or `/lgt-write-tech-spec` |
| `route-unknown-asks-human` | After Pipeline route was asked (`jira_class` unknown, no `--fast`) | `--invocation "/lgt-start-task PROJ-1" --fetch ok --jira-class unknown`. Gate tokens `full,fast,issue` |
| `route-feature-to-full` | After tech-spec-entry was asked (feature, no `--fast`) | `--jira-class feature`. Gate tokens `human,agent` |
| `route-bug-to-issue` | After issue-fix-plan starts from `/lgt-start-task` without re-fetch | `--jira-class bug`. Do not ask pipeline-route / fast-vs-issue / tech-spec-entry |
| `fast-bug-asks-human` | After Fast vs issue was asked (`--fast` + bug) | `--invocation "/lgt-start-task --fast PROJ-1" --jira-class bug`. Tokens `issue,stay_fast` |
| `start-issue-story-stays-issue` | Explicit `/lgt-start-issue-task` after fix-plan + critic, even when type is Story | `--invocation "/lgt-start-issue-task PROJ-1" --jira-class feature` |
| `review-gate-fixes-to-build` | `/lgt-finish-plan` after the human picked `fixes` **and** `software-developer` returned | `--invocation "/lgt-finish-plan" --fetch skip`. Then re-ask review-gate |
| `critic-blocks-flawed-plan` | Verdict blocked on the fixture notification-plugin plan; after critic-blocked was asked | Exact fixture invocation. Tokens may be any non-empty `revise` / `accept F<id>` set. Plan file must stay byte-identical |
| `capture-escape-no-review` | `/lgt-capture-escape` after **Capture-escape destination** (typical path; no engineer-reviewer) | Do **not** ask review-learn-promote. Score this for both `miss` and `project_secret` |
| `capture-escape-promote-new-gate` | Retired. `/lgt-capture-escape` never asks Review-learn promote; kit publishes go through `teach-review` on `miss` | Do not score this case |
| `tech-spec-no-invented-facts` | `/lgt-write-tech-spec` with the order-export acceptance criteria, after entry + decision-blocker + tech-spec-gate | Run skill `trajectory-judge` first, then score |
| `clean-revise-no-archaeology` | `clean-decision-docs` on a forced revise, after tech-spec-gate | Run skill `trajectory-judge` first, then score |
| `create-pr-draft-never-merge` | Four-token Pipeline finale (`jira_key` known) after the ask, before `gh pr ready` | See skill `create-pr`. Observe OPEN drafts via `gh pr view` |
| `create-pr-draft-never-merge-no-jira` | Two-token Pipeline finale (`jira_key` not known) after the ask, before `gh pr ready` | `--fetch skip`. Tokens `keep_draft,ready`. Never skip never-merge scoring solely because Jira options were absent |
| `full-happy-path` / `fast-skips-plan-layer` / `issue-happy-path` | Session ledger at `create-pr` (draft + finale asked) | Do not score these during engineer-review before a draft exists |
