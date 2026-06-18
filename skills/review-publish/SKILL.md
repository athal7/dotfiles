---
name: review-publish
description: Publishing the unified review report (fused static findings + QA evidence, organized by acceptance criterion) to a merge request after approval — the branch-hosting procedure, badge composition, and ownership-based link placement. Fires when lead is about to attach the assembled review report to a merge request.
license: MIT
compatibility: opencode
---

# Skill: review-publish

Publishing the **unified review report** — one AC-organized document fusing
static review findings and QA verification evidence — to a merge request after
human approval.

## Invariant

The analysis agents are read-only with respect to the remote: the static
reviewer returns classified findings as a message and the QA agent writes only
its local artifacts (`report.md`, `report.html`, `NNN-name.png` screenshots) in
its session dir. **Lead assembles** the unified report — in BOTH forms
(`review-report.html` and `review-report.md`) — into that same session dir (so
the relative screenshot refs resolve) and is the sole writer to the remote —
branch-hosting only the Markdown form and placing the link — only after explicit
human approval. The HTML form is opened locally and never pushed.

When QA did not run, lead still creates the session dir at
`~/.local/share/qa/<project>/qa-<ts>/` (the same store and `qa-<ts>` naming the
disk cleanup job prunes on the same schedule) and writes BOTH forms there — the
diff/findings half is always present even when the QA verdict is `n/a`.

## Report forms

The unified report is produced in TWO forms, both written into the QA session
dir, both organized by acceptance criterion, and both led by the same two
machine-readable lines:

```
🧪 Review — QA: PASS ✅ / FAIL ❌ / n/a   ← single parseable verdict (n/a when QA didn't run)
Findings: 1 build · 2 human · 0 plan      ← machine-readable summary count
```

The two forms differ in exactly two things — how they show **diffs** and how
they show **screenshots**:

| | `review-report.html` (local-only) | `review-report.md` (hosted) |
|---|---|---|
| Diffs | **embeds** each changed file's diff rendered inline as self-contained highlighted HTML | **deep-links** each changed file into the hosted changeset; never embeds hunks |
| Screenshots | embedded `<img>` + clickable running-app links | relative-ref `![](NNN.png)` images |
| Lifecycle | auto-opened locally, **never pushed** | hosted on the branch, linked from the request |

Everything else is identical: the verdict + `Findings:` header, the per-AC
sections, the scope/cross-cutting and could-not-verify sections, and the
**no-structured-AC fallback** (a single `### Goal — <stated goal>` section plus
the scope/cross-cutting section).

### The hosted form — `review-report.md`

```
## 🧪 Review — QA: PASS ✅
Findings: 1 build · 2 human · 0 plan

**Changeset:** <files-view URL pinned to the head revision>   (local: `<diff command for the range>`)

### AC1 — <criterion text>
- **Changeset:** per-file deep links into the changed files (local: the diff command scoped to those files)
- **Findings:** `[build] path:line` — text → proposed fix  ·  `[human] path:line` — text   (or "None.")
- **QA:** PASS ✅ / FAIL ❌ / n/a — evidence  ![cap](003-ac1.png)  <details><summary>steps</summary>

  …chronological trail…
  </details>

### AC2 — …

### Scope & cross-cutting
- `[plan]` scope-drift / AC-gap / external-contract findings that map to no single AC

### Could not verify
- …
```

- The first line — `## 🧪 Review — QA: PASS ✅` / `FAIL ❌` / `QA: n/a` — is the
  single parseable verdict; the badge is composed by parsing THIS file.
- Reference the changeset; **never paste diff hunks into this form.** For a
  hosted request, deep-link each changed file the AC touches and pin the files
  view to the head revision (the source-control integration skill documents the
  per-file anchor recipe). For a local changeset with no hosted URL, cite the
  diff command for the range plus `file:line`. The "never copy diff text" rule is
  specific to this hosted form — it has a host that renders the linked diff.

### The local form — `review-report.html`

Self-contained, auto-opened, NEVER pushed. Because there is no host to render a
linked diff, this form **embeds** each changed file's diff rendered inline as
highlighted HTML (diff-level coloring only — add / del / hunk / context), embeds
QA screenshots as images, and links the captured running-app page URLs. It is the
AC-organized successor to the retired offline diff viewer. Render each changed
file's diff inline as self-contained highlighted HTML, and deep-link each changed
file in the hosted form via the per-file anchor recipe — both mechanics live in
the source-control integration skill.

Skeleton (the inline `<style>` carries a GitHub-ish diff palette; the `.diff`
`add`/`del`/`hunk`/`ctx` classes match the rendered diff spans):

```html
<html><head><meta charset="utf-8"><style>
body{font-family:system-ui,sans-serif;max-width:1100px;margin:2em auto;padding:0 1em;color:#1f2328}
h1{font-size:1.5em} h2{font-size:1.15em;border-bottom:1px solid #d0d7de;padding-bottom:.3em}
.summary{color:#57606a;margin:.25em 0 1.5em}
section.ac{margin:2em 0;border-top:2px solid #d0d7de;padding-top:1em}
ul.findings li{margin:.3em 0} ul.findings code{background:#eff1f3;padding:0 .3em;border-radius:3px}
.f-build{color:#9a6700}.f-human{color:#0969da}.f-plan{color:#8250df}
.diff{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;overflow-x:auto;margin:.75em 0}
.diff .file{background:#eaeef2;padding:.3em .6em;font-weight:600;border-bottom:1px solid #d0d7de}
.diff pre{margin:0;padding:.4em 0}
.diff .line{display:block;padding:0 .6em;white-space:pre}
.diff .add{background:#e6ffec}.diff .del{background:#ffebe9}.diff .hunk{background:#ddf4ff;color:#0550ae}.diff .ctx{color:#1f2328}
.qa .shot{width:60%;border:1px solid #ccc;border-radius:4px;margin:.5em 0}
.qa a{color:#0969da;word-break:break-all} details>summary{cursor:pointer}
</style></head><body>
```

Layout:

- **Header:** `<h1>🧪 Review — QA: PASS ✅</h1>` then `<p class="summary">Findings: 1 build · 2 human · 0 plan</p>`.
- **Per AC:** `<section class="ac">` → `<h2>AC1 — criterion</h2>` → the embedded
  rendered diff (one `.diff` block per changed file) → `<ul class="findings">`
  (each item `file:line` with a `[build]`/`[human]`/`[plan]` tag colored via
  `f-build`/`f-human`/`f-plan`) → `<div class="qa">` (the PASS/FAIL line,
  `<img class="shot">` screenshots, the running-app links, and a
  `<details><summary>steps</summary>` chronological trail).
- **Tail:** a `Scope & cross-cutting` section then a `Could not verify` section.
- Close with the body/html end tags and open the file locally.

## Badge composition

Compose the verdict+link badge by parsing the **hosted Markdown form**
(`review-report.md`): read the verdict from the `## 🧪 Review` line and the counts
from the `Findings:` line, e.g. `🧪 QA PASS ✅ · 3 findings — <link>`. (This
replaces reading a QA-only heading; the QA agent keeps its own heading in its own
`report.md` for its own flow.) The local HTML form is never parsed for the badge.

## Publish procedure

Publishing hosts ONLY the Markdown form (`review-report.md`) and its screenshots.
The HTML form (`review-report.html`) is local-only — it is opened locally and
NEVER pushed.

1. **Host the report.** Push `review-report.md` and its referenced screenshots to
   the hosting branch (`qa-assets` by default) at `pr-<n>/`, **overwritten
   wholesale per merge request** (one report per request; deleted/renamed shots
   don't linger), through a throwaway worktree so the working tree and
   checked-out branch are never disturbed. Use the branch-hosting transport from
   the injected source-control skill. The committed `.md` renders natively in the
   file view with its **relative** images resolving — no URL rewriting.

2. **Place the link — depends on ownership.** This is the **sole** write to the
   merge request; there are no inline line-anchored comments. Determine whether
   *you* authored the merge request by comparing the request's author to the
   current user:
   - **You authored it** (your own request — the implement / merge-request
     flows): upsert a single badge line into the **merge request description**
     between `<!-- qa:start -->` / `<!-- qa:end -->` markers (read-modify-write
     the body: replace between the markers if present, else append after a blank
     line).
   - **Someone else authored it** (you're reviewing — the review flow): post the
     badge as ONE **comment** on the merge request. **Never edit another author's
     description.**

## Re-review

On a re-review, lead REGENERATES both forms from the reconciled findings, re-opens
the HTML form locally, and re-hosts the Markdown form — the hosted copy is
overwritten wholesale, so the link is unchanged. Re-run the badge placement to
refresh the verdict/count.

## Approval gate

Before any remote write, show the plan — the files to be pushed to the hosting
branch, and the exact comment text or description section to be added — and wait
for explicit human approval. Only then perform the push and place the link. The
analysis agents never write to the remote.

When a merge request is merged or closed, its `pr-<n>/` dir can be deleted from
the hosting branch as cheap cleanup.
