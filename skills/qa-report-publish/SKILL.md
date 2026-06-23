---
name: qa-report-publish
description: Publishing the AC-organized QA-evidence report to your own merge request after approval — branch-hosting the report and screenshots, then upserting the report block into the request's description. Fires when lead is about to attach the assembled QA-evidence report to its own merge request.
license: MIT
compatibility: opencode
---

# Skill: qa-report-publish

Publishing the **QA-evidence report** — one AC-organized document carrying QA
verification evidence — to a merge request after human approval.

## Invariant

The QA agent is read-only with respect to the remote: it writes only its local
artifacts (`report.md`, `report.html`, `NNN-name.png` screenshots) in its session
dir. **Lead assembles** the report — in BOTH forms (`qa-report.html` and
`qa-report.md`) — into that same session dir (so the relative screenshot refs
resolve) and is the sole writer to the remote, only after explicit human
approval. The remote deliverable: branch-host the Markdown form and upsert the
report block into the request's description. The HTML form is opened locally and
never pushed.

The report is QA evidence (the per-AC verdict may be `n/a` when QA didn't run)
plus a reference to the changeset. Static and blast-radius review is not part of
this report — it happens separately on the merge request and is addressed via the
merge-request workflow.

## Report forms

The report is produced in TWO forms, both written into the QA session dir, both
organized by acceptance criterion, and both led by the same machine-readable
verdict line:

```
🧪 QA — PASS ✅ / FAIL ❌ / n/a   ← single parseable verdict (n/a when QA didn't run)
```

The top-line QA verdict is FAIL if any acceptance criterion's QA failed, n/a if QA
did not run, otherwise PASS.

The two forms differ in exactly two things — how they show **diffs** and how
they show **screenshots**:

| | `qa-report.html` (local-only) | `qa-report.md` (hosted) |
|---|---|---|
| Diffs | **embeds** each changed file's diff rendered inline as self-contained highlighted HTML | **deep-links** each changed file into the hosted changeset; never embeds hunks |
| Screenshots | embedded `<img>` + clickable running-app links | relative-ref `![](NNN.png)` images |
| Lifecycle | auto-opened locally, **never pushed** | hosted on the branch and linked from the request |

Everything else is identical: the verdict header, the per-AC sections, the
could-not-verify section, and the **no-structured-AC fallback** (a single
`### Goal — <stated goal>` section).

### The hosted form — `qa-report.md`

```
## 🧪 QA — PASS ✅

**Changeset:** <files-view URL pinned to the head revision>   (local: `<diff command for the range>`)

### AC1 — <criterion text>
- **Changeset:** per-file deep links into the changed files (local: the diff command scoped to those files)
- **QA:** PASS ✅ / FAIL ❌ / n/a — evidence  ![cap](003-ac1.png)  <details><summary>steps</summary>

  …chronological trail…
  </details>

### AC2 — …

### Could not verify
- …
```

- The first line — `## 🧪 QA — PASS ✅` / `FAIL ❌` / `n/a` — is the single
  parseable verdict; the badge is composed by parsing THIS file.
- Reference the changeset; **never paste diff hunks into this form.** For a
  hosted request, deep-link each changed file the AC touches and pin the files
  view to the head revision (the source-control integration skill documents the
  per-file anchor recipe). For a local changeset with no hosted URL, cite the
  diff command for the range plus `file:line`. The "never copy diff text" rule is
  specific to this hosted form — it has a host that renders the linked diff.

### The local form — `qa-report.html`

Self-contained, auto-opened, NEVER pushed. Because there is no host to render a
linked diff, this form **embeds** each changed file's diff rendered inline as
highlighted HTML (diff-level coloring only — add / del / hunk / context), embeds
QA screenshots as images, and links the captured running-app page URLs. It is the
AC-organized successor to the retired offline diff viewer. Render each changed
file's diff inline as self-contained highlighted HTML, and deep-link each changed
file in the hosted form via the per-file anchor recipe — both mechanics live in
the source-control integration skill.

Skeleton (the inline `<style>` carries a familiar code-host diff palette; the `.diff`
`add`/`del`/`hunk`/`ctx` classes match the rendered diff spans):

```html
<html><head><meta charset="utf-8"><style>
body{font-family:system-ui,sans-serif;max-width:1100px;margin:2em auto;padding:0 1em;color:#1f2328}
h1{font-size:1.5em} h2{font-size:1.15em;border-bottom:1px solid #d0d7de;padding-bottom:.3em}
.summary{color:#57606a;margin:.25em 0 1.5em}
section.ac{margin:2em 0;border-top:2px solid #d0d7de;padding-top:1em}
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

- **Header:** `<h1>🧪 QA — PASS ✅</h1>`.
- **Per AC:** `<section class="ac">` → `<h2>AC1 — criterion</h2>` → the embedded
  rendered diff (one `.diff` block per changed file) → `<div class="qa">` (the
  PASS/FAIL line, `<img class="shot">` screenshots, the running-app links, and a
  `<details><summary>steps</summary>` chronological trail).
- **Tail:** a `Could not verify` section.
- Close with the body/html end tags and open the file locally.

## Badge composition

The verdict+link badge is used in the **own-MR description block**. Compose it by
parsing the **hosted Markdown form** (`qa-report.md`): read the verdict from
the `## 🧪 QA` line, e.g.
`🧪 QA — PASS ✅ · [full report ↗](<link>)`. The local HTML form is never parsed
for the badge.

## Publish procedure

The HTML form (`qa-report.html`) is local-only — it is opened locally and
NEVER pushed. Both forms are ALWAYS generated into the session dir — they are
lead's worktable/record. The remote is the hosted Markdown form plus the
description block.

Lead is the sole writer to the remote, and only after the approval gate.

1. **Host the report.** Push `qa-report.md` and its referenced screenshots
   to the hosting branch (`qa-assets` by default) at `pr-<n>/`, **overwritten
   wholesale per merge request** (one report per request; deleted/renamed shots
   don't linger), through a throwaway worktree so the working tree and
   checked-out branch are never disturbed. Use the branch-hosting transport from
   the injected source-control skill. The committed `.md` renders natively in
   the file view with its **relative** images resolving — no URL rewriting. The
   description block and its `<details>` screenshots need this hosted target.

2. **Upsert the report block into the merge request description** between
   `<!-- qa:start -->` / `<!-- qa:end -->` markers (read-modify-write the body:
   replace between the markers if present, else append after a blank line —
   never a new comment). The block carries a visible lead line (verdict badge ·
   `full report ↗` link), a `<sub>` provenance line (commit short ref · updated
   timestamp), then one collapsed section per acceptance criterion —
   `<details open>` for any FAIL AC, `<details>` for passing ACs — each leading
   with a single head-pinned code reference (a bare same-repo permalink on its
   own line, which unfurls to the rendered snippet) capped to the AC's primary
   implementing region, then a diff deep-link as needed, then its QA line. Close
   with a `Could not verify` section. **The blank line after each `</summary>` is
   mandatory** or the inner markdown won't render. The permalink must be bare (on
   its own line, not wrapped in link text) to unfurl. (See the AC-block layout
   below.)

### Your-own-request AC block layout (Template A)

```
<!-- qa:start -->
🧪 **QA** — FAIL ❌ · [full report ↗](<hosted .md blob URL>)
<sub>commit <shortSHA> · updated <YYYY-MM-DD HH:MM></sub>

<details open><summary>AC1 — <criterion> · QA FAIL ❌</summary>

<head-pinned permalink to the AC's primary region>

- [diff ↗](<per-file deep link>)
- **QA:** FAIL ❌ — <one-line evidence> · [screenshots ↗](<hosted report blob URL>)

</details>

<details><summary>AC2 — <criterion> · QA PASS ✅</summary>

<bare permalink …#L40-L62>

- **QA:** PASS ✅ — <evidence> · [screenshots ↗](…)

</details>

<details><summary>Could not verify</summary>

- <item> — <why>

</details>
<!-- qa:end -->
```

The per-AC code reference is ONE bare permalink pinned to the head revision,
capped to the AC's primary implementing region at ≤40 lines (pick the tightest
`#Lstart-Lend` window over the principal change). Additional files/regions for
that AC get a `[diff ↗]` deep-link only — NOT a second unfurl.

## Re-review

On a re-review, lead REGENERATES both forms from the reconciled evidence and
re-opens the HTML form locally. Then refresh the deliverable: re-host the Markdown
form (overwritten wholesale, so the link is unchanged), then in-place
read-modify-write of the WHOLE marked block in the description, refreshing the
`<sub>` provenance line — never a new comment.

## Approval gate

Before any remote write, show the plan — the files to be pushed to the hosting
branch, and the exact description section to be added — and wait for explicit
human approval. Only then perform the push and place the deliverable. The
analysis agents never write to the remote.

When a merge request is merged or closed, its `pr-<n>/` dir can be deleted from
the hosting branch as cheap cleanup.
