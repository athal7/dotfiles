#!/bin/bash
# Terminal.app profile fixes, applied once via chezmoi's run_once_ semantics.
#
# 1. "Use Option as Meta Key": Alt/Option key combos (e.g. Alt+l) are sent as
#    Meta/Escape sequences to TUI apps like aoe running in tmux, instead of
#    being consumed for special chars. Implemented via PlistBuddy directly
#    against com.apple.Terminal.plist, since it's a plain preference bit and
#    doesn't require Terminal.app to be running.
#
# 2. Background color pinned to pure black (#000000). Terminal.app has a
#    rendering floor on unpainted/fallback screen cells (scrollbar gutters,
#    layout rounding at pane edges) that blends toward a lighter shade no
#    matter the configured background color — the floor renders around
#    RGB(20,20,20) regardless. Pure black minimizes that floor's absolute
#    lightness compared to any lighter configured background, which matters
#    for full-screen TUI apps like aoe/opencode painting up to those edges.
#    This is deliberately a fixed constant rather than tracking aoe's active
#    theme color — dynamic theme-tracking was tried and abandoned, since the
#    floor-vs-theme mismatch was still visible and kept shifting with every
#    theme change. Implemented via osascript against Terminal.app's own
#    settings API rather than a raw plist edit, since com.apple.Terminal.plist
#    is cfprefsd-managed and a direct write risks being silently clobbered;
#    this requires Terminal.app to actually be running.
set -euo pipefail

PLIST="$HOME/Library/Preferences/com.apple.Terminal.plist"

# Nothing to configure if Terminal has never been run (no prefs written yet).
if [ ! -f "$PLIST" ]; then
  exit 0
fi

set_meta_key() {
  local profile="$1"
  local key=":\"Window Settings\":\"${profile}\":useOptionAsMetaKey"

  # Set first (key may already exist); Add if it doesn't. Idempotent either way.
  /usr/libexec/PlistBuddy -c "Set $key true" "$PLIST" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Add $key bool true" "$PLIST" >/dev/null 2>&1
}

set_background_black() {
  local profile="$1"

  if [ "$can_set_background" != true ]; then
    return 0
  fi

  if osascript -e "tell application \"Terminal\" to set background color of settings set \"$profile\" to {0, 0, 0}" >/dev/null 2>&1; then
    echo "terminal-bg-black: set Terminal.app profile '$profile' background to #000000"
  else
    echo "terminal-bg-black: WARN: osascript failed to set Terminal.app profile '$profile' background" >&2
  fi
}

# `tell application "Terminal"` auto-launches Terminal.app via Apple Events if
# it isn't already running — an unwanted side effect during a possibly
# headless/background chezmoi apply. Only attempt the background-color fix
# when Terminal is already running and osascript is available; the meta-key
# fix above needs neither, since it's a direct plist edit.
can_set_background=true
if ! command -v osascript >/dev/null 2>&1; then
  can_set_background=false
elif ! pgrep -x Terminal >/dev/null 2>&1; then
  can_set_background=false
fi

# Default and Startup window settings can point at different profiles, and
# neither is reliably "Basic" — operate on whatever the user actually has active.
profiles="$(
  {
    defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null
    defaults read com.apple.Terminal "Startup Window Settings" 2>/dev/null
  } | sort -u
)"

while IFS= read -r profile; do
  [ -n "$profile" ] || continue
  set_meta_key "$profile"
  set_background_black "$profile"
done <<< "$profiles"
