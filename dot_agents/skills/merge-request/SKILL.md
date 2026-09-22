---
name: merge-request
description: Load when maintaining your own pull request after review feedback or conflicts
license: MIT
---

- Fetch inline review threads and top-level comments.
- Classify each item as actionable, discussable, or resolved.
- Present the full comment, location, author, timestamp, relevant code, and proposed action before changing code or replying.
- Batch actionable fixes. Run the lowest suitable verification tier. Run browser QA first for UI changes.
- Use `shipit` for the commit and push cycle.
- Resolve a fixed thread only after the fix is pushed.
- Show the complete payload before every remote write.
- Do not change draft state, reviewers, or assignment while another reviewer is active.
- Resolve conflicts by preserving both sides' intent. Run the full required checks after resolution.
- Re-request review only after the final summary and stable pushed head are ready.
- Do not rebase a reviewed request unless explicitly required; rebasing invalidates inline comments.
