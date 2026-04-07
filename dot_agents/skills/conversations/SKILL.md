---
name: conversations
description: Research people, decisions, and context across meetings, Slack, and the knowledge base
license: MIT
metadata:
  author: athal7
  version: "1.0"
---

Three sources of conversation context, each with different fidelity and recency. Use them in order.

## 1. Knowledge Base — distilled profiles (start here)

Pre-ingested facts about people and decisions. Fast, structured, low noise.

```bash
# Person profile
cat ~/meetings/knowledge/people/{slug}.md

# List all profiles
ls ~/meetings/knowledge/people/
```

Use when: looking up what someone committed to, their role, recent decisions they were part of.

Skip when: the event was very recent (last day or two) and may not be ingested yet.

## 2. Meeting transcripts — full context

Raw meeting markdown with transcripts, summaries, action items.

```bash
minutes list                        # recent meetings
minutes search "topic or name"      # full-text across all meetings
minutes get YYYY-MM-DD-slug         # specific meeting
minutes person "Name"               # cross-meeting profile
minutes research "topic"            # cross-meeting topic research
minutes actions                     # open action items
minutes consistency                 # conflicting decisions / stale commitments
```

Use when: KB doesn't have enough detail, or you need the surrounding conversation.

Note: `~/meetings/*-slack-digest.md` files are also here — daily Slack digests ingested as meetings.

## 3. Slack — live and undigested

Real-time search for things too recent to be ingested, or threads not captured in digests.

```bash
# Full-text search
curl -s "https://slack.com/api/search.messages?query=QUERY&count=20&sort=timestamp" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.messages.matches[] | {channel: .channel.name, user: .username, text: .text}'

# Scope to a channel or person
# in:#channel-name QUERY
# from:@handle QUERY

# Read a thread
curl -s "https://slack.com/api/conversations.replies?channel=CHANNEL_ID&ts=THREAD_TS" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq '.messages[] | {user: .user, text: .text}'
```

Use when: looking for something from today or yesterday, or a specific thread not in a digest.

## Decision guide

| Question | Source |
|---|---|
| What has someone committed to? | KB → meetings |
| What was decided about X last week? | KB → meetings search |
| What did someone say in Slack this morning? | Slack search |
| Who was in a specific meeting? | meeting file or KB |
| What's the latest on a Slack thread? | Slack search |
