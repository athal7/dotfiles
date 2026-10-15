#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/runlayer-skill-overlay-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

HOME="$WORK/home"
BIN="$WORK/bin"
mkdir -p "$HOME/.runlayer" "$BIN"
: > "$HOME/.runlayer/config.yaml"

cat > "$BIN/gh" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$BIN/uvx" <<'EOF'
#!/bin/sh
mkdir -p "$HOME/.agents/skills/argocd-promotion"
printf '%s\n' 'Runlayer copy that must be overridden' > "$HOME/.agents/skills/argocd-promotion/SKILL.md"
EOF
chmod +x "$BIN/gh" "$BIN/uvx"

DATA="$WORK/local.yaml"
cp "$REPO_ROOT/local.yaml.example" "$DATA"
INSTALLER="$WORK/install-skills.sh"
chezmoi execute-template -S "$REPO_ROOT" \
  --override-data-file "$DATA" \
  --file "$REPO_ROOT/.chezmoiscripts/run_onchange_after_external-skills.sh.tmpl" \
  > "$INSTALLER"
PATH="$BIN:$PATH" HOME="$HOME" sh "$INSTALLER"

cmp "$REPO_ROOT/dot_agents/skills/argocd-promotion/SKILL.md" \
  "$HOME/.agents/skills/argocd-promotion/SKILL.md"
printf 'Runlayer skill overlay wins after Runlayer sync.\n'
