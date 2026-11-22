# Editing skills

## Is it even a skill?

A skill fires at a **specific, named moment**. Guidance that applies to every session of some kind belongs in an always-loaded instructions file instead — if you catch yourself writing "this should fire on every code change", it isn't a skill.

"This orchestrates several other skills" → you're building a phase graph; split it.

## What earns a line

**Would a strong model behave worse without this line?** If no, cut it.

Keep: exact CLI invocations and flags, file paths, auth setup, silent failure modes, wrong-output traps, numeric caps, org conventions, hard-won gotchas. Cut: anything `<binary> --help` says, generic engineering advice, restated model knowledge, and rationale for a rule the reader already accepted.

**Write a rule as a hard line.** A gray area is where an agent quietly does something else, so say ALWAYS or NEVER in one sentence rather than describing a preference — a hard line at least fails visibly. Give the reason only where the agent would otherwise read the line as optional; a reason it already accepts is the rationale above, cut it.

## Shape

- **The description is the trigger** — the only thing seen before deciding to load, so state the situation the caller is in, not the topic. `reminders: macOS Reminders via remindctl CLI` is a topic nobody opens; name the moment (`use when a reminder looks missing`) and what opening it buys. An undersold description costs the whole skill, so it carries more weight than any rule inside it.
- **Under ~80 lines.** When a topic outgrows that, move the detail to `references/<topic>.md` and leave a one-line index entry in SKILL.md that says when to open it.
- **Imperative steps, not phase graphs.** Use a decision tree when a skill has multiple paths.
- **Keep required action in the triggering skill.** A `references/` file is not loaded automatically — SKILL.md must link it, and the link is how the agent decides to pay for the next layer. Runnable programs still belong in `$PATH` as scripts, not in a reference file. For the same reason, restate a rule in each skill that needs it rather than factoring it into a shared file or pointing at another skill that is not guaranteed to be loaded — duplicated text is cheap, a gate that is absent from the skill actually in play is not.

## Public repo

Never hard-code values configured per-workspace: template names, project names, team keys, channel names, account IDs, internal URLs. Teach the agent to *discover* them — show the query, command, or config file that surfaces each user's own. True public constants of a tool (documented endpoints, stable command names) are fine.

For remote APIs, document request and response *shape* — endpoints, body structure, response field paths, gotchas. Not code that calls them.

## Before you commit

Run `agentskills validate` on the skill directory.
