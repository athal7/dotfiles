---
name: atlassian
description: Confluence and Jira collector input with provenance-safe Decision Log handling
---

Run a CQL search in the configured Confluence space or spaces for the enrichment window. Prioritize retrospectives, demos, meeting notes, PRDs, and proposals. Pull sales or prospect notes only for explicit decisions or status changes. Use Jira only when its configured collector scope identifies relevant work.

Do not exclude `decision-log` pages by label. For every candidate page, record its stable page ID, URL, version or modification time, normalized body fingerprint, and collector time.

## KB write-back echo check

Treat a Decision Log page as a KB echo only when all conditions match:

1. The body has a `KB projection: ledger:<entry-id>` marker.
2. KB publication provenance identifies that page ID and entry ID as a KB write-back. Its linked CQ KU is optional.
3. The page's current normalized body fingerprint equals the recorded published-content fingerprint.

If any condition fails, process the page as independently authored source material. A human edit to a KB-created page changes the fingerprint and is eligible for fresh extraction.

## Triage rules

Skip routine meeting notes with no decision or status change. Skip formatting-only edits. Extract explicit decisions, assigned open action items, and project or product status updates. Anchor each item to its project or product. Cite the Confluence URL and page ID with each extracted fact.

Prefer a page summary over a raw demo transcript. Read meeting notes and retrospectives as narrative prose under decision, summary, and action-item headings.

## Wiki-hygiene flagging

Periodically scan configured page trees for stale active content, superseded pages left in active trees, duplicate containers, and obvious mis-parenting. Before filing a personal reminder, establish that the user can act on the page. Deduplicate against current destination state and prior source evidence.

This collector never writes to Confluence. Any publication uses the separate approval-gated KB projection flow.
