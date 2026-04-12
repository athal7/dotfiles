
## PR Review Rules

**"Review this PR" means:** analyze and draft a written review — do NOT submit to GitHub or implement fixes unless explicitly asked.

**Conflict resolution on reviewed PRs:** When a PR has reviews and conflicts with the base branch, use `git merge` (not `git rebase`) to resolve them. Rebasing rewrites history and invalidates existing review comments.

**Submitting reviews:** Show the full proposed review content and ask "Do you approve?" before submitting to GitHub — then STOP and wait for explicit approval. Use your `post-inline-comments` capability when posting inline comments or responding to review feedback.

**Inline-first policy:** When submitting to GitHub, post findings as inline comments only — use your `post-inline-comments` capability. Do NOT post a top-level review body with verdict, TL;DR, summaries, or per-line findings. The verdict, TL;DR, Requirements Check, and all other summary sections are for the session output only — never submitted to GitHub. The only exception is a PR-wide observation that genuinely cannot be attributed to any line; in that case, one brief sentence in the body is acceptable.

---

## PR Checkout

**If reviewing a PR** (URL or number provided): check out the PR branch locally before doing anything else.

```bash
gh pr checkout <PR_NUMBER>
```

This ensures local files reflect the PR's code, enabling accurate diff panel display and local file reads. Save the original branch first so you can restore it if needed:

```bash
ORIGINAL_BRANCH=$(git branch --show-current)
gh pr checkout <PR_NUMBER>
# ... review ...
git checkout $ORIGINAL_BRANCH  # restore when done
```

If `gh pr checkout` fails (e.g., the repo isn't local), fall back to `gh pr diff` for the diff and `gh pr view` for metadata.

---

## PR Prior Review History

Fetch prior review history before dispatching specialists:

1. `gh pr reviews <PR> --json author,state,submittedAt,body` — all submitted reviews with their verdict and top-level body
2. `gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments` — all inline review comments; note `path`, `line`, `body`, `in_reply_to_id` (a non-null `in_reply_to_id` means it's a reply in a thread)
3. Build a **prior review summary**: group inline comments by thread (using `in_reply_to_id`), identify the last message per thread, and mark threads as:
   - **Resolved** — author replied acknowledging the fix, or the thread was explicitly resolved
   - **Unresolved** — no author reply, or last reply disagrees/defers
4. Attach the full prior review summary to the payload for all sub-agents.

**Prior review rules (output):**
- Do NOT re-raise issues that were already raised in a prior review and have been addressed (author replied with a fix, or the code changed to resolve it). Mark them as handled.
- DO surface unresolved threads in the "Unresolved Prior Feedback" section — these are higher priority than new findings since they represent reviewer expectations not yet met.
- Unresolved prior feedback counts toward the verdict the same as blockers if they were originally `CHANGES REQUESTED` items.
- If a new finding duplicates an unresolved prior comment, merge them: cite the prior comment and note it remains unresolved rather than presenting it as a fresh finding.
