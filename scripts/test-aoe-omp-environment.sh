#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home/.config/direnv/lib" "$WORK/bin" "$WORK/tree/.omp" "$WORK/tree/nested"
cat >"$WORK/home/.config/direnv/lib/keychain.sh" <<'EOF'
keychain_env() {
  case "$2" in
    anthropic_api_key) [ "${MISSING_ANTHROPIC_KEY:-}" != 1 ] || return 1; export "$1=work-anthropic-key" ;;
    otari_api_key) export "$1=work-otari-key" ;;
    openrouter_api_key) printf 'openrouter\n' >>"$KEYCHAIN_LOG"; export "$1=personal-test-key" ;;
    *) return 1 ;;
  esac
}
EOF
printf 'existing\n' >"$WORK/tree/.omp/config.yml"
hook="$ROOT/dot_local/bin/executable_aoe-omp-environment"
run_hook() {
  env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" AOE_TOOL="${AOE_TOOL:-omp}" \
    AOE_PROJECT_PATH="$1" KEYCHAIN_LOG="$WORK/keychain.log" "${@:2}" /bin/sh "$hook"
}
work=$(run_hook "$WORK/tree")
[[ "$work" == *'ANTHROPIC_API_KEY=work-anthropic-key'* && "$work" == *'OTARI_API_KEY=work-otari-key'* ]]
[[ "$work" != *'OPENROUTER_API_KEY='* && "$work" != *'PI_CONFIG_FILES='* ]]
[[ ! -e "$WORK/keychain.log" ]]
[[ "$(cat "$WORK/tree/.omp/config.yml")" == existing ]]
nested=$(run_hook "$WORK/tree/nested" PI_CONFIG_FILES=/existing.yml)
[[ "$nested" == *'ANTHROPIC_API_KEY=work-anthropic-key'* ]]
[[ "$nested" != *'PI_CONFIG_FILES='* ]]
[[ ! -e "$WORK/keychain.log" ]]
missing=$(run_hook "$WORK/tree" MISSING_ANTHROPIC_KEY=1 OPENROUTER_API_KEY=inherited-key)
[[ "$missing" != *'ANTHROPIC_API_KEY='* && "$missing" == *'OTARI_API_KEY=work-otari-key'* ]]
[[ "$missing" != *'OPENROUTER_API_KEY='* && ! -e "$WORK/keychain.log" ]]
non_repo=$(run_hook "$WORK/does-not-exist")
[[ "$non_repo" == *'ANTHROPIC_API_KEY=work-anthropic-key'* ]]
freebuff=$(AOE_TOOL=freebuff run_hook "$WORK/tree")
[[ -z "$freebuff" && ! -e "$WORK/keychain.log" ]]
cat >"$WORK/bin/security" <<'EOF'
#!/bin/sh
printf 'security-called\n' >>"$SECURITY_LOG"
EOF
cat >"$WORK/bin/omp" <<'EOF'
#!/bin/sh
printf 'overlay=%s\nkey=%s\narg=%s\n' "${PI_CONFIG_FILES:-}" "${OPENROUTER_API_KEY-unset}" "$1"
EOF
chmod +x "$WORK/bin/security" "$WORK/bin/omp"
# shellcheck disable=SC2016 # Arguments are expanded by the invoked zsh.
shell=$(env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" \
  XDG_STATE_HOME="$WORK/state" XDG_CACHE_HOME="$WORK/cache" PI_CONFIG_FILES=/existing.yml \
  SECURITY_LOG="$WORK/security.log" \
  /bin/zsh -df -c 'source "$1"; builtin cd "$2"; omp hello' -- "$ROOT/dot_zshrc.tmpl" "$WORK/tree/nested" 2>/dev/null)
[[ "$shell" == *'overlay=/existing.yml'* ]]
[[ "$shell" == *'key=unset'* && "$shell" == *'arg=hello'* ]]
[[ ! -e "$WORK/security.log" ]]
printf 'OMP credential isolation and path independence pass.\n'
