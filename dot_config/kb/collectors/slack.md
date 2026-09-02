---
name: slack
description: Slack messages and threads
---

Find messages sent by the authenticated user in the enrichment window, and to fetch threads for any message that received replies. Extract kb facts from the result.

## Scope

Collect from direct messages (DMs), group DMs, and channels. Process every workspace the authenticated user has access to.

## Triage rules

Skip:
- Automated bot messages and notification-only posts
- Threads where the user was only mentioned but did not participate
- Personal content unrelated to work (e.g., weekend plans, personal errands, non-work conversations)

Extract:
- Informal decisions made in chat (look for phrases like "let's go with", "we decided", "agreed")
- Action items directed at or taken on by the user
- New contact information (email addresses, GitHub handles, role or team changes mentioned in conversation)
- Project or product status updates not captured elsewhere

## Same-channel replies

Read all surrounding replies in the same channel or DM conversation, even when a thread does not exist. Context from adjacent messages in the same conversation is required to correctly interpret the user's message and avoid extracting facts out of context.

## Call invitation meeting context

Treat a Slack call invitation as meeting context. A call invitation is any message that starts a Slack audio/video call (e.g., a "Call started" or "Join call" system message, or the user's own invitation message). Also treat an adjacent blank call-app event (a blank message or system event immediately following the call invitation within the same conversation) as part of the same meeting context. Extract any decisions or action items discussed during the call from the surrounding conversation.

## Extraction rules

- Anchor decisions to the project or product they concern.
- For action items, note the thread URL so the item can be cross-referenced at write time.
- For contact info updates, note the source channel and date so the person profile update can cite it.
