# English expansions and before/after examples

Load when drafting English chat (or when language is unset / `en`). For `uk`, use [`uk.md`](uk.md).

## Expand these (not exhaustive)

| Forbidden in chat | Write instead |
|-------------------|---------------|
| PR | pull request |
| CI / CD | continuous integration / continuous delivery |
| HITL | human-in-the-loop / step that needs a human answer |
| AC | acceptance criteria |
| SHA | commit hash |
| P0 / P1 / P2 | highest / high / medium severity |
| MCP | Model Context Protocol |
| TTL | time-to-live |
| JWT | JSON Web Token |
| WIP | work in progress |
| LGTM | looks good to me |
| nits | minor remarks |
| PoC | proof of concept |
| LOC | lines of code |
| UI | user interface |
| API | application programming interface (or name the concrete interface) |

Never use Latin letter clumps as standalone words in chat.

## Before / after (abbreviations)

**Before:** CI failed on the PR after HITL. SHA `abc1234`, this is P0.

**After:** Continuous integration failed on the pull request after the step that needs a human answer. Commit hash `abc1234`. This is highest severity.

## Before / after (proposal shape)

**Before (forbidden):**

```
full host list (or allowlist generation rule from white-label configs);
SameSite (Lax vs None) under same-site cross-origin;
cookie-on-API + cross-site request forgery protection or separate backend-for-frontend / same-origin proxy;
who / where the configurator repo is and one-shot handoff;
Domain cookie: host-only on API or .energysave.se.
```

**After (required):**

```
We need to decide how browser cookies should work between marketing sites and the application programming interface server.

Option A — cookie only on the application programming interface host.
The browser stores the session only on that host. This is simpler, but marketing sites on other domains will not see this cookie directly.

Option B — cookie on the shared parent domain `.energysave.se`.
All sites under that domain can see the session. This is more convenient for sign-in, but widens the leak surface if any subdomain is compromised.

Option C — a separate backend-for-frontend on the same origin as the page.
The page talks only to its proxy; cross-site request forgery protection gets simpler. This is more infrastructure work.

Recommendation: option C if white labels already have a proxy; otherwise option A plus an explicit allowlist of hosts from white-label configs.
```
