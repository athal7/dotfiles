---
name: push
description: Push approval protocol and post-push CI watching
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

After every successful push, automatically create or update a draft PR (default behavior).

1. Check if a PR already exists for this branch: `gh pr list --head <branch> --state all`
2. If no PR exists:
   - Create a draft PR: `gh pr create --draft --title "..." --body "..."`
   - Use commits from the branch to populate title/body
3. If a PR already exists (any state):
   - Leave it as-is; do not update the PR state
4. Once PR is created/confirmed, proceed to CI watching

## After Draft PR — Watch CI

After the draft PR is created/confirmed, watch CI to completion. Do not hand back to the user and consider the task done.

1. Poll every 30s: `gh run list --branch <branch> --limit 1`
2. Wait until status is no longer `queued` or `in_progress`
3. If all checks pass: done
4. If any check fails:
   - `gh run view <run-id> --log-failed` to get failure output
   - Fix the root cause, commit (following `commit` skill), and push
   - Return to step 1
5. Keep iterating until CI is green. Do not give up after one fix attempt.
