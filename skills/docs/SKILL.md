---
name: docs
description: Read and write documentation — Google Docs via gws CLI and Confluence via confluence CLI. Covers gotchas for both.
license: MIT
metadata:
  provides:
    - docs
---

# Docs

Two tools depending on where the content lives:

| Signal | Tool |
|---|---|
| `.google.com/document` URL, Doc ID, user says "Google Doc" | `gws` |
| `*.atlassian.net/wiki` URL, page ID, user says "Confluence" or "wiki" | `confluence` |

Run `--help` on each tool and subcommand first. This skill covers only what help text won't surface.

## Google Docs

- `gws docs documents get` returns raw structural JSON, not readable text — use `gws drive files export --mimeType text/plain` to get readable content
- `--output` paths must be within the current directory — `gws` rejects absolute paths outside it. Use `.scratch/` as the download target: `mkdir -p .scratch && gws ... --output .scratch/filename.txt`. `.scratch/` is globally gitignored.
- The Docs API has no search — use `gws drive files list` with a CQL `q` param instead
- `gws docs documents get` output begins with a "Using keyring backend" line — strip non-JSON prefix lines before parsing
- Inserting real tables requires a multi-phase approach; see `tables.md`

## Google Slides

- `gws slides presentations create` creates a blank presentation — use `gws drive files copy` on an existing themed presentation to inherit its master/theme instead
- Google's template gallery IDs are **not** accessible via the API (404) — copy from a presentation you already own that has the desired theme
- The default master (`Simple Light`) has no named layouts returned in `masters[].layouts` via the API, but predefined layouts (`TITLE_AND_BODY`, `TITLE_ONLY`, `SECTION_HEADER`, `BIG_NUMBER`, `BLANK`) work via `createSlide.slideLayoutReference.predefinedLayout`
- **Use placeholders, not text boxes.** Slides created with a predefined layout get `TITLE` and `BODY` placeholder shapes — insert text into those via `insertText` and the master handles font, size, and position. Manual text boxes (`createShape: TEXT_BOX`) bypass the master entirely and require you to hardcode all coordinates in EMU
- **Canvas is 720×405pt (9144000×5143500 EMU)** — `pt → EMU` conversion: `pt * 12700`. Placeholder positions are already set by the layout; you only need coordinates when placing decorative shapes
- **Object IDs must be ≥5 characters** and match `[a-zA-Z0-9_][a-zA-Z0-9_\-:]*` — no spaces
- `foregroundColor` in `updateTextStyle` takes `{"opaqueColor": {"rgbColor": {...}}}`, not `{"solidFill": ...}`. Page background and shape fills use `{"solidFill": {"color": {"rgbColor": {...}}}}`
- `alignment` in `updateParagraphStyle` uses `START`/`CENTER`/`END`, not `LEFT`/`RIGHT`
- `batchUpdate` request type is `createSlide`, not `addSlide`
- All slides in a `batchUpdate` must succeed or none are applied — validate object IDs and request shape before sending

## Confluence

- `confluence find` matches by exact title — use `confluence search` for partial or full-text matches
- `confluence search` uses CQL — wrap multi-word terms in quotes
- Page IDs appear as `pageId=` in older URLs; newer Confluence Cloud URLs embed the ID in the path — `confluence read` accepts both forms
- Inline comment creation requires editor-generated highlight metadata not exposed by the public REST API — footer comments and replies work reliably, inline creation will 400
