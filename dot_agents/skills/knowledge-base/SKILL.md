---
name: knowledge-base
description: "Look up people, projects, products, and decisions locally first: contact info (email, Slack ID, GitHub handle), titles and teams, project/product status, who works on what, and past decisions. Check before searching Slack, email, calendar, or GitHub — this is the first stop for any contact detail, project context, or decision-history question."
license: MIT
metadata:
  provides:
    - knowledge-base
---

`kb` wraps a local vault of people, projects, and decisions. Check it before reaching for any remote service. Read `kb --help` and `kb <group> --help` on demand.

`kb` with no subcommand opens an interactive TUI — never invoke it bare from an agent session; it will hang waiting on a terminal.

## Coverage, and where it stops

| Need | Command |
|---|---|
| Contact fields for a person | `kb people show <name>` — resolves aliases; JSON |
| Everyone in the vault | `kb people list` |
| Write a journal entry | `kb journal append --date <YYYY-MM-DD> --section <heading> [--content <text>]` — stdin if `--content` omitted |
| Open action items | `kb action-items list`, then `complete`/`progress`/`todo <line_no>` |

**`people show` returns contact fields only** — no `github` handle, no project links, no body content. Those need the profile itself.

**Products, projects, and decisions have no CLI surface yet**, nor does any profile write. Until they do, those lookups read the vault directly — `kb people show` on a known person is the cheapest way to discover the vault root.

**`action-items` has no `add`** — new items become reminders or tracked issues instead.

## Gotchas

- **Journal stats come from git, not from any session store.** Agent session stores are pruned and harness-specific, so they can't supply older counts. `git log --all` double-counts pre-squash and merged copies of the same work and includes bot commits (`reg_actions`, `argocd-image-updater`) — filter to the human author and dedupe.
- **A person usually already exists under another name.** Look them up by alias before creating anything; the vault keeps variant→canonical maps, and a new profile for an existing person is the common corruption.
- **Never invent a URL.** Discover a workspace or org slug from entries already in the vault rather than guessing one.
- **Caps are deliberate:** max 5 current items and 10 key decisions per profile. Drop current items older than ~2 weeks with no recent mention.
- **A project is a durable service or named workstream** — not a feature, ticket, or infra task. Those become status bullets on the parent; time-bound efforts belong in the tracker.
