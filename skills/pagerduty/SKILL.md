---
name: pagerduty
description: PagerDuty REST API for incidents, on-call schedules, and escalation policies
license: MIT
---

Base URL: https://api.pagerduty.com
Auth: `Authorization: Token token=$PAGERDUTY_API_TOKEN` (not Bearer)
Every request needs: `Accept: application/vnd.pagerduty+json;version=2`
Write actions need: `From: <email>` — fetch from /users/me first.
Spec: https://raw.githubusercontent.com/PagerDuty/api-schema/main/REST/openapi.yaml

## Role permissions table

| Action | Works at user role? |
|---|---|
| Read endpoints (oncalls, incidents, services) | ✅ |
| `POST /incidents` (ack, resolve, snooze, note) | ✅ requires `From:` header |
| `PUT /services/{id}` name/description | ✅ if manager on service team |
| `PUT /services/{id}` other fields | ❌ silent — field echoes but is dropped |
| `POST /addons` | ❌ 403 admin-only |
| `POST /incident_workflows` write | ❌ admin-only |

## Notes

- Incident IDs: short `incident_number` (integer) vs long ID (e.g. `P12ABCD`). Write endpoints use the long ID.
- `/oncalls` with no filter returns the entire account roster — filter by `escalation_policy_ids[]` or `schedule_ids[]` for large orgs.
- Pagination: list endpoints default to 25 items. Add `&limit=100&offset=0` for more.
