---
description: Pull meeting context from Granola
agent: context
---

Retrieve context from Granola meeting notes to inform planning or implementation.

**Request:** $ARGUMENTS

## Usage Examples

- `/context standup yesterday` - Find yesterday's standup notes
- `/context meeting with design team` - Search for design team meetings
- `/context requirements for auth feature` - Find discussions about auth
- `/context <granola-url>` - Get notes from a specific meeting link

## Output

- Relevant quotes and decisions
- Who said what (when useful)
- Meeting date for reference
- Any ambiguity or open questions
