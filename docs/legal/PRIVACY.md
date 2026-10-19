# Privacy Policy — Loregate

**Effective date:** 29 September 2026  
**Author / operator of this kit:** Andrey Trembak (`a-trembak`)  
**Product:** **Loregate** (short mark **LGT**). GitHub repository: [a-trembak/loregate](https://github.com/a-trembak/loregate) (formerly `cursor-spells`).

This Privacy Policy describes how personal and project data may be handled when you install or use the **Loregate** pipeline kit (skills, slash commands, rules, hooks, agents, and related scripts). It is written for honesty about a **local developer toolkit**, not a hosted consumer product.

This document is **not** a substitute for the privacy policies of Cursor, GitHub, Jira, Slack, Model Context Protocol tool providers, model hosts, or any other third party you connect.

---

## 1. Who controls what

| Layer | Who typically controls data |
|-------|-----------------------------|
| This kit’s files on your machine | **You** (your disk, your checkout, your `~/.cursor` links) |
| Cursor IDE / agent runtime / chat | **Cursor** and the model providers Cursor uses |
| Your project repositories | **You** and your Git / GitHub / forge hosts |
| Model Context Protocol servers you enable | **Those third-party operators** (and their policies) |
| Ticketing, chat, calendar, or similar integrations | **Those third-party operators** |
| The public `loregate` GitHub repository (formerly `cursor-spells`) | Public content you push or issues you open are under GitHub’s and this repository’s terms |

**The kit author does not operate a central Loregate cloud that receives your agent chats or project files by default.** Installing the kit copies or links files onto machines you control. The author cannot see your local chats, local project contents, or your Model Context Protocol credentials unless you separately send them (for example by opening a GitHub issue that pastes logs).

---

## 2. What this kit may cause to be processed

Depending on how you configure Cursor and which integrations you enable, use of this kit may involve:

1. **Agent chat and prompts** — instructions from kit skills/commands/agents, plus your messages and any context the agent attaches.
2. **Project files and diffs** — source code, specs, plans, review reports, and gate markers under paths such as `.cursor/gates/`.
3. **Install artifacts under `~/.cursor`** — symlinks or copies of skills, commands, agents, rules; kit path markers; optional learn/land preference files (for example `cursor-spells-learn.json`).
4. **Project install artifacts** — hooks, rules, helper scripts, and markers written into consumer projects by `csp install` / `csp update`.
5. **Pipeline journals and metrics** — stage tokens, scores, and similar operational records if you run the pipeline (designed to avoid dumping full chat transcripts; still treat journals as potentially sensitive).
6. **Third-party Model Context Protocol tools** — whatever those tools send to their backends when invoked (issue trackers, messaging, calendars, docs search, and so on).
7. **GitHub / forge traffic** — clones, pulls, pushes, pull requests, and continuous-integration logs when you or agents use `git` / `gh`.
8. **Optional third-party skills** — packages fetched via tools such as `npx skills add` when not skipped.

The kit **does not** require you to create a Loregate account. It **does not** embed a proprietary analytics backend owned by the author.

---

## 3. What the author does **not** control

Be clear about limits:

- The author **cannot** prevent Cursor, model providers, or Model Context Protocol servers from logging or training on data once you send it through those systems.
- The author **cannot** guarantee that agents will never over-share context; agent behavior depends on models, host settings, and your prompts.
- The author **cannot** delete data held by third parties; you must use each provider’s tools and policies.
- Public forks, mirrors, and copies of this repository are outside the author’s operational control.

If you need data to stay on-device, prefer local models and disable or carefully scope cloud Model Context Protocol servers and remote agent features. See also privacy-oriented guidance on local versus cloud AI processing (Sources).

---

## 4. How data is used (by design of the kit)

Within the kit’s intended design:

- Files are used to **drive local agent workflows** (planning, coding, review, gates, docs).
- Preference markers (language, land mode, skill profile, and similar) are used to **configure the next agent step** on your machine.
- Review and metrics helpers may **write local reports** so humans can audit agent work.

The author does **not** sell your personal data. The author does **not** run ads against kit users. If you contact the author (email, GitHub), that correspondence is used only to respond and to maintain the project.

---

## 5. Sharing

Data may leave your machine when **you** (or an agent acting for you) use:

- Cursor and its model backends  
- GitHub or other forges  
- Model Context Protocol servers and their upstream APIs  
- Continuous-integration systems  
- Any other tool you authorize  

Those transfers are governed by **those parties’** policies, not by a cursor-spells hosted service.

---

## 6. Retention

- **Local kit and project files** remain until you delete them, uninstall links, or wipe the machine.
- **Third-party retention** follows each provider’s policy.
- **Public GitHub content** (issues, pull requests, commits) may persist indefinitely under forge norms.

---

## 7. Your choices

You can:

- Install with `--user-only` or skip third-party skills (`--skip-third-party-skills` / `CSP_SKIP_THIRD_PARTY_SKILLS=1`) to reduce surface area.
- Disable Model Context Protocol servers you do not trust.
- Avoid pasting secrets into chats, issues, or review reports.
- Remove `~/.cursor` links and project `.cursor` kit files when you stop using the kit.
- Use private repositories and restrict agent permissions in your host IDE.

---

## 8. Children

This kit is intended for professional software development. It is not directed at children.

---

## 9. Language and sanctions note

Under this kit’s **sanctions-based language policy**, the **Russian language is forbidden** inside this pipeline (agent communication and pipeline language settings). Users who need Russian-language tooling should use tools **outside** this pipeline. Policy detail and runtime enforcement live in [`docs/superpowers/pipeline-language.md`](../superpowers/pipeline-language.md) (and related rules/helpers when present). This Privacy Policy does not itself implement that ban.

---

## 10. Changes

The author may update this policy by committing a new version to the repository. The “Effective date” at the top will change when material updates ship. Continued use after an update means you should re-read this file.

---

## 11. Contact

Privacy questions about **this kit’s documentation** (not about Cursor or other vendors): open a GitHub issue on [a-trembak/loregate](https://github.com/a-trembak/loregate) or contact the repository owner `a-trembak`.

For Cursor, GitHub, or Model Context Protocol vendor questions, contact those organizations directly.

---

## Related documents

- [Terms of use / rights notice](TERMS.md)  
- [Disclaimer of warranty & limitation of liability](DISCLAIMER.md)  
- [Trademark / rights protection mark](NOTICE.md)  
- [Sources consulted](SOURCES.md)  
