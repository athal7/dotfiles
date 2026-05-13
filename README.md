# athal7's dotfiles

Manages `~` on macOS via [chezmoi](https://chezmoi.io). Covers shell, editor, AI tooling, calendar automation, and a library of AI agent skills.

## Quick start

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

You'll be prompted for a few required values (name, email, code directory, GitHub token, calendar names). Optional integrations — Slack, Figma, Elasticsearch, Linear, PagerDuty, ICS feeds, etc. — can be added by editing `~/.config/chezmoi/chezmoi.toml` after init. See the commented sections in [`.chezmoi.toml.tmpl`](.chezmoi.toml.tmpl) for the full list.

## Machine-specific config

Per-machine values that don't belong in version control (secrets manifest, calendar configuration, per-org overrides) live in `~/.local/share/chezmoi/.chezmoidata/local.yaml`. Copy [`local.yaml.example`](local.yaml.example) from this repo's root and fill in your values.

`orgs.<org>` keys cover per-GitHub-org behaviors used by the agent skills:

- `issues: linear` routes issue management to Linear instead of GitHub Issues
- `automated_review` declares an embedded code reviewer (e.g. GitHub Copilot review) — the [`review`](skills/review/) skill consumes prior automated findings instead of duplicating them locally

Note: the example file lives at the repo root rather than under `.chezmoidata/`. Files inside `.chezmoidata/` are merged into `chezmoi data` at runtime, which would leak placeholder values into the live config.

## What's configured

- **Shell** — zsh (`dot_zshrc.tmpl`, `dot_zshenv.tmpl`, `dot_zprofile.tmpl`)
- **Editor** — Neovim (`dot_config/nvim/`)
- **Git** — config, aliases, hooks (`dot_config/git/`)
- **Terminal** — Ghostty (`dot_config/ghostty/`)
- **AI tooling** — OpenCode config, MCPs, plugins, agent instructions (`dot_config/opencode/`)
- **Packages** — brew, cask, mise, GitHub releases (`.chezmoidata/packages.yaml`)
- **Calendar automation** — sync, lunch guard, family scheduler (`dot_local/bin/`, `Library/LaunchAgents/`)
- **Homebridge** — Google Nest via HomeKit (`dot_homebridge/`)
- **macOS services** — LaunchAgents for background processes (`Library/LaunchAgents/`)
- **Agent skills** — see [`skills/`](skills/)

## Local model setup (LM Studio)

LM Studio serves the local model used by OpenCode for agentic coding. Ollama remains installed for the `minutes` skill and cloud-proxied models, but qwen3-family models leak XML tool-calls through Ollama's OpenAI-compatible endpoint (see [OpenCode #26162](https://github.com/anomalyco/opencode/issues/26162), [#24316](https://github.com/anomalyco/opencode/issues/24316), [#4428](https://github.com/anomalyco/opencode/issues/4428)). LM Studio is the most-reported working setup.

One-time bootstrap after `chezmoi apply` installs the cask:

```bash
# 1. Launch LM Studio.app once — sets up ~/.lmstudio/ and accepts quarantine
open -a "LM Studio"
# (close the app after first launch)

# 2. Install the lms CLI on PATH
npx lmstudio install-cli

# 3. Verify
lms --help

# 4. In LM Studio GUI → Developer tab, enable "Run server on login"
#    (makes the server auto-start without keeping the GUI open)

# 5. Download Qwen 3.5 27B Unsloth UD-IQ3_XXS (~11.5 GB)
#    LM Studio's `lms get` can't target a specific quant — download via curl.
mkdir -p ~/.lmstudio/models/unsloth/Qwen3.5-27B-GGUF
curl -fL -o ~/.lmstudio/models/unsloth/Qwen3.5-27B-GGUF/Qwen3.5-27B-UD-IQ3_XXS.gguf \
  "https://huggingface.co/unsloth/Qwen3.5-27B-GGUF/resolve/main/Qwen3.5-27B-UD-IQ3_XXS.gguf?download=true"

# 6. Load with a stable identifier matching opencode.json
lms load unsloth/Qwen3.5-27B-GGUF --identifier qwen3.5-27b --context-length 32768 --ttl 999999

# 7. Verify the server is up
curl http://localhost:1234/v1/models | jq
```

After step 4, the server auto-starts on each login. Reference the model in OpenCode as `lmstudio/qwen3.5-27b`.

To benchmark: `bench-opencode -m lmstudio/qwen3.5-27b` drives the OpenCode HTTP API through 6 realistic agent scenarios. See [`dot_local/bin/executable_bench-opencode`](dot_local/bin/executable_bench-opencode).

### Picking a model

Glukhov maintains an empirical comparison of local models for OpenCode agentic coding, with measured error rates on real coding tasks: **<https://www.glukhov.org/ai-devtools/opencode/llms-comparison/>**. Top recommendations as of May 2026:

- **Qwen 3.5 27B Unsloth UD-Q3_XXS** — 5.0% error rate (clear winner)
- **Qwen3-Coder-Next UD-IQ4_XS** — fastest, 8.8% error rate
- **Gemma 4 26B A4B IQ4_XS** — 6.3% error rate

Glukhov tests on llama.cpp, but LM Studio can serve the same Unsloth GGUFs and ships patched chat templates. Quantization source matters — Unsloth quants have patched templates that Bartowski quants do not, which materially affects tool-call quality.

## Agent Skills

[Agent Skills](https://agentskills.io)-compatible skills deployed to `~/.agents/skills/`. Works with [OpenCode](https://opencode.ai) and any compatible agent.

Skills use a capability-based composition system — workflow skills declare what they `requires`, and [`skills/capabilities.yaml`](skills/capabilities.yaml) binds capabilities to providers (a skill, `cli://<binary>`, or `mcp://<server>`). This lets workflow skills stay tool-agnostic: swap Linear for Jira by changing one line. See [agentskills/agentskills#311](https://github.com/agentskills/agentskills/discussions/311) for the spec proposal.

## Mechanical workflow enforcement

Skills tell the agent *what* to do. Without mechanical enforcement, every skill is a polite suggestion the agent skim-selects from. High-stakes actions — `git commit`, `git push`, any `gh` write — are gated through opencode's [permission config](https://opencode.ai/docs/permissions) in [`opencode.json`](dot_config/opencode/opencode.json): patterns marked `"ask"` prompt for approval before the action runs, and the user picks `once`, `always`, or `reject` per prompt. Common reads like `gh pr list` and `gh issue view` are explicitly `"allow"` to avoid prompt fatigue.

### Installing individual skills

**With the GitHub CLI:**

```bash
gh skill install athal7/dotfiles commit
gh skill install athal7/dotfiles review
```

**With chezmoi** — declare skills in `.chezmoidata/packages.yaml` and use a `run_onchange_` script to install and update them weekly. See [my sync script](.chezmoiscripts/run_onchange_after_sync-and-validate-skills.sh.tmpl) as a reference:

```yaml
# .chezmoidata/packages.yaml
packages:
  skills:
    - repo: athal7/dotfiles
      skill: commit
    - repo: athal7/dotfiles
      skill: review
```
