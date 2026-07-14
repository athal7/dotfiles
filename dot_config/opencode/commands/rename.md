---
description: Rename the current session with a more semantic title based on everything learned so far, using the small model
agent: general
model: mlx/qwen3-30b-a3b-instruct-2507
---

Rename THIS session with a title that reflects the actual work, now that more context exists than when the session was first auto-titled.

$ARGUMENTS

## Steps
1. Review the conversation so far and identify the real subject — the feature, file, bug, subsystem, or question at the heart of the work. If `$ARGUMENTS` is non-empty, treat it as a strong hint or the explicit desired title.
2. Synthesize a single title following the rules below.
3. Call the `rename_session` tool with that title. Do not ask for confirmation.
4. Reply with only the new title.

## Title rules
- <=50 characters, single line, grammatically natural — no word salad.
- Name the NOUN, not the verb: title the thing being worked on, not the activity or the workflow/command used.
- STRIP any leading slash-command and its workflow verb (/implement, /mr, /rename, etc.). Never name the session after a command.
- Keep exact: technical terms, numbers, filenames, HTTP codes, ticket ids.
- Remove filler words: the, this, my, a, an.
- Use the same language as the conversation.
- Never include tool names.
