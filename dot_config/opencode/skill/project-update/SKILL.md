---
name: project-update
description: Compose and publish a Linear project status update by aggregating issue progress
---

Compose a project status update from Linear issue state, then publish via the Linear API. Load the `linear` skill for auth and `gq` usage.

## Steps

### 1. Identify the project

Get the project name or ID from the user or current context. Fetch project metadata, goals, scope, milestones, and current milestone target date using `gq`. Consult the Linear API docs for the `project` and `projectMilestones` queries.

### 2. Gather issues by state

Use `gq` to fetch issues filtered by project and state: completed (done this period), started (in flight), and any marked as blocked. Flag issues as "aged blockers" if in a blocked state for more than 5 days (check `updatedAt`).

### 3. Draft and publish

Use the **Project Status Update** document template in Linear for the body structure. Fill with aggregated data, keep to 150–250 words, focus on outcomes and blockers not task lists. Show the draft to the user, then publish via `projectUpdateCreate` with the project ID, health (`onTrack|atRisk|offTrack`), and body.

## Tips

- Check `project_body` for stated goals and success metrics — reference them explicitly
- If the milestone target date has passed, flag it
- Be specific about blockers (what/why/who) — the update is visible to the whole team

## Note

Extracting action items and state changes from meeting transcripts and Slack conversations is a separate automation — a periodic background job that reads recent meetings/Slack and syncs back to Linear, rather than a manual step here.
