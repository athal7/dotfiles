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
- `agent/` - primary agent overrides (`build.md`, `plan.md`)
- `command/` - slash commands (`/qa`, `/review`, `/todo`)

**Per-project config** (`.opencode/` in repo root):
- `command/` - project-specific slash commands
- Custom tools, agents, themes

## Agent Structure

| Location | Purpose |
|----------|---------|
| `dot_config/opencode/AGENTS.md.tmpl` | Universal rules (safety, CLI tools, task completion) - auto-generates command list |
| `dot_config/opencode/agent/build.md` | Primary agent: TDD workflow, commits, context log |
| `dot_config/opencode/agent/plan.md.tmpl` | Primary agent: read-only analysis and architecture |
| `dot_config/opencode/command/*.md` | Slash commands (loaded on-demand when invoked) |

**Adding a new command**:
1. Create `.md` file in `command/` with YAML frontmatter including `description:`
2. Run `chezmoi apply` - command list auto-updates in AGENTS.md

## Agent File Guidelines

**Keep agent files lean** to maintain compliance as sessions grow:

- **Target**: 50-80 lines per agent file
- **Behavioral rules** (what to do/not do) → keep in agent
- **Reference material** (formats, examples, checklists) → move to skills or docs
- **On-demand content** (verification steps, review criteria) → use commands

**Test for necessity**: If an instruction isn't followed after several sessions:
1. Make it more prominent (move up, simplify wording)
2. Or remove it (not important enough to enforce)
