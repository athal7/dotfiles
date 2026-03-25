---
name: project-update
description: Compose and publish a Linear project status update by aggregating issue progress and meeting context
---

Compose a project status update from Linear issues and Granola meeting context, then publish via the Linear MCP.

## Steps

### 1. Identify the project

Get the project name or ID from the user or current context. Then fetch:

```
linear_get_project(query: "<project name>")
linear_get_project_body(project: "<project name>")  # goals, scope, success metrics
linear_list_milestones(project: "<project name>")   # current milestone + target date
```

### 2. Gather issues by state

```
linear_list_issues(project: "<project name>", state: "completed")   # done this period
linear_list_issues(project: "<project name>", state: "in_progress") # in flight
linear_list_issues(project: "<project name>", state: "blocked")     # blockers
```

Flag issues as "aged blockers" if they have been in a blocked state for more than 5 days (check `updatedAt`).

### 3. Gather meeting context

Load the `meetings` skill and search for recent meetings mentioning the project:

```bash
GRANOLA_TOKEN=$(jq -r '.workos_tokens | fromjson | .access_token' \
  ~/Library/Application\ Support/Granola/supabase.json)

curl -s -X POST "https://api.granola.ai/v2/get-documents" \
  -H "Authorization: Bearer $GRANOLA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"limit": 100, "offset": 0, "include_last_viewed_panel": false}' \
  | jq --arg q "PROJECT_NAME" '.docs[] | select(.title | test($q; "i")) | {id, title, date: .created_at}' \
  | head -20
```

Read panels for the top 2–3 most recent relevant meetings to extract decisions and blockers.

### 4. Calculate health

| Condition | Health |
|-----------|--------|
| Any aged blockers (5+ days) | `atRisk` |
| Completion < 20% with < 2 weeks to milestone | `offTrack` |
| No blockers, progress on track | `onTrack` |

Default to `onTrack` if no clear signal.

### 5. Draft the update body

Structure:

```markdown
## Progress

- **Completed:** X issues — [key highlights]
- **In progress:** Y issues — [notable work]
- **Blocked:** Z issues — [blocker description and owner if known]

## Decisions

[Key decisions from meetings, if any]

## Next

[What's up next / milestone target]
```

Keep it to 150–250 words. Focus on outcomes and blockers, not task lists.

### 6. Get approval and publish

Show the draft to the user. After approval:

```
linear_create_project_update(
  project: "<project name>",
  health: "onTrack|atRisk|offTrack",
  body: "<markdown body>"
)
```

## Tips

- Check `project_body` for stated goals and success metrics — reference them explicitly in the update
- If the milestone target date has passed, flag it in the update
- The update is visible to the whole team — be specific about blockers (what/why/who) and avoid vague status language
