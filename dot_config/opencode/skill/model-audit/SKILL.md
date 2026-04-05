---
name: model-audit
description: Audit local Ollama models against opencode config — what's downloaded, what's configured, what's missing
---

## When to Load This Skill

Load this skill when you want to understand the full picture of local vs. configured models, or when model selection isn't working because a model is missing locally.

## Audit Commands

### 1. List locally downloaded Ollama models

```
ollama list
```

### 2. Read current opencode.json config

```
bat ~/.config/opencode/opencode.json
```

### 3. Compare — find models in config that are NOT downloaded

For each model in `opencode.json` under `provider.ollama.models`, check if it exists in `ollama list` output.

### 4. Check for unused downloaded models

Models in `ollama list` output that are NOT referenced in `opencode.json` are "extra" — consider `ollama rm` to reclaim disk.

## Common Issues & Fixes

| Issue | Fix |
|---|---|
| Model in config but not downloaded | `ollama pull <model-name>` |
| Unused downloaded model | `ollama rm <model-name>` to reclaim disk |
| Model pinned in config but want to swap | Update `~/.config/opencode/opencode.json` or repo `.opencode/opencode.json` |
| Mistaken: wrong model name in config | Exact model ID must match `ollama list` NAME column |

## Model Name Mapping

opencode.json model keys are **logical names** — they don't have to match the Ollama model name exactly. The `name` field under each model entry is what gets sent to the API.

Example:
```json
"models": {
  "qwen3-coder": {           // ← logical key in config
    "name": "qwen3-coder"    // ← actual Ollama model name
  }
}
```

So if `ollama list` shows `qwen3-coder:latest`, the config `"name": "qwen3-coder"` maps correctly.

## Quick Audit Script

Run this to get a full picture:

```bash
echo "=== DOWNLOADED ===" && ollama list && echo "=== CONFIG ===" && jq '.provider.ollama.models | keys' ~/.config/opencode/opencode.json
```

Then diff the two lists manually.
