---
name: push
description: Push approval protocol and post-push CI watching
license: MIT
metadata:
  author: athal7
  version: "1.0"
  provides:
    - push
  requires:
    - commit
    - code-review
    - ci
---

# Skill: Push

## Rule

**Never push on your own initiative.** A push requires either an explicit user command or explicit user approval after you have shown a push summary.

## Two flows

### User-initiated push

The user says "push", "shipit", "ship it", "commit and push", or any clear push command.

1. Run `git log origin/<branch>..HEAD --oneline` and show the summary.
2. Push immediately. The command is the approval.

### Agent-initiated push

You decide a push is needed (e.g. as part of a workflow, after fixing CI, etc.).

1. Run `git log origin/<branch>..HEAD --oneline` and show the summary.
2. **End your response. Do not push.**
3. Wait for the user's next message.
4. Only push if the next message is an explicit confirmation: "yes", "approve", "go ahead", "lgtm", "do it".

## What Does NOT Count as Approval for Agent-initiated Push

- "keep going" or other general continuation
- Any approval from earlier in the conversation

## After Push — Create/Update Draft PR

After every successful push, automatically create or update a draft merge request using your `code-review` capability.

1. Check if a PR already exists for this branch
2. If no PR exists: create a draft PR using commits from the branch to populate title/body
3. If a PR already exists (any state):
   - Compare the current branch commits against the PR's existing title/body
   - If there is a material change (new feature scope, different fix, renamed component, changed API, etc.), update the PR title/body
   - Minor additions (tests, docs, formatting) do not warrant an update
   - Do not update the PR state (draft → ready or vice versa)
4. Once PR is created/confirmed, proceed to CI watching

## After Draft PR — Watch CI

After the draft PR is created/confirmed, watch CI to completion using your `ci` capability. Do not hand back to the user and consider the task done.

1. Poll every 30s until the run is no longer queued or in progress
2. If all checks pass: report success with a markdown link to the PR — never just the bare number
3. If any check fails:
   - Get the failure output from the failed run
   - Fix the root cause
   - **Run the full test suite locally** to verify the fix before pushing — do not push blind
   - Commit (using your `commit` capability) and push
   - Return to step 1
4. Keep iterating until CI is green. Do not give up after one fix attempt.
