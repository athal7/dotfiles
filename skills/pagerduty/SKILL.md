---
name: pagerduty
description: Look up on-call schedules, list and act on incidents, and read services/escalation policies via the PagerDuty REST API
license: MIT
metadata:
  provides:
    - oncall
    - incidents
  requires:
    - secrets
---

# PagerDuty API Skill

API docs: https://developer.pagerduty.com/api-reference/

Fetch the docs above when you need endpoint details. Use `jq` to process responses.

## Auth

**Before making any requests, load your `secrets` capability to fetch `PAGERDUTY_API_TOKEN`.**

The token is a **user token** (acts as you — required for `ack`/`resolve`). Header format is non-standard: `Authorization: Token token=$PAGERDUTY_API_TOKEN` (NOT `Bearer`).

```bash
# Sanity check — current user
curl -s "https://api.pagerduty.com/users/me" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.user | {id, name, email}'
```

`From: <email>` header is required on write actions (ack, resolve, snooze, add note). Use the email from `users/me`.

```bash
PD_USER_EMAIL=$(curl -s "https://api.pagerduty.com/users/me" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" | jq -r '.user.email')
```

## Who's on-call right now

```bash
# Everyone currently on-call across all escalation policies
curl -s "https://api.pagerduty.com/oncalls?earliest=true" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.oncalls[] | {policy: .escalation_policy.summary, level: .escalation_level, user: .user.summary, until: .end}'

# On-call for a specific escalation policy (filter by ID)
curl -s "https://api.pagerduty.com/oncalls?earliest=true&escalation_policy_ids%5B%5D=POLICY_ID" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.oncalls[] | {level: .escalation_level, user: .user.summary, until: .end}'

# On-call for a schedule over a time window
curl -s "https://api.pagerduty.com/schedules/SCHEDULE_ID/users?since=2026-01-01T00:00:00Z&until=2026-01-08T00:00:00Z" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.users[] | {name, email}'
```

`earliest=true` collapses each escalation level to just the next person — drop it to see the full rotation chain.

## Find IDs

```bash
# Services (search by name)
curl -s "https://api.pagerduty.com/services?query=NAME" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.services[] | {id, name, escalation_policy: .escalation_policy.summary}'

# Escalation policies
curl -s "https://api.pagerduty.com/escalation_policies?query=NAME" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.escalation_policies[] | {id, name}'

# Schedules
curl -s "https://api.pagerduty.com/schedules?query=NAME" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.schedules[] | {id, name}'

# Users by email
curl -s "https://api.pagerduty.com/users?query=EMAIL_OR_NAME" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.users[] | {id, name, email}'
```

## List incidents

```bash
# Open incidents (default: triggered + acknowledged)
curl -s "https://api.pagerduty.com/incidents?statuses%5B%5D=triggered&statuses%5B%5D=acknowledged" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.incidents[] | {id, number: .incident_number, status, urgency, title, service: .service.summary, assigned: [.assignments[].assignee.summary], created: .created_at, url: .html_url}'

# Filter by service
# add: &service_ids%5B%5D=SERVICE_ID

# Filter by urgency
# add: &urgencies%5B%5D=high

# Time window (last 24h)
# add: &since=$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)
```

## Get incident detail

```bash
# Use the human-readable incident number (e.g. 1234) or the full ID (e.g. P12ABCD)
curl -s "https://api.pagerduty.com/incidents/INCIDENT_ID" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.incident | {id, number: .incident_number, status, urgency, title, service: .service.summary, assigned: [.assignments[].assignee.summary], created: .created_at, last_status_change: .last_status_change_at, url: .html_url, description}'

# Recent log entries (timeline) for an incident
curl -s "https://api.pagerduty.com/incidents/INCIDENT_ID/log_entries?limit=20" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.log_entries[] | {at: .created_at, type, summary: .summary, agent: .agent.summary}'

# Notes
curl -s "https://api.pagerduty.com/incidents/INCIDENT_ID/notes" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  | jq '.notes[] | {at: .created_at, by: .user.summary, content}'
```

## Write actions — show & confirm before running

All write actions modify production paging state. **Show the user the proposed action and the incident summary, ask "Do you approve?", and wait for explicit approval before running.**

### Acknowledge incident(s)

```bash
curl -s -X PUT "https://api.pagerduty.com/incidents" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  -H "Content-Type: application/json" \
  -H "From: $PD_USER_EMAIL" \
  -d '{
    "incidents": [
      { "id": "INCIDENT_ID", "type": "incident_reference", "status": "acknowledged" }
    ]
  }' | jq '.incidents[] | {id, status, title}'
```

### Resolve incident(s)

```bash
curl -s -X PUT "https://api.pagerduty.com/incidents" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  -H "Content-Type: application/json" \
  -H "From: $PD_USER_EMAIL" \
  -d '{
    "incidents": [
      { "id": "INCIDENT_ID", "type": "incident_reference", "status": "resolved" }
    ]
  }' | jq '.incidents[] | {id, status, title}'
```

### Snooze (delay re-escalation)

```bash
# duration is in seconds — 3600 = 1h, 14400 = 4h
curl -s -X POST "https://api.pagerduty.com/incidents/INCIDENT_ID/snooze" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  -H "Content-Type: application/json" \
  -H "From: $PD_USER_EMAIL" \
  -d '{ "duration": 3600 }' | jq '.incident | {id, status}'
```

### Add a note

```bash
curl -s -X POST "https://api.pagerduty.com/incidents/INCIDENT_ID/notes" \
  -H "Authorization: Token token=$PAGERDUTY_API_TOKEN" \
  -H "Accept: application/vnd.pagerduty+json;version=2" \
  -H "Content-Type: application/json" \
  -H "From: $PD_USER_EMAIL" \
  -d '{ "note": { "content": "Investigating; see thread #incident-room" } }' \
  | jq '.note | {id, content, created_at}'
```

## What a `user`-role token can and can't do

PagerDuty's REST API silently degrades several admin-gated writes — the request returns 200 and the field appears in the response, but the value is dropped. Check `/users/me` to see your role; if `role` is `user`, the table below applies.

| Action | Works at user role? | Notes |
|---|---|---|
| `PUT /services/{id}` (description, name) | ✅ if you're a manager on the service's team | |
| `PUT /services/{id}` (other fields like `documentation_link`) | ❌ silent — field echoes but stays null | UI-only at user role; admin can write via API |
| `POST /addons` (incident_show_addon) | ❌ 403 Access Denied | Admin-only |
| `POST /incidents` (ack, resolve, snooze, note) | ✅ | Requires `From: <email>` header |
| Read endpoints (oncalls, incidents, services, addons) | ✅ | |
| `POST /response_plays` | ❌ 301 redirect | Deprecated in favor of incident workflows on most accounts |
| `POST /incident_workflows` | ❌ admin-only | Read works; write doesn't |

Service Profile fields visible in the UI (Documentation Link, Communication Channel, Custom Incident Actions) are not writable through the public REST API at user role. Either configure manually in the UI or have an admin make the change.

## Notes

- The `Accept: application/vnd.pagerduty+json;version=2` header is required on every request — without it the API may return a different schema or reject the call.
- Auth header uses `Token token=...`, NOT `Bearer ...`. This is a common mistake.
- `From: <email>` is required on every write action — the email must belong to a real PagerDuty user in the account.
- Incident IDs come in two forms: the short `incident_number` (integer, e.g. `1234`) and the long ID (e.g. `P12ABCD`). Most write endpoints accept the long ID; URLs in `html_url` use the long ID.
- Pagination: list endpoints default to 25 items. Add `&limit=100&offset=0` for more, or follow `more`/`offset` in the response.
- `/oncalls` with no filter returns the entire account's roster — for large orgs prefer filtering by `escalation_policy_ids[]`, `schedule_ids[]`, or `user_ids[]`.
