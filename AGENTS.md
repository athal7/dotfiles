# Agent Context

## Safety Rules

**STOP and wait for explicit user approval before modifying remote services.**

For any remote modification (issues, PRs, comments, commits, API writes):
1. Show the full proposed content in your response
2. Ask "Do you approve?" and STOP
3. Do NOT execute the action in the same response as showing the draft
4. Only execute after user explicitly approves (e.g., "yes", "approve", "go ahead")

Read-only operations don't require confirmation.

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

**Secrets**: Use your configured secrets manager. Check `~/AGENTS_LOCAL.md` for available secrets.
