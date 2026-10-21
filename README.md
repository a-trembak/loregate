# Loregate

![Loregate LGT logo](docs/legal/lgt-logo.png)

**Loregate** (short mark **LGT**) — from lore to merge through gates.

Personal workflow kit — skills, slash commands, rules, hooks, and agents. Author: Andrey Trembak (`a-trembak`). Brand lock and GitHub rename note: [`docs/legal/NAME-OPTIONS.md`](docs/legal/NAME-OPTIONS.md). Do not put “Cursor” in the product title.

> GitHub repository: [`a-trembak/loregate`](https://github.com/a-trembak/loregate) (formerly `cursor-spells`). In-repo CLI and commands are `lgt` / `/lgt-*` (deprecated `/csp-*` stubs still forward).

## Developing this kit (no pipeline dogfood)

When the workspace **is** this repository, do **not** run `/lgt-start-task` (or deprecated `/csp-start-task`), `/lgt-start-issue-task`, or ask Pipeline route to ship kit changes — that recurses the pipeline onto itself. Edit kit files directly; use ordinary branches and draft pull requests. Rule: [`rules/kit-no-pipeline-dogfood.mdc`](rules/kit-no-pipeline-dogfood.mdc) (kit-only; not copied by `lgt install`). Manual checklists under [`docs/superpowers/dogfood/`](docs/superpowers/dogfood/) remain the way to verify kit behavior.

## Install & update

**Do not clone this repo into every app.** Keep **one** checkout of Loregate, then point each project at it.

### First-time install

```bash
# 1) Clone the kit once
git clone https://github.com/a-trembak/loregate.git ~/loregate

# 2) Optional: put `lgt` on PATH
echo 'export PATH="$HOME/loregate/bin:$PATH"' >> ~/.bashrc   # or ~/.zshrc
source ~/.bashrc

# 3) Install into a project (path optional when already inside the repo / multi-repo)
#    Non-interactive: pass --agree-policy (or --i-agree) after reading docs/legal/
lgt install /path/to/your-app --agree-policy
cd /path/to/your-app && lgt install --agree-policy   # same — path defaults to this repo
lgt install /path/to/your-app --agree-policy --language uk  # chat language (--lang / LGT_PIPELINE_LANGUAGE (alias CSP_PIPELINE_LANGUAGE))
cd /path/to/multi-repo-workspace && lgt update --agree-policy
```

**Public policy at install:** you must agree to [`docs/legal/`](docs/legal/) (Privacy, Terms, Disclaimer, NOTICE) before install or update continues. Interactive terminals get a yes/no prompt with paths to those files. Scripts and continuous integration must pass `--agree-policy` / `--i-agree` (or `LGT_AGREE_POLICY=1 (alias CSP_AGREE_POLICY=1)`). Acceptance is recorded in `~/.cursor/lgt-policy-accepted` and, for project installs, also `<project>/.cursor/lgt-policy-accepted`, with `accepted_at`, `agree_via`, `policy_hash`, `policy_docs`, `kit_commit`, and `kit_root`. Matching hash skips the prompt on later runs; a changed policy requires a fresh agreement. A valid user-level acceptance can seed a project marker. Product name **Loregate** / **LGT**; GitHub id [`a-trembak/loregate`](https://github.com/a-trembak/loregate): [`docs/legal/NAME-OPTIONS.md`](docs/legal/NAME-OPTIONS.md).

Useful flags: `--agree-policy` / `--i-agree` (accept public policy), `--humanizer` (also link `english-humanizer`), `--user-only` (only `~/.cursor`, no project files), `--copy` (copy instead of symlink), `--skip-third-party-skills` (do not run `npx skills add` for mapped third-party skills; same as `LGT_SKIP_THIRD_PARTY_SKILLS=1 (alias CSP_SKIP_THIRD_PARTY_SKILLS=1)` on air-gapped machines).

**Why `--user-only` agents may not show in Cursor**

`--user-only` only creates links under `~/.cursor/agents/` (user-global). They are **not** a separate “Custom Agents” product mode — they are **subagents** (`@csp-engineer-reviewer`, `@csp-pr-reviewer`, …). After install: **Reload Window**. Cursor **CLI** completions often list only `<project>/.cursor/agents/` — for agents that always appear in the open project, run `lgt install` / `lgt update` **without** `--user-only` (that also mirrors agents into the project).

Check: `ls -la ~/.cursor/agents` and (after full install) `ls -la .cursor/agents`.

### Update (kit + links)

```bash
lgt update /path/to/your-app   # git pull the kit, then re-sync ~/.cursor + project files
cd /path/to/your-app && lgt update   # path optional — current repo / workspace
lgt update                     # git pull + refresh ~/.cursor only (when cwd is not a project)
lgt install --user-only --agree-policy   # ~/.cursor only (also: lgt update --user-only --agree-policy)
lgt status                     # kit path, commit, what is linked
```

**Default project when path is omitted**

1. Git toplevel of the current directory (works inside a leaf repo of a multi-repo)
2. Else cwd if it has `.cursor/multi-repo.json` or `graphify-out/`
3. Else cwd if it contains 2+ immediate child git repos (workspace parent)
4. Else: `lgt update` refreshes `~/.cursor` only; `lgt install` errors — pass a path or `--user-only`

Installing into the Loregate kit checkout itself is refused on `install`. On `update`, that case also falls back to refreshing `~/.cursor` only.
With **symlink** mode (default), `git pull` in the kit already refreshes skill/command/agent *contents*; `lgt update` still matters to **add new** skills/commands/agents and to **refresh** project hooks/rules. With `--copy`, `lgt update` is required to refresh copied bodies.

### What install creates

Two places: **Cursor user dir** (`~/.cursor`) and **the project**.

#### A) `~/.cursor/` (always on `install` / `update`)

| Path | Action |
|------|--------|
| `~/.cursor/skills/<name>` | Symlink → `<kit>/skills/<name>` for every skill in the kit (`english-humanizer` only with `--humanizer` or if already present) |
| `~/.cursor/commands/<file>.md` | Symlink → `<kit>/commands/…` (all slash commands) |
| `~/.cursor/agents/<file>.md` | Symlink → `<kit>/agents/…` (all agents, including `review-*`) |
| `~/.cursor/rules/plain-language-chat.mdc` | Copied / refreshed — always-on full-words, full-sentence chat in the selected pipeline language (pipeline gate rules stay project-only) |
| `~/.cursor/rules/pipeline-language-no-russian.mdc` | Copied / refreshed — sanctions policy: never use Russian in agent chat or language settings |
| `~/.cursor/rules/code-via-coding-agents.mdc` | Copied / refreshed — parent chat must dispatch `csp-software-developer` / `csp-bug-fixer` for product code |
| `~/.cursor/statusline-loregate.sh` | Copied / refreshed — optional Cursor Agent CLI two-line context-spend status (enable in `cli-config.json`; see below) |
| `~/.cursor/extensions/loregate-context-spend-status-<version>/` | Copied / refreshed — IDE status bar context-spend proxies (Reload Window after install; see below) |
| `~/.cursor/cursor-spells-kit-path` | Text file with absolute path to this kit checkout |
| `~/.cursor/cursor-spells-learn.json` | Created if missing — `land` (`draft_merge` default / `auto_push`); never overwritten on update |
| `~/.cursor/lgt-policy-accepted` | Written on every install/update after public policy agreement (`accepted_at`, `agree_via`, `policy_hash`, …) |
| mapped third-party skills (`npx skills add`) | Curated ids from [`skill-map.md`](skills/engineer-review/references/skill-map.md); skip with `--skip-third-party-skills` / `LGT_SKIP_THIRD_PARTY_SKILLS=1 (alias CSP_SKIP_THIRD_PARTY_SKILLS=1)`; `npx` failure is `skill_missing`, not a failed kit install |

Directories `skills/`, `commands/`, `agents/` are created if missing. Existing **foreign** files/symlinks are never overwritten.

### CLI context-spend status line (Cursor Agent CLI)

Install copies `scripts/statusline-loregate.sh` to `~/.cursor/statusline-loregate.sh`. **Install does not edit** your CLI config — add this once to `~/.cursor/cli-config.json`:

```json
"statusLine": {
  "type": "command",
  "command": "~/.cursor/statusline-loregate.sh",
  "updateIntervalMs": 500,
  "timeoutMs": 2000,
  "padding": 2
}
```

Example render (proxies from the CLI context ring and on-disk pipeline gates — **not** API billing or token invoices):

```text
cursor  Opus  ctx 68% ███████░░░  ring
pipe  full·eng-review  +12pp/stage  peak:tech-spec(+28)  ⚠+18  hint:cut-clarify
```

- **pp** — percentage points on the context ring scale (`50%` → `68%` is **+18pp**, not “+18% of 50”).
- **peak:&lt;stage&gt;(+N)** — largest per-stage ring growth this session; use it to pick which pipeline stage to thin first.
- **⚠+N** — same number as **+Npp/stage** when that per-stage delta is ≥ **15** (alert threshold; growth since this stage started in the session).
- **hint:&lt;token&gt;** — fixed optimization lever for the **current** stage only (not for peak).

| Hint token | Typical lever |
|------------|----------------|
| `thin-spec` | Shorter tech spec / acceptance criteria |
| `thin-plan` | Smaller implementation plan |
| `compact-critic` | Tighter critic prompts / returns |
| `slim-handoff` | Less nested Task paste into parent chat |
| `cut-clarify` | Shorter engineer-review clarify loops |
| `less-diff-paste` | Smaller local-diff review payloads |
| `short-docs` / `short-pr` | Trim docs or pull-request body bulk |

Full behavior, snapshot rules, and stage mapping: [`docs/superpowers/specs/2026-10-21-cli-context-spend-statusline-design.md`](docs/superpowers/specs/2026-10-21-cli-context-spend-statusline-design.md). Manual checks: [`docs/superpowers/dogfood/cli-context-spend-statusline-checklist.md`](docs/superpowers/dogfood/cli-context-spend-statusline-checklist.md).

### IDE context-spend status bar (Agent Window)

Install copies the compiled extension from `extensions/context-spend-status/` to `~/.cursor/extensions/loregate-context-spend-status-<version>/` (package manifest, README, and `out/` only). **Reload Window** once after install or update so Cursor loads it.

The status bar shows pipeline **route and stage** (`pipe …`) for Agent Window users. Click the item to open an Output channel with drill-down text.

**Peak / ⚠ deltas need snapshots.** The IDE extension does **not** see Cursor’s context-ring percentage, so it does not write `.cursor/gates/context-spend/snapshots.jsonl`. Those files are written by the **CLI** status line above. With Agent Window only, you still see stage; peak and the 15pp warning appear after the CLI status line has recorded snapshots in that project (same store both surfaces read).

Design: [`docs/superpowers/specs/2026-10-21-ide-context-spend-statusbar-design.md`](docs/superpowers/specs/2026-10-21-ide-context-spend-statusbar-design.md). Manual checks: [`docs/superpowers/dogfood/ide-context-spend-statusbar-checklist.md`](docs/superpowers/dogfood/ide-context-spend-statusbar-checklist.md).

Consumer projects may add `.cursor/gates/context-spend/` to `.gitignore` if they do not want debounced context snapshots in version control.

#### B) `<project>/` (path argument, or auto-detected cwd repo / multi-repo workspace)

| Path | Action |
|------|--------|
| `<project>/.cursor/skills|commands|agents/` | Same kit entries as in `~/.cursor` (so this project’s Cursor UI/CLI sees them) |
| `<project>/.cursor/hooks/post-plan-review-gate.sh` | Copied from kit (refreshed on every install/update) |
| `<project>/.cursor/hooks/pre-build-gate.sh` | Copied from kit (refreshed on every install/update) |
| `<project>/.cursor/hooks.json` | Created if missing; **refreshed on `update`** |
| `<project>/.cursor/rules/after-plan-review-gate.mdc` | Copied / refreshed |
| `<project>/.cursor/rules/before-build-critique-gate.mdc` | Copied / refreshed |
| `<project>/.cursor/rules/clean-decision-docs.mdc` | Copied / refreshed — specs/plans stay final-form (no revision archaeology) |
| `<project>/.cursor/rules/hitl-askquestion.mdc` | Copied / refreshed — closed-set HITL must call AskQuestion first |
| `<project>/.cursor/rules/plain-language-chat.mdc` | Copied / refreshed — chat with the human uses full words and full sentences in the selected pipeline language |
| `<project>/.cursor/rules/pipeline-language-no-russian.mdc` | Copied / refreshed — sanctions policy: Russian language never allowed in agent communication or pipeline language settings |
| `<project>/.cursor/rules/code-via-coding-agents.mdc` | Copied / refreshed — parent chat must dispatch coding agents for product code |
| `<project>/.cursor/cursor-spells-kit-path` | Absolute path to the kit |
| `<project>/.cursor/cursor-spells-learn.json` | Created if missing — same template; never overwritten on update. Project `land` wins over the user file |
| `<project>/.cursor/lgt-policy-accepted` | Also written on project install/update (`agree_via` may be `flag`, `prompt`, or `prior-user`) |
| `<project>/scripts/check-project-patterns.sh` | Optional CI helper — created once, refreshed on `update` |
| `<project>/scripts/extract-review-snippet.sh` | Helper for review evidence backfill (always refreshed) |
| `<project>/scripts/validate-review-report.sh` | Rejects Verdict/Blockers digests missing File/Jump/snippet (always refreshed) |
| `<project>/scripts/pipeline-gates.sh` | Per-plan gate helper — always refreshed |
| `<project>/scripts/pipeline-status.sh` | Orientation resolver — always refreshed |
| `<project>/scripts/pipeline-run-log.sh` | Pipeline run journal helper — always refreshed; recommend gitignore `.cursor/gates/run-log/` |
| `<project>/scripts/lgt-pipeline-language.sh` | Pipeline chat language get/set/validate — always refreshed; markers `.cursor/lgt-pipeline-language` and legacy `.cursor/csp-pipeline-language` |
| `<project>/scripts/jira-issue.sh` | Jira key / URL / type classifier — always refreshed |

Also ensures `<project>/.cursor/`, `.cursor/hooks/`, `.cursor/rules/`, and `scripts/` exist.

Runtime markers the agents write later (not created by install): `.cursor/gates/<kind>/<slug>` for `plan-gate`, `critique-gate`, `plan-critique-clear`, `review-gate`, `docs-gate` (legacy flat `.cursor/*.pending` / `plan-critique.clear` migrate-on-read), optional `.cursor/gates/run-log/` journals (gitignore recommended), plus `.cursor/project-patterns.md`. Stop hooks follow up only when the current plan path is known; they stay silent if the path is missing so a foreign slug cannot loop another chat.

### What update does (step by step)

1. `git pull --ff-only` inside the kit checkout (skips if no upstream).
2. Re-walks every kit `skills/*`, `commands/*.md`, `agents/*.md` and links/copies any **new** entries into `~/.cursor` (relinks owned symlinks).
3. If a project is targeted (explicit path or auto-detected cwd): refreshes hook scripts, rules, `hooks.json`, and the patterns helper as in the table above.

```
~/loregate/               ← one clone (source of truth)
        │
        │  lgt install / update
        ▼
~/.cursor/skills|commands|agents/   ← symlinks into the kit
your-app/.cursor/hooks|rules/       ← copies of gate hooks & rules
```

## Layout

```
bin/         CLI (`csp` → install / update / status)
skills/      Agent skills (SKILL.md)
commands/    Cursor slash commands
rules/       Persistent rules (install per project)
hooks/       Cursor hooks (templates for consumer projects)
agents/      Custom agent configs
scripts/     Install internals + CI helpers
docs/        Design specs, plans, dogfood checklists
evals/       Kit-only golden sets (trajectories, harness reports, code-quality) — not installed into apps
```

## Skills

| Skill | What it does |
|-------|----------------|
| [`hitl-choice`](skills/hitl-choice/) | HITL UX — AskQuestion (or alias) required first; typed tokens only after failed/missing tool |
| [`bug-fix`](skills/bug-fix/) | Root-cause bug fix — reproduce, minimal fix, regression test; used by `csp-bug-fixer` / `/lgt-start-issue-task` |
| [`jira-fetch`](skills/jira-fetch/) | Fetch Jira issue text via Atlassian MCP; classify Bug vs Story for `/lgt-start-task` routing |
| [`jira-transition`](skills/jira-transition/) | Move a fetched issue to In Progress (`/lgt-start-task`) or Review (`create-pr` after every opened pull request is merged and continuous integration succeeded) |
| [`create-pr`](skills/create-pr/) | Push + **draft** GitHub PR (requires `commit-approved` when commits were needed), then HITL Pipeline finale (`keep_draft` / `ready` / Jira comment). Never merge; Review transition after merge and successful builds |
| [`trajectory-score`](skills/trajectory-score/) | Record a trajectory ledger and hard-score it at wired pipeline stops; session ledger for full/fast/issue paths |
| [`trajectory-judge`](skills/trajectory-judge/) | Nested-Task judge for invented business facts and decision-doc archaeology; writes actions then re-scores |
| [`harness-status`](skills/harness-status/) | Kit harness inventory + last bench summary; orientation only (does not advance gates) |
| [`code-quality-score`](skills/code-quality-score/) | Hard-score kit code-quality fixtures (files / substrings / tests); no language-model judge |
| [`english-humanizer`](skills/english-humanizer/) | Strip AI tells from English bug reports, colleague messages, and PR comments |
| [`plain-language-chat`](skills/plain-language-chat/) | User-facing chat uses full words and full sentences in the **selected pipeline language** — no abbreviations or telegram fragment stacks; always-on via rule `plain-language-chat` |
| [`finish-plan`](skills/finish-plan/) | Plan→HITL handoff: `review-surface` (`SetActiveBranch` + Local Diff Review when installed) then review-gate; engineer-review still runs after |
| [`local-diff-review-gate`](skills/local-diff-review-gate/) | Pipeline-only HITL before `propose-commit` — Local Diff Review canvas (`approve-diff` / `comment`); applies comments; never commits or opens a pull request |
| [`propose-commit`](skills/propose-commit/) | Post-review HITL — propose commit message + file list; `approve-commit` / `revise`; `git commit` only (never push); writes `commit-approved` gate |
| [`update-docs`](skills/update-docs/) | Post-review HITL — product docs destination (`docs/` / docs repo / Confluence) + dual-audience writing |
| [`engineer-review`](skills/engineer-review/) | Multi-phase review orchestrator — snippets + file links + humanizer prose; P0–P2, chunking |
| [`implementation-critic`](skills/implementation-critic/) | Pre-code plan audit — Pass A/B (+ Pass C for bug-fix plans), must-fix/should-fix/accept-risk |
| [`tech-spec`](skills/tech-spec/) | Developer technical action plan — human always full system-design path; agent chooses light\|full; Blocker/Decision/Assumption on light path |
| [`system-design`](skills/system-design/) | Anthropic-style system design draft for tech-spec full path (format human plan or draft-from-ac) |
| [`system-design-critic`](skills/system-design-critic/) | Read-only audit of system-design drafts inside auto-consensus |
| [`code-comments`](skills/code-comments/) | Keep/remove taxonomy for comments — shared by developers and `csp-review-deadcode`; services forbid user-interface citations; React / frontend UI may reference screens, charts, or Figma |
| [`clean-decision-docs`](skills/clean-decision-docs/) | Specs/plans stay final-form decisions — no "fixed/changed to" archaeology after critique or revise |
| [`start-build`](skills/start-build/) | Thin build handoff — requires critique-clear plan, then `csp-software-developer`, **waits**, then `finish-plan` → `csp-engineer-reviewer` (no critic here) |
| [`approve-plan`](skills/approve-plan/) | HITL approve/revise the plan, then auto-run `implementation-critic`; on clear → `start-build` |
| [`pr-review`](skills/pr-review/) | PR-entry wrapper around engineer-review — canvas orientation + snippets + file links + humanizer prose; default report-only |
| [`teach-review`](skills/teach-review/) | After a shareable review miss (`miss`): generalize into kit instructions, `learn/…` branch, land via `cursor-spells-learn.json`. Project-private misses use `project_secret` instead. |
| [`software-developer`](skills/software-developer/) | Implements a cleared plan (or `mode:fast` AC brief) — feature branch(es), skill-map routing, code-comments, verify-before-handoff; web UI vs Figma via `ce-test-browser` |

## Agents

| Agent | Role |
|-------|------|
| `csp-software-developer` | Feature branch(es) then code to tech spec + plan after critic clear (or `mode:fast`) — routes skills, verifies; web → browser vs Figma |
| `csp-bug-fixer` | Reproduce → root cause → regression test → minimal fix — used by `/lgt-start-issue-task` |
| `csp-engineer-reviewer` | Orchestrator — phase agents; findings with snippets, clickable links, humanized What/Where/Why |
| `csp-pr-reviewer` | Same phases as engineer-reviewer; PR Review Canvas + Findings with snippets, clickable links, humanized prose |
| `csp-review-lint` | Runs real project tooling (eslint/tsc/checkstyle/…) — catches mechanical rule violations heuristic phases miss |
| `csp-review-logic` | Correctness + stack best practices |
| `csp-review-patterns` | Project patterns MD (create/enforce); frontend also compact-table / narrow-viewport gates (**V1–V4**) |
| `csp-review-deadcode` | Dead code, unused symbols, comment cleanup |
| `csp-review-simplify` | Cleanliness / reuse / local efficiency — primary `ce-simplify-code` + kit extensions |
| `csp-review-architecture` | Architecture gaps |
| `csp-review-performance` | Performance |
| `csp-review-security` | Security (conditional); always [security-hardening-checklist.md](skills/engineer-review/references/security-hardening-checklist.md) **S1–S11** when triggered; same checklist loaded by `csp-software-developer` / `csp-bug-fixer` on those surfaces |
| `csp-review-figma-markup` | Markup vs Figma (needs node URLs); always [figma-markup-checklist.md](skills/engineer-review/references/figma-markup-checklist.md) F1–F7; on web also `ce-test-browser` at tablet and phone, not only the desktop frame; [responsive-layout-checklist.md](skills/engineer-review/references/responsive-layout-checklist.md) V1–V4 |
| `csp-review-learn` | Load hints from kit seed + this project's private ledger; write `.cursor/review-learnings.md` only after `project_secret` |
| `csp-multi-repo-supervisor` | Supervises engineer-review across 2+ changed repositories |
| `csp-review-cross-repo` | Reports cross-repo contract drift as clarification-only findings |
| `csp-implementation-critic` | Audits a plan before code — Pass A/B (+ Pass C bug-fix), read-only |
| `csp-tech-spec` | Drafts technical action plan pre-plan — human plan → full path; agent light\|full; one question at a time, never invents business facts |
| `csp-system-design-designer` | Formats/drafts system-design for tech-spec full path |
| `csp-system-design-critic` | Critiques system-design drafts; no human asks mid-loop |

## Recommended third-party skills

```bash
npx skills add vercel-labs/agent-skills@vercel-react-best-practices
npx skills add vercel-labs/agent-skills@vercel-react-native-skills
npx skills add github/awesome-copilot@java-springboot
npx skills add affaan-m/everything-claude-code@security-review
npx skills add addyosmani/agent-skills@performance-optimization
npx skills add getsentry/warden@architecture-review
npx skills add abpai/skills@dead-code-eliminator
npx skills add everyinc/compound-engineering-plugin@ce-test-browser
# simplify phase primary (Cursor compound-engineering plugin — not always via npx):
# ensure ce-simplify-code is available under ~/.cursor/plugins/.../ce-simplify-code
# preferred when present for review scoping / multi-repo (optional install):
npx skills add graphify-labs/graphify@graphify
# PR Review Canvas (Cursor plugin — not npx): install "PR Review Canvas" / pr-review-canvas
# so /lgt-pr-review can emit a diff-orientation canvas (skip with no-canvas)
# Local Diff Review (Cursor plugin — not npx): install "Local Diff Review" / local-diff-review
# so /lgt-finish-plan review-surface can show uncommitted diffs in an Agent Window canvas
# (skill review-local-diff; escape with no-local-diff-review; chat git diff remains fallback)
# Database: always-on + current MySQL/MongoDB stack (same ids as skill-map Database skill routing).
# Conditional Postgres/Flyway/Prisma stay manual unless the consumer project uses them.
npx skills add wshobson/agents@database-migration
npx skills add affaan-m/everything-claude-code@database-migrations
npx skills add planetscale/database-skills@mysql
npx skills add affaan-m/everything-claude-code@mysql-patterns
npx skills add github/awesome-copilot@sql-code-review
npx skills add mongodb/agent-skills@mongodb-query-optimizer
npx skills add mongodb/agent-skills@mongodb-connection
npx skills add hoodini/ai-agents-skills@mongodb
```


Database migrations and schema changes are automatically routed to matching DB skills (MySQL, MongoDB, and conditional Postgres/Flyway/Prisma rows) via [`skill-map.md`](skills/engineer-review/references/skill-map.md#database-skill-routing)'s Database skill routing section. `lgt install` installs the always-on + current-stack ids from that map (skip with `--skip-third-party-skills`). Conditional Postgres/Flyway/Prisma rows stay manual unless the consumer project uses them. If a stack isn't covered by the map at all, the kit follows a two-tier skill resolution protocol: curated skills are used directly, anything else is presented to you for an explicit decision — never auto-installed mid-review.

**Skill profile (L2 depth):** set `.cursor/csp-skill-profile` to `strict` (default), `balanced`, or `expert`. Profiles change only **third-party enrichment** load depth. Kit miss-class checklists (security S1–S11, interaction replay, JPA gates, …) stay **L1** and open on triggers. See Skill classes / Load levels in [`skill-map.md`](skills/engineer-review/references/skill-map.md). Closed-set human gates use skill [`hitl-choice`](skills/hitl-choice/) — load **one** preset section from [`presets.md`](skills/hitl-choice/references/presets.md), not the whole catalog.

**Pipeline language:** set at install with `--language` / `--lang` / `LGT_PIPELINE_LANGUAGE (alias CSP_PIPELINE_LANGUAGE)`, or at `/lgt-start-task` / `/lgt-start-issue-task` bootstrap when unset (`hitl-choice` preset **Pipeline language**), or mid-session by asking the agent to switch (any allowed language). Preference persists in `.cursor/lgt-pipeline-language` (default `en`). Kit docs and canvas copy stay English. **Russian is impossible** in this pipeline (sanctions-based language policy) — user requests cannot override; use Russian only **outside this pipeline**. Rule `pipeline-language-no-russian`. Details: [`pipeline-language.md`](docs/superpowers/pipeline-language.md). Legal docs: [`docs/legal/`](docs/legal/).

When `graphify-out/` exists (or `graphify query` answers), the pipeline uses graphify to save tokens: skill [`graphify-pipeline`](skills/graphify-pipeline/SKILL.md) + [`scripts/graphify-pipeline.sh`](scripts/graphify-pipeline.sh) for **scope before code** (software-developer, bug-fix, implementation-critic) and **read-only scoping during** engineer-review ([`graphify-protocol.md`](skills/engineer-review/references/graphify-protocol.md)). After verified code changes, implement agents run **`graphify update`** via `graphify-pipeline.sh refresh` so review does not run on a stale graph. If graphify is absent, stages skip silently. On tiny non-risky diffs (≤3 files, ≤40 changed lines), engineer-review may skip low-value heuristic phases per [Tiny-diff heuristic phase skip](skills/engineer-review/references/phase-protocol.md#tiny-diff-heuristic-phase-skip) and must record `phase_skip: tiny-diff (…)` in Coverage.

## Usage

### English humanizer

- `@english-humanizer` / ask to humanize a PR comment or problem description
- Humanizer does **not** expand abbreviations. Chat with you still goes through [`plain-language-chat`](skills/plain-language-chat/) (always-on rule after `lgt update`)

### review-gate → HITL → engineer review

1. When coding from a plan is done: `/lgt-finish-plan` (this is the **review-gate** HITL, not another planning step). First it applies [`review-surface`](skills/finish-plan/references/review-surface.md): check out the feature branch in each open folder and call `SetActiveBranch` so the pull request tab shows the diff. That is **not** a GitHub pull request and **not** the pipeline end. When the branch has **zero commits ahead of base**, the tab may be empty — prefer the **Local Diff Review** canvas ([`local-diff-review`](skills/finish-plan/references/local-diff-review.md) / plugin skill `review-local-diff`; keep **Current thread** and press **Send**). Chat (`git status` / `git diff`) is the fallback when the plugin is missing (`skill_missing: review-local-diff`).
2. Answer via interactive buttons when offered (`AskQuestion`), or type `skip` / `approve` / `done`. Type `fixes` (or send canvas comments with `intent: apply-fixes`) to return to `csp-software-developer`, then the same gate. After `skip` / `approve` / `done`, **engineer-review** starts.
3. On frontend, use the Figma picker or paste node URLs / `no figma`
4. Orchestrator runs phases; applies **P0/P1** unambiguous fixes; lists clarifications separately

Comment cleanup and apply-vs-clarify decisions across all review phases now follow a strict [auto-fix eligibility test](skills/engineer-review/references/auto-fix-eligibility.md): a finding is only auto-applied if it's deterministic, has a single correct answer, loses no information, and has zero blast radius on data or user-facing behavior — otherwise it's always `clarify`, regardless of severity. User-facing findings **must** pass the hard [evidence gate](skills/engineer-review/references/evidence-gate.md) before emit: `path` + line range + real code fence + File/Lines/Jump links (GitHub `#L` on PR). [Forbidden](skills/engineer-review/references/forbidden-formats.md): Verdict/Blockers digests (and the same compact shape in other languages, including Ukrainian `Блокери`) without paths and snippets. Incomplete items are backfilled via `scripts/extract-review-snippet.sh` or dropped; draft reports must pass `scripts/validate-review-report.sh`. Shape: [feedback-format.md](skills/engineer-review/references/feedback-format.md).

**Manual review:** `/lgt-engineer-review` — evidence-gated snippets + file links; validator before emit; `english-humanizer` then `plain-language-chat` on prose.  
**PR review:** `/lgt-pr-review [url|number|branch] [apply] [no-figma] [no-canvas]` — same gate (plus required GitHub blob links); default PR Review Canvas for diff orientation (`no-canvas` to skip); never a Verdict/Blockers compact digest; report-only unless `apply`.

### Start a task (full pipeline)

**Canvas (layers, sequence, cycles):** interactive [`pipeline-flow.html`](docs/superpowers/pipeline-flow.html) · Mermaid source [`pipeline-flow.md`](docs/superpowers/pipeline-flow.md). Run `/lgt-pipeline-status` (or `scripts/pipeline-status.sh`) for a where-am-I strip and a canvas link with `?route=&layer=&stage=` highlight. Optional consumer run-log journals (`scripts/pipeline-run-log.sh`, see dogfood [`pipeline-run-memory-checklist.md`](docs/superpowers/dogfood/pipeline-run-memory-checklist.md)) enrich the strip — not kit-global chat memory. After code the graph names the HITL **`review-gate`** (skill `finish-plan` / command `/lgt-finish-plan` writes the marker). `fixes` returns to Build, not to `writing-plans`. Kit harness inventory: `/lgt-harness-status` (or `python3 scripts/harness-health.py`) — orientation only.

`/lgt-start-task [ac-source]` orchestrates the whole pipeline end-to-end, stopping only at the human-in-the-loop (HITL) gates that already exist — it never skips or softens any of them. Closed-set HITL asks **must** call Cursor **`AskQuestion`** (or alias) via skill [`hitl-choice`](skills/hitl-choice/) (rule `hitl-askquestion`); typed tokens only after the tool fails or is missing. When the AC source looks like a Jira ticket (`PROJ-123` or `*.atlassian.net` URL), it **fetches** via Atlassian MCP (`jira-fetch`), moves the ticket to **In Progress** (`jira-transition`), then **routes** (Bug → `/lgt-start-issue-task`; unknown type → HITL **Pipeline route**; never auto-selects `--fast`). Ends with skill [`create-pr`](skills/create-pr/) (draft PR, then HITL **Pipeline finale**).

1. Bootstraps context (project patterns, stack) — automatic
2. Runs `tech-spec` — **HITL** at entry (`human` / `agent`), depth (`light` / `full` when agent), any Blocker/Decision question (light path), and `approve-spec`/`revise`/`skip`
3. Generates the implementation plan via `writing-plans` — automatic once the spec's `Status` is `approved` or explicitly `skip`ped
4. `/lgt-approve-plan` — **HITL** `approve-plan`/`revise`, then **automatic** `implementation-critic`; **HITL** only if findings block; on `Verdict: clear` → `start-build`

On every `revise` of a spec or plan, agents follow [`clean-decision-docs`](skills/clean-decision-docs/): rewrite the file as current truth; put "what changed" in chat, not as changelog archaeology inside the document.
5. Executes via `csp-software-developer` (branch setup in target repo(s) → skill-map routing + Skill profile → `subagent-driven-development`) — automatic, no "which approach?" prompt in this flow
6. `review-gate` via `/lgt-finish-plan` — surface the diff (`SetActiveBranch` + Local Diff Review when installed) then **HITL** `skip`/`approve`/`done` (or `fixes` / canvas `apply-fixes` back to `csp-software-developer`). Pipeline continues.
7. `engineer-review` — phases honor Skill profile for L2; optional tiny-diff phase skip; **HITL** only for clarifications it raises
7b. [`local-diff-review-gate`](skills/local-diff-review-gate/) — **HITL** `approve-diff` / `comment` (plugin Local Diff Review; skip if clean / missing plugin)
8. [`propose-commit`](skills/propose-commit/) — **HITL** `approve-commit` / `revise`; stages listed paths and `git commit` only (never push); writes `.cursor/gates/commit-approved/<slug>`
9. `/lgt-update-docs` — **HITL** `skip` / `docs_md` / `docs_repo` / `confluence` (product docs destination; dual-audience write); residual **`propose-commit`** if docs left uncommitted files
10. `/create-pr` skill — **always draft first**, then HITL **Pipeline finale**: `keep_draft` / `ready` (`gh pr ready`), and `keep_draft_jira` / `ready_jira` when a Jira key is known (comment PR URL on the ticket). `ready` / `ready_jira` move the Jira issue to **Review** only after every opened pull request is merged and every continuous-integration build succeeded. Never merge.

Full `/lgt-start-task` **does** fetch Jira when the prompt looks like a ticket. MCP failure → stop and paste the ticket (never a URL-only stub). Writing AC is still out of scope. Explicit `/lgt-start-issue-task` always stays on the issue path even if the type is Story.

Prefer `/lgt-write-tech-spec [ac-source]` directly if you only want the tech spec, without triggering the rest of the pipeline.

### Start a task (fast — no planning HITL)

`/lgt-start-task --fast [ac-source]` for small work: bootstrap → fetch (if ticket-shaped) → short AC brief → `csp-software-developer` `mode:fast` → `csp-engineer-reviewer` (no review-gate HITL) → `local-diff-review-gate` → `propose-commit` → `create-pr` (Pipeline finale HITL). No tech-spec, plan approval, critic, or update-docs. **You** must pass `--fast`; the agent never chooses it. If the fetched type is Bug, HITL **Fast vs issue** asks `issue` vs `stay_fast`.

### Start an issue task (Jira bug fix)

`/lgt-start-issue-task [jira-key|url]` fetches the issue via **Atlassian MCP** (skill `jira-fetch`; stops if MCP fails — paste text then), moves it to **In Progress**, writes a fix plan, auto-runs `implementation-critic` (Pass A/B/**C**), HITL only if critic is blocked/pending accept, then `csp-bug-fixer` → `csp-engineer-reviewer` → `local-diff-review-gate` → `propose-commit` → `create-pr` (Pipeline finale; Jira comment options when the key is known; `ready` / `ready_jira` move the ticket to **Review** only after every opened pull request is merged and every continuous-integration build succeeded). Always this path when invoked explicitly, even if the type is Story.

**Pay-as-you-go / on-demand budget:** `/lgt-start-issue-task-on-demand [jira-key|url]` — same issue pipeline with a built-in orchestration contract (GLM 5.3 Flash in chat, Composer 2.5 for `csp-bug-fixer`, graphify scope + refresh, narrow context). Deprecated alias: `/csp-start-issue-task-on-demand`.

### Capture a production escape

`/lgt-capture-escape [what slipped]` records a production miss without a full `engineer-review`. It asks **Capture-escape destination**: `miss` writes kit instructions via `teach-review`; `project_secret` writes this project's `.cursor/review-learnings.md` only (client names that must not enter the kit).

`/lgt-teach-review [what slipped]` writes generalized **kit** instructions (not `.cursor/review-learnings.md`). After every settled engineer/PR review the orchestrator asks `miss` / `project_secret` / `no_miss`. Land config: `~/.cursor/cursor-spells-learn.json` and `<project>/.cursor/cursor-spells-learn.json` (created on `lgt install` if missing).

Design: [`docs/superpowers/specs/2026-08-04-bugfix-issue-fast-pipelines-design.md`](docs/superpowers/specs/2026-08-04-bugfix-issue-fast-pipelines-design.md) · Jira fetch + router + PR finale: [`docs/superpowers/specs/2026-08-16-jira-ac-router-finale-design.md`](docs/superpowers/specs/2026-08-16-jira-ac-router-finale-design.md)

### Update product docs

`/lgt-update-docs` asks where documentation should land, resolves style (existing house docs or a custom user/engineer guide — especially for a separate docs repo or Confluence), then writes prose (see [`skills/update-docs/references/writing-guide.md`](skills/update-docs/references/writing-guide.md)). Kit dual-audience default is only the fallback. Compose with:

- **`english-humanizer`** — strip AI filler from engineer sections (bundled)
- **`ce-compound`** (optional third-party) — durable solved-problem docs in `docs/solutions/`; not a substitute for product docs
- **`ce-explain`** (optional) — personal teaching artifacts; not a product-docs destination
- **`ce-promote`** (optional) — launch/announcement copy; separate from the docs body

```bash
npx skills add everyinc/compound-engineering-plugin@ce-compound
npx skills add everyinc/compound-engineering-plugin@ce-explain
```

### Approve plan → critic → build

`/lgt-approve-plan [path]` is the plan gate: the human reads the plan (`approve-plan` / `revise` via `hitl-choice` (AskQuestion required)), then `implementation-critic` runs **automatically** (no HITL to start it). On `Verdict: clear` it writes `.cursor/gates/plan-critique-clear/<slug>` and invokes `/lgt-start-build`. On `blocked` / `clear pending accept`, it stops for a revision or `accept F<id>`.

`/lgt-start-build [path]` no longer runs the critic — it starts `csp-software-developer` when this plan's `.cursor/gates/plan-critique-clear/<slug>` matches the plan, **waits for that agent to return**, then invokes `finish-plan` (human-in-the-loop, then `csp-engineer-reviewer`). Other slugs' pending gates do not block.

### Critique a plan before coding

`/lgt-critique-plan [path]` audits an implementation plan ad-hoc (complexity, risk, scope drift). Prefer `/lgt-approve-plan` in the pipeline so plan HITL is not skipped. If the report's `Verdict` is not `clear`, revise the plan or reply `accept F<id>` for a specific finding, then re-run.

For work spanning multiple sibling repos, see [Multi-repo review](#multi-repo-review).

### Multi-repo review

Use multi-repo review when a task changes **2+ sibling repositories**. If routing finds no changed repos, it stops with a message; if it finds one changed repo, the normal single-repo `csp-engineer-reviewer` path runs unchanged.

- Explicit `/lgt-multi-review` paths are the repo set for that run. Without explicit paths, discovery prefers graphify at the workspace parent, then existing parent `.cursor/multi-repo.json`, then a sibling scan.
- Single-repo and per-repo review also prefer graphify (when `graphify-out/` or the CLI can answer) to narrow deep-reads; without it, behavior is unchanged.
- `finish-plan` routing uses a non-mutating probe; parent `.cursor/multi-repo.json` is written only for a confirmed multi-repo run without graphify, or when `/lgt-multi-review --refresh` explicitly asks for it. It is never written inside a single leaf repo.
- Commands:
  - `/lgt-multi-review [path ...] [--refresh]` runs the multi-repo routing manually. Explicit paths override discovery for that run.
  - `/lgt-finish-plan` auto-routes after HITL approval: single-repo tasks use `csp-engineer-reviewer`; multi-repo tasks use `csp-multi-repo-supervisor`.
- Cross-repo contract drift is clarify-only in v1 (`C_CR*`); it is not auto-applied or listed under Fixed now.
- Jira/Linear **ticket→repo** discovery is deferred to v1.1. v1 routing uses explicit `/lgt-multi-review` paths, graphify, parent `.cursor/multi-repo.json`, or sibling scan. Jira **issue fetch** and **status transitions** (In Progress on start, Review when the PR is marked ready) for `/lgt-start-task` / `/lgt-start-issue-task` are in v1.

Design: [`docs/superpowers/specs/2026-07-22-multi-repo-supervisor-design.md`](docs/superpowers/specs/2026-07-22-multi-repo-supervisor-design.md)

**First run** writes `.cursor/project-patterns.md` in the consumer repo.

**Patterns CI (optional):** `scripts/check-project-patterns.sh --strict`  
Workflow template: [`scripts/templates/project-patterns.yml`](scripts/templates/project-patterns.yml)

**Dogfood checklist:** [`docs/superpowers/dogfood/engineer-review-checklist.md`](docs/superpowers/dogfood/engineer-review-checklist.md) · Jira fetch / router / PR finale: [`docs/superpowers/dogfood/jira-ac-router-finale-checklist.md`](docs/superpowers/dogfood/jira-ac-router-finale-checklist.md)

**Agent trajectory golden set:** kit-only contracts under [`evals/trajectories/`](evals/trajectories/) — what the agent must do, must not do, and where a human must appear. Validate with `python3 scripts/trajectory-cases.py validate`. Score a recorded run with `python3 scripts/trajectory-cases.py score --run <file>` (hard sensors only). Wired stops follow skill [`trajectory-score`](skills/trajectory-score/): fetch-fail scores `fetch-failure-stops`; `create-pr` scores `create-pr-draft-never-merge` (four-token) or `create-pr-draft-never-merge-no-jira` (two-token) after Pipeline finale is asked and before `gh pr ready`; remaining golden cases score at their natural stops; session ledgers score `full-happy-path` / `fast-skips-plan-layer` / `issue-happy-path` when a draft exists. Invented facts / archaeology go through skill [`trajectory-judge`](skills/trajectory-judge/) then re-score. Tests: `bash scripts/tests/trajectory-cases-test.sh`, `bash scripts/tests/trajectory-score-test.sh`, and `bash scripts/tests/trajectory-wiring-test.sh`. Not copied into consumer apps. Not a live agent runner. Overnight unsupervised loops and agent-to-agent teams without an orchestrator stay out of scope.

**Harness health / bench:** before changing skills or agents, run `bash scripts/harness-bench.sh` (all `scripts/tests/*.sh` plus trajectory validate + fixture score; writes `evals/harness/reports/<timestamp>.json` with `metrics.quality` pass rates, `metrics.speed` p50/p95/slowest, and `metrics.review_response_quality` (evidence/clarify/markdown sensors)). Inventory without a full bench: `python3 scripts/harness-health.py` or `/lgt-harness-status` (orientation only; prints quality/speed when a bench report exists). See [`evals/harness/README.md`](evals/harness/README.md) and [`docs/superpowers/dogfood/harness-health-checklist.md`](docs/superpowers/dogfood/harness-health-checklist.md).


**Live pipeline metrics (consumer runs):** during real ticket pipelines, agents append quality/speed rows via `scripts/pipeline-metrics.py` (`mark-start` after ledger init, `append-score` at trajectory score stops, `append-review` after a validated engineer-review report). History: `.cursor/gates/pipeline-metrics/history.jsonl`. Inspect with `summary`; graph with `export --format csv`. Contract: `bash scripts/tests/pipeline-metrics-test.sh`. **Diagrams + plain-language names:** [`docs/superpowers/pipeline-metrics-guide.md`](docs/superpowers/pipeline-metrics-guide.md).

**Code-quality evals:** kit-only hard sensors under [`evals/code-quality/`](evals/code-quality/) — expected files, forbidden paths, substrings, and shell tests. Validate with `python3 scripts/code-quality-cases.py validate`. Score golden fixtures with `python3 scripts/code-quality-cases.py score --runs-dir evals/code-quality/fixtures/pass`. Skill [`code-quality-score`](skills/code-quality-score/). Dogfood: [`docs/superpowers/dogfood/code-quality-evals-checklist.md`](docs/superpowers/dogfood/code-quality-evals-checklist.md).

Design: [`docs/superpowers/specs/2026-07-22-engineer-review-orchestrator-design.md`](docs/superpowers/specs/2026-07-22-engineer-review-orchestrator-design.md)

## License

MIT — steal freely, please sound human.

**Legal / policy docs:** [`docs/legal/`](docs/legal/) — [Privacy Policy](docs/legal/PRIVACY.md), [Terms](docs/legal/TERMS.md), [Disclaimer](docs/legal/DISCLAIMER.md), [Rights notice](docs/legal/NOTICE.md). Russian is impossible inside this pipeline under the sanctions-based language policy; use Russian only outside this pipeline — see [`pipeline-language.md`](docs/superpowers/pipeline-language.md). Working title **Loregate** (reserved): [`NAME-OPTIONS.md`](docs/legal/NAME-OPTIONS.md). Install requires `--agree-policy` (or an interactive yes) and writes `.cursor/lgt-policy-accepted`.
