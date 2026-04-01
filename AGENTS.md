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

**Config validation**: `opencode.json` is validated against its `$schema` (`https://opencode.ai/config.json`) before the opencode-web service restarts. If `chezmoi apply` succeeds but the restart script reports a schema validation error:
1. **Do not re-apply or restart manually** — the running server is still using the old (working) config
2. Fix the invalid JSON in `dot_config/opencode/opencode.json`
3. Run `check-jsonschema --schemafile "https://opencode.ai/config.json" dot_config/opencode/opencode.json` to verify
4. Run `chezmoi apply` again to deploy the fix and trigger the restart

## Host-Specific Files (NOT managed by chezmoi)

- `~/.env` - API keys and secrets (loaded by direnv)

## Key Locations

| Location | Contents |
|----------|----------|
| `dot_zshrc.tmpl` | Shell configuration |
| `dot_config/starship.toml` | Prompt configuration |
| `.chezmoitemplates/Brewfile` | Homebrew packages (includes `opencode` CLI + `opencode-desktop`) |
| `Library/LaunchAgents/opencode-web.plist.tmpl` | Web service (port 4096, Tailscale-served) |

## OpenCode Configuration

**Global config** (`~/.config/opencode/`):
- `opencode.json` - models, MCPs, agent config (managed by chezmoi)
- `AGENTS.md` - instructions for all agents
- `skill/` - on-demand skills (invokable via `/skill-name` or loaded by the agent)

**Per-project config** (`.opencode/` in repo root):
- `command/` - project-specific slash commands
- Custom tools, agents, themes

## Agent Structure

| Location | Purpose |
|----------|---------|
| `dot_config/opencode/opencode.json` | Agent config (models, permissions, temperature) |
| `dot_config/opencode/AGENTS.md.tmpl` | Universal rules (safety, CLI tools, task completion) |
| `dot_config/opencode/skill/*/SKILL.md` | On-demand skills (invokable via `/skill-name` or loaded by the agent) |

**Adding a new skill**:
1. Create `skill/<name>/SKILL.md` with `name:` and `description:` in frontmatter
2. Run `chezmoi apply` - skill appears in skill tool listing

**Editing skills/commands**: Always edit in `dot_config/opencode/` here, then `chezmoi apply`. Edits made directly to `~/.config/opencode/` will be overwritten on the next `chezmoi apply`. If a skill was already edited at the target path, copy it back here first.

## OpenCode MCP Configuration

**`tools` vs `permission` are different mechanisms** — `tools: { "foo_*": false }` hides tools from the LLM prompt entirely. `permission: { "foo_*": "deny" }` blocks execution but the tool descriptions are still injected. Use `tools` for context pressure reduction, `permission` only for approval gates.

**Work MCPs (linear, figma) are disabled globally** and enabled per work repo via `.opencode/opencode.json`. The plan agent has read-only `linear_get_*` / `linear_list_*` / `figma_get_*` overrides in `opencode.json` so it can research without write access, even in work repos.

**opencode-pilot `linear/my-issues` preset** expects `mcp: linear` with `response_key: nodes` and `body: title` by default — no `tools:` overrides needed in `pilot/config.yaml`.

**Slack uses curl + `$SLACK_USER_TOKEN`** (xoxp-\*), not an MCP. The Slack MCP reference server lacks `search.messages`, making curl strictly better. Load the `slack` skill for patterns.

**Figma's `mcp.figma.com/mcp`** returns HTTP 405 on GET (not 404) — it is a live MCP endpoint. The 405 is expected; it requires POST per the MCP spec.

**Credentials** live in `~/.env` (not chezmoi-managed): `LINEAR_API_KEY`, `ES_URL`, `ES_API_KEY`, `FIGMA_ACCESS_TOKEN`, `SLACK_USER_TOKEN`.
