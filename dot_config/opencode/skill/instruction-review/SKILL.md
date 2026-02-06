---
name: instruction-review
description: Review and optimize agent instructions, skills, and commands
---

## When to Use

Load this skill when:
- Agent behavior doesn't match expectations
- Instructions aren't being followed consistently
- Adding new capabilities (skill vs instruction decision)
- Periodic maintenance of agent configuration

## Instruction Hierarchy

```
AGENTS.md (global)          ← Universal rules, always loaded
  └── agent/*.md            ← Agent-specific overrides (build, plan)
       └── skill/*.md       ← On-demand, loaded when invoked
            └── command/*.md ← Slash commands, loaded on invocation
```

**Load order**: Global → Agent → Skills/Commands (on demand)

## Where to Put Instructions

| Content Type | Location | Loaded |
|--------------|----------|--------|
| Safety rules, tool tips | `AGENTS.md` | Always |
| Workflow (TDD, commits) | `agent/build.md` | When using build agent |
| Read-only constraints | `agent/plan.md` | When using plan agent |
| Reference material | `skill/*.md` | On demand via skill tool |
| Verification steps | `command/*.md` | On `/command` invocation |

## Decision: Skill vs Instruction

**Put in agent file if:**
- Must be followed every time (safety, workflow)
- Affects core behavior
- Short (< 10 lines)

**Put in skill if:**
- Reference material (formats, examples, checklists)
- Only needed occasionally
- Longer content that would bloat context

**Put in command if:**
- Triggered by explicit user action
- Self-contained workflow
- Needs fresh context (e.g., `/review`)

## Evaluation Checklist

### 1. Compliance Check

For each rule in agent files, ask:
- Is it being followed? (Test with real tasks)
- If not, is wording unclear? Move up, simplify
- If still not followed, is it important enough to keep?

### 2. Context Budget

Agent files should be lean:
- **Target**: 50-80 lines per agent file
- Count lines: `wc -l dot_config/opencode/agent/*.md`
- If over budget, move reference content to skills

### 3. Redundancy

- Check for duplicate instructions across files
- Global rules shouldn't repeat in agent files
- Skills shouldn't duplicate what's in AGENTS.md

### 4. Effectiveness Test

Run a few representative tasks and note:
- Did the agent follow the workflow?
- Were skills loaded when needed?
- Did safety rules trigger appropriately?

## File Locations (chezmoi)

| Target | Source |
|--------|--------|
| `~/.config/opencode/AGENTS.md` | `dot_config/opencode/AGENTS.md.tmpl` |
| `~/.config/opencode/agent/*` | `dot_config/opencode/agent/*` |
| `~/.config/opencode/skill/*` | `dot_config/opencode/skill/*` |
| `~/.config/opencode/command/*` | `dot_config/opencode/command/*` |

After changes: `chezmoi apply`

## Common Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Rule ignored | Too buried, unclear | Move up, simplify wording |
| Context too large | Too much in agent files | Move to skills |
| Inconsistent behavior | Conflicting rules | Audit for contradictions |
| Skill not loaded | Wrong description | Update skill description |
