---
description: Daily knowledge base enrichment — enrich profiles, journal, and decisions from today's activity
subtask: true
---

Run the daily knowledge base enrichment for today (or the date given in arguments).

$ARGUMENTS

## Sources

Check activity across all available sources:

- **opencode** coding sessions
- **slack** chat messages and threads
- **zoom** meeting transcripts
- **linear** issues and comments
- **gh** code reviews, PRs, and issues
- **openspec** newly-archived change proposals — when session activity shows a change was archived that day, read its artifacts (proposal.md, design.md, tasks.md, delta specs) from that repo's `openspec/changes/archive/YYYY-MM-DD-*/` for the full reasoning behind completed work

## Enrichment Steps

1. **Extract** people facts, project updates, and decisions from each source
2. **Journal** — write a journal entry for the day summarizing coding activity with diff stats
3. **Profiles** — merge new facts into knowledge-base people and project profiles
4. **Decisions** — add any decisions to the decisions log. Include key design decisions and rejected alternatives captured in any OpenSpec changes archived that day.
5. **Action items** — extract action items from today's activity. Cross-reference within the same activity data — if the activity shows you already took the action (replied to the thread, reviewed the PR, closed the issue), skip the reminder. Only create reminders for items that were not resolved within the same day of activity.

## Privacy

Do not extract or store:
- Health information
- Compensation details
- Performance evaluations
- Legal or attorney-client privileged content
- Content from HR-related discussions
