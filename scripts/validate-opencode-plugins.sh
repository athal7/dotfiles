#!/usr/bin/env bash
# Guard against blocking calls in opencode plugins.
#
# opencode plugins run inside the server's single-threaded event loop. Any
# synchronous `*Sync(` call site (execFileSync/execSync/spawnSync/readFileSync/
# any *Sync()) freezes the loop and deadlocks the server. Shelling out to
# `opencode-cmd` re-enters the same server and deadlocks the same way. The async
# `child_process` *imports* themselves are allowed — only the synchronous call
# sites are forbidden. Plugins must be fully async and use the injected SDK
# `client`.
#
# Comment lines are stripped before scanning so files may *document* the
# forbidden patterns (e.g. a plugin may explain what to avoid) without
# tripping this guard. Pre-commit passes the matched files as arguments.

set -euo pipefail

# Synchronous `*Sync(` call sites and re-entrant CLI shell-outs. The bare
# `child_process` import name is intentionally NOT matched — async usage is fine.
forbidden='([A-Za-z]+Sync\(|opencode-cmd)'

# Comment lines: line `//`, block `/*` opener, and ` * ` body lines.
comment='^[[:space:]]*(\*|//|/\*)'

errors=0

for file in "$@"; do
  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))

    # Skip comment lines so documented forbidden patterns don't false-positive.
    if printf '%s\n' "$line" | grep -qE "$comment"; then
      continue
    fi

    if printf '%s\n' "$line" | grep -qE "$forbidden"; then
      echo "PLUGIN ERROR: $file:$lineno — blocking/child_process call not allowed" >&2
      echo "    $line" >&2
      echo "    opencode plugins run on the server event loop — use the async SDK \`client\`, never blocking/child_process calls" >&2
      errors=$((errors + 1))
    fi
  done < "$file"
done

if [ "$errors" -gt 0 ]; then
  echo "$errors blocking-call violation(s) found in opencode plugins" >&2
  exit 1
fi
