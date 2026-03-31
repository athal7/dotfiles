---
name: project-update
description: Compose and publish a Linear project status update by aggregating issue progress and meeting context
---

Compose a project status update from Linear issues and Minutes meeting context, then publish via the Linear API. Load the `linear` skill for auth and `gq` usage.

## Steps

### 1. Identify the project

Get the project name or ID from the user or current context. Then fetch project metadata, goals, scope, milestones, and current milestone target date using `gq`. Consult the Linear API docs for the `project` and `projectMilestones` queries.

### 2. Gather issues by state

Use `gq` to fetch issues filtered by project and state: completed (done this period), started (in flight), and any marked as blocked. Check `updatedAt` to identify aged blockers (5+ days in blocked state).

Flag issues as "aged blockers" if they have been in a blocked state for more than 5 days (check `updatedAt`).

### 3. Gather meeting context

Load the `meetings` skill and search for recent meetings mentioning the project:

```
minutes_search_meetings query="PROJECT_NAME"
```

Read the top 2–3 most recent relevant meetings using `minutes_get_meeting` to extract decisions and blockers.

### 4. Calculate health

| Condition | Health |
|-----------|--------|
| Any aged blockers (5+ days) | `atRisk` |
| Completion < 20% with < 2 weeks to milestone | `offTrack` |
| No blockers, progress on track | `onTrack` |

Default to `onTrack` if no clear signal.

### 5. Draft and publish

Use the **Project Status Update** document template in Linear for the body structure. Fill it with the aggregated data, keep it to 150–250 words, focus on outcomes and blockers not task lists. Show the draft to the user, then publish via `projectUpdateCreate` with the project ID, health (`onTrack|atRisk|offTrack`), and body.

## Tips

- Check `project_body` for stated goals and success metrics — reference them explicitly in the update
- If the milestone target date has passed, flag it in the update
- The update is visible to the whole team — be specific about blockers (what/why/who) and avoid vague status language
