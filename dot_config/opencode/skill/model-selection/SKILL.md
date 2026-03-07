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
| `anthropic` | API key | **Work** | Pay-per-token |
| `github-copilot` | Copilot Business seat | **Work** | Monthly seat + premium request multipliers |
| `opencode` | `OPENCODE_API_KEY` env var | **Personal** | OpenCode Zen subscription — only use free-tier models |

Cost philosophy:
- `anthropic` is work-provided — use freely, including premium models
- `github-copilot` is work-provided but **premium request allowance is limited** — reserve it for Copilot PR review; in OpenCode, **only use 0× multiplier models** (`gpt-4o`, `gpt-4.1`, `gpt-5-mini`)
- `opencode` is personal — **only use free-tier models** (cost.input == 0 && cost.output == 0)

## GitHub Copilot — Cost Tiers

All models below confirmed working with a Copilot Business seat
(`sku: copilot_for_business_seat_quota`) as of 2026-03.

### Free (0× multiplier)

| Model ID | Config alias | Best for |
|---|---|---|
| `gpt-4o` | `gpt-4o` | General-purpose fallback |
| `gpt-4.1` | `gpt-4.1` | General coding, planning, research |
| `gpt-5-mini` | `gpt-5-mini` | Fast, lightweight tasks |

### Do not use in OpenCode (burns premium requests needed for PR review)

| Model ID | Multiplier |
|---|---|
| `claude-haiku-4.5` | 0.33× |
| `gpt-5.1-codex-mini` | 0.33× |
| `claude-sonnet-4.6` | 1× |
| `gemini-2.5-pro` | 1× |
| `claude-opus-4.5` / `claude-opus-4.6` | 3× |
| (and all others with multiplier > 0) | |

## OpenCode Zen — Free Models Only

Only use models with `cost.input == 0 && cost.output == 0` (personal cost).
Requires `OPENCODE_API_KEY` env var.

| Model ID | Config alias | Capabilities | Notes |
|---|---|---|---|
| `big-pickle` | `pickle` | tool_call ✓, reasoning ✓ | Strong reasoning, 200k context |

## Anthropic Direct — Cost Reference

Billed per token. Approximate relative costs (not absolute):

| Model | Relative cost | Best for |
|---|---|---|
| `claude-haiku-4-5` | cheapest | Fast, lightweight |
| `claude-sonnet-4-6` | mid | Agentic coding (default) |
| `claude-opus-4-6` | most expensive | Deep analysis (expert agent) |

**Prefer Copilot over Anthropic direct** for models that appear in both, since
Copilot Business makes them free or cheaper (0–1× vs pay-per-token).

Exception: if Copilot has an outage or you need a model only on Anthropic direct.

## Ollama — Local Models

Free, no network cost. Current model: `llama3.1`.
Only useful for tasks that don't require strong tool-calling or reasoning.
Not suitable for agentic coding.

## Configuration Architecture

Agent model pins live in the **global config** (`~/.config/opencode/opencode.json`) and
apply everywhere. The top-level `model` (default session model) is set **per repo** in
`.opencode/opencode.json` so work and personal repos can differ without touching global config.

### Global config (always applies)

| Agent | Model | Rationale |
|---|---|---|
| `plan` (default agent) | inherits repo `model` | No pin — uses whatever the repo default is |
| `expert` | `anthropic/claude-opus-4-6` | Work-paid; deepest analysis |
| global fallback `model` | `github-copilot/gpt-4.1` | Safe free fallback if repo config is missing |

### Work repo `.opencode/opencode.json`

```json
{
  "model": "anthropic/claude-sonnet-4-6"
}
```

### Personal repo `.opencode/opencode.json`

```json
{
  "model": "opencode/big-pickle"
}
```

Only `expert` has a global model pin. `plan` inherits the repo `model` so it uses the
same model as the default session — no redundant config needed.

## Selection Rules

1. **Agentic coding with tool calls?** → `anthropic/claude-sonnet-4-6` (best tool-calling; work-paid)
2. **Deep code review or architecture?** → `anthropic/claude-opus-4-6` (work-paid)
3. **Read-only research or planning?** → `github-copilot/gpt-4.1` (0× — no premium spend)
4. **Lightweight single-shot question?** → `github-copilot/gpt-5-mini` (0× — no premium spend)
5. **Personal project, no work account?** → `opencode/big-pickle` (free tier)
6. **Never use Copilot premium models in OpenCode** — premium allowance is reserved for Copilot PR review
8. **Never use `opencode` paid models** — personal cost

## How to Refresh the Copilot Model List

Multiplier table source:
`https://docs.github.com/en/copilot/concepts/billing/copilot-requests#model-multipliers`

To query available models live:

```bash
COPILOT_TOKEN=$(cat ~/.config/github-copilot/apps.json | jq -r 'to_entries[0].value.oauth_token')
SESSION_TOKEN=$(curl -s \
  -H "Authorization: token $COPILOT_TOKEN" \
  -H "Editor-Version: vscode/1.95.0" \
  https://api.github.com/copilot_internal/v2/token | jq -r '.token')

curl -s \
  -H "Authorization: Bearer $SESSION_TOKEN" \
  -H "Editor-Version: vscode/1.95.0" \
  https://api.business.githubcopilot.com/models \
  | jq '[.data[] | select(.model_picker_enabled == true) | {id, name, category: .model_picker_category}]'
```
