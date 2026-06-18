---
name: slack
description: Slack Web API for messaging, search, and channel management
license: MIT
---

Base URL: https://slack.com/api
Spec: https://api.slack.com/methods

Non-ASCII channel names won't match on conversations.list — use search.messages to locate them.

`search.messages` requires GET, not POST — POST returns `invalid_arguments` with no further detail. Pass `query`, `count`, `sort`, `sort_dir` as query params.

`chat.postMessage` uses POST with JSON body (`channel`, `text`). For `@mentions` in text, use `<@UXXXXXXXX>` format with the user's Slack ID.

When `text` contains apostrophes, quotes, or other shell-special characters, do not hand-escape it inline in the shell — that silently corrupts the rendered message (a stray apostrophe came out as `"'`). Pass the literal text through a file or stdin into the JSON body so it is preserved verbatim.

`chat.update` repairs a posted message in place — same JSON body as `chat.postMessage` (`channel`, `text`) plus the message `ts`.

Verify what actually posted with `conversations.history` (`channel`, plus `latest`=the ts and `inclusive`=true to fetch that single message) to confirm the rendered text is clean.
