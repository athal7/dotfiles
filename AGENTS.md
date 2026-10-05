# Chezmoi Dotfiles Repository

This repo manages `~` via chezmoi. Edit source files here.

**No pull requests — deploy is the ship step.** Land changes with `chezmoi-deploy <branch>`: it fast-forward-merges the branch into the primary checkout's `main`, runs `chezmoi apply`, and pushes `main` to origin as a mirror. Only `chezmoi apply` mutates your live `~`. Load the chezmoi skill for verify-render-only and deploy mechanics.

**LaunchAgents:** Edit `dot_config/launchd-yaml/agents.yaml.tmpl`, not generated plists. `.chezmoiscripts/run_onchange_after_zz-launch-agents.sh.tmpl` delegates to `launchd-yaml apply` after package installation; it reloads only changed plists and prunes removed agents.

## Source of truth

- Packages: edit only `.chezmoidata/packages.yaml`; install scripts and `.chezmoiexternal.toml.tmpl` are generated from it.
- OMP: `dot_config/omp/private_agent/private_config.yml.tmpl` renders agent config; `APPEND_SYSTEM.md` in that directory owns its system prompt. `PI_CONFIG_DIR=.config/omp` selects the global root and `PI_CODING_AGENT_DIR` selects the agent path for shells, AoE, and LaunchAgents. MCP server data lives in `.chezmoidata/mcp.yaml`.
- Authored skills: `dot_agents/skills/` manages `~/.agents/skills/`; externally installed skills own separate siblings.
- Private machine/org values: gitignored `.chezmoidata/local.yaml`; public shape in `local.yaml.example`.

## Agent Operating Rules

- OMP MCP server names are selector labels. When referring to exposed MCP tools, use server/tool names with hyphens converted to underscores. Server-specific read-only MCP exceptions belong in that server's `approval_allow` field in `.chezmoidata/mcp.yaml`; OMP prompts for registered remote MCP tools whose names indicate mutation, but native approvals cannot inspect tool arguments.
- Browser use requires affirmative user consent before the first browser API call in each OMP session. This is instruction-based, not enforced by OMP tool approval. Consent does not authorize consequential actions or navigation in the user's visible tab.
- Keep code-review findings unlabeled; prefix only nits with `nit:`. For pull-request reviews, anchor each finding to a diff line when possible.
- Daily maintenance runs production-error triage and KB enrichment independently. Report outcomes separately; a settled worker or scheduled launcher exit does not establish complete coverage. Unanswered approvals and uncertain writes remain pending; do not retry timed-out writes until their outcome is known. The KB MCP overlay is for collector access; the KB Markdown vault remains canonical for facts and evidence. OMP Mnemopi stores curated agent-learned insights only; never copy KB records into it.
- For GitHub session actions in attention, use a checkout under `codeDir` or a registered AoE project whose GitHub origin matches the item. Register any checkout outside `codeDir` with AoE first.
- Before changing Homebridge's storage path, stop its LaunchAgent; verify `~/.homebridge/config.json` exists and parses. Preserve an existing `~/.config/homebridge` by renaming it to a unique backup, move the complete legacy directory, verify the moved JSON, then restart.

## Public Repo — Privacy Guidelines

This is a **public repository**. Never commit employer/internal names, URLs, hosts, infrastructure, personal identifiers, or credentials. Use generic examples (`myapp`, `myorg`, `your-repo`); put private values in gitignored chezmoi data or `~/.config/zsh/private.zsh`. For secrets, use `promptStringOnce` in `.chezmoi.toml.tmpl` and `modify_private_dot_env.tmpl`.

## README

Update `README.md` for structural changes affecting setup or use (skills, LaunchAgents, config sections, package registry design); keep agent operating rules here.
