#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home" "$WORK/bin"
cat >"$WORK/bin/security" <<'EOF'
#!/bin/sh
printf 'lookup\n' >> "$LOOKUPS"
[ "${MISSING_KEY:-}" != 1 ] || exit 1
printf '%s' "${KEYCHAIN_KEY-keychain-test-key}"
EOF
cat >"$WORK/bin/aoe" <<'EOF'
#!/bin/sh
printf '%s|%s\n' "${LINEAR_API_KEY-unset}" "${LINEAR_TOKEN-unset}" > "$PROBE"
exit 7
EOF
cp "$ROOT/dot_local/bin/executable_linear-api-key" "$WORK/bin/linear-api-key"
chmod +x "$WORK/bin/security" "$WORK/bin/aoe" "$WORK/bin/linear-api-key"
run_shell() {
  # shellcheck disable=SC2016 # The invoked zsh expands these expressions.
  env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" \
    XDG_STATE_HOME="$WORK/state" XDG_CACHE_HOME="$WORK/cache" \
    LOOKUPS="$WORK/lookups" PROBE="$WORK/probe" "$@" \
    /bin/zsh -df -c '
      source "$1" 2>/dev/null
      aoe --version
      result=$?
      print -r -- "${LINEAR_API_KEY-unset}|${LINEAR_TOKEN-unset}|$result"
    ' -- "$ROOT/dot_zshrc.tmpl"
}
# A shell-started daemon gets the key; the parent shell and unrelated children do not.
[[ "$(run_shell)" == 'unset|unset|7' ]]
[[ "$(cat "$WORK/probe")" == 'keychain-test-key|unset' ]]
rm "$WORK/lookups"
# Explicit credentials win without touching Keychain, including the token alias.
[[ "$(run_shell LINEAR_API_KEY=explicit-key)" == 'explicit-key|unset|7' ]]
[[ "$(cat "$WORK/probe")" == 'explicit-key|unset' ]]
[[ ! -e "$WORK/lookups" ]]
[[ "$(run_shell LINEAR_TOKEN=explicit-token)" == 'unset|explicit-token|7' ]]
[[ "$(cat "$WORK/probe")" == 'unset|explicit-token' ]]
[[ ! -e "$WORK/lookups" ]]
# Missing or empty credentials must not prevent non-Linear AoE use.
[[ "$(run_shell MISSING_KEY=1)" == 'unset|unset|7' ]]
[[ "$(cat "$WORK/probe")" == 'unset|unset' ]]
[[ "$(run_shell KEYCHAIN_KEY=)" == 'unset|unset|7' ]]
[[ "$(cat "$WORK/probe")" == 'unset|unset' ]]
# A 0600 key file supplies the key when Keychain cannot be read, as over SSH,
# and an exported key still wins over it.
mkdir -p "$WORK/home/.config/linear"
printf 'file-test-key\n' >"$WORK/home/.config/linear/api_key"
chmod 600 "$WORK/home/.config/linear/api_key"
rm -f "$WORK/lookups"
[[ "$(run_shell MISSING_KEY=1)" == 'unset|unset|7' ]]
[[ "$(cat "$WORK/probe")" == 'file-test-key|unset' ]]
[[ ! -e "$WORK/lookups" ]]
[[ "$(run_shell LINEAR_API_KEY=explicit-key)" == 'explicit-key|unset|7' ]]
[[ "$(cat "$WORK/probe")" == 'explicit-key|unset' ]]
# An empty key file falls back to Keychain rather than sending a blank credential.
printf '\n' >"$WORK/home/.config/linear/api_key"
[[ "$(run_shell)" == 'unset|unset|7' ]]
[[ "$(cat "$WORK/probe")" == 'keychain-test-key|unset' ]]
printf 'AoE credential precedence, command scope, key-file fallback, and missing-key behavior pass.\n'
