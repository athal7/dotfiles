# Editing skills

## Is it even a skill?

A skill fires at a **specific, named moment**. Guidance that applies to every session of some kind belongs in an always-loaded instructions file instead — if you catch yourself writing "this should fire on every code change", it isn't a skill.

"This orchestrates several other skills" → you're building a phase graph; split it.

## What earns a line

**Would a strong model behave worse without this line?** If no, cut it.

Keep: exact CLI invocations and flags, file paths, auth setup, silent failure modes, wrong-output traps, numeric caps, org conventions, hard-won gotchas. Cut: anything `<binary> --help` says, generic engineering advice, restated model knowledge, and rationale for a rule the reader already accepted.

## Shape

- **The description is the trigger** — the only thing seen before deciding to load. State the situation, not the topic.
- **Under ~80 lines.**
- **Imperative steps, not phase graphs.** Use a decision tree when a skill has multiple paths.
- **Keep required action in the triggering skill.** Referenced sub-files are not loaded automatically; put longer programs in `$PATH` as scripts.

## Public repo

Never hard-code values configured per-workspace: template names, project names, team keys, channel names, account IDs, internal URLs. Teach the agent to *discover* them — show the query, command, or config file that surfaces each user's own. True public constants of a tool (documented endpoints, stable command names) are fine.

For remote APIs, document request and response *shape* — endpoints, body structure, response field paths, gotchas. Not code that calls them.

## Before you commit

Run `agentskills validate` on the skill directory.
