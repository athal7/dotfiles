#!/bin/bash
ZSH_PATH="$(which zsh)"

# Skip if zsh is already the default shell
if [ "$SHELL" = "$ZSH_PATH" ]; then
  exit 0
fi

# Add zsh to /etc/shells if not already there
if ! grep -qF "$ZSH_PATH" /etc/shells; then
  echo "$ZSH_PATH" | sudo tee -a /etc/shells
fi

# Change default shell — uses dscl on macOS to avoid chsh password prompt
if command -v dscl >/dev/null 2>&1; then
  sudo dscl . -create "/Users/$(whoami)" UserShell "$ZSH_PATH"
else
  chsh -s "$ZSH_PATH" "$(whoami)"
fi
