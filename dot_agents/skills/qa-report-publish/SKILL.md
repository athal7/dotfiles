---
name: qa-report-publish
description: Fires before submitting a QA-backed GitHub pull request review after human approval.
license: MIT
---

This skill publishes concise QA evidence in your GitHub pull request review body. It is submitted with your inline review comments. The QA agent produces local artifacts. This skill never uploads `report.md`, `report.html`, or screenshots.

The QA block carries QA evidence only. It sits with any concise review summary and the inline review comments.

## Prepare the QA evidence block

Read `report.md` and reconcile it with the local HTML report before publication. Derive the verdict from the required report heading. Make the block self-contained and concise:

- Include `QA — PASS` or `QA — FAIL`.
- For each verified flow, include the acceptance criterion, observed result, and final local URL when it helps reproduce the result.
- For a failure, include exact repro steps, expected result, observed result, URL, and console errors.
- Include `**Could not verify:**` with its value.
- Do not embed, link, upload, or otherwise publish screenshots or QA report files. They remain local evidence.

Use one stable block in the review body:

```markdown
<!-- qa:start -->
## QA — PASS

**Verified**
- <acceptance criterion> — <observed result>

**Could not verify:** none
<!-- qa:end -->
```

On a fail, replace the verified result with the required failure detail. Load `communication` when composing the review. Append its required authorship marker as the final line of the review body.

## Approval gate

Before any remote write, show the full proposed review body, including the QA block and its authorship marker. Show every proposed inline comment too. Ask `Do you approve?` and wait for explicit approval. Do not create a pending review, add inline comments, or submit the review before approval.

## Submit the review

Build the full final review body locally. Start with any prepared review summary:

- If exactly one `<!-- qa:start -->` through `<!-- qa:end -->` block exists, replace that block.
- If no QA block exists, append the new block.
- If more than one QA block exists, stop and report the ambiguity. Do not select one.

Use native GitHub review support when it is available.
If native support cannot create and submit one pending review with inline comments, use approval-gated `gh api` for the pending-review API calls.
Create one bodyless pending review.
Add each approved inline finding to that pending review.
Submit that same review once with the full approved review body and the approved decision.

Do not update the pull request body, create issue comments, create GitHub Deployments, or register deployment statuses.

## Re-review

Before submitting a pending review, regenerate and reconcile the local evidence. Replace or append the marked QA block in the review body. Show the full updated review body and obtain explicit approval again.

After a review is submitted, do not modify the pull request body or create a separate QA comment. A later QA review can have no inline comments. Create and submit a new pending review with its new QA evidence block.

## Merged or closed

Do not make a final remote write.

## Retired `qa-assets` branch

Do not delete the existing remote `qa-assets` branch. Do not delete it during QA publication, re-review, or pull-request closure.

The separate destructive operation is:

```sh
git push origin --delete qa-assets
```

Show this command in full and obtain separate explicit user approval before running it.
