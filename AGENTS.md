# Agent Context

## Safety Rules

**STOP and wait for explicit user approval before modifying remote services.**

For any remote modification, you MUST follow this two-step process:
1. **First response**: Show the full proposed content and ask "Do you approve?" - then STOP
2. **Second response**: Only after explicit approval, execute the action

This applies to ALL remote modifications, including:
- Git operations: `git push`, `git commit` (commits modify repository history)
- GitHub/GitLab: creating/updating issues, PRs, comments
- API calls that write/modify data
- Production database changes
- Any other operation that modifies state outside the local machine

**Important**: Even if the user says "commit and push" or "go ahead", you MUST still show the proposed commit message and changes first, then wait for confirmation. The user's initial request does NOT count as approval of the specific content.

Read-only operations (git status, git diff, git log, fetching data, etc.) don't require confirmation.

## Project-Specific Context

See `~/AGENTS_LOCAL.md` for:
- Tool names (issue tracker, VCS, CI/CD, cloud provider, secrets manager, etc.)
- Platform architecture and repositories
- State machines and API structures
- Infrastructure and deployment details
- Project-specific security concerns
- Code review guidelines

## Development

**Devcontainer first**: Check for `.devcontainer/` or `docker-compose.yml`. Prefer when available. Fallback to local only if missing or explicitly requested.

**Devcontainer CLI**: Use the `devcontainer` CLI for managing development containers:
- Building: `devcontainer build`
- Executing commands: `devcontainer exec`
- Running features: `devcontainer features`
- Useful for testing configs, CI/CD integration, and automation

**Secrets**: Use your configured secrets manager. Check `~/AGENTS_LOCAL.md` for available secrets.
