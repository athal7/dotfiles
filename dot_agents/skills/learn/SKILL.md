---
name: learn
description: Capture non-obvious discoveries, hidden dependencies, and workarounds from the current session into AGENTS.md or a new skill
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides:
    - learn
---

## What to Capture

Analyze the session for non-obvious learnings only:

- Hidden relationships between files or modules
- Execution paths that differ from how code appears
- Non-obvious configuration, env vars, or flags
- Debugging breakthroughs when error messages were misleading
- API/tool quirks and workarounds
- Build/test commands not in README
- Architectural decisions and constraints
- Files that must change together

**Do NOT capture:**

- Obvious facts from documentation
- Standard language/framework behavior
- Things already in an AGENTS.md
- Verbose explanations
- Session-specific details (timestamps, branch names, etc.)

## Where to Place Learnings

Two equally valid destinations -- choose based on when the knowledge is needed:

### AGENTS.md

Use for learnings that agents need **proactively on every session**: safety rules, workflow constraints, always-applicable gotchas. AGENTS.md files can exist at any directory level and are automatically loaded when an agent reads files in that tree.

- Project-wide: root `AGENTS.md`
- Package/module-specific: `packages/foo/AGENTS.md`
- Feature-specific: `src/auth/AGENTS.md`

### Skills

Use for learnings that are **reactive/situational** -- only needed when a specific problem arises or task is requested. This includes: troubleshooting procedures, specialized workflows, fix recipes for recurring issues, tool-specific gotchas.

**Prefer updating an existing skill over creating a new one.** Check `~/.agents/skills/` first -- the learning often belongs as a new section, example, or failure mode in a skill that already exists. Create a new skill only when no existing skill covers the domain.

New skills go under `~/.agents/skills/<name>/SKILL.md` with `name:` and `description:` frontmatter. The description is the trigger -- make it specific enough for the agent to know when to load it.

### Decision rule

If the knowledge is needed every session regardless of task, use AGENTS.md. If you'd only reach for it when something specific goes wrong or is asked, use a skill.

## Input

If given specific context about what to capture (e.g., "capture the retry logic discovery" or "focus on the auth module"), prioritize that over general session introspection.

## Quality Gate — Before You Write

Every line you add should clear this bar: **does the agent genuinely not know this, or would it figure it out from docs?**

| Type | Definition | Treatment |
|------|------------|-----------|
| **Expert** | Agent won't know this without being told | Keep — this is the value |
| **Activation** | Agent knows but might not think of it | Keep only if brief (1 line max) |
| **Redundant** | Standard behavior, in docs, or obvious | Delete — wastes context |

Target: >70% Expert content. If most lines are Activation or Redundant, the learning isn't worth capturing.

**The description is the trigger.** For new skills, the description is the only thing the agent sees before deciding whether to load it. A vague description means the skill never activates. Make it specific: what situation, what problem, what the agent gains.

## Process

1. Review session for discoveries, errors that took multiple attempts, unexpected connections
2. For each learning, decide: AGENTS.md or skill?
3. Read existing files at the target location (AGENTS.md at relevant directory level, or existing skill)
4. Update the existing file, or create a new one if nothing fits
5. Apply the quality gate — strip Redundant content, keep Expert tight
6. Keep entries to 1-3 lines per insight

After updating, summarize which files were created/updated and how many learnings per file.
