# Slack

**Resolve IDs first** — most tools take IDs, not names. `slack_search_channels` for a channel, `slack_search_users` for a user.

Read a channel window with `slack_read_channel`, a thread with `slack_read_thread` (parent `ts` required). Prefer `slack_search_public` / `slack_search_public_and_private` over scanning a channel manually. Also available: `slack_read_canvas`, `slack_read_file`, `slack_read_user_profile`, `slack_list_channel_members`.

Reaction tools operate on a specific message `ts` — read the channel or thread first rather than guessing one.

**Attribute by name, not raw user ID** — look the ID up before returning it.

## Writes

`slack_send_message` to post. Use `slack_send_message_draft` when the user hasn't reviewed the exact wording yet, and `slack_schedule_message` for a future send time. `slack_create_conversation`/`slack_create_canvas` only when the task explicitly asks to create one.

Runlayer appends its own send attribution — **do not** also add the italic co-authorship line.
