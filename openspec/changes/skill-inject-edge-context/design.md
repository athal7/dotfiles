## Context

The skill-inject plugin (`skill-inject.ts`) intercepts skill tool calls via `tool.execute.before`/`after` hooks. When a configured skill loads, it appends a footer listing related skills with their frontmatter descriptions. The config is `Record<string, string[]>` — skill name to array of target skill names. The `buildInjection` function reads each target's `SKILL.md` frontmatter description and formats `- load \`name\` skill (description)`. Current footer example: `- load \`xh\` skill (HTTPie-compatible HTTP client for REST API calls)`.

The footer tells agents WHAT to load but not WHY or HOW to use the injected skill in context. This creates multi-hop indirection — the agent must load the recommended skill, find the relevant info, then connect it back. Observed failure: agents loading API skills don't connect them to xh sessions for auth; they try raw Authorization headers, fail, and go credential hunting.

## Goals / Non-Goals

**Goals:**

- Allow per-edge context hints so agents understand WHY two skills are related
- Backward compatible — plain string entries keep working identically
- Minimal plugin change — extend the existing mechanism, don't replace it

**Non-Goals:**

- Auto-loading injected skills (loading the full content would change skill loading semantics)
- New frontmatter fields on skills (keeps agentskills spec compatibility)
- Changing the injection footer format beyond adding context hints

## Decisions

1. **Config format: union type `(string | {skill: string, context: string})[]`**
   - Why: Backward compatible, minimal syntax for simple cases, explicit context when needed
   - Alternative: Separate config section for hints — rejected because it splits the relationship definition across two places
   - Alternative: New frontmatter field on target skill — rejected because description serves skill selection (needs to be short) and context serves injection (needs to be actionable); different audiences

2. **Render context instead of description when present**
   - When a config entry is an object with `context`, the footer line becomes: `- load \`name\` skill — <context>`
   - The description is omitted (not appended) because the context replaces its purpose in the injection footer
   - Why: Keeps lines concise; the context IS the relevant info for the loading agent

3. **Update skills AGENTS.md auth guidance**
   - The `$VARIABLE` pattern for API skill auth is supplemented with guidance about edge context: when an API skill is injected alongside an HTTP client skill, the injection config's context hint should tell the agent how to authenticate
   - Why: The current `$VARIABLE` guidance assumes env-var auth but the actual auth mechanism is xh sessions. The guidance should match reality.

## Risks / Trade-offs

- Context hints in the config are plain strings with no validation — risk of stale or incorrect hints if the target skill changes. Mitigation: hints are short and stable (e.g., "use --session=agent for auth" won't change often).
- The `inject_list` tool output currently shows simple name lists. It should be updated to show context hints too. Low risk — only used for debugging.
