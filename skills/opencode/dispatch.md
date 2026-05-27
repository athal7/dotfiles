Send a task to an OpenCode session running in a different workspace. Prefer reusing an idle session over creating a new one.

**API base:** `http://localhost:4096`

**Dispatch in plan mode by default.** Always include `"agent": "plan"` in the message body — the dispatched session should propose changes and wait for approval, not edit autonomously. Only override with a different agent when the user explicitly asks for autonomous execution.

---

## Worktree sandboxes — mandatory for PR reviews

**Any task that involves reviewing or modifying a PR branch MUST use a worktree sandbox.** Never point a review session at the live repo directory — concurrent sessions on the same directory clobber each other's branch state (checkouts, stashes, index).

Use a worktree whenever:
- Reviewing a PR (always)
- Running experimental or speculative work on a branch
- Multiple sessions need to operate on the same repo simultaneously

```bash
REPO_DIR="$HOME/code/<repo>"

# Fetch the PR branch name first
BRANCH=$(gh pr view <number> --repo <owner>/<repo> --json headRefName -q .headRefName)

# Create a worktree via the API (OpenCode manages the path)
WORKTREE=$(curl -s -X POST "http://localhost:4096/experimental/worktree?directory=$REPO_DIR" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$BRANCH\"}" | jq -r '.directory')

# Check out the PR branch inside the worktree
git -C "$WORKTREE" fetch origin "$BRANCH"
git -C "$WORKTREE" checkout "$BRANCH"

# Create session in the worktree
SESSION_ID=$(curl -s -X POST "http://localhost:4096/session?directory=$WORKTREE" \
  -H "Content-Type: application/json" -d '{}' | jq -r '.id')

# Send task — use --max-time 10 so curl doesn't block waiting for the session to finish
curl -s --max-time 10 -X POST "http://localhost:4096/session/$SESSION_ID/message?directory=$WORKTREE" \
  -H "Content-Type: application/json" \
  -d '{"agent": "plan", "parts": [{"type": "text", "text": "<prompt>"}]}' || true
```

---

## Standard dispatch (no branch isolation needed)

For tasks that don't need branch isolation (e.g. reading logs, answering questions, running tests on main):

```bash
REPO_DIR="$HOME/code/<repo>"

# 1. Look for an existing non-archived session
SESSION_ID=$(curl -s "http://localhost:4096/session?directory=$REPO_DIR&roots=true" \
  | jq -r '[.[] | select(.time.archived == null)] | sort_by(.time.updated) | reverse | .[0].id // empty')

# 2. If found, check if it's idle
if [ -n "$SESSION_ID" ]; then
  STATUS=$(curl -s "http://localhost:4096/session/status" \
    | jq -r --arg id "$SESSION_ID" '.[$id].type // "unknown"')
  if [ "$STATUS" != "idle" ]; then
    SESSION_ID=""  # busy — create a new one
  fi
fi

# 3. Create a new session if needed
if [ -z "$SESSION_ID" ]; then
  SESSION_ID=$(curl -s -X POST "http://localhost:4096/session?directory=$REPO_DIR" \
    -H "Content-Type: application/json" -d '{}' | jq -r '.id')
fi

echo "Session: $SESSION_ID"
```

## Send the task

```bash
# --max-time 10 prevents blocking — the session keeps running server-side after curl exits
curl -s --max-time 10 -X POST "http://localhost:4096/session/$SESSION_ID/message?directory=$REPO_DIR" \
  -H "Content-Type: application/json" \
  -d '{"agent": "plan", "parts": [{"type": "text", "text": "<prompt>"}]}' || true
```

The POST streams and will hit the timeout — that's expected and correct. The session keeps running server-side.

## Check on it (optional)

```bash
curl -s "http://localhost:4096/session/status" \
  | jq --arg id "$SESSION_ID" '.[$id]'
```

The session is also visible in the OpenCode web UI at `http://localhost:4096` or in OpenCode Desktop.

---

## Usage

- "Review PR #123 in myapp" → **worktree sandbox** in `~/code/myapp` on the PR branch, send review prompt
- "Fix the failing test in mylib" → **worktree sandbox**, send the fix prompt
- "What's the last deploy status in myapp?" → standard dispatch, no branch isolation needed
- "Implement Linear issue KEY-1234 in myapp" → **worktree sandbox** in `~/code/myapp` on a feature branch, dispatch `Workflow: implement. Linear issue KEY-1234`

## Cross-repo implementation

When the current workspace is not the target repo (e.g., you're in dotfiles but the issue targets `odin`): create a worktree + session in the target repo, then **dispatch the workflow command with the issue key**. Do not decompose the workflow yourself — the receiving session's plan agent runs the full `/implement` pipeline with direct codebase access.

```bash
# Create worktree, branch, and session (see above), then dispatch the command:
curl -s --max-time 10 -X POST "http://localhost:4096/session/$SESSION_ID/message?directory=$WORKTREE" \
  -H "Content-Type: application/json" \
  -d '{"agent": "plan", "parts": [{"type": "text", "text": "Workflow: implement.\n\nLinear issue KEY-1234"}]}' || true
```

Anti-pattern: gathering context, exploring files, and running plan/build sub-agents from the wrong workspace. The dispatched session has the repo's AGENTS.md, skills, and file access — let it drive.

## Design principles

- **Plan mode by default** — dispatched sessions get `"agent": "plan"` so they propose changes for approval rather than editing autonomously
- **Worktree for anything branch-specific** — PRs, experiments, multi-session work on same repo
- **Reuse over creation** — check for idle sessions first (standard dispatch only)
- **Fire and forget** — the POST may timeout; the session is still working
- **Dispatch the command, not the decomposition** — send `/implement` or `/review` as the prompt, not the individual steps. The receiving session runs its own workflow.
- **One task per session** — don't queue multiple prompts into a busy session
- **Never use `opencode run` for dispatch** — it bypasses the API, can't be reused, and runs synchronously in your shell
