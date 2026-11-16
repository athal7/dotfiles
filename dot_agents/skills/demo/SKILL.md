---
name: demo
description: Load when building a cycle or sprint demo deck from tracker issues and QA screenshots, or publishing one to Quick
license: MIT
---

Build a static deck of the requester's shipped work. Never claim an image shows something you did not verify.

## Scope

Both entry points mean the requester's own work only. State the resolved scope before gathering.

- **Cycle — default.** Resolve with `list_cycles(teamId, type: "current")`; never infer the cycle id from issue rows. Then `list_issues(team, cycle, assignee: "me", state: "completed")`. Dropping `assignee=me` returns teammates' work; broaden only when asked to.
- **Window — "since the last demo".** Read the marker `~/.local/share/kb/last-demo.md` for the last demo date; `2w`, `10d`, or an explicit date overrides it, and 7 days is the fallback. Gather `~/.local/share/kb/journal/YYYY-MM-DD.md` for per-project activity and diff stats, `~/.local/share/kb/projects/<slug>.md` for status, `~/.local/share/kb/decisions/cross-cutting.md` for the why, and `qa-*` directories by mtime.

Re-query before delivery: users move issues to Done mid-session (one run went 9 → 20). Write the marker only after the deck ships.

Read `get_issue` for description and attachments; attachments carry the PR links. One slide per **parent** when the children only make sense together — an OAuth parent covering three children — and name the grouping on the slide. Do not shatter a parent into a child-per-slide.

## Evidence

Screenshots are not in PRs or tracker comments: `qa-report-publish` forbids publishing report files or screenshots, so PR bodies carry only bot assets. Look locally, in order:

1. `~/.local/share/qa/<slug>/qa-YYYYMMDD-HHMMSS/` — `report.md` (often `report.html` too) plus `NNN-name.png`. Slugs are branch-like and many are unrelated to any one issue (`install-page`, `retry`); map each by reading its report for the issue id, PR link, or feature described. Skip directories that hold a report but no images.
2. `~/.firefox-devtools-mcp/output/page-screenshot-*.png` — when a report cites these absolute paths because the browser refused the session directory. Filename timestamps do not sort against the report's narrative; identify each file by its content.

Use only PASS reports — check the `## 🧪 QA — PASS ✅` / `FAIL ❌` heading. A FAIL report's images are evidence of a bug, not of shipped work.

## Verify images

Models here usually cannot see images: `read` returns `image omitted: the active model does not support image input`. OCR through macOS Vision; `tesseract` is not installed.

```swift
import Vision
import AppKit
let path = CommandLine.arguments[1]
guard let img = NSImage(contentsOfFile: path),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(2) }
let req = VNRecognizeTextRequest(); req.recognitionLevel = .accurate
try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
for o in req.results ?? [] { guard let c = o.topCandidates(1).first else { continue }
  let b = o.boundingBox
  print(String(format: "%.4f %.4f %.4f %.4f\t%@", b.origin.x, b.origin.y, b.height, b.width, c.string)) }
```

`swiftc -O /tmp/ocr.swift -o /tmp/ocr`, then `/tmp/ocr img.png | cut -f2-`. The box columns locate a region for cropping.

- Confirm every string a caption asserts — page heading, status text, button labels — appears in the OCR output.
- A report once captioned two images `Generation failed` and `Dismissed`; OCR showed a normally-scored page with neither string. Drop such images or caption what they actually show. Never inherit a report's claim.
- A report verifying a standalone URL does not prove the nav link that is the feature. Caption only what was verified and put request-test evidence in the prose.
- No usable capture: say so on the slide and link the PR. Never a placeholder or fabricated image.

## Deck

One self-contained `index.html` plus `img/`, no CDN: the site is static and IAP-gated, and a self-contained file also deep-links and opens from disk. reveal.js from a CDN is the fallback when presenting from a networked browser and you want `<aside class="notes">` speaker notes.

- Title slide with the cycle or window and a one-line headline. Order slides by impact, not chronology; skip pure refactors and chores.
- One slide per issue or parent, headline stating the outcome. Frame each as problem → shipped → proof, in plain language rather than a commit list. Several figures per slide are allowed — a before/after or `paused` / `running` pair beats one image.
- Keyboard nav (Arrow, Space, PageUp/Down, Home/End), click-to-advance, an `n / total` counter, and `history.replaceState` for deep links. Link each issue id to its tracker URL.
- Images: `object-fit: contain; object-position: center top` so full-desktop captures stay legible. Flex children holding images need `min-height: 0` or they overflow. Size type with `%`/`clamp()` so it projects.
- Keep the talk track out of the slide body — `notes.md` beside the deck, or reveal's `<aside class="notes">`.
- Reveal only: never style `<section>` for layout (it writes an inline `display` on the visible section and wins), never size with `vh`/`vw` (reveal scales by `transform`, so they measure the real window and overflow), and lay content out in an inner `<div>` — a two-column grid with the screenshot right keeps 4:3 captures visible.

## Verify locally

Serve the directory and assert structure over HTTP, not by eye: count `class="slide"`, extract the issue ids, and `curl -o /dev/null -w '%{http_code} %{size_download}'` every image.

Drive the real page with the Firefox devtools MCP: `get_page_text` for the current slide's copy and the `n / total` counter, `press_key` on a snapshot uid to confirm Arrow and End advance. A fresh `navigate_page` to a `#hash` does not re-run the deck JS; reload or press keys.

## Publish to Quick

Read `skill://quick` first; it owns naming, install, and overwrite rules. Prefix the name per its convention, and confirm the name is free with `quick list` — an empty list with exit 0 usually means dead auth, not an empty namespace.

- **gcloud on Python 3.14:** `quick deploy` shells out to `gcloud storage rsync`, which dies with `module 'ssl' has no attribute 'PROTOCOL_TLSv1'`. Never patch the SDK and never `quick update` to fix it. Pin an interpreter in gcloud's supported range that still has the attribute: `CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.13 quick deploy . <name>`. System Python 3.9 is rejected as unsupported.
- **`invalid_rapt`:** reauth needs an *interactive* sign-in. No cached access token, ADC, or legacy refresh token fixes it; refreshes fail with `invalid_grant`. Stop and hand the user two routes: drag the directory into the Quick web UI (same IAP browser session, no CLI), or run `gcloud auth login` then the pinned deploy. Never start a login prompt in a background job — the PKCE state will not survive the turn.
- Gate the deploy on `CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.13 gcloud auth print-access-token` succeeding, then `quick url <name>`.
- **IAP blocks rendering it yourself:** an unauthenticated `curl` gets `302` to Google sign-in, a gcloud access token gets `401` (IAP wants an OIDC identity token, and `print-identity-token --audiences` needs a service account). Verify bytes instead: read the bucket from `quick env`'s `sites bucket` line, then `gcloud storage ls -l gs://<bucket>/<name>/**` for sizes and `gcloud storage cat gs://<bucket>/<name>/<file> | shasum -a 256` against the local file (`shasum` is portable; `md5` exists at `/sbin/md5` but is not on a default non-login `PATH`). Report the visual render as unconfirmed and ask the user for the one look.

## Hand-off

Keep the source in the session's `demo/` directory and give its absolute path. Stop the preview server once published, and call `cleanup_session` when done with the browser. Report an issue → slide table, and name every issue without a screenshot with the reason.
