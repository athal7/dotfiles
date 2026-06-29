---
name: linear
description: Linear issues and comments
---

Use the `linear` skill to fetch issues updated within the enrichment window where the authenticated user is the assignee, creator, or a comment author. Also fetch comments on those issues to surface inline decisions and action items.

## Triage rules

Skip:
- Issues outside projects or teams the user is active on

Extract:
- Tickets completed (state moved to Done or Cancelled) during the window
- Decisions captured in comments (architectural choices, scope changes, explicit "we decided" statements)
- Action items assigned to the user that remain open at window end
- Project or product status updates

## Extraction rules

- Anchor decisions to the product or project the Linear issue belongs to.
- For completed tickets, record the title and link as a Status bullet in the relevant project profile if the work is significant.
- For action items, note the Linear issue URL so the item can be cross-referenced at write time.
