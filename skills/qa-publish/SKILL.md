---
name: qa-publish
description: Publishing a QA/verification report to a merge request after approval — the branch-hosting procedure and ownership-based link placement. Fires when lead is about to attach a QA verdict + screenshots to a code review. (Not the qa subagent's browser-driving role.)
license: MIT
compatibility: opencode
---

# Skill: qa-publish

Publishing a QA session (verdict + screenshots) to a merge request after human
approval.

## Invariant

The `qa` subagent produces `report.md` plus its `NNN-name.png` screenshots in the
session dir and **never writes to the remote**. Lead publishes — branch-hosts the
report and places the link — only after explicit human approval.

## Publish procedure

1. **Host the report.** Push `report.md` and its referenced screenshots to the
   hosting branch (`qa-assets` by default) at `pr-<n>/`, **overwritten wholesale
   per merge request** (one report per request; deleted/renamed shots don't
   linger), through a throwaway worktree so the working tree and checked-out
   branch are never disturbed. Use the branch-hosting transport from the injected
   source-control skill. The committed `.md` renders natively in the file view
   with its **relative** images resolving — no URL rewriting.

2. **Place the link — depends on ownership.** Determine whether *you* authored the
   merge request by comparing the request's author to the current user:
   - **You authored it** (your own request — the implement / merge-request flows):
     upsert a single verdict+link line into the **merge request description**
     between `<!-- qa:start -->` / `<!-- qa:end -->` markers (read-modify-write the
     body: replace between the markers if present, else append after a blank line).
   - **Someone else authored it** (you're reviewing — the review flow): post the
     verdict+link as a **comment** on the merge request. **Never edit another
     author's description.**

   The verdict+link line is a `🧪 QA: PASS ✅` / `🧪 QA: FAIL ❌` badge (read from
   the report's `## 🧪 QA` heading) plus a link to the hosted `report.md`.

## Approval gate

Before any remote write, show the plan — the files to be pushed to the hosting
branch, and the exact comment text or description section to be added — and wait
for explicit human approval. Only then perform the push and place the link. The
qa subagent never writes to the remote.

When a merge request is merged or closed, its `pr-<n>/` dir can be deleted from
the hosting branch as cheap cleanup.
