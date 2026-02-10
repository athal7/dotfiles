---
description: Review and optimize agent instructions, skills, and commands
---

Audit the OpenCode agent configuration for this dotfiles repo.

$ARGUMENTS

## Instruction Hierarchy

```
Base system prompt (upstream)  ← Built into OpenCode, auto-updated
  + AGENTS.md (global)         ← Universal rules, always loaded
  + opencode.json              ← Agent config (models, permissions, temperature)
  + skill/*.md                 ← On-demand, loaded via skill tool
  + command/*.md               ← Loaded on /command invocation
```

## Where to Put Things

| Content Type | Location | Loaded |
|--------------|----------|--------|
| Safety rules, tool tips | `AGENTS.md` | Always |
| Agent config (model, permissions, temperature) | `opencode.json` | Always |
| Workflows, methodologies, checklists | `skill/*.md` | On demand via skill tool |
| User-triggered workflows | `command/*.md` | On `/command` invocation |

## Decision: Skill vs Command

**Put in `opencode.json` if:**
- Model, temperature, permission overrides
- Agent-specific settings (per-agent under `agent.*`)

**Put in skill if:**
- Reference material (formats, examples, checklists)
- Only needed occasionally
- Longer content that would bloat always-on context

**Put in command if:**
- Triggered by explicit user action (`/qa`, `/todo`)
- Self-contained workflow with `$ARGUMENTS`

## Evaluation Checklist

### 1. Compliance Check

For each rule in AGENTS.md, ask:
- Is it being followed? (Test with real tasks)
- If not, is wording unclear? Move up, simplify
- If still not followed, is it important enough to keep?

### 2. Context Budget

AGENTS.md should be lean — it's loaded on every conversation.
- Count lines: `wc -l dot_config/opencode/AGENTS.md.tmpl`
- Move reference content to skills if it's growing

### 3. Redundancy

- Check for duplicate instructions across files
- Skills shouldn't duplicate what's in AGENTS.md
- Skills auto-appear in the skill tool listing — no need to reference them elsewhere

### 4. Effectiveness Test

Run a few representative tasks and note:
- Did the agent follow the workflow?
- Were skills loaded when needed?
- Did safety rules trigger appropriately?

## File Locations (chezmoi)

| Target | Source |
|--------|--------|
| `~/.config/opencode/AGENTS.md` | `dot_config/opencode/AGENTS.md.tmpl` |
| `~/.config/opencode/opencode.json` | `dot_config/opencode/opencode.json` |
| `~/.config/opencode/skill/*` | `dot_config/opencode/skill/*` |
| `~/.config/opencode/command/*` | `dot_config/opencode/command/*` |

After changes: `chezmoi apply`

## Common Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Rule ignored | Too buried, unclear | Move up, simplify wording |
| Context too large | Too much in AGENTS.md | Move to skills |
| Inconsistent behavior | Conflicting rules | Audit for contradictions |
| Skill not loaded | Wrong description | Update skill description |
