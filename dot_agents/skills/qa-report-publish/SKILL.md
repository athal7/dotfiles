---
name: qa-report-publish
description: Load before submitting a QA-backed pull request review
license: MIT
---

Read `report.md` and reconcile it with the local HTML report. Use the exact report heading as the verdict.

Build one concise block:

```markdown
<!-- qa:start -->
## QA — PASS

**Verified**
- <acceptance criterion> — <observed result>

**Could not verify:** none
<!-- qa:end -->
```

For a failure, include exact repro steps, expected result, observed result, URL, and console errors. Never upload or publish report files or screenshots.

Before any remote write:

- Show the complete review body.
- Show every inline comment.
- Replace exactly one existing QA block, append one when none exists, and stop when more than one exists.
- Create one pending review, add its inline findings, and submit that review once.

Do not update the pull request body or create a separate QA comment. Do not delete a remote `qa-assets` branch as part of publication.
