---
name: model-eval
description: Evaluate and optimize OpenCode model configuration
---

## When to Use

Load this skill when:
- New models become available
- Evaluating model performance for different agents
- Optimizing cost vs capability tradeoffs
- Quota exceeded on a provider

## Required Steps

**Do NOT skip any step.** Complete each before proceeding. Report findings to user after each step.

### Step 1: Read Current Config

```bash
cat ~/.config/opencode/opencode.json
```

Identify: current models per role, configured providers, aliases.

### Step 2: Quota Check

Open quota page and **ask the user** for current usage:

```bash
open "https://github.com/settings/copilot"
```

Ask: "What's your current Copilot premium request usage percentage?"

Record: `___%` — if >90%, deprioritize Copilot for flagship models.

### Step 3: Discovery

List models from ALL providers (run in parallel):

```bash
CLI=/Applications/OpenCode.app/Contents/MacOS/opencode-cli
$CLI models anthropic
$CLI models github-copilot
$CLI models openai
$CLI models ollama
```

Ignore providers that return errors (not configured). Present a summary table of **new or notable models** not in current config.

### Step 4: Test Candidates

**Every model considered for a role MUST be tested.** Run all tests in parallel:

```bash
CLI=/Applications/OpenCode.app/Contents/MacOS/opencode-cli
$CLI run -m <provider>/<model> "Say only 'working'" 2>&1 | tail -5
```

Use 60s timeout. Record results in a table:

| Model | Provider | Result |
|-------|----------|--------|
| ... | ... | working / quota exceeded / timeout / error |

### Step 5: Present Recommendations

Show the user a comparison table:

| Role | Current | Recommended | Provider | Rationale |
|------|---------|-------------|----------|-----------|
| build | ... | ... | ... | ... |
| plan | ... | ... | ... | ... |
| explore | ... | ... | ... | ... |
| small_model | ... | ... | ... | ... |
| default | ... | ... | ... | ... |

Optimization priorities:
1. **Capability** — best available model for each role
2. **Availability** — must be working (not quota-exceeded or timed out)
3. **Unlimited > quota-based** — prefer direct API (no limits) over quota-based when capability is comparable
4. **Quota-based for savings** — use quota-included models only for roles where they're as good as alternatives
5. **Redundancy** — keep aliases for quota-exceeded models (they'll recover)

**Wait for user approval before making changes.**

### Step 6: Update Config

Edit `dot_config/opencode/opencode.json` (chezmoi source, NOT target).

Ensure every provider with working models has aliases configured:
- Short names: `opus`, `sonnet`, `gemini`, `flash`, `gpt`, `qwen`
- Keep aliases for quota-exceeded models (they'll work when quota resets)

### Step 7: Apply and Verify

Apply and test each role's model:

```bash
chezmoi apply
CLI=/Applications/OpenCode.app/Contents/MacOS/opencode-cli
$CLI run -m <build-model> "Say 'build ok'"
$CLI run -m <plan-model> "Say 'plan ok'"
$CLI run -m <explore-model> "Say 'explore ok'"
$CLI run -m <small-model> "Say 'small ok'"
```

**All must respond.** If any fail, go back to Step 5.

## Role Reference

| Role | Optimize For | Typical Tier |
|------|--------------|--------------|
| **build** | Coding accuracy, tool use, instruction following | Flagship |
| **plan** | Reasoning, architecture, read-only analysis | Flagship or Standard |
| **explore** | Large context window, fast navigation | Standard (high context) |
| **small_model** | Speed, cost efficiency for quick tasks | Fast |
| **default** | All-around capability | Usually matches plan |

## Provider Reference

| Provider | Quota | Cost | Notes |
|----------|-------|------|-------|
| `github-copilot` | Monthly premium requests | Subscription | Check: https://github.com/settings/copilot |
| `anthropic` | None | Pay-per-use | Best Opus/Sonnet access |
| `openai` | None | Pay-per-use | GPT models |
| `ollama` | Unlimited | Free (local) | Offline fallback |

## Alias Guidelines

- Short (4-8 chars): `opus`, `sonnet`, `gemini`, `flash`, `gpt`, `qwen`
- Version suffix only when multiple versions coexist: `opus46`, `opus45`
- Keep aliases for models across providers (user picks via model switcher)
