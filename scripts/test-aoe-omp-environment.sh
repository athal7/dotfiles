#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home/.config/direnv/lib" "$WORK/bin"
cat >"$WORK/home/.config/direnv/lib/keychain.sh" <<'EOF'
keychain_env() {
  case "$2" in
    anthropic_api_key) export "$1=work-anthropic-key" ;;
    otari_api_key) export "$1=work-otari-key" ;;
    *) return 1 ;;
  esac
}
EOF
git init -q "$WORK/repo"
git -C "$WORK/repo" -c user.name=Test -c user.email=test@example.invalid -c core.hooksPath=/dev/null commit -q --allow-empty -m init
git -C "$WORK/repo" remote add origin https://github.com/work-org/project.git
git -C "$WORK/repo" worktree add -q -b test "$WORK/tree"
hook="$ROOT/dot_local/bin/executable_aoe-omp-environment"
run_hook() { env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" AOE_TOOL=omp AOE_PROJECT_PATH="$1" "${@:2}" /bin/sh "$hook"; }
work=$(run_hook "$WORK/tree")
[[ "$work" == *'ANTHROPIC_API_KEY=work-anthropic-key'* && "$work" == *'OTARI_API_KEY=work-otari-key'* ]]
[[ "$work" != *'OPENROUTER_API_KEY='* ]]
primary=$(run_hook "$WORK/repo" PI_CONFIG_FILES=/existing.yml)
[[ "$primary" != *'PI_CONFIG_FILES='* ]]
[[ ! -e "$WORK/repo/.omp" ]]
mkdir -p "$WORK/tree/.omp" "$WORK/tree/nested"
printf 'existing\n' >"$WORK/tree/.omp/config.yml"
nested=$(run_hook "$WORK/tree/nested")
[[ "$nested" != *'PI_CONFIG_FILES='* ]]
[[ "$(cat "$WORK/tree/.omp/config.yml")" == existing ]]
cat >"$WORK/bin/omp" <<'EOF'
#!/bin/sh
printf 'overlay=%s\nkey=%s\narg=%s\n' "${PI_CONFIG_FILES:-}" "${OPENROUTER_API_KEY:-}" "$1"
EOF
chmod +x "$WORK/bin/omp"
# shellcheck disable=SC2016 # Arguments are expanded by the invoked zsh.
shell=$(env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" \
  XDG_STATE_HOME="$WORK/state" XDG_CACHE_HOME="$WORK/cache" PI_CONFIG_FILES=/existing.yml \
  /bin/zsh -df -c 'source "$1"; builtin cd "$2"; omp hello' -- "$ROOT/dot_zshrc.tmpl" "$WORK/tree/nested" 2>/dev/null)
[[ "$shell" == *'overlay=/existing.yml'* ]]
[[ "$shell" == *'arg=hello'* ]]
printf 'Credential separation and path independence pass.\n'
