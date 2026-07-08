---
name: qa-report-publish
description: Fires when lead is about to publish the assembled QA report to a merge request after human approval.
license: MIT
compatibility: opencode
---

# Skill: qa-report-publish

Covers how lead hosts the report and registers the deployment status that surfaces a **"View deployment"** button in the request's timeline.

## Invariant

- The QA agent is read-only with respect to the remote; it writes only local artifacts in its session dir.
- Lead is the sole remote writer, and only after explicit human approval.
- Remote deliverable: the hosted Markdown form (`qa-report.md`) plus a deployment status on the request's head commit.
- The HTML form is never pushed.

The report is QA evidence only (the per-AC verdict may be `n/a` when QA didn't
run). Static and blast-radius review is not part of this report — it happens
separately on the merge request and is addressed via the merge-request workflow.

## Report forms

The report is produced in TWO forms, both written into the QA session dir, both
organized by acceptance criterion, and both led by the same machine-readable
verdict line:

```
🧪 QA — PASS ✅ / FAIL ❌ / n/a   ← single parseable verdict (n/a when QA didn't run)
```

The top-line QA verdict is FAIL if any acceptance criterion's QA failed, n/a if QA
did not run, otherwise PASS.

The two forms differ in exactly one thing — how they show **screenshots**:

| | `qa-report.html` (local-only) | `qa-report.md` (hosted) |
|---|---|---|
| Screenshots | embedded `<img>` + clickable running-app links | relative-ref `![](NNN.png)` images |
| Lifecycle | auto-opened locally | hosted on the branch and linked from the request |

Everything else is identical: the verdict header, the per-AC QA sections, the
could-not-verify section, and the **no-structured-AC fallback** (a single
`### Goal — <stated goal>` section).

### The hosted form — `qa-report.md`

```
## 🧪 QA — PASS ✅

### AC1 — <criterion text>
- **QA:** PASS ✅ / FAIL ❌ / n/a — evidence  ![cap](003-ac1.png)  <details><summary>steps</summary>

  …chronological trail…
  </details>

### AC2 — …

### Could not verify
- …
```

### The local form — `qa-report.html`

Self-contained, auto-opened locally. This form embeds QA screenshots as
images and links the captured running-app page URLs, organized by acceptance
criterion.

Skeleton:

```html
<html><head><meta charset="utf-8"><style>
body{font-family:system-ui,sans-serif;max-width:1100px;margin:2em auto;padding:0 1em;color:#1f2328}
h1{font-size:1.5em} h2{font-size:1.15em;border-bottom:1px solid #d0d7de;padding-bottom:.3em}
.summary{color:#57606a;margin:.25em 0 1.5em}
section.ac{margin:2em 0;border-top:2px solid #d0d7de;padding-top:1em}
.qa .shot{width:60%;border:1px solid #ccc;border-radius:4px;margin:.5em 0}
.qa a{color:#0969da;word-break:break-all} details>summary{cursor:pointer}
</style></head><body>
```

Layout:

- **Header:** `<h1>🧪 QA — PASS ✅</h1>`.
- **Per AC:** `<section class="ac">` → `<h2>AC1 — criterion</h2>` →
  `<div class="qa">` (the PASS/FAIL line, `<img class="shot">` screenshots, the
  running-app links, and a `<details><summary>steps</summary>` chronological
  trail).
- **Tail:** a `Could not verify` section.
- Close with the body/html end tags and open the file locally.

## Verdict

The verdict is read from `qa-report.md` by parsing the `## 🧪 QA` first line and used as the deployment status `description` (e.g. `QA — PASS ✅`).

## Publish procedure

1. **Host the report.** Push `qa-report.md` and its referenced screenshots
   to the hosting branch (`qa-assets` by default) at `pr-<n>/`, **overwritten
   wholesale per merge request** (one report per request; deleted/renamed shots
    don't linger), through a throwaway worktree so the working tree and
    checked-out branch are never disturbed. The committed `.md` renders natively in
   the file view with its **relative** images resolving — no URL rewriting.

2. **Register the deployment.** This write MUST be performed by lead directly
   via bash — never dispatched to the `github` subagent or any other
   source-control MCP wrapping-subagent. The source-control MCP server has no
   Deployments API coverage (no create-deployment/create-deployment-status
   tool exists on its surface), and the wrapping-subagent is bash-denied by
   design — dispatching this write there sends it hunting for credentials it
   couldn't use even if it found them, and it gets stuck indefinitely. Use the
   `gh` CLI directly, passing the JSON body via `--input -` and a heredoc —
   never `-f`/`-F` flag syntax for the `required_contexts` array field
   (`-f required_contexts[]=` breaks on zsh glob expansion, not the API).
   Create the deployment on the merge request's head commit for environment
   `qa-report`:

   ```
   gh api repos/<owner>/<repo>/deployments -X POST --input - << 'EOF'
   {"ref": "<head-sha>", "environment": "qa-report", "auto_merge": false, "required_contexts": []}
   EOF
   ```

   Then post a `success` deployment status with the hosted report's blob URL
   as the `environment_url` and the parsed verdict as the `description` (e.g.
   `QA — PASS ✅`):

   ```
   gh api repos/<owner>/<repo>/deployments/<id>/statuses -X POST --input - << 'EOF'
   {"state": "success", "environment": "qa-report", "environment_url": "<blob-url>", "description": "<verdict>"}
   EOF
   ```

   This surfaces a **"View deployment"** button in the request's timeline and
   environments panel — no description editing required.

## Re-review

On a re-review, lead REGENERATES both forms from the reconciled evidence and
re-opens the HTML form locally. Then refresh the deliverable: re-host the Markdown
form (overwritten wholesale, so the blob URL is unchanged), then post a new
`success` deployment status on the existing deployment with the updated
`description` field reflecting the new verdict — no new deployment object needed.
Post this status via direct bash as in the Publish procedure — never dispatch
this to the `github` subagent.

## Approval gate

Before any remote write, show the plan — the files to be pushed to the hosting
branch, and the deployment status to be registered — and wait for explicit human
approval. Only then perform the push and register the deliverable. The analysis
agents never write to the remote.

When a merge request is merged or closed, post a final `inactive` deployment
status on the existing deployment — via direct bash as above, never dispatched
to the `github` subagent — then delete its `pr-<n>/` dir from the hosting
branch as cheap cleanup.
