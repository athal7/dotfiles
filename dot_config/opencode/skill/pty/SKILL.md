---
name: pty
description: Working with PTY sessions for background and interactive processes
---

## When to Use PTY

Use `pty_spawn` instead of `bash` when:
- The process runs in the background or long-running (dev servers, watchers, etc.)
- The command requires interactive input
- You need to send signals (Ctrl+C, Ctrl+D) mid-run
- You want to tail output while the process is still running

## Key Sequences

| Action | Data |
|--------|------|
| Ctrl+C (interrupt) | `\x03` |
| Ctrl+D (EOF) | `\x04` |
| Ctrl+Z (suspend) | `\x1a` |
| Enter | `\n` |

Send with `pty_write`: `data="\x03"`

## Reading Output

Use the `pattern` parameter in `pty_read` to filter lines by regex:

```
pattern="error|ERROR"       # find errors
pattern="ERROR|WARN|FATAL"  # find warnings and errors
pattern="failed.*connection" # more specific match
```

`pattern` filters first, then `offset`/`limit` apply to the matches — original line numbers are preserved.

## Checking Status

- `pty_list` — see all running/exited sessions
- `pty_read` with high `offset` or omit offset to see latest output
- To tail last N lines: `offset = totalLines - N`

## Cleanup

- `pty_kill` with `cleanup=false` (default) — stops process, keeps buffer for reading
- `pty_kill` with `cleanup=true` — stops process and frees buffer entirely

## notifyOnExit

Set `notifyOnExit=true` to receive a message when the process exits, including exit code and last output line. Useful for build processes where you want to be notified on completion rather than polling.
