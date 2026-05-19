---
name: meetings
description: Search and query meeting transcripts, summaries, and knowledge base
license: MIT
metadata:
  provides:
    - meetings
---

Meeting data lives in `~/meetings/` as markdown files with YAML frontmatter.

## Files

- `~/meetings/YYYY-MM-DD-<slug>.md` — meeting markdown (frontmatter + summary + transcript in one file)
- `~/meetings/knowledge/people/<slug>.md` — person profiles (facts, decisions, commitments per meeting)
- `~/meetings/knowledge/names.json` — display name → canonical name mapping

## Searching

Search transcripts and summaries using grep, ripgrep, or file reads. Frontmatter fields: `title`, `type`, `date`, `duration`, `status`, `source`, `recorded_by`.

## Processing a new transcript

If a Zoom caption file needs manual processing:

```bash
meeting-postprocess /path/to/meeting_saved_closed_caption.txt
```

This parses the transcript, summarizes via LM Studio, writes meeting markdown, updates the knowledge base, and adds action items to reminders. Normally triggered automatically by launchd when Zoom writes a caption file.

## People lookup

Person profiles in `~/meetings/knowledge/people/` contain per-meeting facts extracted by LM Studio — decisions, commitments, demonstrations, concerns. Read a profile to get context on a person across meetings.
