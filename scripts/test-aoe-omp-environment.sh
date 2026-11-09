#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home/.config/direnv/lib" "$WORK/home/.config/omp" "$WORK/home/.local/bin" "$WORK/bin"
ln -s "$(command -v jq)" "$WORK/bin/jq"
cp "$ROOT/dot_local/bin/executable_omp-personal-repo" "$WORK/home/.local/bin/omp-personal-repo"
printf '["personal-org"]\n' >"$WORK/home/.config/omp/personal-orgs.json"
cat >"$WORK/home/.config/direnv/lib/keychain.sh" <<'EOF'
keychain_env() {
  case "$2" in
    openrouter_api_key) [ "${MISSING_PERSONAL_KEY:-}" != 1 ] || return 1; export "$1=personal-test-key" ;;
    anthropic_api_key) export "$1=work-anthropic-key" ;;
    otari_api_key) export "$1=work-otari-key" ;;
    *) return 1 ;;
  esac
}
EOF
git init -q "$WORK/repo"
git -C "$WORK/repo" -c user.name=Test -c user.email=test@example.invalid -c core.hooksPath=/dev/null commit -q --allow-empty -m init
git -C "$WORK/repo" remote add origin https://github.com/personal-org/project.git
git -C "$WORK/repo" worktree add -q -b test "$WORK/tree"
hook="$ROOT/dot_local/bin/executable_aoe-omp-environment"
run_hook() { env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" AOE_TOOL=omp AOE_PROJECT_PATH="$1" "${@:2}" /bin/sh "$hook"; }
personal=$(run_hook "$WORK/tree")
[[ "$personal" == *'OPENROUTER_API_KEY=personal-test-key'* ]]
[[ "$personal" != *'ANTHROPIC_API_KEY='* && "$personal" != *'OTARI_API_KEY='* ]]
[[ "$personal" != *'PI_CONFIG_FILES='* ]]
[[ ! -e "$WORK/tree/.omp" ]]
primary=$(run_hook "$WORK/repo" PI_CONFIG_FILES=/existing.yml)
[[ "$primary" != *'PI_CONFIG_FILES='* ]]
[[ ! -e "$WORK/repo/.omp" ]]
missing=$(run_hook "$WORK/tree" MISSING_PERSONAL_KEY=1 OPENROUTER_API_KEY=inherited-key)
[[ "$missing" == *'OPENROUTER_API_KEY='* && "$missing" != *'OPENROUTER_API_KEY=inherited-key'* ]]
git -C "$WORK/repo" remote set-url origin https://github.com/work-org/project.git
work=$(run_hook "$WORK/tree")
[[ "$work" == *'ANTHROPIC_API_KEY=work-anthropic-key'* && "$work" == *'OTARI_API_KEY=work-otari-key'* ]]
[[ "$work" != *'OPENROUTER_API_KEY='* ]]
git -C "$WORK/repo" remote set-url origin https://github.com/personal-org/project.git
mkdir -p "$WORK/tree/.omp" "$WORK/tree/nested"
printf 'existing\n' >"$WORK/tree/.omp/config.yml"
nested=$(run_hook "$WORK/tree/nested")
[[ "$nested" != *'PI_CONFIG_FILES='* ]]
[[ "$(cat "$WORK/tree/.omp/config.yml")" == existing ]]
cat >"$WORK/bin/security" <<'EOF'
#!/bin/sh
printf 'personal-test-key\n'
EOF
cat >"$WORK/bin/omp" <<'EOF'
#!/bin/sh
printf 'overlay=%s\nkey=%s\narg=%s\n' "${PI_CONFIG_FILES:-}" "${OPENROUTER_API_KEY:-}" "$1"
EOF
chmod +x "$WORK/bin/security" "$WORK/bin/omp"
# shellcheck disable=SC2016 # Arguments are expanded by the invoked zsh.
shell=$(env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" \
  XDG_STATE_HOME="$WORK/state" XDG_CACHE_HOME="$WORK/cache" PI_CONFIG_FILES=/existing.yml \
  /bin/zsh -df -c 'source "$1"; builtin cd "$2"; omp hello' -- "$ROOT/dot_zshrc.tmpl" "$WORK/tree/nested" 2>/dev/null)
[[ "$shell" == *'overlay=/existing.yml'* ]]
[[ "$shell" == *'key=personal-test-key'* && "$shell" == *'arg=hello'* ]]
git -C "$WORK/repo" remote remove origin
if run_hook "$WORK/tree" >/dev/null 2>&1; then exit 1; fi
git -C "$WORK/repo" remote add origin https://github.com/personal-org/project.git
if run_hook "$WORK/does-not-exist" >/dev/null 2>&1; then exit 1; fi
printf '{invalid\n' >"$WORK/home/.config/omp/personal-orgs.json"
if run_hook "$WORK/tree" >/dev/null 2>&1; then exit 1; fi
rm "$WORK/home/.local/bin/omp-personal-repo"
if run_hook "$WORK/tree" >/dev/null 2>&1; then exit 1; fi
printf 'Checkout classification and credential separation pass.\n'
