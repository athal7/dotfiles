---
name: slack
description: Slack messages and threads
---

Use the `slack` skill to find messages sent by the authenticated user in the enrichment window. Fetch threads for any message that received replies.

## Triage rules

Skip:
- Automated bot messages and notification-only posts
- Threads where the user was only mentioned but did not participate

Extract:
- Informal decisions made in chat (look for phrases like "let's go with", "we decided", "agreed")
- Action items directed at or taken on by the user
- New contact information (email addresses, GitHub handles, role or team changes mentioned in conversation)
- Project or product status updates not captured elsewhere

## Extraction rules

- Anchor decisions to the project or product they concern.
- For action items, note the thread URL so the item can be cross-referenced at write time.
- For contact info updates, note the source channel and date so the person profile update can cite it.
