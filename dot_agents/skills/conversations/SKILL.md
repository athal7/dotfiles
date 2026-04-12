---
name: conversations
description: Research people, decisions, and context across meetings, Slack, the knowledge base, and Gmail
license: MIT
metadata:
  author: athal7
  version: "1.0"
  requires:
    - chat
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

Use your `chat` capability for full API reference (search, post, reply, find channel IDs).

Use when: looking for something from today or yesterday, or a specific thread not in a digest.

## 4. Gmail — email threads and formal correspondence

Sent/received email, support tickets, procurement threads, and anything via your work email domain.

```bash
# Search by query (same syntax as Gmail search box)
gws gmail users messages list --params '{"userId": "me", "q": "QUERY", "maxResults": 20}'

# Get message metadata
gws gmail users messages get --params '{"userId": "me", "id": "MESSAGE_ID", "format": "metadata", "metadataHeaders": ["Subject","From","To","Date"]}'

# Get full message body
gws gmail users messages get --params '{"userId": "me", "id": "MESSAGE_ID", "format": "full"}' > /tmp/msg.json
# then decode: base64 -d the payload.body.data (or parts[].body.data for multipart)

# Get full thread
gws gmail users threads get --params '{"userId": "me", "id": "THREAD_ID", "format": "metadata", "metadataHeaders": ["Subject","From","To","Date"]}'

# Send / reply
gws gmail users messages send --params '{"userId": "me"}' --json '{"raw": "BASE64_RFC2822", "threadId": "THREAD_ID"}'
```

Use when: looking for email correspondence, JSM/Jira notifications, procurement tickets, or any thread not in Slack/meetings.

## Decision guide

| Question | Source |
|---|---|
| What has someone committed to? | KB → meetings |
| What was decided about X last week? | KB → meetings search |
| What did someone say in Slack this morning? | `chat` capability |
| Who was in a specific meeting? | meeting file or KB |
| What's the latest on a Slack thread? | `chat` capability |
| Email thread, support ticket, JSM notification? | Gmail (gws) |
