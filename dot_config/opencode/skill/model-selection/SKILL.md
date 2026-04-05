---
name: model-selection
description: Model cost tiers, multipliers, and selection guidance for OpenCode agents
---

## When to Load This Skill

Load this skill when:

- Choosing which model to assign to an agent
- Deciding whether a task warrants a premium model or a free one
- Configuring a new agent in `opencode.json`
- Auditing spend

## Configured Providers

| Provider | Auth | Who pays | Billing model |
|---|---|---|---|
| `anthropic` | API key in `~/.env` | **Work** | Pay-per-token |
| `opencode` | `OPENCODE_API_KEY` in `~/.env` | **Personal** | OpenCode Zen subscription — only use free-tier models |
| `ollama` | Local, no auth | **Free** | Self-hosted on device |

Cost philosophy:
- `anthropic` is work-provided — use freely for work, including premium models
- `opencode` is personal — **only use free-tier models** (cost.input == 0 && cost.output == 0)
- `ollama` is always free — prefer for personal repos

## Anthropic Direct — Cost Reference

Billed per token. Approximate relative costs:

| Model | Relative cost | Best for |
|---|---|---|
| `claude-haiku-4-5` | cheapest | Fast, lightweight |
| `claude-sonnet-4-6` | mid | Agentic coding (default) |
| `claude-opus-4-6` | most expensive | Deep analysis (expert agent) |

## OpenCode Zen — Free Models Only

Only use models with `cost.input == 0 && cost.output == 0`.
Requires `OPENCODE_API_KEY` env var. Run `opencode models` to see current free options.

| Model ID | Capabilities | Notes |
|---|---|---|
| `opencode/big-pickle` | tool_call ✓, reasoning ✓ | Strong reasoning, 200k context |
| `opencode/gpt-5-nano` | fast | Lightweight |
| `opencode/minimax-m2.5-free` | general | Free tier |
| `opencode/nemotron-3-super-free` | general | Free tier |
| `opencode/qwen3.6-plus-free` | general | Free tier |

## Ollama — Local Models

Configured in global `opencode.json` under `provider.ollama.models`.

| Config key | Ollama model | Best for |
|---|---|---|
| `ollama/gemma4` | `gemma4:31b` | Personal repo default — strong, local, private |
| `ollama/minimax-m2.7:cloud` | `minimax-m2.7:cloud` | Cloud-routed via Ollama (larger than free tier) |

## Configuration Architecture

Agent model pins live in the **global config** (`~/.config/opencode/opencode.json`) and
apply everywhere. The top-level `model` (default session model) is set **per repo** in
`.opencode/opencode.json` so work and personal repos can differ without touching global config.

### Global config (always applies)

| Agent | Model | Rationale |
|---|---|---|
| `plan` (default agent) | inherits repo `model` | No pin — uses whatever the repo default is |
| `expert` | `anthropic/claude-opus-4-6` | Work-paid; deepest analysis |
| global fallback `model` | `anthropic/claude-sonnet-4-6` | Consistent quality everywhere |

### Work repo `.opencode/opencode.json`

```json
{
  "model": "anthropic/claude-sonnet-4-6"
}
```

### Personal repo `.opencode/opencode.json`

```json
{
  "model": "ollama/gemma4"
}
```

Prefer local ollama models for personal repos — private and free.

## Selection Rules

1. **Agentic coding with tool calls?** → `anthropic/claude-sonnet-4-6` (work-paid)
2. **Deep code review or architecture?** → `anthropic/claude-opus-4-6` (work-paid)
3. **Personal project?** → `ollama/gemma4` (local, private, free)
4. **Personal, no local model or needs stronger reasoning?** → `opencode/big-pickle` (free tier)
