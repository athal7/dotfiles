---
name: knowledge-base
description: Local knowledge base of people, projects, and decisions — check here first before searching Slack, email, or calendar for contact info, project status, or decision history
license: MIT
metadata:
  provides:
    - knowledge-base
---

The knowledge base at `~/.local/share/kb/` is a distilled, maintained view of people, projects, and decisions.

## Structure

- `people/<slug>.md` — person profiles
- `projects/<slug>.md` — project profiles
- `decisions/log.md` — cross-source decision log
- `journal/YYYY-MM-DD.md` — daily dev journal
- `names.json` — display name → canonical name (people)
- `projects.json` — variant name → canonical name (projects, empty string = suppress)

## People profiles

Distilled reference cards, not meeting logs. Omit any section with no information.

    # Jane Smith
    - **Email**: jane@example.com
    - **Slack**: <@U123ABC>
    - **GitHub**: @janesmith
    - **Title**: Engineering Lead
    - **Team**: Platform
    ## Current
    - Leading infrastructure migration on [[Shield]]
    - Key contact for enterprise onboarding
    ## Style
    - Prefers short threads over long documents
    - Direct, action-oriented
    ## Personal
    - Based in Portland, two kids
    ## Key Decisions
    - Deprecate old UI in favor of portal automation (2026-01)
    - Move analytics to PostHog (2026-04)

Rules: preserve contact fields (never remove Email/Slack/GitHub/Title/Team). Drop stale Current items (>2 weeks, no recent mention). Max 5 Current, max 10 Key Decisions. Use `[[Project Name]]` wikilinks in Current.

When looking up a person: read their profile first. If it has their email/Slack ID, use that directly.

## Project profiles

    # Shield
    - **Linear**: https://linear.app/myorg/project/shield
    - **GitHub**: https://github.com/myorg/shield
    ## Status
    - Active development, migrating from monolith to microservices
    - Blocked on [[Auth Service]] dependency
    ## Key Decisions
    - Use Rust for core service (2026-03)
    - GCS for storage, not Vertex (2026-04)
    ## People
    - [[Jane Smith]] — engineering lead
    - [[Bob Chen]] — infrastructure

Rules: preserve link fields (never remove Linear/GitHub). Use `[[Person Name]]` wikilinks in People, `[[Project Name]]` in Status.

## Decisions log

Chronological, grouped by source and date:
    # Decisions
    ## Weekly Standup (2026-05-20)
    - Adopt PostHog for analytics, replacing Mixpanel
    - Deprecate v1 API by end of Q3
    ## DM with Jane (2026-05-21)
    - Ship Shield MVP without auth, add it in v2

When a later decision supersedes an earlier one, keep only the latest. Consolidate when the log exceeds ~20 sections.

## Journal

Daily coding activity per project, with diff stats:

    # 2026-05-22
    ## Shield
    - Fix auth token refresh race condition
    - Add integration tests for session middleware
    - *5 sessions, 12 files changed, +340/-120 lines*
    ## dotfiles
    - Update knowledge base skill
    - *2 sessions, 3 files changed, +87/-40 lines*

## Name resolution

`names.json` maps display name variants to canonical names: `{"Joe": "Joseph Martinez", "J. Martinez": "Joseph Martinez"}`. Check before creating a new profile — the person may exist under a different name.

`projects.json` maps project name variants to canonical names: `{"the scanner": "Scanner", "devscanner": "Scanner"}`. Empty string value means suppress (noise, not a real project). Update both files when encountering new name variants.

## Enriching profiles

When you encounter new contact info (email, chat handle, GitHub handle, title, team) from any source — calendar attendees, chat messages, email headers, commit authors — update the person's profile.

## Searching
- Find a person: `cat ~/.local/share/kb/people/<slug>.md`
- Find a project: `cat ~/.local/share/kb/projects/<slug>.md`
- Search across KB: `grep -r "search term" ~/.local/share/kb/`
- Search journal: `grep -r "search term" ~/.local/share/kb/journal/`
