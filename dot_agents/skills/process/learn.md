# Learning Capture

After surprising failures, hidden dependency discoveries, or non-obvious workarounds — extract learnings so they persist across sessions.

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

AGENTS.md files can exist at any directory level. When an agent reads a file, any AGENTS.md in parent directories are automatically loaded. Place learnings close to the relevant code:

- Project-wide → root `AGENTS.md`
- Package/module-specific → `packages/foo/AGENTS.md`
- Feature-specific → `src/auth/AGENTS.md`

## AGENTS.md vs Skills

Put it in **AGENTS.md** if agents need it proactively on every session (safety rules, workflow constraints, always-applicable tool tips).

Put it in a **skill** if it's reactive/situational — only needed when a specific problem arises or task is requested. Good candidates: troubleshooting procedures, specialized workflows, fix recipes for recurring issues. Create skills under `~/.agents/skills/<name>/SKILL.md` with `name:` and `description:` frontmatter.

When in doubt: if you'd only reach for it when something goes wrong or a specific task is asked, make it a skill.

## Input

If given specific context about what to capture (e.g., "capture the retry logic discovery" or "focus on the auth module"), prioritize that over general session introspection.

## Process

1. Review session for discoveries, errors that took multiple attempts, unexpected connections
2. Determine scope — what directory does each learning apply to?
3. Read existing AGENTS.md files at relevant levels
4. Create or update AGENTS.md (or create a new skill) at the appropriate level — check existing skills under `~/.agents/skills/` before creating new ones to avoid duplicates
5. Keep entries to 1-3 lines per insight

After updating, summarize which files were created/updated and how many learnings per file.
