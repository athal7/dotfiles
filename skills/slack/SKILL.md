---
name: slack
description: Slack Web API for messaging, search, and channel management
license: MIT
---

Base URL: https://slack.com/api
Spec: https://api.slack.com/methods

SLACK_USER_TOKEN posts as you; SLACK_BOT_TOKEN posts as the bot.
Non-ASCII channel names won't match on conversations.list — use search.messages to locate them.

`search.messages` requires GET, not POST — POST returns `invalid_arguments` with no further detail. Pass `query`, `count`, `sort`, `sort_dir` as query params.

`chat.postMessage` uses POST with JSON body (`channel`, `text`). For `@mentions` in text, use `<@UXXXXXXXX>` format with the user's Slack ID.
