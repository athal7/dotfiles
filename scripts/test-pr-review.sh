#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/pr-review.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
mkdir -p "$HOME/.local/bin" "$WORK/bin"
cp "$ROOT/dot_local/bin/executable_pr-review" "$HOME/.local/bin/pr-review"
chmod +x "$HOME/.local/bin/pr-review"
export PATH="$WORK/bin:$PATH"
PR_REVIEW="$HOME/.local/bin/pr-review"

# Stub gh: records argv, answers GraphQL isResolved and dismissals state.
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$GH_CALLS"
[ "${GH_FAIL:-}" != 1 ] || exit 1
case "$*" in
  'api graphql'*)
    q=""
    for arg in "$@"; do
      case $arg in
        *'{unresolveReviewThread'*) q=unresolve ;;
        *'{resolveReviewThread'*) q=resolve ;;
      esac
    done
    [ -n "$q" ] || exit 3
    [ "$q" = "$QUERY_KIND" ] || exit 4
    printf '%s\n' "${GRAPHQL_RESULT:-true}"
    ;;
  'api --method PUT'*'/dismissals --input -'*)
    [ "${DISMISS_STATE:-DISMISSED}" = DISMISSED ] && printf 'DISMISSED\n' || printf '%s\n' "$DISMISS_STATE"
    ;;
  *) exit 3 ;;
esac
EOF
chmod +x "$WORK/bin/gh"
export GH_CALLS="$WORK/calls"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# resolve / unresolve: correct mutation, correct payload, verified result.
rm -f "$GH_CALLS"; export QUERY_KIND=resolve GRAPHQL_RESULT=true
out=$($PR_REVIEW resolve PRRT_kwDOA1b2c3) || fail "resolve exited nonzero"
[ "$out" = "resolve PRRT_kwDOA1b2c3" ] || fail "resolve output: $out"
body=$(tr '\n' ' ' < "$GH_CALLS")
case $body in *"query=mutation(\$id:ID!){resolveReviewThread"*) ;; *) fail "resolve query: $body" ;; esac
case $body in *"id=PRRT_kwDOA1b2c3"*) ;; *) fail "resolve thread arg: $body" ;; esac

rm -f "$GH_CALLS"; export QUERY_KIND=unresolve GRAPHQL_RESULT=false
out=$($PR_REVIEW unresolve PRRT_kwDOA1b2c3) || fail "unresolve exited nonzero"
[ "$out" = "unresolve PRRT_kwDOA1b2c3" ] || fail "unresolve output: $out"
body=$(tr '\n' ' ' < "$GH_CALLS")
case $body in *"query=mutation(\$id:ID!){unresolveReviewThread"*) ;; *) fail "unresolve query: $body" ;; esac

# A mismatch between the requested state and GitHub's answer is a failure.
export QUERY_KIND=resolve GRAPHQL_RESULT=false
if $PR_REVIEW resolve PRRT_ok >/dev/null 2>&1; then fail 'accepted isResolved=false for resolve'; fi
export QUERY_KIND=unresolve GRAPHQL_RESULT=true
if $PR_REVIEW unresolve PRRT_ok >/dev/null 2>&1; then fail 'accepted isResolved=true for unresolve'; fi
export GRAPHQL_RESULT=true
if GH_FAIL=1 $PR_REVIEW resolve PRRT_ok >/dev/null 2>&1; then fail 'accepted gh failure on resolve'; fi

# dismiss: JSON body on stdin, DISMISSED verified.
rm -f "$GH_CALLS"
out=$($PR_REVIEW dismiss 42 12345 'addressed at head') || fail "dismiss exited nonzero"
[ "$out" = 'dismissed 12345' ] || fail "dismiss output: $out"
body=$(tr '\n' ' ' < "$GH_CALLS")
case $body in *'pulls/42/reviews/12345/dismissals'*) ;; *) fail "dismiss path: $body" ;; esac
case $body in *'--input -'*) ;; *) fail "dismiss stdin: $body" ;; esac
export DISMISS_STATE=APPROVED
if $PR_REVIEW dismiss 42 12345 'msg' >/dev/null 2>&1; then fail 'accepted undismissed state'; fi
export DISMISS_STATE=DISMISSED
if GH_FAIL=1 $PR_REVIEW dismiss 42 12345 'msg' >/dev/null 2>&1; then fail 'accepted gh failure on dismiss'; fi

# Rejected inputs never reach gh.
rm -f "$GH_CALLS"
reject() { if "$@" >/dev/null 2>&1; then fail "accepted: $*"; fi; }
reject "$PR_REVIEW"
reject "$PR_REVIEW" resolve
reject "$PR_REVIEW" resolve ''
reject "$PR_REVIEW" resolve --force
reject "$PR_REVIEW" resolve 'PRRT_ok; rm -rf /'
reject "$PR_REVIEW" resolve PRRT_ok extra
reject "$PR_REVIEW" unresolve 'PRRT_a b'
reject "$PR_REVIEW" dismiss
reject "$PR_REVIEW" dismiss 42 12345
reject "$PR_REVIEW" dismiss 42 12345 '   '
reject "$PR_REVIEW" dismiss abc 12345 'msg'
reject "$PR_REVIEW" dismiss 42 12x45 'msg'
reject "$PR_REVIEW" dismiss -42 12345 'msg'
reject "$PR_REVIEW" bogus x
[ ! -s "$GH_CALLS" ] || fail "rejected input reached gh: $(tr '\n' ' ' < "$GH_CALLS")"

# Usage errors exit 2.
rc=0; $PR_REVIEW >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "usage exit code: $rc"

# Message content survives JSON encoding, including quotes and newlines.
rm -f "$GH_CALLS"
$PR_REVIEW dismiss 42 12345 $'say "hi"\nsecond line' >/dev/null || fail 'quoted message rejected'
printf 'pr-review scenarios passed\n'
