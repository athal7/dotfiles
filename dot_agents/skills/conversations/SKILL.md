---
name: conversations
description: Research people, decisions, and context across meetings, Slack, the knowledge base, Gmail, and Discord
license: MIT
metadata:
  author: athal7
  version: "1.2"
  requires:
    - chat
    - discord
    - meetings
    - email
---

Five sources of conversation context, each with different fidelity and recency. Use them in order.

## 1. Knowledge Base — distilled profiles (start here)

Pre-ingested facts about people and decisions. Fast, structured, low noise.

Files live under `~/meetings/knowledge/people/{slug}.md`.

Use when: looking up what someone committed to, their role, recent decisions they were part of.

Skip when: the event was very recent (last day or two) and may not be ingested yet.

## 2. Meeting transcripts — full context

Raw meeting markdown with transcripts, summaries, action items.

Use your `meetings` capability for full command reference (list, search, get, person, research, actions, consistency).

Use when: KB doesn't have enough detail, or you need the surrounding conversation.

Note: daily Slack digests are also ingested as meetings — check there for recent Slack summaries.

## 3. Slack — live and undigested

Real-time search for things too recent to be ingested, or threads not captured in digests.

Use your `chat` capability for full API reference (search, post, reply, find channel IDs).

Use when: looking for something from today or yesterday, or a specific thread not in a digest.

## 4. Discord — customer support and community

Real-time customer support conversations, community reports, and user feedback. Distinct from Slack (internal).

Use your `discord` capability for full command reference (search, messages, members, mentions).

Use when: looking for customer-reported issues, support requests, user feedback, or community discussions.

## 5. Gmail — email threads and formal correspondence

Sent/received email, support tickets, procurement threads, and anything via your work email domain.

Use your `email` capability for full command reference (search messages, get threads, send/reply).

Use when: looking for email correspondence, JSM/Jira notifications, procurement tickets, or any thread not in Slack/meetings.

## Decision guide

| Question | Source |
|---|---|
| What has someone committed to? | KB → `meetings` capability |
| What was decided about X last week? | KB → `meetings` capability |
| What did someone say in Slack this morning? | `chat` capability |
| Who was in a specific meeting? | `meetings` capability or KB |
| What's the latest on a Slack thread? | `chat` capability |
| Customer complaint or support request? | `discord` capability |
| Community feedback or bug report from users? | `discord` capability |
| Email thread, support ticket, JSM notification? | `email` capability |
