---
description: Capture non-obvious discoveries from this session into AGENTS.md
---

## What to Capture

Analyze the session for non-obvious learnings that agents need **proactively on every session**, regardless of task: safety rules, workflow constraints, always-applicable gotchas.

- Hidden relationships between files or modules
- Execution paths that differ from how code appears
- Non-obvious configuration, env vars, or flags
- Architectural decisions and constraints
- Files that must change together

**Do NOT capture:**

- Obvious facts from documentation
- Standard language/framework behavior
- Things already in an AGENTS.md
- Verbose explanations
- Session-specific details (timestamps, branch names, etc.)
- Situational/reactive knowledge — debugging breakthroughs, API/tool quirks and workarounds, fix recipes for recurring issues, troubleshooting procedures. That's `cq`'s job, not this command's: `cq propose` it in the moment, or run `/cq:reflect` at session end to catch anything missed. `cq` is query-on-demand and can't load anything proactively, which is why AGENTS.md still needs this command for the always-loaded half.

## Where to Place Learnings

AGENTS.md files can exist at any directory level and are automatically loaded when an agent reads files in that tree.

- Project-wide: root `AGENTS.md`
- Package/module-specific: `packages/foo/AGENTS.md`
- Feature-specific: `src/auth/AGENTS.md`

The global `~/.config/opencode/AGENTS.md` is chezmoi-managed — edit it at `$(chezmoi source-path)/dot_config/opencode/AGENTS.md`.

## Input

If given specific context about what to capture (e.g., "capture the retry logic discovery" or "focus on the auth module"), prioritize that over general session introspection:

$ARGUMENTS

## Quality Gate — Before You Write

Every line you add should clear this bar: **does the agent genuinely not know this, or would it figure it out from docs?**

| Type | Definition | Treatment |
|------|------------|-----------|
| **Expert** | Agent won't know this without being told | Keep — this is the value |
| **Activation** | Agent knows but might not think of it | Keep only if brief (1 line max) |
| **Redundant** | Standard behavior, in docs, or obvious | Delete — wastes context |

Target: >70% Expert content. If most lines are Activation or Redundant, the learning isn't worth capturing.

## Process

1. Review session for discoveries that belong in every future session's context, not something situational `cq` should hold instead
2. Read the existing AGENTS.md at the relevant directory level
3. Update it, or create a new one if nothing fits
4. Apply the quality gate — strip Redundant content, keep Expert tight
5. Keep entries to 1-3 lines per insight

After updating, summarize which AGENTS.md files were created/updated and how many learnings per file.
