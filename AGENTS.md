# Agent Context

## Safety Rules

**Always ask for user confirmation before modifying remote services**: Issue tracker issues/comments, version control PRs/comments, API calls that modify data, production database changes. Read-only operations don't require confirmation.

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
