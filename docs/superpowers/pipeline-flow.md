# Quality pipeline flow (canvas)

Canonical flowchart of `/lgt-start-task` (full + `--fast`), `/lgt-start-issue-task`, and shared finale `create-pr` — every stage, HITL gate, condition, and branch as shipped in this kit.

**Interactive canvas (click stages → detail branches):** open [`pipeline-flow.html`](pipeline-flow.html) in a browser.

Static Mermaid diagrams below are the same graph for GitHub preview and diffs.

**Legend**

| Shape / style | Meaning |
|---------------|---------|
| Stadium `([…])` | Start / end |
| Rectangle `[…]` | Automatic stage |
| Diamond `{…}` | Decision / condition |
| Trapezoid `[/…/]` | HITL gate (human must answer) |
| Hexagon `{{…}}` | Artifact / marker handoff |
| Subgraph box | Layer in time (Plan → Build → Review → Docs) |
| Thick `==>` | Happy-path sequence |
| Cross `--x` | Stop / blocked |
| Dotted `-.->` | Cycle: stay in this layer, or go **one layer back** |

`review-gate` is the HITL **after code**. Skill `finish-plan` (slash command `/lgt-finish-plan`) writes `.cursor/gates/review-gate/<slug>` and asks `skip` / `approve` / `done` / `fixes`. It does **not** reopen `writing-plans`.

Source of truth: [`commands/lgt-start-task.md`](../../commands/lgt-start-task.md), [`commands/lgt-start-issue-task.md`](../../commands/lgt-start-issue-task.md), [`commands/lgt-capture-escape.md`](../../commands/lgt-capture-escape.md), plus `jira-fetch`, `jira-transition`, `csp-tech-spec`, `approve-plan`, `start-build`, `finish-plan`, `propose-commit`, `update-docs`, `create-pr`, `bug-fix`, `hitl-choice`, `teach-review`.

Closed-set HITL: skill `hitl-choice` **must** call AskQuestion (or alias) first; typed tokens only after failed/missing tool (rule `hitl-askquestion`).

### Pipeline language

At bootstrap of `/lgt-start-task` (full and `--fast`) and `/lgt-start-issue-task`, skill `hitl-choice` preset **Pipeline language** asks how the agent should talk to the human **when** `csp-pipeline-language.sh status` is `unset`. Preference may also be set at install (`--language` / `--lang` / `LGT_PIPELINE_LANGUAGE`) or mid-session by asking the agent. Stored in `.cursor/lgt-pipeline-language` (default `en` when unset). Kit documentation and this canvas stay English. **Russian is impossible** in this pipeline (sanctions-based language policy of this project/kit) — user requests cannot override; refuse and recommend Russian only **outside this pipeline**. Rule `pipeline-language-no-russian`, helper `scripts/lgt-pipeline-language.sh`. See [`pipeline-language.md`](pipeline-language.md) and [`docs/legal/`](../legal/).

### Orientation strip and live canvas

At every closed-set human gate, skill `hitl-choice` prints a short **orientation strip** (via skill `pipeline-status` / `scripts/pipeline-status.sh`) before the question. Humans may run `/lgt-pipeline-status` anytime — read-only; it does not advance gates.

| Surface | What it does |
|---------|----------------|
| Chat strip | Route · layer · stage · next stages · legal returns · **bare** canvas file path |
| `/lgt-pipeline-status` | Same strip from disk markers + optional session ledger |
| Canvas file (chat click) | Absolute path to `docs/superpowers/pipeline-flow.html` in the consumer project (copied by `lgt install`) — **no** `?` / `#` in the markdown link |
| Canvas highlight / browser URL | `pipeline-flow.html?route=&layer=&stage=` (+ optional `#stage` hash) via `--canvas-url` or the strip’s `Canvas highlight:` line |

**URL query parameters** (highlight on load; overview stays highlighted; hash opens a detail view and keeps the query so Back retains highlight):

| Param | Example | Effect |
|-------|---------|--------|
| `route` | `full` | Shown in the header when present |
| `layer` | `review` | That layer box is `here`; earlier layers `done`; later `waiting` |
| `stage` | `review-gate` | Matching overview node (`data-stage`) is `here` |
| `pending` | `review-gate` | Optional; styles waiting human-gate nodes |

**Legal returns** in the strip are **informational only** in v1 (for example `fixes` → Build). There is no `/pipeline-back` that mutates gates.

Resolver: `scripts/pipeline-status.sh` (`--json`, `--canvas-url`, optional `--invocation <id>`). Pending-gate precedence for stage/layer: `docs-gate` → `review-gate` → `critique-gate` → `plan-gate`; else last `stages_entered` from the session ledger; else `idle`.

### Pipeline run-log (consumer orientation journal)

Short append-only journals live under the **consumer** project (not in the Spells kit checkout). There is **no** kit-global chat / vector memory.

| When | Path |
|------|------|
| Pre-plan | `.cursor/gates/run-log/inv-<invocation_id>.md` |
| After successful promote | `.cursor/gates/run-log/<slug>.md` |
| Pointer (every successful `init`) | `.cursor/gates/run-log/current-invocation` |
| Optional fast/tiny brief | `.cursor/gates/run-log/briefs/inv-<id>.brief.md` |

Helper: `scripts/pipeline-run-log.sh` (`init` / `append` / `promote` / `read-tail` / `path` / `brief-upsert`). Installer copies it beside `pipeline-status.sh` and recommends gitignoring `.cursor/gates/run-log/`.

**Promote:** target absent → `mv` + header refresh; target already exists → **refuse-on-conflict** (exit non-zero, leave `inv-*.md` intact, no merge). Keep appending with `--invocation`.

**Authority split:** pending gates + trajectory session ledgers own stage/scoring; the run-log only enriches orientation (`run_log_path` / `run_log_tail`, optional `Recent:`). Status resolution: `--invocation` → pending-plan slug journal → pointer → omit.

**Forbidden in journals/briefs:** chat transcripts, full ticket bodies, secrets.

---

## 1. Layers, sequence, and cycles

Time flows **down**. Thick arrows are the happy path. Dotted arrows are the only legal loops.

```mermaid
flowchart TB
  fetch["0 Fetch + route"]

  subgraph planLayer [Plan layer — spec and plan, no code yet]
    direction TB
    spec["csp-tech-spec"]
    plans["writing-plans"]
    critic["approve-plan + critic"]
    spec ==> plans ==> critic
    spec -.->|"revise"| spec
    critic -.->|"revise"| plans
    critic -.->|"blocked / accept F-id"| critic
  end

  subgraph buildLayer [Build layer — write the code]
    direction TB
    startB["start-build"]
    code["csp-software-developer"]
    startB ==> code
  end

  subgraph reviewLayer [Review layer — the plan is already executed]
    direction TB
    gate[/"review-gate"/]
    review["engineer-review"]
    gate ==>|"skip / approve / done"| review
    review -.->|"Needs clarification"| review
  end

  subgraph shipLayer [Docs and PR]
    direction TB
    localDiff["local-diff-review-gate"]
    commit["propose-commit"]
    docs["update-docs"]
    localDiff2["local-diff-review-gate residual"]
    commit2["propose-commit residual"]
    pr["create-pr"]
    localDiff ==> commit
    commit ==> docs
    docs ==> localDiff2
    localDiff2 ==> commit2
    commit2 ==> pr
  end

  fetch ==> spec
  critic ==>|"Verdict: clear"| startB
  code ==>|"tasks verified"| gate
  gate -.->|"fixes — back to Build, not Plan"| code
  review ==> localDiff
```

| Cycle | Returns to | Does not return to |
|-------|------------|--------------------|
| `revise` on csp-tech-spec | Plan / csp-tech-spec | Build |
| `revise` / `accept F-id` on critic | Plan / writing-plans or the same critic HITL | Build |
| **`fixes` on review-gate** | **Build / `csp-software-developer`, then the same review-gate** | **`writing-plans`** |
| Needs clarification | Review / engineer-review | Plan |
| Docs location follow-up | Docs | Review |

`--fast` skips the Plan layer and skips `review-gate`; it still runs engineer-review. `/lgt-start-issue-task` has its own fix-plan loop, not this full Plan layer.

---

## 2. Full pipeline (end-to-end)

```mermaid
flowchart TD
  startNode(["/lgt-start-task ac-source"])
  looksJira{Looks like Jira?}
  fetch[["jira-fetch MCP"]]
  fetchFail{MCP ok?}
  stopPaste[/"Stop: paste ticket text"/]
  inProgress[["jira-transition in_progress"]]
  route{"Route"}
  hitlRoute[/"HITL Pipeline route: full / fast / issue"/]
  noAc{AC exist?}
  stopNoAc[/"Stop: writing AC out of scope"/]
  bootstrap["Bootstrap: patterns + stack + pipeline language"]
  techSpec[["csp-tech-spec"]]
  planWrite["writing-plans"]
  approvePlan[["approve-plan + critic"]]
  startBuild[["start-build"]]
  softwareDev[["csp-software-developer"]]
  reviewGate[/"review-gate"/]
  engReview[["csp-engineer-reviewer or csp-multi-repo-supervisor"]]
  localDiffGate[["local-diff-review-gate HITL approve-diff / comment"]]
  proposeCommit[["propose-commit HITL approve-commit"]]
  updateDocs[["update-docs"]]
  localDiffGate2[["local-diff-review-gate residual if dirty"]]
  proposeCommit2[["propose-commit residual if dirty"]]
  createPr[["create-pr draft then HITL finale"]]
  doneNode(["PR URL + docs path"])

  startNode ==> looksJira
  looksJira -->|"yes"| fetch
  looksJira -->|"no"| noAc
  fetch ==> fetchFail
  fetchFail -->|"no"| stopPaste
  fetchFail -->|"yes"| inProgress
  inProgress ==> route
  route -->|"bug, no --fast"| issuePipe[["issue pipeline"]]
  route -->|"unknown, no --fast"| hitlRoute
  hitlRoute -->|"full"| noAc
  hitlRoute -->|"fast"| fastPipe[["fast pipeline"]]
  hitlRoute -->|"issue"| issuePipe
  route -->|"feature or --fast not-bug"| noAc
  noAc -->|"no"| stopNoAc
  noAc -->|"yes"| bootstrap
  bootstrap ==> techSpec
  techSpec ==>|"Status approved or skip"| planWrite
  techSpec -.->|"revise"| techSpec
  planWrite ==> approvePlan
  approvePlan -.->|"revise"| planWrite
  approvePlan ==>|"Verdict: clear"| startBuild
  startBuild ==> softwareDev
  softwareDev ==>|"all tasks verified"| reviewGate
  reviewGate -.->|"fixes"| softwareDev
  reviewGate ==>|"skip / approve / done"| engReview
  engReview -.->|"Needs clarification"| engReview
  engReview ==> localDiffGate
  localDiffGate ==>|"approve-diff"| proposeCommit
  localDiffGate -.->|"comment — Loop"| engReview
  proposeCommit ==>|"approve-commit"| updateDocs
  proposeCommit -.->|"revise"| proposeCommit
  updateDocs ==>|"skip / docs_md / docs_repo / confluence"| localDiffGate2
  localDiffGate2 ==> proposeCommit2
  proposeCommit2 ==>|"if dirty"| createPr
  proposeCommit2 -.->|"clean tree"| createPr
  createPr ==>|"keep_draft / ready / *_jira"| doneNode
```

`--fast` is never auto-selected. `--fast` + classified bug → HITL **Fast vs issue** (`issue` / `stay_fast`) before the fast pipeline. Explicit `/lgt-start-issue-task` always stays on the issue path. Skill `finish-plan` (slash command `/lgt-finish-plan`) is how the orchestrator enters `review-gate` after `csp-software-developer` returns.

---

## 3. Tech spec — modes, tiers, gate

```mermaid
flowchart TD
  entry([tech-spec start])
  entryHitl[/"HITL: human or agent"/]
  requirePlan["Require plan path or paste"]
  depthHitl[/"HITL: light or full"/]
  fullPath[["system-design pair"]]
  uncertainty{Uncertainty tier?}
  blocker[/"HITL Blocker: stop ask"/]
  decision[/"HITL Decision: options A/B/C"/]
  assumption["Log Assumption in spec"]
  writeFile{{"Write English tech-spec file"}}
  gate[/"HITL: approve-spec / revise / skip"/]
  approved["Status: approved"]
  skipped["Status: skip + reason logged"]
  reviseLoop["clean-decision-docs rewrite"]
  toPlan(["Hand off to writing-plans"])

  entry ==> entryHitl
  entryHitl -->|"human"| requirePlan
  requirePlan --> fullPath
  entryHitl -->|"agent"| depthHitl
  depthHitl -->|"light"| uncertainty
  depthHitl -->|"full"| fullPath
  fullPath --> writeFile
  uncertainty -->|"Blocker"| blocker
  blocker --> uncertainty
  uncertainty -->|"Decision"| decision
  decision --> uncertainty
  uncertainty -->|"Assumption"| assumption
  assumption --> uncertainty
  uncertainty -->|"none left"| writeFile
  writeFile ==> gate
  gate -->|"approve-spec"| approved
  gate -->|"skip reason"| skipped
  gate -->|"revise"| reviseLoop
  reviseLoop --> writeFile
  approved ==> toPlan
  skipped ==> toPlan
```

---

## 4. Approve plan → critic → build

```mermaid
flowchart TD
  planReady(["Plan exists"])
  writeGate{{".cursor/gates/plan-gate/slug"}}
  clearStale["clear this slug plan-critique-clear"]
  hitlApprove[/"HITL: approve-plan / revise"/]
  revisePlan["clean-decision-docs rewrite plan"]
  delGate["Clear this slug plan-gate"]
  writeCritique{{".cursor/gates/critique-gate/slug"}}
  critic[["implementation-critic Pass A + Pass B"]]
  verdict{Verdict?}
  writeClear{{".cursor/gates/plan-critique-clear/slug"}}
  delCritique["Clear this slug critique-gate"]
  toBuild(["start-build"])
  blockedHitl[/"HITL: revise / accept F-id"/]
  acceptIds["Accept findings; recompute Verdict"]
  stopBlocked[/"Stop: no Task 1"/]

  planReady ==> writeGate
  writeGate --> clearStale
  clearStale ==> hitlApprove
  hitlApprove -->|"revise"| revisePlan
  revisePlan --> writeGate
  hitlApprove -->|"approve-plan"| delGate
  delGate --> writeCritique
  writeCritique ==> critic
  critic ==> verdict
  verdict -->|"clear"| delCritique
  delCritique --> writeClear
  writeClear ==> toBuild
  verdict -->|"blocked or clear pending accept"| blockedHitl
  blockedHitl -->|"revise"| revisePlan
  blockedHitl -->|"accept F-id"| acceptIds
  acceptIds --> verdict
  verdict -.->|"still not clear"| stopBlocked
```

### Critic verdict rules

| Verdict | Condition | Build? |
|---------|-----------|--------|
| `clear` | No open Must-fix; no un-accepted Accept-risk | Yes → `start-build` |
| `clear pending accept` | Must-fix resolved/accepted; Accept-risk still open | No — HITL `accept F<id>` or revise |
| `blocked` | Open Must-fix remains | No — revise or `accept F<id>` |

Should-fix findings are visible but never block.

---

## 5. Start-build → csp-software-developer

```mermaid
flowchart TD
  startBuildCmd(["start-build"])
  checkClear{".cursor/gates/plan-critique-clear/slug matches this plan?"}
  checkPending{"this slug plan-gate or critique-gate pending?"}
  stopApprove[/"Stop: run approve-plan first"/]
  stopPending[/"Stop: approval or critique still open"/]
  entryOk{Entry: spec + plan + critic clear?}
  stopEntry[/"Stop: missing gate"/]
  branchSetup["Create feature branch in every target repo"]
  skillRoute["skill-map: stack + DB + code-comments + skill profile"]
  execMode{User asked executing-plans?}
  sdd[["subagent-driven-development"]]
  ep[["executing-plans separate session"]]
  verify["verification-before-completion"]
  toReviewGate(["review-gate"])

  startBuildCmd ==> checkClear
  checkClear -->|"no"| stopApprove
  checkClear -->|"yes"| checkPending
  checkPending -->|"yes"| stopPending
  checkPending -->|"no"| entryOk
  entryOk -->|"no"| stopEntry
  entryOk -->|"yes"| branchSetup
  branchSetup ==> skillRoute
  skillRoute ==> execMode
  execMode -->|"no default"| sdd
  execMode -->|"yes"| ep
  sdd ==> verify
  ep ==> verify
  verify ==> toReviewGate
```

**Skill load (Build):** [`skill-map.md`](../../skills/engineer-review/references/skill-map.md) Skill classes / Load levels / Skill profile. Kit miss-class checklists stay **L1** (trigger-gated, never skipped by model IQ). Mapped third-party stack skills are **L2** enrichment. Profile from `.cursor/csp-skill-profile` (`strict` / `balanced` / `expert`, default `strict`) modulates L2 only — writers may skip L2 under `balanced` / `expert` and note `skill_skipped_by_profile`. Rules under `rules/*.mdc` stay always-on. Pipeline chat language from `.cursor/lgt-pipeline-language` (default `en`; Russian forbidden — see [`pipeline-language.md`](pipeline-language.md)).

`start-build` **must Wait for** the `csp-software-developer` Task to return, then invoke skill `finish-plan` (slash command `/lgt-finish-plan`) in the parent chat. That handoff **is** the `review-gate` HITL; after `skip` / `approve` / `done` it starts `csp-engineer-reviewer`. **Fire-and-forget** dispatch is a pipeline bug: the nested Task cannot run `AskQuestion`, so review never launches.

---

## 6. review-gate → review routing

Coding is done. This gate is **not** another Plan-layer step and **not** the pipeline end. Skill `finish-plan` (slash command `/lgt-finish-plan`) writes the marker, applies thin `review-surface` (`SetActiveBranch` + checkout in each open folder so the merge-base diff tab can show the branch), asks HITL (`skip` / `approve` / `done` / `fixes`), then routes to engineer-review. **This gate does not open the Local Diff Review canvas** — that canvas belongs to skill `local-diff-review-gate` **after** engineer-review and Teach-review miss. When the branch has **zero commits ahead of base**, the tab may be empty; `review-surface` may summarize the **uncommitted** working tree in chat (`git status` / `git diff`) — not a GitHub pull request. `fixes` returns to `csp-software-developer` (Build), then re-runs `review-surface` and re-asks this same gate. Product commits happen later via `propose-commit` (after engineer-review → miss → `local-diff-review-gate` Loop until `approve-diff`). GitHub `create-pr` still happens after docs and any residual `propose-commit`.

```mermaid
flowchart TD
  planDone(["Build complete — plan already executed"])
  writeReview{{".cursor/gates/review-gate/slug"}}
  surface["review-surface: checkout + SetActiveBranch"]
  hitlFinish[/"HITL: skip / approve / done / fixes"/]
  doFixes["csp-software-developer implements fixes"]
  delReview["Clear this slug review-gate"]
  probe["Non-mutating multi-repo probe"]
  repoCount{Changed repo count?}
  stopZero[/"Stop: no changed repos"/]
  multi[["csp-multi-repo-supervisor"]]
  singleFrontend{Frontend stack?}
  figmaHitl[/"HITL: no_figma / have_urls"/]
  single[["csp-engineer-reviewer"]]
  clarify[/"HITL: Needs clarification only"/]
  reviewed(["Review complete"])

  planDone ==> writeReview
  writeReview ==> surface
  surface ==> hitlFinish
  hitlFinish -->|"fixes"| doFixes
  doFixes -->|"re-run review-surface"| surface
  hitlFinish -->|"skip or approve or done"| delReview
  delReview ==> probe
  probe ==> repoCount
  repoCount -->|"0"| stopZero
  repoCount -->|">= 2"| multi
  repoCount -->|"1"| singleFrontend
  singleFrontend -->|"react-web / react-native"| figmaHitl
  singleFrontend -->|"other"| single
  figmaHitl --> single
  multi --> clarify
  single --> clarify
  clarify -.->|"C-id answers"| clarify
  clarify ==> reviewed
```

---

## 7. Update-docs destination

```mermaid
flowchart TD
  reviewDone(["Review complete"])
  writeDocs{{".cursor/gates/docs-gate/slug"}}
  hitlDocs[/"HITL: skip / docs_md / docs_repo / confluence"/]
  skipDocs["Clear this slug; no docs"]
  needLoc{Location follow-up?}
  waitLoc[/"Chat: path, URL, or Confluence space"/]
  draft["Dual-audience draft + english-humanizer"]
  publish["Publish to chosen destination"]
  clearDocs["Clear this slug docs-gate"]
  doneDocs(["Pipeline done"])

  reviewDone ==> writeDocs
  writeDocs ==> hitlDocs
  hitlDocs -->|"skip"| skipDocs
  skipDocs ==> doneDocs
  hitlDocs -->|"docs_md"| draft
  hitlDocs -->|"docs_repo or confluence"| needLoc
  needLoc -->|"yes"| waitLoc
  waitLoc --> draft
  draft ==> publish
  publish ==> clearDocs
  clearDocs ==> doneDocs
```

| Token | Meaning |
|-------|---------|
| `skip` | No product docs this run |
| `docs_md` | Markdown under `docs/` in the current repo (not `docs/superpowers/`) |
| `docs_repo` | Separate documentation repository — path/URL in chat next |
| `confluence` | Confluence page — space/parent or URL in chat next |

Writing shape: skill `update-docs` + `references/writing-guide.md`. For `docs_repo` / `confluence`, **style resolution** first (custom user/engineer style → house siblings → kit default dual-audience). Optional follow-ups: `ce-compound` for durable learnings, `ce-explain` for personal teaching artifacts — neither replaces this gate.

---

## 8. Engineer-review internals (phase graph)

```mermaid
flowchart TD
  orch(["csp-engineer-reviewer"])
  lint[["csp-review-lint first"]]
  tinyDiff{"Tiny-diff skip? ≤3 files, ≤40 LOC, non-risky"}
  parallelFind["Parallel find: logic / patterns (+ deadcode / simplify / architecture / performance unless tiny-diff) / security? / figma?"]
  autofix{Auto-fix eligible?}
  apply["Serialize apply: lint then patterns deadcode logic arch perf security figma"]
  clarifyItem[/"clarify — never silent apply"/]
  verifyLint["Verify: re-run csp-review-lint once"]
  merge["Merge JSON + evidence gate + validate report"]
  needsClarify{Needs clarification?}
  waitHitl[/"HITL wait for C-id answers"/]
  redispatch["Re-dispatch affected phases"]
  report(["User-facing report"])

  orch ==> lint
  lint ==> tinyDiff
  tinyDiff -->|"yes: Coverage phase_skip: tiny-diff"| parallelFind
  tinyDiff -->|"no: all heuristic phases"| parallelFind
  parallelFind ==> autofix
  autofix -->|"all 4 tests pass + P0/P1 unambiguous"| apply
  autofix -->|"any test fails or P2"| clarifyItem
  apply --> verifyLint
  clarifyItem --> verifyLint
  verifyLint --> merge
  merge --> needsClarify
  needsClarify -->|"yes"| waitHitl
  waitHitl --> redispatch
  redispatch --> merge
  needsClarify -->|"no"| report
```

**Skill load (Review):** same Skill profile as Build. Phase agents load kit **L1** checklists on triggers; third-party stack / simplify / architecture bodies are **L2** when the profile allows. **Tiny-diff heuristic phase skip** (see [`phase-protocol.md`](../../skills/engineer-review/references/phase-protocol.md)): when ≤3 files, ≤40 changed lines, and paths are non-risky, orchestrator may skip `deadcode` / `simplify` / `architecture` / `performance` — always keep `lint` + `logic` + `patterns`; Coverage must list `phase_skip: tiny-diff (…)`. Never skip L1 checklist opens when a trigger matches.

Auto-fix requires all four: deterministic check, single correct answer, no information loss, zero blast radius on data/UX. Traceability drift and migrations are always `clarify`.

After a validated engineer-review report, HITL **Teach-review miss** (`miss` / `project_secret` / `no_miss`). `miss` invokes skill `teach-review` (kit `learn/…` branch and a ready-for-review pull request when `land` is `draft_merge`; does not merge to `main`). `project_secret` writes this project's `.cursor/review-learnings.md` only.

Pipeline handoff (full / `--fast` / issue): invoke skill **`local-diff-review-gate`** next (HITL `approve-diff` / `comment`; skip if clean / missing plugin), then skill **`propose-commit`** — HITL `approve-commit` / `revise`, then `git commit` only (never push). **`no_miss` does not skip Local Diff Review** — order is miss answer → `local-diff-review-gate` → (Loop on `comment`) → `propose-commit` on `approve-diff`. **Loop:** token `comment` applies canvas notes, sets `next_skill: engineer-review`, re-runs engineer-review and Teach-review miss, then **`local-diff-review-gate`** again until the human answers `approve-diff`. Writes `.cursor/gates/commit-approved/<slug>`. Full path continues to `update-docs`; if the tree is still dirty after docs, run **`local-diff-review-gate`** once more, then **`propose-commit`** again for residual files, then `create-pr`. Manual `/lgt-engineer-review` does not auto-start `local-diff-review-gate` or `propose-commit`.

---

## 9. Propose-commit (commit gate)

```mermaid
flowchart TD
  reviewDone(["Review settled + teach-review handled"])
  localDiff[["local-diff-review-gate"]]
  hitlDiff[/"HITL: approve-diff / comment"/]
  reReview[["engineer-review + teach-review miss"]]
  propose[["propose-commit"]]
  hitlCommit[/"HITL: approve-commit / revise"/]
  revise["Re-propose message + file list"]
  stageCommit["Stage listed paths + git commit"]
  writeCommit{{".cursor/gates/commit-approved/slug"}}
  toDocs(["update-docs or create-pr"])

  reviewDone ==> localDiff
  localDiff ==> hitlDiff
  hitlDiff -->|"approve-diff"| propose
  hitlDiff -.->|"comment — Loop"| reReview
  reReview ==> localDiff
  propose ==> hitlCommit
  hitlCommit -->|"revise"| revise
  revise --> propose
  hitlCommit -->|"approve-commit"| stageCommit
  stageCommit ==> writeCommit
  writeCommit ==> toDocs
```

| Rule | Detail |
|------|--------|
| When | After engineer-review (or `csp-multi-repo-supervisor`) settles and Teach-review miss is handled; again on full path if docs left uncommitted files (local-diff-review-gate then propose-commit) |
| Local Diff Review | Skill `local-diff-review-gate` — HITL `approve-diff` / `comment`; plugin canvas; never commit/push/PR inside that gate; required before propose-commit even after `no_miss` |
| HITL | `approve-commit` / `revise` via skill `hitl-choice` preset **Propose commit** |
| Marker | `.cursor/gates/commit-approved/<slug>` written on `approve-commit` |
| Never | `git push`, `gh pr create`, `git add -A`, commits on default branch, jump from `no_miss` straight to `approve-commit` |
| Zero commits until gate | `csp-software-developer` / `csp-bug-fixer` must not product-commit; branch may be 0 commits ahead of base until this gate |

---

## 10. Marker state machine

Runtime markers live in the **consumer project** `.cursor/gates/<kind>/<slug>` (never the kit). Parallel tickets use different slugs; a foreign slug never blocks this plan. Stop hooks emit `followup_message` only when the current plan path is known and that slug is pending. Unknown plan path stays silent — listing every open slug auto-continues unrelated chats and cannot be cleared there. Legacy flat files (`.cursor/*.pending`, `plan-critique.clear`) migrate-on-read then delete.

```mermaid
stateDiagram-v2
  [*] --> Idle

  Idle --> PlanGate: approve-plan writes plan-gate/slug
  PlanGate --> CritiqueGate: approve-plan + critic starts
  PlanGate --> PlanGate: revise clears this slug plan-critique-clear
  CritiqueGate --> CritiqueClear: Verdict clear
  CritiqueGate --> CritiqueGate: blocked / pending accept
  CritiqueClear --> Building: start-build + csp-software-developer
  Building --> ReviewGate: /lgt-finish-plan writes review-gate/slug
  ReviewGate --> Reviewing: skip / approve / done
  ReviewGate --> Building: fixes then csp-software-developer
  Building --> ReviewGate: re-ask review-gate
  Reviewing --> Reviewing: Needs clarification
  Reviewing --> LocalDiffGate: local-diff-review-gate
  LocalDiffGate --> Reviewing: comment Loop
  LocalDiffGate --> CommitGate: approve-diff then propose-commit
  CommitGate --> DocsGate: update-docs writes docs-gate/slug
  DocsGate --> LocalDiffGate: residual local-diff-review-gate if dirty
  DocsGate --> CommitGate: residual propose-commit if dirty
  DocsGate --> [*]: skip / publish complete
  DocsGate --> DocsGate: waiting location follow-up
  CommitGate --> [*]: fast / issue path to create-pr

  note right of CritiqueClear
    plan-critique-clear/slug must match this plan path
  end note
```

| Marker | Written by | Cleared when |
|--------|------------|--------------|
| `.cursor/gates/plan-gate/<slug>` | `approve-plan` | Human replies `approve-plan` |
| `.cursor/gates/critique-gate/<slug>` | after plan approval | `Verdict: clear` |
| `.cursor/gates/plan-critique-clear/<slug>` | on `Verdict: clear` | invalidated on `revise` / re-approve |
| `.cursor/gates/review-gate/<slug>` | `/lgt-finish-plan` (`review-gate` HITL) | `skip` / `approve` / `done` |
| `.cursor/gates/commit-approved/<slug>` | `propose-commit` on `approve-commit` | consumed by `create-pr` / next pipeline step |
| `.cursor/gates/docs-gate/<slug>` | `update-docs` | `skip` or publish/abort complete |

---

## 11. Standalone entry points (bypass full orchestrator)

```mermaid
flowchart LR
  writeSpec["/lgt-write-tech-spec"] --> techOnly[["tech-spec only"]]
  critique["/lgt-critique-plan"] --> criticOnly[["implementation-critic ad-hoc"]]
  approve["/lgt-approve-plan"] --> approveFlow[["approve + critic + start-build"]]
  build["/lgt-start-build"] --> buildOnly[["requires this slug plan-critique-clear"]]
  finish["/lgt-finish-plan"] --> finishFlow[["review-gate HITL then review"]]
  eng["/lgt-engineer-review"] --> reviewDirect[["skip review-gate HITL"]]
  docs["/lgt-update-docs"] --> docsFlow[["HITL destination then write"]]
  pr["/lgt-pr-review"] --> prWrap[["PR wrapper: canvas + report-only Findings"]]
  multi["/lgt-multi-review"] --> multiDirect[["csp-multi-repo-supervisor"]]
  issue["/lgt-start-issue-task"] --> issuePipe[["Jira MCP + csp-bug-fixer + create-pr finale"]]
  fast["/lgt-start-task --fast"] --> fastPipe[["fetch + brief + mode:fast + review + create-pr finale"]]
  escape["/lgt-capture-escape"] --> dest[/"miss vs project_secret"/]
  dest -->|miss| teachEsc[["teach-review"]]
  dest -->|project_secret| learnPipe[["csp-review-learn capture production-escape"]]
```

`/lgt-critique-plan` alone does **not** write `plan-critique-clear/<slug>` for build — prefer `/lgt-approve-plan` so plan HITL is not skipped.

`/lgt-pr-review` resolves a GitHub PR, optionally builds a **PR Review Canvas** (Cursor plugin `pr-review-canvas`; skip with `no-canvas`), then runs the same engineer-review phases. Canvas orients the diff; validated Findings remain the review contract.

---

## 12. Fast mode (`/lgt-start-task --fast`)

```mermaid
flowchart TD
  startFast(["/lgt-start-task --fast ac-source"])
  looksJira{Looks like Jira?}
  fetch[["jira-fetch"]]
  inProgress[["jira-transition in_progress"]]
  fastVsIssue[/"HITL Fast vs issue if class bug"/]
  boot["Bootstrap"]
  brief["Short AC brief in chat"]
  exec["csp-software-developer mode:fast"]
  review["csp-engineer-reviewer no review-gate HITL"]
  localDiff[["local-diff-review-gate"]]
  commitNode[["propose-commit HITL approve-commit"]]
  prNode[["create-pr draft then HITL finale"]]
  doneFast(["PR URL"])

  startFast ==> looksJira
  looksJira -->|"yes"| fetch --> inProgress --> fastVsIssue --> boot
  looksJira -->|"no"| boot
  boot ==> brief ==> exec ==> review ==> localDiff ==> commitNode ==> prNode ==> doneFast
```

No tech-spec, writing-plans, approve-plan, critic, review-gate, or update-docs. Clarify HITL only if engineer-review needs it. `--fast` is explicit only.

---

## 13. Issue mode (`/lgt-start-issue-task`)

```mermaid
flowchart TD
  startIssue(["/lgt-start-issue-task jira-key"])
  boot["Bootstrap"]
  jira[["jira-fetch getJiraIssue"]]
  jiraFail{MCP ok?}
  stopJira[/"Stop: paste ticket text"/]
  inProgress[["jira-transition in_progress"]]
  planFix["Write fix plan"]
  critic["implementation-critic Pass A B C"]
  verdict{Verdict clear?}
  hitlCrit[/"HITL: revise or accept F-id"/]
  fixer["csp-bug-fixer"]
  review["csp-engineer-reviewer"]
  localDiff[["local-diff-review-gate"]]
  commitNode[["propose-commit HITL approve-commit"]]
  prNode[["create-pr draft then HITL finale"]]
  doneIssue(["PR URL"])

  startIssue ==> boot ==> jira ==> jiraFail
  jiraFail -->|"no"| stopJira
  jiraFail -->|"yes"| inProgress ==> planFix ==> critic ==> verdict
  verdict -->|"blocked or pending accept"| hitlCrit
  hitlCrit --> planFix
  verdict -->|"clear"| fixer ==> review ==> localDiff ==> commitNode ==> prNode ==> doneIssue
```

Always this path when `/lgt-start-issue-task` is invoked explicitly (even if type is Story). After fetch, `jira-transition` target `in_progress`. Jira comment options appear on the Pipeline finale when `jira_key` is known. `ready` / `ready_jira` run `jira-transition` target `review` only after every opened pull request is merged and continuous integration succeeded. Never `gh pr merge`.

---

## 14. Create-pr Pipeline finale

```mermaid
flowchart TD
  startPr["create-pr"]
  draft["Always draft first"]
  hitl[/"HITL Pipeline finale"/]
  keep["keep_draft"]
  ready["gh pr ready"]
  jiraC["addCommentToJiraIssue PR URL"]
  waitMerge["all PRs merged + CI success"]
  jiraRev[["jira-transition review"]]
  done(["Report PR URL"])

  startPr ==> draft ==> hitl
  hitl -->|"keep_draft"| keep --> done
  hitl -->|"ready"| ready --> waitMerge --> jiraRev --> done
  hitl -->|"keep_draft_jira"| jiraC --> done
  hitl -->|"ready_jira"| ready --> jiraC --> waitMerge --> jiraRev --> done
```

`keep_draft_jira` / `ready_jira` only when a Jira key is known. Never merge. `ready` / `ready_jira` with a key → wait until `pr_merge_ci_verdict` is `all_merged_ci_success`, then `jira-transition` target `review` (skip if already Review; report and continue on failure). `keep_draft` / `keep_draft_jira` leave the ticket In Progress.
