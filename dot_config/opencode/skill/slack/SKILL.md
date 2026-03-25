---
name: slack
description: Search Slack messages, read channel history, and fetch threads via curl — auth, search syntax, and pagination
---

Query Slack using the Web API directly with your user token. Auth is via `$SLACK_USER_TOKEN` (the `xoxp-*` token), which is available in the shell environment via direnv.

## Search messages

Full-text search across all channels you have access to:

```bash
curl -s "https://slack.com/api/search.messages?query=YOUR+QUERY&count=20&sort=timestamp" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.messages.matches[] | {channel: .channel.name, user: .username, ts: .ts, text: .text, permalink: .permalink}'
```

Useful search modifiers:
- `in:#channel-name` — scope to a channel
- `from:@username` — messages from a specific person
- `before:2026-01-01` / `after:2025-12-01` — date range
- `"exact phrase"` — phrase search

## Read channel history

Get recent messages from a channel. Requires the channel ID (e.g. `C01ABC123`):

```bash
# Get channel ID by name first
CHANNEL_ID=$(curl -s "https://slack.com/api/conversations.list?limit=200&exclude_archived=true" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq -r '.channels[] | select(.name == "channel-name") | .id')

# Then fetch history
curl -s "https://slack.com/api/conversations.history?channel=$CHANNEL_ID&limit=20" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.messages[] | {ts: .ts, user: .user, text: .text}'
```

## Read a thread

Given a channel ID and the parent message timestamp:

```bash
curl -s "https://slack.com/api/conversations.replies?channel=$CHANNEL_ID&ts=$THREAD_TS" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.messages[] | {user: .user, text: .text}'
```

The `ts` from search results (e.g. `1234567890.123456`) is the thread timestamp.

## Resolve user IDs to names

Slack messages return user IDs (e.g. `U01ABC123`) rather than names. Resolve in bulk:

```bash
curl -s "https://slack.com/api/users.list" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.members[] | {id: .id, name: .real_name, handle: .name}'
```

Or resolve a single user from a message's `user` field:

```bash
curl -s "https://slack.com/api/users.info?user=U01ABC123" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.user | {name: .real_name, handle: .name}'
```

## Tips

- `$SLACK_USER_TOKEN` must be loaded — if missing, run `direnv allow` in the project directory
- User tokens (`xoxp-*`) support `search.messages`; bot tokens (`xoxb-*`) do not
- Search pagination: add `&page=2` for subsequent pages, check `.messages.paging.pages` for total
- For finding context about a feature or PR: combine `in:#eng-channel YOUR_TOPIC` with a date range
