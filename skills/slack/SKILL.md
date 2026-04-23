---
name: slack
description: Send messages, search conversations, and read threads in Slack via the API
license: MIT
metadata:
  provides:
    - chat
---

Requires: `$SLACK_USER_TOKEN`, `$SLACK_USER_ID`.

## Search messages

```bash
# Full-text search across all channels
curl -s "https://slack.com/api/search.messages?query=QUERY&count=20&sort=timestamp" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.messages.matches[] | {channel: .channel.name, user: .username, text: .text, ts: .ts}'

# Scope to a channel
# query: in:#channel-name QUERY

# Scope to a person
# query: from:@handle QUERY
```

## Find a channel ID

```bash
curl -s "https://slack.com/api/conversations.list?limit=1000&types=public_channel,private_channel&exclude_archived=true" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.channels[] | select(.name | test("PATTERN"; "i")) | {name, id}'
```

Note: channels with special characters (e.g. `ø`) won't match ASCII patterns — use search.messages to find them:
```bash
curl -s "https://slack.com/api/search.messages?query=in:channel-name some-recent-text&count=1" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.messages.matches[0] | {channel: .channel.name, channel_id: .channel.id}'
```

## Read channel history

```bash
curl -s "https://slack.com/api/conversations.history?channel=CHANNEL_ID&limit=100" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.messages[] | {user: .user, text: .text, ts: .ts}'
```

## Read a thread

```bash
curl -s "https://slack.com/api/conversations.replies?channel=CHANNEL_ID&ts=THREAD_TS" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.messages[] | {user: .user, text: .text}'
```

## Post a message

```bash
curl -s -X POST "https://slack.com/api/chat.postMessage" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "CHANNEL_ID",
    "text": "Your message here"
  }' | jq '{ok, ts, error}'
```

## Reply in a thread

```bash
curl -s -X POST "https://slack.com/api/chat.postMessage" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "CHANNEL_ID",
    "thread_ts": "THREAD_TS",
    "text": "Your reply here"
  }' | jq '{ok, ts, error}'
```

## Notes

- Always show the full proposed message text and get explicit user approval before posting
- `conversations.list` returns max ~1000 channels; channels with non-ASCII names (like `ødin-core`) may not match grep — use search.messages to locate them
- `SLACK_USER_TOKEN` posts as you; `SLACK_BOT_TOKEN` posts as the bot
