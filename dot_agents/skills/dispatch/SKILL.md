---
name: dispatch
description: Spawn or reuse an OpenCode session in another workspace to perform a task
license: MIT
metadata:
  author: athal7
  version: "1.0"
---

# Skill: Dispatch

Send a task to an OpenCode session running in a different workspace. Prefer reusing an idle session over creating a new one.

**API base:** `http://localhost:4096`

---

## Step 1: Find or create a session

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

## Step 2: Send the task

```bash
curl -s -X POST "http://localhost:4096/session/$SESSION_ID/message?directory=$REPO_DIR" \
  -H "Content-Type: application/json" \
  -d '{"parts": [{"type": "text", "text": "<prompt>"}]}'
```

The POST streams and may timeout from curl's perspective — that's expected. The session is working.

## Step 3: Check on it (optional)

```bash
# Session status
curl -s "http://localhost:4096/session/status" \
  | jq --arg id "$SESSION_ID" '.[$id]'
```

The session is also visible in the OpenCode web UI at `http://localhost:4096` or in OpenCode Desktop.

---

## Worktree sandbox (for PRs or experimental work)

When the task needs an isolated branch:

```bash
# Create worktree
WORKTREE=$(curl -s -X POST "http://localhost:4096/experimental/worktree?directory=$REPO_DIR" \
  -H "Content-Type: application/json" \
  -d '{"name": "<branch-or-slug>"}' | jq -r '.directory')

# Create session in the worktree
SESSION_ID=$(curl -s -X POST "http://localhost:4096/session?directory=$WORKTREE" \
  -H "Content-Type: application/json" -d '{}' | jq -r '.id')

# Send task
curl -s -X POST "http://localhost:4096/session/$SESSION_ID/message?directory=$WORKTREE" \
  -H "Content-Type: application/json" \
  -d '{"parts": [{"type": "text", "text": "<prompt>"}]}'
```

---

## Usage

Load this skill when you need to delegate work to another repo. Examples:

- "Review PR #123 in odin" → find/create session in `~/code/odin`, send `/review pr 123`
- "Fix the failing test in garak" → create session in `~/code/garak`, send the fix prompt
- "Start work on 0DIN-1216" → create worktree sandbox, send `process` kickoff prompt

## Design principles

- **Reuse over creation** — check for idle sessions first
- **Fire and forget** — the POST may timeout; the session is still working
- **One task per session** — don't queue multiple prompts into a busy session
- **Process skill for orchestration** — once a session is running, it loads `process` internally to manage plan → implement → verify → commit
