---
name: writing
description: Write product artifacts clearly — tickets, PRDs, project updates, and architecture decision records
license: MIT
metadata:
  requires:
    - docs
---

# Writing Skill

Given a writing task, identify the right document type, read the relevant template, and apply it.

## Document types

| Type | When to use | File |
|------|-------------|------|
| **Ticket / Issue** | Capturing a scoped unit of work — bug, feature, task, spike | `templates/ticket.md` |
| **PRD** | Defining a feature or product area before implementation begins | `templates/prd.md` |
| **Project update** | Communicating project status to stakeholders (weekly, milestone, etc.) | `templates/project-update.md` |
| **ADR** | Recording an architecture decision and why alternatives were rejected | `templates/adr.md` |

## How to route

Read what the user wants to write. Pick the best-fit type. If unclear, ask one question: "Is this scoped work for someone to pick up, or a broader proposal/decision?"

- "Scoped work" → ticket
- "Broader proposal" → PRD
- "Status comms" → project update
- "Architecture choice" → ADR

## Reading a template file

Use the Read tool on the relevant path:
- `~/.agents/skills/writing/templates/ticket.md`
- `~/.agents/skills/writing/templates/prd.md`
- `~/.agents/skills/writing/templates/project-update.md`
- `~/.agents/skills/writing/templates/adr.md`

Each file contains the structure, field-by-field guidance, and a fill-in template. Apply it to the user's context — don't just repeat the template verbatim.

## General principles

**Lead with outcomes, not tasks.** The reader should understand *why* before *what*. A good ticket describes the problem and success condition; the implementation approach is secondary.

**Be specific about scope.** Ambiguity in a ticket becomes scope creep. If you can't state clearly what done looks like, the artifact isn't ready.

**Compress ruthlessly.** Remove words that don't add information. Background sections should be the minimum needed to make the decision or task legible.

**One artifact, one audience.** A ticket is for the implementer. A PRD is for alignment. A project update is for stakeholders. Don't mix them.

## Saving to a document

When the user wants the output saved to Google Docs, use your `docs` capability:

1. **Find an existing doc** — search by name first before creating a new one
2. **Create if needed** — create with a descriptive title matching the artifact type
3. **Write the content** — append the finished artifact as plain text

Always confirm the document name and location with the user before creating. If they provide a doc name or link, use that directly.
