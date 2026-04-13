---
name: conversations
description: Research people, decisions, and context across meetings, chat, email, and the knowledge base
license: MIT
metadata:
  author: athal7
  version: "1.3"
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

Note: daily internal chat digests are also ingested as meetings — check there for recent summaries.

## 3. Internal chat — live and undigested

Real-time search for things too recent to be ingested, or threads not captured in digests.

Use your `chat` capability for full API reference (search, post, reply, find channel IDs).

Use when: looking for something from today or yesterday, or a specific thread not in a digest.

## 4. Customer support and community chat

Real-time customer support conversations, community reports, and user feedback.

Use your `discord` capability for full command reference (search, messages, members, mentions).

Use when: looking for customer-reported issues, support requests, user feedback, or community discussions.

## 5. Email — formal correspondence

Sent/received email, support tickets, procurement threads, and anything via your work email domain.

Use your `email` capability for full command reference (search messages, get threads, send/reply).

Use when: looking for email correspondence, ticketing notifications, procurement threads, or any thread not in chat or meetings.

## Decision guide

| Question | Source |
|---|---|
| What has someone committed to? | KB → `meetings` capability |
| What was decided about X last week? | KB → `meetings` capability |
| Who was in a specific meeting? | `meetings` capability or KB |
| What did someone say in internal chat today? | `chat` capability |
| What's the latest on an internal thread? | `chat` capability |
| Customer complaint or support request? | `discord` capability |
| Community feedback or bug report from users? | `discord` capability |
| Email thread, ticket notification, procurement? | `email` capability |
