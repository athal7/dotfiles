---
name: meetings
description: Search and read Granola meeting notes via REST API — auth, pagination, transcript and notes access
---

Query Granola meeting notes using the Granola REST API. Granola stores auth tokens locally — no separate credentials needed.

## Auth

Read the Bearer token from Granola's local Supabase file:

```bash
GRANOLA_TOKEN=$(jq -r '.workos_tokens | fromjson | .access_token' \
  ~/Library/Application\ Support/Granola/supabase.json)
```

If this returns `null` or the request returns 401, the token has expired. Open the Granola app, wait ~10 seconds for it to refresh, then re-run.

## List recent meetings

```bash
curl -s -X POST "https://api.granola.ai/v2/get-documents" \
  -H "Authorization: Bearer $GRANOLA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"limit": 20, "offset": 0, "include_last_viewed_panel": false}' \
  | jq '.docs[] | {id: .id, title: .title, date: .created_at}'
```

## Search meetings by keyword

Filter client-side with `jq` — Granola's API has no server-side search:

```bash
curl -s -X POST "https://api.granola.ai/v2/get-documents" \
  -H "Authorization: Bearer $GRANOLA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"limit": 100, "offset": 0, "include_last_viewed_panel": false}' \
  | jq --arg q "standup" '.docs[] | select(.title | test($q; "i")) | {id: .id, title: .title, date: .created_at}'
```

For broader search (titles + attendees + notes), increase `limit` to 100 and chain multiple `select` conditions.

## Get meeting panels (notes)

Each meeting has one or more panels. The `content` field is either a string or a ProseMirror JSON doc.

```bash
# First get the document ID from the list, then:
curl -s "https://api.granola.ai/v1/get-document-panels?document_id=DOC_ID" \
  -H "Authorization: Bearer $GRANOLA_TOKEN" \
  | jq '.panels[] | {slug: .template_slug, content: .content}'
```

## Get meeting transcript

```bash
curl -s "https://api.granola.ai/v1/get-transcript?document_id=DOC_ID" \
  -H "Authorization: Bearer $GRANOLA_TOKEN" \
  | jq '.segments[] | {speaker: (if .source == "microphone" then "Me" else "Them" end), text: .text}'
```

## Response structure

Each document has:
- `id` — UUID
- `title` — meeting title
- `created_at` — ISO timestamp
- `people.attendees[]` — `{name, email}` (may also have `details.person.name.fullName`)

## Tips

- Granola has no server-side full-text search — pull a large batch and filter with `jq`
- For date filtering: `select(.created_at >= "2026-01-01")`
- To find meetings about a project: search by project name in title AND attendee names
- For Slack context around a meeting topic, load the `slack` skill and search alongside Granola
