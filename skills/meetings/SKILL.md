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
- `~/meetings/knowledge/projects/<slug>.md` — project profiles (status updates, decisions per meeting)
- `~/meetings/knowledge/decisions/log.md` — chronological decision log across all meetings
- `~/meetings/knowledge/names.json` — display name → canonical name mapping

## Knowledge base

Three categories, updated automatically after each meeting and daily from Slack:

**People** — what each person said, decided, committed to, or demonstrated. Profiles consolidate automatically when they exceed 15 meeting sections. Look up a person to understand their role, recent decisions, and open commitments.

**Projects** — status updates per meeting. Tracks what changed, what was decided, what's blocked. Consolidates the same way as people profiles.

**Decisions** — cross-meeting decision log. Later decisions that supersede earlier ones are reconciled automatically — the log reflects current state, not accumulated contradictions.

## Searching

Search transcripts and summaries using grep, ripgrep, or file reads. Frontmatter fields: `title`, `type`, `date`, `duration`, `status`, `source`, `recorded_by`.

## Processing

New Zoom meetings are processed automatically by launchd when a caption file is saved. Slack DMs and private channels are scanned daily at 6am. To manually process:

```bash
python3 -m kb meeting /path/to/caption.txt    # new Zoom caption
python3 -m kb meeting /path/to/meeting.md     # reprocess existing (KB + reminders only)
python3 -m kb enrich --slack --since 48        # scan last 48h of Slack
python3 -m kb enrich --slack --dry-run         # preview what would be processed
```

Requires `PYTHONPATH=~/.local/lib` (set automatically by the LaunchAgents).
