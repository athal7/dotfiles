#!/bin/bash
# Bootstrap the LM Studio `lms` CLI into ~/.lmstudio/bin so it is reachable on
# PATH (the PATH entry is added in dot_zshenv.tmpl). Idempotent, and a safe
# no-op on machines where LM Studio is not installed.
#
# Named "zz-" so it sorts after run_onchange_after_packages (which installs the
# lm-studio cask): chezmoi runs after_ scripts alphabetically by stripped target
# name, and the cask must exist before bootstrap can run on a fresh machine.
set -euo pipefail

# Already bootstrapped — nothing to do.
if [ -x "$HOME/.lmstudio/bin/lms" ]; then
  exit 0
fi

# The lms binary shipped inside the LM Studio app bundle.
BUNDLE_LMS="/Applications/LM Studio.app/Contents/Resources/app/.webpack/lms"

# LM Studio not installed yet — nothing to bootstrap.
if [ ! -x "$BUNDLE_LMS" ]; then
  exit 0
fi

"$BUNDLE_LMS" bootstrap
