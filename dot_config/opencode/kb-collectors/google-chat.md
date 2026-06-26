---
name: google-chat
enabled: false
priority: 6
authoritative_for: [volunteer-work, informal-decisions]
description: Google Chat messages from spaces you are active in (volunteer org, etc.)
# token_path: absolute path to the file containing the Google Chat bearer token.
# When empty or the file does not exist, this collector is skipped automatically.
token_path: ""
---

## Enabled check

Before running: if `token_path` is empty or the file at that path does not exist, skip this collector entirely and log "google-chat: no token, skipping". Set `enabled: true` and `token_path` in the frontmatter on machines where Google Chat is available.

## How to query

Read the bearer token from the file at `token_path`. Use the Google Chat REST API `spaces.messages.list` endpoint with a `createTime` filter for the date window:

```
GET https://chat.googleapis.com/v1/spaces/{space}/messages
  ?filter=createTime>"YYYY-MM-DDT00:00:00Z" AND createTime<"YYYY-MM-DDT23:59:59Z"
Authorization: Bearer <token from token_path>
```

Focus on spaces related to volunteer work.

## Triage

- **What to extract:**
  - Decisions and action items from volunteer organization spaces
  - Event planning, logistics, or coordination you were part of
  - New contacts (names, roles) from the organization

- **What to skip:**
  - Casual social messages with no action or decision content
  - Announcements you didn't participate in
  - Anything already captured from a Granola meeting for the same day
