---
name: jira-fetch
description: >-
  Fetch a Jira issue via Atlassian MCP and assemble AC text. Use from
  /lgt-start-task, /lgt-start-issue-task, or /lgt-write-tech-spec when the AC source is a
  Jira key or atlassian.net URL. Never invents ticket contents. Stops if MCP
  fails.
disable-model-invocation: true
---

# Jira Fetch

Load a Jira issue as Acceptance Criteria / bug source of truth. Parsing uses `scripts/jira-issue.sh` (consumer copy after `lgt update`, or kit path).

## When to Use

- `/lgt-start-task` / `--fast` / `/lgt-write-tech-spec` when the AC source looks like a Jira issue
- `/lgt-start-issue-task` (always — this is the fetch step)
- Not for writing AC, Linear, or inventing description text

## Detect

Source `scripts/jira-issue.sh`, then:

1. `jira_looks_like_issue "<source>"` must be true (bare `PROJ-123` **or** `*.atlassian.net` URL). A prose paragraph that merely mentions a key is **not** a fetch — use it as pasted AC.
2. `jira_extract_key` → `ISSUE_KEY`. If that fails, stop (not a Jira source).
3. `jira_extract_site` → optional hostname for `cloudId`.

## Fetch (mandatory order)

1. Discover Atlassian MCP tools (`GetMcpTools` / schema helpers). Required: `getJiraIssue`. For comments later, `addCommentToJiraIssue` is **not** required here.
2. Resolve `cloudId`:
   - If the source URL has a site hostname, pass that hostname first (`ex.atlassian.net`).
   - On failure, call `getAccessibleAtlassianResources` and retry `getJiraIssue` per cloud until one succeeds.
3. Call `getJiraIssue` with `issueIdOrKey`, `cloudId`, `responseContentFormat: "markdown"`. Prefer fields `summary`, `description`, `issuetype`, `status` (defaults are fine).
4. **On any MCP/auth/not-found failure: stop.** Ask the human to paste the ticket text (summary + description + AC). Do not continue on a URL-only stub. Do not invent fields.

On that stop, if a kit checkout is known, record and score case `fetch-failure-stops` per skill `trajectory-score`. Skip score when the kit path, scorer, or ledger is missing (still stop for pasted ticket text).

```bash
KIT="$(tr -d '\n' < .cursor/cursor-spells-kit-path 2>/dev/null || true)"
if [[ -z "$KIT" ]]; then
  KIT="$(tr -d '\n' < "$HOME/.cursor/cursor-spells-kit-path" 2>/dev/null || true)"
fi
LEDGER=".cursor/gates/trajectory-run/fetch-failure-stops.json"
python3 "$KIT/scripts/trajectory-cases.py" record init \
  --ledger "$LEDGER" --case-id fetch-failure-stops \
  --invocation "/lgt-start-task PROJ-1" --fetch fail
python3 "$KIT/scripts/trajectory-cases.py" record stage --ledger "$LEDGER" jira-fetch
python3 "$KIT/scripts/trajectory-cases.py" record artifact --ledger "$LEDGER" \
  --kind report --name stop-paste-ticket
python3 "$KIT/scripts/trajectory-cases.py" record dump --ledger "$LEDGER"
python3 "$KIT"/scripts/trajectory-cases.py score --kit-root "$KIT" --run "$LEDGER"
```

If `record dump` fails, skip score. If score prints `FAIL`, print its `FAIL` lines and stop. At that stop, ask skill `hitl-choice` preset **Trajectory fail**. On `skip`, mention `/lgt-capture-escape` with the `FAIL` lines and do not start `csp-engineer-reviewer`. On `generalize`, follow `evals/trajectories/README.md` “Add a case” only when the current git root contains both `skills/engineer-review` and `agents/csp-engineer-reviewer.md`; otherwise print the `FAIL` log and stop. After validate, display the validated case JSON (the file contents) in chat and wait for the human to confirm it is correct before `git commit`. Do not offer `git diff` as a substitute. Do not continue bootstrap. Do not ask `pipeline-route`, `tech-spec-entry`, or `ready`. Do not invent acceptance criteria. If score prints `PASS` or score was skipped, still wait for pasted ticket text. In chat, say in one full sentence when trajectory score was skipped.

For every `/lgt-start-task` fetch failure, use the case's fixed `--invocation "/lgt-start-task PROJ-1"` input shown above, regardless of the requested ticket key. If the caller was `/lgt-start-issue-task` or `/lgt-write-tech-spec`, skip this case because its input would not match; still stop for pasted ticket text and skip score.

## Assemble AC text

Do not add requirements that are not in the ticket.

```markdown
# <KEY>: <summary>
Type: <issuetype name>
Status: <status name>

## Description
<description or "(empty)">
```

If both description and summary are empty, treat as fetch failure (paste).

## Classify

`class="$(jira_classify_type "<issuetype name>")"` → `bug` | `feature` | `unknown`.

## Output (handoff)

Pass to the caller (do not start tech-spec or bug-fixer yourself):

| Field | Value |
|-------|--------|
| `jira_key` | Uppercased key |
| `jira_site` | Hostname or empty |
| `jira_cloud_id` | The `cloudId` that worked |
| `jira_type` | Issuetype display name |
| `jira_class` | `bug` / `feature` / `unknown` |
| `jira_status` | Status name |
| `ac_text` | Assembled markdown above |
| `browse_url` | Source URL if it was a URL, else empty |

Record `jira_key` (and browse URL when known) as the tech-spec **AC references** entry. The assembled `ac_text` is the AC body — not a stub link.

Callers `/lgt-start-task` and `/lgt-start-issue-task` next invoke skill `jira-transition` target `in_progress`. `/lgt-write-tech-spec` does not.
