#!/bin/sh
# Reconcile the running opencode-web server against the on-disk binary.
#
# opencode is a chezmoi-native github-release external, but the opencode-web
# LaunchAgent runs with KeepAlive, so it keeps the OLD in-memory binary alive
# after an upgrade — the launch-agents generator only reloads agents whose plist
# CONTENT changed, and a binary bump doesn't touch the plist. The running server
# then drifts from disk (e.g. "SQLiteError: no such column: replacement_seq").
#
# This is a plain run_after script (no run_once/run_onchange suffix) so it runs
# on EVERY apply and always reconciles. It is deliberately defensive: every
# external call is guarded and it never fails the apply (exit 0 throughout).

set -u

# PID listening on :4096 — if nothing is listening, there's nothing to reconcile.
PID=$(lsof -nP -iTCP:4096 -sTCP:LISTEN -t 2>/dev/null | head -1)
[ -n "${PID:-}" ] || exit 0

BIN="$HOME/.local/bin/opencode"
[ -e "$BIN" ] || exit 0

# On-disk binary mtime (epoch). macOS stat.
BIN_MTIME=$(stat -f %m "$BIN" 2>/dev/null) || exit 0
[ -n "${BIN_MTIME:-}" ] || exit 0

# Process start time -> epoch. `ps -o lstart=` gives e.g. "Thu Jun 25 09:00:00 2026";
# parse it with macOS `date -j -f`. If parsing fails, skip rather than restart blindly.
LSTART=$(ps -o lstart= -p "$PID" 2>/dev/null) || exit 0
[ -n "${LSTART:-}" ] || exit 0
PROC_EPOCH=$(date -j -f "%a %b %e %T %Y" "$LSTART" +%s 2>/dev/null) || exit 0
[ -n "${PROC_EPOCH:-}" ] || exit 0

# Binary newer than the running server => stale; kickstart the LaunchAgent.
if [ "$BIN_MTIME" -gt "$PROC_EPOCH" ]; then
  LABEL="com.$(id -un).opencode-web"
  echo "opencode-web: on-disk binary newer than running server (pid $PID); restarting $LABEL"
  launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>/dev/null || \
    echo "opencode-web: kickstart failed (non-fatal)"
else
  echo "opencode-web: running server is up to date (pid $PID); no restart needed"
fi

exit 0
