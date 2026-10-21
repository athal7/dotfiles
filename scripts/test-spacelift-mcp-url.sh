#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/spacelift-mcp-url.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT INT TERM
mkdir -p "$tmpdir/bin"

cat >"$tmpdir/bin/spacectl" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "profile current") printf '%s\n' "${TEST_PROFILE:-active}" ;;
  "profile list")
    printf '%s\n' \
      'Current | Alias   | Endpoint                              | Type' \
      '--------|---------|---------------------------------------|----------' \
      '        | standby | https://standby.app.spacelift.io      | API Token' \
      '*       | active  | https://active.app.us.spacelift.io   | API Token'
    ;;
esac
STUB
chmod +x "$tmpdir/bin/spacectl"

actual=$(PATH="$tmpdir/bin:/usr/bin:/bin" "$REPO_ROOT/dot_local/bin/executable_spacelift-mcp-url")
[[ $actual == https://active.app.us.spacelift.io/mcp ]]

if TEST_PROFILE=missing PATH="$tmpdir/bin:/usr/bin:/bin" "$REPO_ROOT/dot_local/bin/executable_spacelift-mcp-url" >/dev/null 2>&1; then
  printf 'spacelift-mcp-url unexpectedly accepted a missing current profile\n' >&2
  exit 1
fi

printf 'Spacelift endpoint lookup selects the current profile and fails closed when missing.\n'
