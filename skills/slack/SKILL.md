---
name: slack
description: Slack Web API for messaging, search, and channel management
license: MIT
---

Base URL: https://slack.com/api
Auth: `Authorization: Bearer $SLACK_USER_TOKEN`
Spec: https://api.slack.com/methods

SLACK_USER_TOKEN posts as you; SLACK_BOT_TOKEN posts as the bot.
Non-ASCII channel names won't match on conversations.list — use search.messages to locate them.
