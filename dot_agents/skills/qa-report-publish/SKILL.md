---
name: qa-report-publish
description: Fires before publishing an assembled QA report to a merge request after human approval.
license: MIT
---

This skill performs the remote writes for QA publishing. The QA agent produces only local artifacts; those artifacts are pushed to the remote here.

The report carries QA evidence only. Static and blast-radius review happens separately on the merge request.

**Verdict** — the deployment status `description` is exactly `QA - PASS` or `QA - FAIL`. It must be pure ASCII: GitHub Deployments rejects 4-byte Unicode in status descriptions. Derive the verdict from `qa-report.md`, stripping any emoji or other non-ASCII decoration from the heading before use.

## Approval gate

Before any remote write, show what will be pushed and what status will be registered. Wait for explicit approval.

## 1. Host the report

Push `qa-report.md` plus its screenshots to branch `qa-assets` at `pr-<n>/`.

- Overwrite wholesale — one report per request, so deleted or renamed shots don't linger.
- Use a throwaway worktree; never disturb the checkout or the current branch.
- Relative image refs render natively in the file view. No URL rewriting.

## 2. Register the deployment

**No MCP server exposes the GitHub Deployments API** — not this one, not any. This write must go through `gh` directly via bash. Dispatching it to a GitHub MCP agent strands that agent hunting for a credential it couldn't use.

Pass the body with `--input -` and a heredoc — never `-f`/`-F` for `required_contexts`, which breaks on **zsh glob expansion** (not the API).

```
gh api repos/<owner>/<repo>/deployments -X POST --input - << 'EOF'
{"ref": "<head-sha>", "environment": "qa-report", "auto_merge": false, "required_contexts": []}
EOF
```

```
gh api repos/<owner>/<repo>/deployments/<id>/statuses -X POST --input - << 'EOF'
{"state": "success", "environment": "qa-report", "environment_url": "<blob-url>", "description": "<verdict>"}
EOF
```

That surfaces a **"View deployment"** button in the timeline and environments panel — no description editing needed.

## Re-review

Regenerate both report forms from the reconciled evidence, re-open the HTML locally, re-host the Markdown (overwritten wholesale, so the blob URL is unchanged), then post a **new status on the existing deployment** with the updated `description`. No new deployment object.

## Merged or closed

Post a final `inactive` status on the existing deployment, then delete its `pr-<n>/` directory from the hosting branch.
