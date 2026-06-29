---
name: zoom
description: Zoom meeting transcripts — distilled via kb-distill on-device model
---

Use the `zoom` skill to locate caption files for meetings whose date prefix falls within the enrichment window. For each in-window meeting, run the distillation step below.

## Distillation step

For each in-window transcript, run:

```
~/.config/opencode/bin/kb-distill <caption-file> "<title>" YYYY-MM-DD
```

Use the returned JSON facts (fields: `participants`, `topics`, `decisions`, `action_items`, `open_questions`, `summary`) in place of the raw caption text when extracting people facts, decisions, and action items. Only the on-device local model sees the raw transcript.

If `kb-distill` exits non-zero, read the raw transcript yourself instead and note the fallback in the journal.

## Triage rules

Extract from the distilled JSON:
- Meeting participants and any contact info surfaced (new names, roles, team membership)
- Decisions recorded under the `decisions` field
- Action items from the `action_items` field
- Open questions from `open_questions` that remain unresolved at the end of the enrichment window

## Extraction rules

- Map participants to people facts.
- Anchor decisions to the project or product they concern.
- For action items, note the meeting title and date so the item can be cross-referenced at write time.
