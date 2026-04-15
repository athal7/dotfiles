
## Merge Request Review Rules

**"Review this merge request" means:** analyze and draft a written review — do NOT submit or implement fixes unless explicitly asked.

**Conflict resolution on reviewed merge requests:** When a merge request has reviews and conflicts with the base branch, use merge (not rebase) to resolve them. Rebasing rewrites history and invalidates existing review comments.

**Submitting reviews:** Show the full proposed review content and ask "Do you approve?" before submitting — then STOP and wait for explicit approval. Use your `post-inline-comments` capability when posting inline comments or responding to review feedback.

**Inline-first policy:** When submitting, post findings as inline comments only — use your `post-inline-comments` capability. Do NOT post a top-level review body with verdict, TL;DR, summaries, or per-line findings. The verdict, TL;DR, Requirements Check, and all other summary sections are for the session output only — never submitted. The only exception is a review-wide observation that genuinely cannot be attributed to any line; in that case, one brief sentence in the body is acceptable.

---

## Merge Request Checkout

**If reviewing a merge request** (URL or number provided): check out the branch locally before doing anything else using your `code-review` capability.

This ensures local files reflect the code under review, enabling accurate diff panel display and local file reads. Save the original branch first so you can restore it after review.

If the capability cannot check out the branch locally (e.g., the repo isn't available locally), fall back to fetching the diff and metadata via your `code-review` capability.

---

## Server Startup

**After checking out the branch**, auto-detect and start the dev server using your `shell` capability:

1. Inspect the repo root for a dev server command in this priority order:
   - `package.json` → `scripts.dev`, then `scripts.start`
   - `Procfile` → the `web:` entry
   - `Makefile` → a `dev`, `serve`, or `start` target
   - `README.md` → look for a "Getting started" / "Running locally" code block
2. If a command is found, spawn the server in the background via your `shell` capability. Wait up to 15 seconds for the server to be ready (look for a "listening on" / "ready" / port-bound log line).
3. Record the session ID and the local URL (e.g. `http://localhost:3000`) for use in QA.
4. If no command can be determined, note "Server auto-start skipped — could not detect dev server command" and continue with review (QA will be skipped).
5. After the full review is complete and QA has run, kill the background session and restore the original branch.

---

## Prior Review History

Fetch prior review history before dispatching specialists using your `code-review` capability:

1. All submitted reviews with their verdict and top-level body
2. All inline review comments, including `path`, `line`, `body`, and reply thread relationships
3. Build a **prior review summary**: group inline comments by thread, identify the last message per thread, and mark threads as:
    - **Resolved** — author replied acknowledging the fix, or the thread was explicitly resolved
   - **Awaiting reviewer** — author has replied (most recent message is from the merge request author) but no reviewer response yet
   - **Unresolved** — no author reply, or last reply disagrees/defers
4. Attach the full prior review summary to the payload for all sub-agents.

**Prior review rules (output):**
- Do NOT re-raise issues that were already raised in a prior review and have been addressed (author replied with a fix, or the code changed to resolve it). Mark them as handled.
- DO surface unresolved threads in the "Unresolved Prior Feedback" section — these are higher priority than new findings since they represent reviewer expectations not yet met.
- DO surface **awaiting-reviewer** threads in an "Awaiting Your Response" section — the author has replied and is blocked waiting on the reviewer.
- Unresolved prior feedback counts toward the verdict the same as blockers if they were originally `CHANGES REQUESTED` items.
- If a new finding duplicates an unresolved prior comment, merge them: cite the prior comment and note it remains unresolved rather than presenting it as a fresh finding.
