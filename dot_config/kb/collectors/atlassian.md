---
name: atlassian
description: Confluence decisions/status and wiki-hygiene flags — fetched by dispatching the atlassian subagent
---

Dispatch the `atlassian` subagent (`task` tool, `subagent_type: atlassian`) with a prompt asking it to run a CQL search scoped to whatever Confluence space(s) the team's wiki presence lives in (discoverable via `getConfluenceSpaces` if not already known — a natural candidate for a per-workspace config value alongside the other local settings this repo already keeps, rather than a value assumed here) with `lastmodified` inside the enrichment window, prioritizing sections organized like retrospectives, demos, PRDs, and proposals; sections like sales/prospect notes are lower priority and worth a pull only if the page shows an explicit decision or status change, not routine meeting-note traffic. Exclude pages carrying the `decision-log` label (e.g. `AND label != "decision-log"`) — those are the write-back target of the Decision Log feature, not source material, and re-ingesting them here would echo-loop the two features against each other. Extract kb facts from its returned summary.

## Triage rules

Skip:
- Routine meeting-note pages with no decision or status change, especially in sales/prospect-note sections
- Page edits that are formatting-only (typo fixes, reordering) with no substantive content change

Extract:
- Decisions recorded on pages like retrospectives, PRDs, or proposals (explicit "we decided", scope changes, architectural choices)
- Action items assigned to the user or left open at page-edit time
- Project or product status updates, including those surfaced in demo-page transcripts
- Explicit decisions or status changes on prospect/sales-note pages (contact/deal status change, not routine notes)

## Extraction rules

- Anchor each decision or status update to the project or product it concerns.
- Cite the Confluence page URL for every extracted fact so it can be cross-referenced at write time.
- For demo-page transcripts, prefer the page's own summary/notes over the raw transcript; only extract what is distilled there.

## Wiki-hygiene flagging

Separately from the window-scoped extraction above, periodically have the subagent scan the space's page tree (`getPagesInConfluenceSpace` / `getConfluencePageDescendants`) for hygiene issues and surface each as a candidate action item, filed through the same reminder/tracked-issue pipeline `/kb-enrich` uses for other collectors — subject to its existing dedup-against-current-state rule, which suppresses re-filing a flag already raised on a prior run.

Heuristics for what's hygiene-worthy:
- A page unmodified for more than ~9 months that sits in an actively-referenced section (e.g. a roadmap, goals, or infra/architecture container) — stale content in a section people still consult is worse than stale content in an archive.
- A page whose title contains "(superseded)" or similar but that still exists in the tree rather than being deleted or archived.
- Two top-level containers covering the same topic (e.g. two goals containers, two retrospectives containers) — a sign one is a stale duplicate that should be merged or removed.
- A page that's obviously mis-parented — its content topic doesn't match its parent container (e.g. a meeting-agenda page filed under a policies/procedures container).

This is not an exhaustive checklist — apply the heuristics to whatever the current page tree looks like rather than checking only for previously-found instances.

**This collector never proposes writing to Confluence itself.** Flagged hygiene issues are always filed as a local reminder or a tracked issue for a human (or a future explicitly-approved write path) to act on — never as a direct page edit, move, or delete.
