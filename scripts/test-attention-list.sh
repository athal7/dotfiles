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
  out="$(PATH="$STUB_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST")"

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
  out="$(PATH="$CAL_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST")"

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
  out="$(PATH="$DECLINE_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST")"

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
# Covers the config-contract bug where fetch_github()'s `gh pr list`/`gh issue
# list` calls had no `--limit` and no org scoping from chezmoi data
# (orgs.<key>). The stub `gh` logs its argv so the test can assert the actual
# invocation shape rather than just the JSON it returns.
echo
echo "== gh org scoping and --limit regression =="

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

cat > "$GH_BIN/gh" <<STUB
#!/bin/sh
echo "\$*" >> "$GH_LOG"
echo "[]"
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
  PATH="$GH_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST" >/dev/null

  local pr_call issue_call
  pr_call="$(grep 'pr list' "$GH_LOG" || true)"
  issue_call="$(grep 'issue list' "$GH_LOG" || true)"

  case "$pr_call" in
    *"review-requested:@me org:acme org:example-corp"*"--limit 50"*) ok "pr list scoped to orgs with --limit 50" ;;
    *) bad "pr list scoped to orgs with --limit 50 (got: $pr_call)" ;;
  esac

  case "$issue_call" in
    *"assignee:@me org:acme org:example-corp"*"--limit 50"*) ok "issue list scoped to orgs with --limit 50" ;;
    *) bad "issue list scoped to orgs with --limit 50 (got: $issue_call)" ;;
  esac
}
test_gh_org_scoping

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
