---
name: slack
description: Slack messages and threads
---

Discover every channel, DM, and group DM that the authenticated user can access. For each discovered conversation, read at most the most recent 200 messages in the enrichment window. Use no more than two history pages of 100 messages each. Collect from this bounded discovered history, not `search_messages`. Filter the bounded history for messages authored by the authenticated user. Do not filter by a raw author ID. For every retained authored message, retain nearby same-conversation messages, the thread parent, and applicable replies with their parent/reply relationship. Extract kb facts from the retained evidence.

Emit the shared collector report record. Set `terminal_status` to `succeeded`, `succeeded with no eligible evidence`, or `failed`. Set `coverage.state` to `non-exhaustive` and include `bounded 200-message per-conversation history` in `coverage.reasons`. Also include `pagination unavailable` when a requested history page cannot be read. Set `counts.discovered` to discovered conversations, `counts.read` to conversations with history read, `counts.eligible_evidence` to retained eligible messages, and `counts.known_omitted` to known skipped messages or conversations. Set `counts.out_of_allowlist` to `0`. Never report bounded history as exhaustive.

Preserve the raw eligible message evidence and thread structure. Before storing or presenting it, replace credential-bearing values with `[REDACTED_CREDENTIAL]`. Credential-bearing values include API keys, bearer tokens, passwords, private keys, and connection strings with embedded credentials. Do not redact surrounding non-sensitive context.

## Scope

Collect from direct messages (DMs), group DMs, and channels. Process every workspace the authenticated user has access to.

## Triage rules

Skip:
- Automated bot messages and notification-only posts
- Messages with `bot_id`, a bot-message subtype, or another automated sender marker
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
