---
name: communication
description: Load when composing human-facing prose through an integration — chat messages, review comments, merge request descriptions, emails, doc bodies, ticket descriptions. Carries the AI-authorship attribution rule.
license: MIT
---
Query CQ for normal context. Load `knowledge-base` when CQ has no answer or its projection verification is incomplete.
## Draft-first workflow

When the user has not provided exact final wording for an external communication, create a local draft before using an integration write tool.

- Write the literal outbound body to `~/.omp/agent/drafts/communications/<slug>.md`.
- Use a collision-safe slug, such as `<YYYYMMDD-HHMM>-<topic>`, or confirm that an existing draft and sidecar are intentionally being replaced. Never silently overwrite an existing pair.
- Include the AI-authorship marker in the draft body when it applies. Add it before stopping so the reviewed file is complete.
- Keep destination, recipients, subject, thread, schedule, tool, and other metadata in the matching `<slug>.json` sidecar.
- Keep the `.md` file limited to the outbound body. Do not put YAML frontmatter or review notes in it.
- Keep drafts outside the repository unless the user explicitly requests a repository file.
- Stop after creating the draft and give the user its path so they can edit it directly.
- If the user requests changes, update the draft file and stop again.
- When the user requests sending, read both the body file and matching sidecar immediately before constructing the integration call. Treat the `.md` contents as the authoritative body and the `.json` contents as authoritative metadata. Do not rewrite, paraphrase, or append to the body or silently replace the metadata.

If the user provides exact final wording and explicitly requests a send, a local draft is optional.

Do not use a remote Slack or Gmail draft as the editing surface when a local draft is requested. Remote draft creation is itself a remote write.

Tailor to the recipient — role, technical depth, your relationship with them. Some want two lines; some need the context.

Surface assumptions as questions, not conclusions: "I'm reading this as X — does that match?" beats "this is X." Informal, contractions fine, no corporate hedging. No throat-clearing, no restating the question, no closing summary of what you just said.

## AI-authorship marker

When a draft will be posted through an integration on the user's behalf, include this as the last line of the draft body when it applies:

```
*Co-authored with <model id>*
```

Do not add or change the marker after the user edits the draft.

Skip it when: relaying the user's words verbatim · titles · commit messages and merge request descriptions (the `Co-Authored-By` trailer already signals it) · Slack (its own send attribution covers it).
