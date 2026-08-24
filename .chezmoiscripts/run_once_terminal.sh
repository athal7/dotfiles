#!/bin/bash
# Terminal.app profile fixes, applied once via chezmoi's run_once_ semantics.
#
# 1. "Use Option as Meta Key": Alt/Option key combos (e.g. Alt+l) are sent as
#    Meta/Escape sequences to TUI apps like aoe running in tmux, instead of
#    being consumed for special chars. Implemented via PlistBuddy directly
#    against com.apple.Terminal.plist, since it's a plain preference bit and
#    doesn't require Terminal.app to be running.
#
# 2. Nerd Font enforced. Starship's prompt icons and nvim-web-devicons'
#    file-tree glyphs both render through Terminal's own font and need a
#    Nerd Font glyph set to display correctly — neither dependent is
#    Neovim-side config, both are downstream of whatever font Terminal
#    itself uses. If a profile's font isn't a Monaspace variant, it's set to
#    the default MonaspaceNeonNF-Regular; if it's already a plain
#    (unpatched) Monaspace variant (e.g. MonaspaceNeon-Regular), it's
#    upgraded in place to the matching NF-patched style. Non-destructive:
#    already-NF fonts are left untouched. Implemented via osascript for the
#    same reason as point 3 below.
#
# 3. Background color pinned to pure black (#000000). Terminal.app has a
#    rendering floor on unpainted/fallback screen cells (scrollbar gutters,
#    layout rounding at pane edges) that blends toward a lighter shade no
#    matter the configured background color — the floor renders around
#    RGB(20,20,20) regardless. Pure black minimizes that floor's absolute
#    lightness compared to any lighter configured background, which matters
#    for full-screen TUI apps such as aoe and omp painting up to those edges.
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

set_nerd_font() {
  local profile="$1"

  if [ "$can_set_background" != true ]; then
    return 0
  fi

  local font
  font="$(osascript -e "tell application \"Terminal\" to get font name of settings set \"$profile\"" 2>/dev/null)" || {
    echo "terminal-nerd-font: WARN: osascript failed to read Terminal.app profile '$profile' font" >&2
    return 0
  }

  # Leave already-NF-patched fonts untouched.
  if [[ "$font" == *NF* ]]; then
    return 0
  fi

  local new_font
  if [[ "$font" =~ ^Monaspace([A-Za-z]+)-(.+)$ ]]; then
    # Plain (unpatched) Monaspace variant — upgrade in place to the
    # matching NF-patched style.
    new_font="Monaspace${BASH_REMATCH[1]}NF-${BASH_REMATCH[2]}"
  else
    # Non-Monaspace font (macOS default Menlo, or an unrelated font like
    # AndaleMono, Monaco, Courier, ...) — fall back to the default Nerd
    # Font so glyph-dependent tooling (Starship, nvim-web-devicons, tmux
    # powerline) still renders.
    new_font="MonaspaceNeonNF-Regular"
  fi

  if osascript -e "tell application \"Terminal\" to set font name of settings set \"$profile\" to \"$new_font\"" >/dev/null 2>&1; then
    echo "terminal-nerd-font: set Terminal.app profile '$profile' font to '$new_font'"
  else
    echo "terminal-nerd-font: WARN: osascript failed to set Terminal.app profile '$profile' font to '$new_font'" >&2
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
  set_nerd_font "$profile"
done <<< "$profiles"
