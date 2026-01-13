# Chezmoi Dotfiles Repository

## Chezmoi Workflow

**Always edit source files here**, then run `chezmoi apply`. Never edit target files directly.

**Naming conventions**:
- `dot_` prefix becomes `.` (e.g., `dot_zshrc` -> `~/.zshrc`)
- `.tmpl` extension for templated files
- `executable_` prefix for scripts that need +x
- `create_` prefix for files created only if missing

**Making changes**:
1. Edit files in this repo
2. Run `chezmoi apply` to deploy
3. For new packages, update `.chezmoitemplates/Brewfile`
4. Ensure `README.md` stays up to date with any functionality changes

## Host-Specific Files (NOT managed by chezmoi)

- `~/.env` - API keys and secrets (loaded by direnv)

## Key Locations

| Location | Contents |
|----------|----------|
| `dot_zshrc.tmpl` | Shell configuration |
| `dot_config/starship.toml` | Prompt configuration |
| `.chezmoitemplates/Brewfile` | Homebrew packages (includes `opencode` and `opencode-desktop`) |

## OpenCode Configuration

**Global config** (`~/.config/opencode/`):
- `opencode.json` - models, MCPs, tools config (managed by chezmoi)
- `AGENTS.md` - instructions for all agents
- `agent/` - primary agent overrides and subagents
- `command/` - global slash commands
- `mcps/` - custom MCP servers (granola-mcp.py)

**Per-project config** (`.opencode/` in repo root):
- `command/` - project-specific slash commands
- Custom tools, agents, themes

## Agent Override Structure

When modifying agent behavior, choose the right location:

| File | Purpose |
|------|---------|
| `dot_config/opencode/AGENTS.md` | Universal rules (safety, env vars, quality) |
| `dot_config/opencode/agent/build.md` | Development workflow: TDD, commits, PRs, code quality |
| `dot_config/opencode/agent/plan.md` | Delegation hub: analysis, research, coordination |
| `dot_config/opencode/agent/architect.md` | Design decisions and tradeoffs (Fowler-style) |
| `dot_config/opencode/agent/pm.md` | Customer context, requirements (Cagan-style) |
| `dot_config/opencode/agent/docs.md` | READMEs, guides, ADRs, markdown documentation |
| `dot_config/opencode/agent/ux.md` | Figma MCP access for design specs and visual details |
| `dot_config/opencode/agent/qa.md` | Playwright MCP for browser testing and verification |
| `dot_config/opencode/agent/context.md` | Granola MCP for meeting notes and conversation context |
| `dot_config/opencode/agent/observability.md` | Elasticsearch MCP for APM traces, logs, metrics investigation |
| `dot_config/opencode/agent/local.md` | Fast local code agent (Ollama 14B) for quick file ops |
| `dot_config/opencode/agent/local-plan.md` | Fast local planning agent (Ollama 7B) for triage and routing |
| `dot_config/opencode/agent/review.md` | Code review agent with Uncle Bob/Fowler/Beck principles |
| `dot_config/opencode/command/review.md` | `/review` command - delegates to review agent |
| `dot_config/opencode/command/ux.md` | `/ux` command - delegates to ux agent for Figma lookups |
| `dot_config/opencode/command/qa.md` | `/qa` command - delegates to qa agent for browser verification |
| `dot_config/opencode/command/context.md` | `/context` command - delegates to context agent for meeting notes |
| `dot_config/opencode/command/attention.md` | `/attention` command - check what needs attention (GitHub, etc.) |
| `dot_config/opencode/command/standup.md` | `/standup` command - prepare standup answers from recent activity |
| `dot_config/opencode/command/todo.md` | `/todo` command - add items to todo list without interrupting |
| `dot_config/opencode/command/project-updates.md` | `/project-updates` command - draft status updates |
| `dot_config/opencode/command/event-digest.md` | `/event-digest` command - weekly local events digest |
| `dot_config/opencode/command/cleanup.md` | `/cleanup` command - clean up old worktrees and devcontainer clones |

**When updating agent instructions**:
1. Review all agents to ensure appropriate placement
2. Check for conflicting or duplicative guidance across agents
3. Clean up as appropriate
4. Update this table if adding/removing/renaming agents

## Skills

- `opencode-devcontainers` - Concurrent branch development using devcontainer clones (for devcontainer projects)
