#!/usr/bin/env bash
# Regression tests for attention-list's reminder field-name handling. Plain
# bash, no bats. Stubs chezmoi/remindctl/ical/gh/security so the script runs
# against fixed fixture data instead of live system state.
#
# Covers the bug where fetch_reminders()/get_list() read the reminder JSON
# keys as `list`/`completed`/`due_date` instead of the actual remindctl
# schema (`listName`/`isCompleted`/`dueDate`), which silently dropped every
# reminder from the output.
#
#   scripts/test-attention-list.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ATTENTION_LIST="$REPO_ROOT/dot_local/bin/executable_attention-list.tmpl"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/attention-list-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0; fail=0
ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (want '$3' got '$2')"; fi; }

STUB_BIN="$WORK/bin"
mkdir -p "$STUB_BIN"

# Isolated HOME without ~/.local/bin/ical so get_ical_path() falls back to
# PATH-based `which ical` resolution (each scenario's stubbed `ical`) rather
# than picking up the real machine's chezmoi-managed binary, whose presence
# or absence shouldn't affect these tests.
TEST_HOME="$WORK/home"
mkdir -p "$TEST_HOME"

# `chezmoi data --format json`: reminder lists configured for attention_check,
# matching production shape. Empty `calendars` since this test focuses on the
# reminders regression.
cat > "$STUB_BIN/chezmoi" <<'STUB'
#!/bin/sh
if [ "$1" = "data" ]; then
  cat <<'JSON'
{
  "reminders": {
    "personal": {"attention_check": true, "name": "Personal"},
    "work": {"attention_check": true, "name": "Work"}
  },
  "calendars": {}
}
JSON
  exit 0
fi
echo "fake chezmoi: unexpected invocation: $*" >&2
exit 99
STUB
chmod +x "$STUB_BIN/chezmoi"

# Portable "clearly yesterday" ISO date (matches the yyyy-mm-dd prefix the
# script parses via date.fromisoformat(due[:10])).
YESTERDAY="$(date -v-1d +%F 2>/dev/null || date -d yesterday +%F)"

# `remindctl show all --json`: fixed fixture covering the four regression
# cases. Real schema uses listName/isCompleted/dueDate (not
# list/completed/due_date) — this is exactly what the bug fix corrects.
cat > "$STUB_BIN/remindctl" <<STUB
#!/bin/sh
if [ "\$1" = "show" ] && [ "\$2" = "all" ]; then
  cat <<JSON
[
  {"id": "r1", "title": "REGRESSION-open-personal", "listName": "Personal", "isCompleted": false, "priority": "none"},
  {"id": "r2", "title": "REGRESSION-completed-work", "listName": "Work", "isCompleted": true, "priority": "none"},
  {"id": "r3", "title": "REGRESSION-open-shopping", "listName": "Shopping", "isCompleted": false, "priority": "none"},
  {"id": "r4", "title": "REGRESSION-overdue-work", "listName": "Work", "isCompleted": false, "priority": "none", "dueDate": "${YESTERDAY}"}
]
JSON
  exit 0
fi
echo "fake remindctl: unexpected invocation: \$*" >&2
exit 99
STUB
chmod +x "$STUB_BIN/remindctl"

# `ical`: no calendars configured so fetch_calendar() short-circuits before
# ever calling this, but stub harmlessly just in case.
cat > "$STUB_BIN/ical" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$STUB_BIN/ical"

# `gh`: empty PR/issue lists so fetch_github() contributes nothing.
cat > "$STUB_BIN/gh" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$STUB_BIN/gh"

# `security`: fail so get_linear_token() falls through to the env lookup,
# which is also unset here, so fetch_linear() short-circuits to [].
cat > "$STUB_BIN/security" <<'STUB'
#!/bin/sh
exit 1
STUB
chmod +x "$STUB_BIN/security"

# ---------------------------------------------------------------------------
echo "== reminder field-name regression =="

test_reminders() {
  local out
  out="$(HOME="$TEST_HOME" PATH="$STUB_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST")"

  if grep -q 'REGRESSION-open-personal' <<<"$out"; then
    ok "open reminder in configured list (Personal) appears"
  else
    bad "open reminder in configured list (Personal) appears (got: $out)"
  fi

  if grep -q 'REGRESSION-completed-work' <<<"$out"; then
    bad "completed reminder must not appear"
  else
    ok "completed reminder does not appear"
  fi

  if grep -q 'REGRESSION-open-shopping' <<<"$out"; then
    bad "reminder in unconfigured list must not appear"
  else
    ok "reminder in unconfigured list does not appear"
  fi

  if grep -q 'REGRESSION-overdue-work' <<<"$out"; then
    ok "overdue open reminder in configured list (Work) appears"
  else
    bad "overdue open reminder in configured list (Work) appears (got: $out)"
  fi

  local overdue_line
  overdue_line="$(grep 'REGRESSION-overdue-work' <<<"$out" || true)"
  case "$overdue_line" in
    *"(95)"*) ok "overdue reminder weighted 95 (overdue logic engaged)" ;;
    *) bad "overdue reminder weighted 95 (got: $overdue_line)" ;;
  esac
}
test_reminders

# ---------------------------------------------------------------------------
# Covers the config-contract bug where fetch_calendar() collected every
# calendar with a `name` key regardless of `attention_check`, unlike
# fetch_reminders() which already filtered correctly. Two calendars are
# configured, only one flagged `attention_check: true`; ical is stubbed to
# return a distinct event per calendar so a leak is visible in the output.
echo
echo "== calendar attention_check regression =="

CAL_BIN="$WORK/bin-cal-check"
mkdir -p "$CAL_BIN"

cat > "$CAL_BIN/chezmoi" <<'STUB'
#!/bin/sh
if [ "$1" = "data" ]; then
  cat <<'JSON'
{
  "calendars": {
    "work": {"attention_check": true, "name": "Work"},
    "family": {"attention_check": false, "name": "Family"}
  },
  "reminders": {}
}
JSON
  exit 0
fi
echo "fake chezmoi: unexpected invocation: $*" >&2
exit 99
STUB
chmod +x "$CAL_BIN/chezmoi"

cat > "$CAL_BIN/ical" <<'STUB'
#!/bin/sh
cal=""
prev=""
for a in "$@"; do
  if [ "$prev" = "-c" ]; then cal="$a"; fi
  prev="$a"
done
case "$cal" in
  Work)
    echo '[{"id": "e1", "title": "CALTEST-work-event", "status": "confirmed", "availability": "busy", "all_day": true}]'
    ;;
  Family)
    echo '[{"id": "e2", "title": "CALTEST-family-event", "status": "confirmed", "availability": "busy", "all_day": true}]'
    ;;
  *)
    echo "[]"
    ;;
esac
STUB
chmod +x "$CAL_BIN/ical"

cat > "$CAL_BIN/remindctl" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$CAL_BIN/remindctl"

cat > "$CAL_BIN/gh" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$CAL_BIN/gh"

cat > "$CAL_BIN/security" <<'STUB'
#!/bin/sh
exit 1
STUB
chmod +x "$CAL_BIN/security"

test_calendar_attention_check() {
  local out
  out="$(HOME="$TEST_HOME" PATH="$CAL_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST")"

  if grep -q 'CALTEST-work-event' <<<"$out"; then
    ok "event on attention_check calendar (Work) appears"
  else
    bad "event on attention_check calendar (Work) appears (got: $out)"
  fi

  if grep -q 'CALTEST-family-event' <<<"$out"; then
    bad "event on non-attention_check calendar (Family) must not appear"
  else
    ok "event on non-attention_check calendar (Family) does not appear"
  fi
}
test_calendar_attention_check

# ---------------------------------------------------------------------------
# Covers the config-contract bug where fetch_calendar() never excluded
# declined events. `self_status` is the real ical JSON field for the user's
# own RSVP (accepted/declined/tentative). A single attention_check calendar
# carries one accepted and one declined event.
echo
echo "== declined calendar event regression =="

DECLINE_BIN="$WORK/bin-cal-decline"
mkdir -p "$DECLINE_BIN"

cat > "$DECLINE_BIN/chezmoi" <<'STUB'
#!/bin/sh
if [ "$1" = "data" ]; then
  cat <<'JSON'
{
  "calendars": {
    "work": {"attention_check": true, "name": "Work"}
  },
  "reminders": {}
}
JSON
  exit 0
fi
echo "fake chezmoi: unexpected invocation: $*" >&2
exit 99
STUB
chmod +x "$DECLINE_BIN/chezmoi"

cat > "$DECLINE_BIN/ical" <<'STUB'
#!/bin/sh
cat <<'JSON'
[
  {"id": "e1", "title": "DECLINETEST-attending", "status": "confirmed", "availability": "busy", "all_day": true, "self_status": "accepted"},
  {"id": "e2", "title": "DECLINETEST-declined", "status": "confirmed", "availability": "busy", "all_day": true, "self_status": "declined"}
]
JSON
exit 0
STUB
chmod +x "$DECLINE_BIN/ical"

cat > "$DECLINE_BIN/remindctl" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$DECLINE_BIN/remindctl"

cat > "$DECLINE_BIN/gh" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$DECLINE_BIN/gh"

cat > "$DECLINE_BIN/security" <<'STUB'
#!/bin/sh
exit 1
STUB
chmod +x "$DECLINE_BIN/security"

test_declined_event_excluded() {
  local out
  out="$(HOME="$TEST_HOME" PATH="$DECLINE_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST")"

  if grep -q 'DECLINETEST-attending' <<<"$out"; then
    ok "accepted event on attention_check calendar appears"
  else
    bad "accepted event on attention_check calendar appears (got: $out)"
  fi

  if grep -q 'DECLINETEST-declined' <<<"$out"; then
    bad "declined event must not appear even on an attention_check calendar"
  else
    ok "declined event does not appear"
  fi
}
test_declined_event_excluded

# ---------------------------------------------------------------------------
# Covers the multi-org bug where fetch_github() ANDed every configured org
# into a single `org:a org:b` search qualifier, which GitHub's search
# semantics can never match (a repo can't belong to two orgs at once) and so
# always returned zero results. Correct behavior is one search per org,
# merged together. The stub `gh` logs its argv (so the test can assert the
# per-org invocation shape) and returns a distinct fixture PR/issue per org
# (so the test can assert results from every org actually survive the merge).
echo
echo "== gh org scoping regression (multi-org dedupe) =="

GH_BIN="$WORK/bin-gh-scope"
mkdir -p "$GH_BIN"
GH_LOG="$WORK/gh-invocations.log"
: > "$GH_LOG"

cat > "$GH_BIN/chezmoi" <<'STUB'
#!/bin/sh
if [ "$1" = "data" ]; then
  cat <<'JSON'
{
  "calendars": {},
  "reminders": {},
  "orgs": {
    "acme": {"issues": "github"},
    "example-corp": {"issues": "linear"}
  }
}
JSON
  exit 0
fi
echo "fake chezmoi: unexpected invocation: $*" >&2
exit 99
STUB
chmod +x "$GH_BIN/chezmoi"

# Logs every invocation's argv, then returns a fixture item keyed off which
# org: qualifier (if any) was passed, and which list type (pr/issue).
cat > "$GH_BIN/gh" <<STUB
#!/bin/sh
echo "\$*" >> "$GH_LOG"
list_type="\$1"
org=""
prev=""
for a in "\$@"; do
  case "\$prev \$a" in
    *"org:acme"*) org="acme" ;;
    *"org:example-corp"*) org="example-corp" ;;
  esac
  prev="\$a"
done
case "\$list_type-\$org" in
  pr-acme)
    echo '[{"number": 1, "title": "PR from acme", "repository": {"nameWithOwner": "acme/repo"}, "url": "https://github.com/acme/repo/pull/1"}]'
    ;;
  pr-example-corp)
    echo '[{"number": 2, "title": "PR from example-corp", "repository": {"nameWithOwner": "example-corp/repo"}, "url": "https://github.com/example-corp/repo/pull/2"}]'
    ;;
  issue-acme)
    echo '[{"number": 3, "title": "Issue from acme", "repository": {"nameWithOwner": "acme/repo"}, "url": "https://github.com/acme/repo/issues/3"}]'
    ;;
  issue-example-corp)
    echo '[{"number": 4, "title": "Issue from example-corp", "repository": {"nameWithOwner": "example-corp/repo"}, "url": "https://github.com/example-corp/repo/issues/4"}]'
    ;;
  *)
    echo "[]"
    ;;
esac
exit 0
STUB
chmod +x "$GH_BIN/gh"

cat > "$GH_BIN/ical" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$GH_BIN/ical"

cat > "$GH_BIN/remindctl" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$GH_BIN/remindctl"

cat > "$GH_BIN/security" <<'STUB'
#!/bin/sh
exit 1
STUB
chmod +x "$GH_BIN/security"

test_gh_org_scoping() {
  local out
  out="$(HOME="$TEST_HOME" PATH="$GH_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST")"

  local pr_calls issue_calls
  pr_calls="$(grep -c 'pr list' "$GH_LOG" || true)"
  issue_calls="$(grep -c 'issue list' "$GH_LOG" || true)"

  check "gh invoked once per org for pr list" "$pr_calls" "2"
  check "gh invoked once per org for issue list" "$issue_calls" "2"

  # Each individual pr-list invocation must carry exactly one org: qualifier,
  # never both ANDed together in the same search string.
  if grep 'pr list' "$GH_LOG" | grep -q 'org:acme.*org:example-corp\|org:example-corp.*org:acme'; then
    bad "no single pr list call ANDs both orgs together"
  else
    ok "no single pr list call ANDs both orgs together"
  fi
  if grep 'issue list' "$GH_LOG" | grep -q 'org:acme.*org:example-corp\|org:example-corp.*org:acme'; then
    bad "no single issue list call ANDs both orgs together"
  else
    ok "no single issue list call ANDs both orgs together"
  fi

  if grep -q 'PR from acme' <<<"$out" && grep -q 'PR from example-corp' <<<"$out"; then
    ok "PR results from both org-scoped calls are merged into output"
  else
    bad "PR results from both org-scoped calls are merged into output (got: $out)"
  fi

  if grep -q 'Issue from acme' <<<"$out" && grep -q 'Issue from example-corp' <<<"$out"; then
    ok "issue results from both org-scoped calls are merged into output"
  else
    bad "issue results from both org-scoped calls are merged into output (got: $out)"
  fi
}
test_gh_org_scoping

# ---------------------------------------------------------------------------
# Regression protection: solo-org (or no-org) users must still get the old
# unscoped single-query behavior, not an org:-qualified search with no org.
echo
echo "== gh unscoped regression (zero configured orgs) =="

GH_NOORG_BIN="$WORK/bin-gh-noorg"
mkdir -p "$GH_NOORG_BIN"
GH_NOORG_LOG="$WORK/gh-noorg-invocations.log"
: > "$GH_NOORG_LOG"

cat > "$GH_NOORG_BIN/chezmoi" <<'STUB'
#!/bin/sh
if [ "$1" = "data" ]; then
  cat <<'JSON'
{
  "calendars": {},
  "reminders": {},
  "orgs": {}
}
JSON
  exit 0
fi
echo "fake chezmoi: unexpected invocation: $*" >&2
exit 99
STUB
chmod +x "$GH_NOORG_BIN/chezmoi"

cat > "$GH_NOORG_BIN/gh" <<STUB
#!/bin/sh
echo "\$*" >> "$GH_NOORG_LOG"
echo "[]"
exit 0
STUB
chmod +x "$GH_NOORG_BIN/gh"

cat > "$GH_NOORG_BIN/ical" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$GH_NOORG_BIN/ical"

cat > "$GH_NOORG_BIN/remindctl" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$GH_NOORG_BIN/remindctl"

cat > "$GH_NOORG_BIN/security" <<'STUB'
#!/bin/sh
exit 1
STUB
chmod +x "$GH_NOORG_BIN/security"

test_gh_unscoped_no_orgs() {
  HOME="$TEST_HOME" PATH="$GH_NOORG_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST" >/dev/null

  local pr_calls issue_calls pr_call issue_call
  pr_calls="$(grep -c 'pr list' "$GH_NOORG_LOG" || true)"
  issue_calls="$(grep -c 'issue list' "$GH_NOORG_LOG" || true)"
  pr_call="$(grep 'pr list' "$GH_NOORG_LOG" || true)"
  issue_call="$(grep 'issue list' "$GH_NOORG_LOG" || true)"

  check "gh invoked exactly once for pr list with zero orgs" "$pr_calls" "1"
  check "gh invoked exactly once for issue list with zero orgs" "$issue_calls" "1"

  case "$pr_call" in
    *"review-requested:@me"*"--limit 50"*)
      if grep -q 'org:' <<<"$pr_call"; then
        bad "unscoped pr list search has no org: qualifier (got: $pr_call)"
      else
        ok "unscoped pr list search has no org: qualifier"
      fi
      ;;
    *) bad "unscoped pr list search shape (got: $pr_call)" ;;
  esac

  case "$issue_call" in
    *"assignee:@me"*"--limit 50"*)
      if grep -q 'org:' <<<"$issue_call"; then
        bad "unscoped issue list search has no org: qualifier (got: $issue_call)"
      else
        ok "unscoped issue list search has no org: qualifier"
      fi
      ;;
    *) bad "unscoped issue list search shape (got: $issue_call)" ;;
  esac
}
test_gh_unscoped_no_orgs

# ---------------------------------------------------------------------------
# Regression for get_ical_path() preferring `which ical` over the
# chezmoi-managed binary at ~/.local/bin/ical. A stray dev build shadowing
# `ical` on PATH (e.g. a mise shim) is ad-hoc-signed separately, so macOS TCC
# treats it as a different app identity and Calendar access silently fails.
# Stubs `which` to resolve to a decoy path and points HOME at a temp dir with
# a fake managed binary, then calls get_ical_path() directly (via importlib,
# since main() is guarded by __name__ == "__main__") to assert the managed
# path wins even though `which` would report something else.
echo
echo "== ical path preference regression =="

ICAL_BIN="$WORK/bin-ical-path"
mkdir -p "$ICAL_BIN"

cat > "$ICAL_BIN/which" <<'STUB'
#!/bin/sh
if [ "$1" = "ical" ]; then
  echo "/opt/shadow/mise/shims/ical"
  exit 0
fi
exit 1
STUB
chmod +x "$ICAL_BIN/which"

FAKE_HOME="$WORK/fake-home-ical"
mkdir -p "$FAKE_HOME/.local/bin"
: > "$FAKE_HOME/.local/bin/ical"
chmod +x "$FAKE_HOME/.local/bin/ical"

test_ical_path_prefers_managed_binary() {
  # Expected value goes through the same Path.home() normalization (which
  # collapses any double slashes from $TMPDIR) so the comparison isn't
  # sensitive to raw string formatting of $FAKE_HOME.
  local result expected
  expected="$(HOME="$FAKE_HOME" python3 -c "from pathlib import Path; print(Path.home() / '.local/bin/ical')")"
  result="$(HOME="$FAKE_HOME" PATH="$ICAL_BIN:$PATH" python3 -c "
import importlib.util
from importlib.machinery import SourceFileLoader
loader = SourceFileLoader('attention_list', '$ATTENTION_LIST')
spec = importlib.util.spec_from_loader('attention_list', loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)
print(m.get_ical_path())
")"
  check "get_ical_path() prefers managed ~/.local/bin/ical over PATH-shadowed which" "$result" "$expected"
}
test_ical_path_prefers_managed_binary

# ---------------------------------------------------------------------------
# Regression for the get_linear_token() keychain account-name typo:
# find-generic-password was called with -a linear_api_token, but the real
# keychain item (set by chezmoi) is stored under linear_api_key, so the
# lookup always failed and fetch_linear() always short-circuited to [].
# Invokes get_linear_token() directly (via importlib, since main() is
# guarded by __name__ == "__main__") rather than the whole script, so this
# doesn't depend on stubbing the Linear GraphQL network call too.
echo
echo "== linear keychain account name regression =="

SEC_BIN="$WORK/bin-security-account"
mkdir -p "$SEC_BIN"
SEC_LOG="$WORK/security-invocations.log"
: > "$SEC_LOG"

cat > "$SEC_BIN/security" <<STUB
#!/bin/sh
echo "\$*" >> "$SEC_LOG"
if [ "\$1" = "find-generic-password" ]; then
  echo "fake-linear-token"
  exit 0
fi
exit 1
STUB
chmod +x "$SEC_BIN/security"

test_linear_keychain_account_name() {
  local token
  token="$(PATH="$SEC_BIN:$PATH" python3 -c "
import importlib.util
from importlib.machinery import SourceFileLoader
loader = SourceFileLoader('attention_list', '$ATTENTION_LIST')
spec = importlib.util.spec_from_loader('attention_list', loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)
print(m.get_linear_token())
")"
  check "get_linear_token() returns the keychain value" "$token" "fake-linear-token"

  local sec_call
  sec_call="$(cat "$SEC_LOG")"
  case "$sec_call" in
    *"-a linear_api_key"*) ok "security invoked with account name linear_api_key" ;;
    *) bad "security invoked with account name linear_api_key (got: $sec_call)" ;;
  esac

  case "$sec_call" in
    *"linear_api_token"*) bad "security must not use stale account name linear_api_token (got: $sec_call)" ;;
    *) ok "security does not use stale account name linear_api_token" ;;
  esac
}
test_linear_keychain_account_name

# ---------------------------------------------------------------------------
echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
