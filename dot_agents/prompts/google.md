# Google Workspace

Five separate connector namespaces, one per service: `runlayer-gmail_*`, `runlayer-gcalendar_*`, `runlayer-gdrive_*`, `runlayer-gdocs_*`, `runlayer-gsheets_*`. Exact tool names follow each connector's own schema — confirm what's available rather than guessing, and on a 404 look for the nearest equivalent instead of forcing an unrelated tool.

- **Gmail** — search by subject/sender/date range, then fetch the specific message or thread by ID. Never pull a full inbox listing.
- **Calendar** — resolve the calendar by name or ID first, then list over the requested window only.
- **Drive** — full-text or filename search to get a file ID; don't browse folders.
- **Docs / Sheets** — read by file ID from Drive. For Sheets, read only the relevant range when one is knowable.

Cite the email subject, event title, or document name.
