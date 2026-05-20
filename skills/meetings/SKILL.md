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
- `~/meetings/knowledge/people/<slug>.md` — person profiles (contact info, current work, style, personal, key decisions)
- `~/meetings/knowledge/projects/<slug>.md` — project profiles (Linear/GitHub links, status, key decisions, people)
- `~/meetings/knowledge/decisions/log.md` — chronological decision log across all meetings
- `~/meetings/knowledge/names.json` — display name → canonical name mapping (people)
- `~/meetings/knowledge/projects.json` — project name → canonical name mapping
- `~/meetings/knowledge/product-labels.json` — Linear label → product profile mapping
- `~/meetings/knowledge/github-repos.json` — GitHub repo → project profile mapping

## Knowledge base

Three categories, updated automatically from meetings, Slack, Linear, and GitHub:

**People** — distilled reference cards: contact info (Email, Slack ID), current work, communication style, personal details, key decisions. Profiles consolidate automatically when they grow past 40 lines.

**Projects** — current state with metadata links (Linear project URLs, GitHub repos). Products get Linear label mappings; projects get direct URLs. Name normalization via `projects.json` prevents duplicates.

**Decisions** — cross-meeting decision log. Later decisions that supersede earlier ones are reconciled automatically — the log reflects current state, not accumulated contradictions.

## Searching

Search transcripts and summaries using grep, ripgrep, or file reads. Frontmatter fields: `title`, `type`, `date`, `duration`, `status`, `source`, `recorded_by`.

## Processing

New Zoom meetings are processed automatically by launchd when a caption file is saved. Slack DMs and private channels are scanned daily at 6am. To manually process:

```bash
python3 -m kb meeting /path/to/caption.txt    # new Zoom caption
python3 -m kb meeting /path/to/meeting.md     # reprocess existing (KB + reminders only)
python3 -m kb enrich --slack --since 48        # scan last 48h of Slack
python3 -m kb enrich --linear                  # sync Linear project URLs and labels
python3 -m kb enrich --github                  # sync GitHub repo URLs
python3 -m kb enrich                           # all sources
python3 -m kb enrich --dry-run                 # preview what would change
```

Requires `PYTHONPATH=~/.local/lib` (set automatically by the LaunchAgents).
