---
name: code-review
description: Load when reviewing a pull request, posting review findings, or deciding an APPROVE or REQUEST_CHANGES verdict
license: MIT
---

- Keep findings unlabeled; prefix only nits with `nit:`.
- Anchor each finding to a diff line when possible; use a top-level review comment only when it cannot be anchored.
- ALWAYS post the review as `APPROVE` or `REQUEST_CHANGES`; NEVER post `gh pr review --comment` when the review has findings, because a comment review leaves the pull request in `REVIEW_REQUIRED` and a human has to re-read it to know a maintainer looked and found something.
- ALWAYS use `REQUEST_CHANGES` when any finding meets the target repo's blocking threshold and otherwise use `APPROVE`, listing each finding that does not block as non-blocking.
- ALWAYS identify any unreviewed part of a large change in the review body and still give a verdict; partial coverage is a caveat in the body, never a reason to withhold the verdict.
