---
description: Draft project status updates for review
agent: plan
---

Draft project status updates for projects where I am the lead.

## Steps

1. Get all projects from the project management tool (e.g., Linear, Jira)
2. Filter for projects where I am the lead AND are either:
   - In progress / started / active status
   - OR completed within the last week
3. For each matching project, gather context:
   - Recent issue activity (completed, in-progress, blocked)
   - Current project health and progress percentage
   - Any recent comments or updates
4. Draft a status update for each project, including:
   - Health status (on track, at risk, off track)
   - What was accomplished
   - What's in progress
   - Blockers or risks
   - Next steps

## Configuration

This command uses local overrides for personalization. Create `~/.config/opencode/command.local/project-updates.md` with:
- Your project management tool specifics
- Additional steps like demo video creation
- Approval workflow preferences

## Output

Present the drafted updates for my review and approval before posting anything.

**Do NOT submit updates to the project management tool. Only draft them for approval.**
