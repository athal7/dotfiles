---
name: openclaw-rescue
description: Rescue a stuck/unresponsive OpenClaw instance - saves unsent messages, fixes compaction loops, corrects model config, clears stuck sessions, restarts gateway, and resends saved messages
---

# openclaw-rescue

Use this skill when OpenClaw is unresponsive in Telegram (typing indicator appears but no reply, or no response at all).

## Common Root Causes

1. **Compaction loop** — session context too large; summarization keeps timing out and aborting, blocking all new messages
2. **Wrong model** — gateway restarted with a local model (e.g. `glm-4.7-flash`) instead of the cloud model after a restart
3. **Ollama signed out** — cloud models require `ollama signin`; signing out causes all cloud model calls to silently fail
4. **Stale session entry** — `sessions.json` references a session that is stuck/corrupt

## Step 1: Diagnose

```sh
# Check recent logs for root cause
openclaw logs 2>&1 | tail -40

# Key patterns to look for:
# "embedded run timeout" + "compaction" → compaction loop (most common)
# "agent model: ollama/glm-4.7-flash" on last startup → wrong model
# "You need to be signed in to Ollama" → run: ollama signin
# "typing TTL reached" with no response → model not responding
```

```sh
# Check what model the gateway is currently using
openclaw logs 2>&1 | grep "agent model"

# Check what model is configured
cat ~/.openclaw/openclaw.json | jq '.agents.defaults.model'
```

## Step 2: Save Unsent User Messages

Before clearing anything, extract the last N user messages from the stuck session so they can be resent.

```sh
# Find the stuck session ID from sessions.json
TELEGRAM_USER_ID="8241121359"  # Andrew's Telegram ID
SESSION_KEY="agent:main:telegram:direct:${TELEGRAM_USER_ID}"
SESSION_ID=$(cat ~/.openclaw/agents/main/sessions/sessions.json | jq -r ".\"${SESSION_KEY}\".sessionId // empty")
SESSION_FILE=~/.openclaw/agents/main/sessions/${SESSION_ID}.jsonl

echo "Session file: $SESSION_FILE"
wc -l "$SESSION_FILE"
```

```sh
# Extract the last few user messages (skip system/metadata wrapper, get actual text)
# Shows the last 5 user turns
jq -r 'select(.type=="message" and .message.role=="user") |
  .message.content | if type=="array" then
    map(select(.type=="text") | .text) | join("")
  else . end' "$SESSION_FILE" | tail -5
```

```sh
# Copy session file before clearing (so Step 7 can summarize it)
cp "$SESSION_FILE" /tmp/openclaw_session.jsonl
echo "Saved session to /tmp/openclaw_session.jsonl ($(wc -l < /tmp/openclaw_session.jsonl) lines)"
```

## Step 3: Fix Model Config (if wrong)

The correct model is `ollama/minimax-m2.7:cloud`. If the config shows `glm-4.7-flash`, fix it:

```sh
# Check current config
cat ~/.openclaw/openclaw.json | jq '.agents.defaults.model'

# Fix if needed
cat ~/.openclaw/openclaw.json | \
  jq '.agents.defaults.model = {"primary": "ollama/minimax-m2.7:cloud"}' \
  > /tmp/openclaw_fixed.json && mv /tmp/openclaw_fixed.json ~/.openclaw/openclaw.json

# Verify
cat ~/.openclaw/openclaw.json | jq '.agents.defaults.model'
```

## Step 4: Check Ollama Sign-in

```sh
# Test if cloud model works
ollama run minimax-m2.7:cloud "say hello" 2>&1 | head -5

# If output contains "You need to be signed in" → re-authenticate
ollama signin
# Then re-test
ollama run minimax-m2.7:cloud "say hello" 2>&1 | head -5
```

## Step 5: Clear the Stuck Session

```sh
TELEGRAM_USER_ID="8241121359"
SESSION_KEY="agent:main:telegram:direct:${TELEGRAM_USER_ID}"

# Remove the stuck session entry from the index
cat ~/.openclaw/agents/main/sessions/sessions.json | \
  jq "del(.\"${SESSION_KEY}\")" \
  > /tmp/sessions_fixed.json && mv /tmp/sessions_fixed.json ~/.openclaw/agents/main/sessions/sessions.json

# Verify it's gone
cat ~/.openclaw/agents/main/sessions/sessions.json | jq 'keys'
```

```sh
# Also remove the lock file if it exists (leave the .jsonl — history is preserved)
SESSION_ID=$(cat ~/.openclaw/agents/main/sessions/sessions.json | jq -r ".\"${SESSION_KEY}\".sessionId // empty")
rm -f ~/.openclaw/agents/main/sessions/${SESSION_ID}.jsonl.lock
```

**Do NOT delete the `.jsonl` file** — it contains conversation history. Only removing it from `sessions.json` is enough to break the compaction loop. A fresh session entry will be created on next message.

## Step 6: Restart Gateway

```sh
openclaw gateway restart 2>&1

# Wait a few seconds, then verify correct model loaded
sleep 5
openclaw logs 2>&1 | grep "agent model" | tail -3
```

Expected: `agent model: ollama/minimax-m2.7:cloud`

## Step 7: Summarize and Resend

Rather than resending the raw transcript (which risks hitting token limits again), summarize the conversation and send that as the opening message of the new session. This is what compaction was supposed to do.

**Extract the full conversation text for summarization:**

```sh
# Dump the conversation as readable text (user + assistant turns only, no tool noise)
jq -r 'select(.type=="message" and (.message.role=="user" or .message.role=="assistant")) |
  "[" + .message.role + "] " +
  (.message.content | if type=="array" then
    map(select(.type=="text") | .text) | join("")
  else . end)' /tmp/openclaw_session.jsonl > /tmp/openclaw_transcript.txt

wc -l /tmp/openclaw_transcript.txt
```

**Summarize it yourself** (you are an AI — read the transcript and produce a compact summary):

Read `/tmp/openclaw_transcript.txt` and write a summary covering:
- What tasks were completed or are in progress
- Any decisions made or context established
- The last thing the user asked that went unanswered (this should be resent verbatim)

**Send the summary as a context-reset message:**

```sh
openclaw message send \
  --channel telegram \
  --target 8241121359 \
  --message "[Session restored after compaction failure]

**Context summary:**
<your summary here>

**Last unanswered message:**
<verbatim last user message>"
```

This gives OpenClaw enough context to continue without re-loading the full history.

## Quick Reference: Session File Locations

| File | Purpose |
|------|---------|
| `~/.openclaw/agents/main/sessions/sessions.json` | Index mapping session keys to session IDs |
| `~/.openclaw/agents/main/sessions/<id>.jsonl` | Full conversation transcript |
| `~/.openclaw/agents/main/sessions/<id>.jsonl.lock` | Write lock — delete if gateway is stopped |

## Verification

```sh
# Sessions should show fresh entry with cloud model
openclaw sessions

# Logs should be quiet (no more compaction warnings)
openclaw logs 2>&1 | tail -10
```
