---
name: slack
priority: 2
authoritative_for: [informal-decisions, action-items, contact-info]
description: Slack messages — your sent messages and mentions, in the enrichment window
---

## How to query

Token is in `~/.config/team-context-mcp/.env` as `SLACK_USER_TOKEN`. Set `SLACK_USER_ID` to your Slack user ID (find it in your Slack profile → "Copy member ID").

```bash
SLACK_TOKEN=$(grep SLACK_USER_TOKEN ~/.config/team-context-mcp/.env | cut -d= -f2)
SLACK_USER_ID="<your-slack-user-id>"  # e.g. U01ABC23DEF

# Your messages in the date window
curl -s "https://slack.com/api/search.messages?query=from:me+after:YYYY-MM-DD+before:YYYY-MM-DD&count=20&sort=timestamp" \
  -H "Authorization: Bearer $SLACK_TOKEN"

# Mentions of you in the date window
curl -s "https://slack.com/api/search.messages?query=%3C${SLACK_USER_ID}%3E+after:YYYY-MM-DD+before:YYYY-MM-DD&count=20&sort=timestamp" \
  -H "Authorization: Bearer $SLACK_TOKEN"

# Read a thread (get replies)
curl -s "https://slack.com/api/conversations.replies?channel=CHANNEL_ID&ts=THREAD_TS" \
  -H "Authorization: Bearer $SLACK_TOKEN"
```

Slack is high-volume; read selectively to keep token cost manageable.

## What to extract

- Decisions announced or confirmed in Slack that didn't appear in a Granola meeting
- Action items assigned to you or by you that aren't already in Linear
- New contact info (Slack handles, email addresses) for people profiles
- Customer or partner names that surfaced in conversation

## What to skip

- Routine standup threads already covered by Granola
- Emoji reactions and short acknowledgments ("👍", "sounds good")
- HR, compensation, or personal channels (privacy)
- Anything already captured from a Granola meeting for the same day
