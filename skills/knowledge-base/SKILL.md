---
name: knowledge-base
description: Local knowledge base of people, projects, and decisions — check here first before searching Slack, email, or calendar for contact info, project status, or decision history
license: MIT
metadata:
  provides:
    - knowledge-base
---

The knowledge base at `~/meetings/knowledge/` is a distilled, maintained view of people, projects, and decisions. Updated automatically from meetings, Slack, Linear, and GitHub.

## Structure

- `people/<slug>.md` — person profiles: contact info (Email, Slack ID), current work, communication style, personal details, key decisions
- `projects/<slug>.md` — project and product profiles with Linear/GitHub links, status, key decisions, people involved
- `decisions/log.md` — active decisions with context, reconciled when superseded
- `names.json` — people display name → canonical name mapping
- `projects.json` — project name → canonical name mapping (prevents LLM-generated duplicates)

## People profiles

Profiles are distilled, not meeting logs. A person profile looks like:

```markdown
# Jane Smith
- **Title**: Engineering Lead
- **Team**: Platform

## Current
- Leading sprint planning and infrastructure migration
- Key contact for enterprise customer onboarding

## Key Decisions
- Deprecate old UI in favor of portal automation (2026-01)
- Move analytics to PostHog (2026-04)
```

When looking up a person: read their profile first. If it has their email/Slack ID, use that directly instead of searching Slack or email for contact info.

## Enriching profiles

When you encounter new contact info (email, Slack ID, title, team) from any source — calendar attendees, Slack messages, email headers — update the person's profile. This makes future lookups faster.

## Searching

- Find a person: `cat ~/meetings/knowledge/people/<slug>.md`
- Find a project: `cat ~/meetings/knowledge/projects/<slug>.md`
- Search across KB: `grep -r "search term" ~/meetings/knowledge/`
- Search meeting transcripts: `grep -r "search term" ~/meetings/*.md`
