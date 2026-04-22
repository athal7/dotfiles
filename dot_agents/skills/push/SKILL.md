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
    - source-control
    - ci
---

# Skill: Push

## Rule

**Never push on your own initiative.** A push requires either an explicit user command or explicit user approval after you have shown a push summary.

## Two flows

### User-initiated push

The user says "push", "shipit", "ship it", "commit and push", or any clear push command.

1. Run the full local test suite for the project. If tests fail, stop and report — do not push.
2. Show a summary of unpushed commits using your `branching` capability.
3. Push immediately. The command is the approval.

### Agent-initiated push

You decide a push is needed (e.g. as part of a workflow, after fixing CI, etc.).

1. Run the full local test suite for the project. If tests fail, fix them first.
2. Show a summary of unpushed commits using your `branching` capability.
3. **End your response. Do not push.**
4. Wait for the user's next message.
5. Only push if the next message is an explicit confirmation: "yes", "approve", "go ahead", "lgtm", "do it".

## What Does NOT Count as Approval for Agent-initiated Push

- "keep going" or other general continuation
- Any approval from earlier in the conversation

## After Push — Create/Update Draft Merge Request

After every successful push, automatically create or update a draft merge request using your `source-control` capability.

1. Check if a merge request already exists for this branch
2. If none exists: create a draft merge request using commits from the branch to populate title/body
3. If one already exists (any state):
   - Compare the current branch commits against the existing title/body
   - If there is a material change (new feature scope, different fix, renamed component, changed API, etc.), update the title/body
   - Minor additions (tests, docs, formatting) do not warrant an update
   - Do not update the state (draft → ready or vice versa)
4. Once created/confirmed, proceed to CI watching

## After Draft Merge Request — Watch CI

After the draft merge request is created/confirmed, watch CI to completion using your `ci` capability. Do not hand back to the user and consider the task done.

1. Poll every 30s until the run is no longer queued or in progress
2. If all checks pass: report success with a markdown link to the merge request — never just the bare number
3. If any check fails:
   - Get the failure output from the failed run
   - Fix the root cause
   - **Run the full test suite locally** to verify the fix before pushing — do not push blind
   - Commit (using your `commit` capability) and push
   - Return to step 1
4. Keep iterating until CI is green. Do not give up after one fix attempt.
