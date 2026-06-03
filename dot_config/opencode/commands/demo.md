---
description: Generate a demo slide deck from your work since the last demo meeting
subtask: true
---

Build a compelling, ready-to-present demo slide deck from your own work since the last weekly demo meeting.

$ARGUMENTS

Optional argument: a time-window override — e.g. `2w`, `10d`, or an explicit date like `2026-05-20`. Bare `/demo` uses the marker-file default.

## Skills

- **knowledge-base** — read the journal, project profiles, and decisions log.
- **qa** — know where QA reports live (`~/.local/share/qa/<project>/qa-*/`) and their format (a `report.html` plus sequentially numbered `001-*.png` screenshots).

## Steps

1. **Resolve the window.** Read the marker file `~/.local/share/kb/last-demo.md` for the date of the last demo. An argument overrides it — parse `2w`/`10d` as a relative window or accept an explicit date as the start. If neither marker nor argument exists, default to the last 7 days (weekly cadence). State the resolved window before continuing.

2. **Gather raw material since the boundary.** All of it is your own work, so it's naturally scoped to "my work":
   - **KB journal** — entries in range at `~/.local/share/kb/journal/YYYY-MM-DD.md`, for per-project coding activity with diff stats.
   - **QA reports** — directories under `~/.local/share/qa/*/qa-*/` whose timestamp or mtime falls in the window. Each holds a `report.html` and numbered screenshots (`001-*.png`, …) — these are visual proof of features working.
   - **Project profiles** — `~/.local/share/kb/projects/<slug>.md` for framing and status.
   - **Decisions log** — `~/.local/share/kb/decisions/log.md` for the "why" behind the work.

3. **Synthesize the demo.** Group by project; order by impact, most demo-worthy first — not chronological. Lead each project with a one-line "why this matters" framing. For each demo item use **problem → shipped → proof**:
   - *Problem* — the user-facing pain or goal (pull from project status and decisions).
   - *Shipped* — what was built, in plain language, outcome-focused — not a commit list.
   - *Proof* — the specific QA screenshot used on the item's slide; if no QA report exists for the item, it gets a "demo live" callout instead.
   Skip noise (pure refactors, chores) unless they enable a visible win.

4. **Build the slide deck** as a single self-contained HTML file at `~/.local/share/qa/demos/demo-YYYY-MM-DD.html` (create the dir), presented live fullscreen in a browser. Use **reveal.js via CDN** (pull the script and a theme `<link>` from cdnjs or jsdelivr) so arrow-key navigation, fullscreen, and speaker notes work out of the box — this needs network for the CDN. Slide structure, projects ordered by impact (most demo-worthy first):
   - **Title slide** — the week/window plus a one-line headline of what got done.
   - **Project intro slide** — one per project, leading with the "why this matters" line.
   - **Item slides** — one per demo item: a punchy headline (the win/outcome), a tight problem→shipped framing as 2-3 bullets, and the QA screenshot as the slide's main visual, referenced by absolute file path (e.g. `<img src="/Users/athal/.local/share/qa/<project>/qa-*/001-*.png">`). Items with no screenshot get a "demo live" callout in place of the image.
   Put the detailed talk-track in reveal.js **speaker notes** (`<aside class="notes">`) so the slides stay visual and uncluttered while the presenter keeps their script. Then `open` the `.html` file.

5. **Update the marker.** Write today's date into `~/.local/share/kb/last-demo.md` so next week's window starts here.

## Writing guidance

Visual-first slides, one idea per slide. Headlines sell the outcome; the screenshot is the hero of each slide; the detailed talk-track lives in the speaker notes, not on the slide. Sound like a confident engineer showing off working software — not a status report. Lead with impact and keep on-slide text tight.
