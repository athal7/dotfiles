---
name: demo
description: Load when building a cycle or sprint demo deck from tracker issues and QA screenshots, or publishing one to Quick
license: MIT
---

Build a static deck of the requester's shipped work. Never claim an image shows something you did not verify.

## Scope

Both entry points mean the requester's own work only. State the resolved scope before gathering.

- **Cycle — default.** Resolve with `list_cycles(teamId, type: "current")`; never infer the cycle id from issue rows. Then `list_issues(team, cycle, assignee: "me", state: "completed")`. Dropping `assignee=me` returns teammates' work; broaden only when asked to.
- **Window — "since the last demo".** Read the marker `vault://kb/last-demo.md` if present — it may not exist yet, so create it on first run; `2w`, `10d`, or an explicit date overrides it, and 7 days is the fallback. Gather `vault://kb/journal/YYYY-MM-DD.md` for activity and diff stats, `vault://kb/projects/<slug>.md` for status, `vault://kb/decisions/cross-cutting.md` for the why, and `qa-*` directories by mtime. Write the marker only after the deck ships. Read these through `vault://`, never the backing files under `~/.local/share/kb/`.

Re-query before delivery: users move issues to Done mid-session (one run went 9 → 20). Read `get_issue` for description and attachments; attachments carry the PR links.

Include only issues the requester actually worked on, and treat their word as authoritative over Linear `assignee`, `createdBy`, and git author. When they say an issue is not theirs, drop it — even with their name on the record — or ask; never defend the record against them.

One slide per **parent** when the children only make sense together — an OAuth parent covering three children — and name the grouping on the slide. The parent body is the source of the umbrella claim. A child with no visual evidence becomes a bullet under the parent slide, not its own slide.
Scope each claim to what the issue establishes. Read the body's status notes, including a trailing not-done paragraph: an issue with every acceptance box unchecked is not delivered however finished the work looks, and a number belongs to the issue that measured it, never to a pair of siblings.

## Evidence

Screenshots are not in PRs or tracker comments: `qa-report-publish` forbids publishing report files or screenshots, so PR bodies carry only bot assets. Look locally, in order (the same tree is readable at `vault://qa/`; use the filesystem path when copying images into the deck):

1. `~/.local/share/qa/<slug>/qa-YYYYMMDD-HHMMSS/` — `report.md` (often `report.html` too) plus `NNN-name.png`. Slugs are branch-like and many match no issue (`install-page`, `retry`); map each by reading its report for the issue id, PR link, or feature. Skip directories holding a report but no images.
2. `~/.firefox-devtools-mcp/output/page-screenshot-*.png` — when a report cites these absolute paths because the browser refused the session directory. Filename timestamps do not sort against the report's narrative; identify each file by its content.

Use only PASS reports — check the `## 🧪 QA — PASS ✅` / `FAIL ❌` heading. A FAIL report's images are evidence of a bug, not of shipped work.

## Capture

- **Never defeat the production login gate.** reCAPTCHA Enterprise is enforced server-side on prod sign-in and rejects scripted submits. Do not iterate on stealth or solve the challenge.
- **Never put a password in a tool argument** (`fill_by_uid`, `type_text`) or a temp file for a script to read: the first lands in the transcript, the second leaves plaintext on disk. `op read > /tmp/pw` is a leak, not a workaround.
- Anything behind sign-in: name the exact URL and hand it to the user for a screenshot. Never substitute a placeholder.
- Driving the requester's Firefox devtools MCP beats headless: a headless render came out dark-themed and unreadable, while the real profile kept its theme and retina scale.
- `screenshot_by_uid` and `screenshot_page` take `saveTo`, but only an absolute path under `~/.firefox-devtools-mcp/output/` works; relative and `./` paths get mangled into `/hots` or fail ENOENT/EROFS. Save there, then copy into `demo/img/`.
- Capture the smallest element that tells the story — `screenshot_by_uid` on the figure or its section, not a full page where the subject is clipped or scaled to a third. A retina element can land at 5090x2650; run `sips -Z 1600` before shipping.
- Verify the rendered slide, not just the asset: navigate to it and OCR the screenshot. One caption survived three reviews describing motion a still cannot show; it now states the numbers in the pixels.

## Motion

When the feature *is* the motion — a chart drawing, a state transition, a transition animation — a still is not emblematic of it. A short clip is easier than it looks; Playwright video beats assembling GIFs and keeps full colour.

1. Record: `chromium.launch({ executablePath: <installed Chrome> })`, then a context with `recordVideo: { dir: <abs>, size: { width, height } }`. Grab `const video = page.video()`, and call `await video.path()` **before** `ctx.close()` — the file only exists after close.
2. Convert and trim: `-c:v libx264 -pix_fmt yuv420p -crf 24 -movflags +faststart`, then `-ss <start> -t <duration>` for the window, adding `crop=w:h:x:y` to frame the feature only.
3. Find the window empirically instead of guessing. Extract at 10fps (`-vf fps=10`), then `magick compare -metric AE prev.png cur.png null:` between consecutive frames (the metric prints on stderr) and take the run where the diff is high. Scroll motion swamps everything, so scroll instantly — `window.scrollTo` — to isolate the draw from the travel.
4. `<video autoplay loop muted playsinline poster="img/<still>.png">` with a real still as poster, so the slide stays readable if autoplay is blocked. Keep clips a couple of seconds and a few hundred KB.
5. Verify like a still: extract frames from the *final* clip, not the raw recording, and OCR both ends of the window. A clip whose first and last frame OCR the feature's own labels, and whose middle frames differ, is proven.

**Gotcha:** CSS gated on `.is-in-view` usually toggles `animation-play-state`, so scrolling away and back *resumes* a finished animation instead of replaying it — a verified case returns with the animation still at its end time. Capture the first entry after a fresh load, or you will record a static chart forever.

Do not mine a marketing or marketing-adjacent page for proof of an engineering fix. It is not evidence that the fix shipped, and it reads as padding.

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

`swiftc -O /tmp/ocr.swift -o /tmp/ocr`, then `/tmp/ocr img.png | cut -f2-`; the box columns locate a region for cropping.

- Confirm every string a caption asserts — page heading, status text, button labels — appears in the OCR output.
- A report once captioned images `Generation failed` and `Dismissed`; OCR showed neither. Drop such images or caption what they show; never inherit a report's claim.
- A report verifying a standalone URL does not prove the nav link that is the feature. Caption only what was verified; put request-test evidence in the prose.
- No usable capture: say so on the slide and link the PR. Never a placeholder or fabricated image.

## Deck

One self-contained `index.html` plus `img/`, no CDN: the site is static and IAP-gated, and a self-contained file also deep-links and opens from disk. reveal.js from a CDN is the fallback when presenting from a networked browser and you want `<aside class="notes">` speaker notes.

- Title slide with the cycle or window and a one-line headline. Order slides by impact, not chronology; skip pure refactors and chores.
- One slide per issue or parent, headline stating the outcome, framed as problem → shipped → proof in plain language rather than a commit list. Several figures per slide are allowed — a before/after or `paused` / `running` pair beats one image.
- Keyboard nav (Arrow, Space, PageUp/Down, Home/End), click-to-advance, an `n / total` counter, and `history.replaceState` for deep links. Link each issue id to its tracker URL.
- Images: `object-fit: contain; object-position: center top` so full-desktop captures stay legible. Flex children holding images need `min-height: 0` or they overflow. Size type with `%`/`clamp()` so it projects.
- Keep the talk track out of the slide body — `notes.md` beside the deck, or reveal's `<aside class="notes">`.
- Reveal only: never style `<section>` for layout (it writes an inline `display` and wins), never size with `vh`/`vw` (reveal scales by `transform`), and lay content out in an inner `<div>`; a two-column grid with the screenshot right keeps 4:3 captures visible.

## Verify locally

Serve the directory and assert structure over HTTP: count `class="slide"`, extract issue ids, and `curl -o /dev/null -w '%{http_code} %{size_download}'` every image. Drive the real page with the Firefox devtools MCP: `get_page_text` for slide copy and the `n / total` counter, `press_key` on a snapshot uid to confirm Arrow and End advance. A fresh `navigate_page` to a `#hash` does not re-run the deck JS; reload or press keys.

## Publish to Quick

Read `skill://quick` first; it owns naming, install, and overwrite rules. Prefix the name per its convention and read the sites bucket from `quick env`.

- **Prune orphans before mirroring.** A plain `quick deploy` never deletes remote objects. `--mirror` deletes remote objects absent *locally*, so an unreferenced file still in `demo/img/` keeps its orphan alive and the mirror looks like a no-op. Delete unreferenced locals first, deploy `--mirror`, then assert the bucket listing equals the deck's referenced images, removing stragglers with `gcloud storage rm`. Orphans on IAP-gated but staff-open hosting are still published content, readable at guessable URLs.
- **gcloud on Python 3.14:** `quick deploy` shells out to `gcloud storage rsync`, which dies with `module 'ssl' has no attribute 'PROTOCOL_TLSv1'`. Never patch the SDK and never `quick update` to fix it. Discover an interpreter in gcloud's supported range that still has the attribute and pin it — `for v in 13 12 11; do p=$(command -v python3.$v); [ -n "$p" ] && "$p" -c 'import ssl;ssl.PROTOCOL_TLSv1' 2>/dev/null && { echo "$p"; break; }; done` — then `CLOUDSDK_PYTHON=<that path> quick deploy . <name>`. System Python 3.9 is rejected as unsupported.
- **`invalid_rapt`:** reauth needs an *interactive* sign-in. No cached access token, ADC, or legacy refresh token fixes it; refreshes fail with `invalid_grant`. Stop and hand the user two routes: drag the directory into the Quick web UI (same IAP browser session, no CLI), or run `gcloud auth login` then the pinned deploy. Never start a login prompt in a background job — the PKCE state will not survive the turn.
- Gate the deploy on `CLOUDSDK_PYTHON=<that path> gcloud auth print-access-token` succeeding. `quick url <name>` only formats a URL — it prints one and exits 0 even for a nonexistent name, so never treat it as an availability check. Test existence with `gcloud storage ls gs://<bucket>/<name>/`: it exits 0 when objects exist and 1 with `matched no objects` when the name is free.
- **IAP blocks rendering it yourself:** an unauthenticated `curl` gets `302` to Google sign-in, a gcloud access token gets `401` (IAP wants an OIDC identity token, and `print-identity-token --audiences` needs a service account). Verify bytes instead: `gcloud storage ls -l gs://<bucket>/<name>/**` for sizes, and `gcloud storage cat gs://<bucket>/<name>/<file> | shasum -a 256` against the local file. Report the visual render as unconfirmed and ask the user for the one look.

## Hand-off

Keep the source in the session's `demo/` directory and give its absolute path. Stop the preview server once published and call `cleanup_session`. Report an issue → slide table, naming every issue without a screenshot with the reason.
