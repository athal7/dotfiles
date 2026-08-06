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
  if grep -Eq '^OVERDUE\b' <<<"$overdue_line"; then
    ok "overdue reminder gets OVERDUE status (overdue logic engaged)"
  else
    bad "overdue reminder gets OVERDUE status (got: $overdue_line)"
  fi
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
# fetch_github() must use the global-search subcommands (`gh search prs` /
# `gh search issues`), not the repo-scoped `gh pr list` / `gh issue list`.
# The latter resolve a single target repo from the cwd's git remote (or -R)
# and only filter *within* that repo — --search never made them global.
# Also covers the expanded fetch: PRs I authored that need MY attention
# (failing checks / changes requested / merge conflict / new comments,
# resolved via a follow-up `gh pr view`), issues in repos I own regardless
# of assignee, and de-duplication when the same issue matches more than one
# query.
echo
echo "== gh search regression (global search, not repo-scoped list; authored-PR attention; owned-repo issues) =="

GH_BIN="$WORK/bin-gh-noorg-scoping"
mkdir -p "$GH_BIN"
GH_LOG="$WORK/gh-invocations.log"
: > "$GH_LOG"

cat > "$GH_BIN/chezmoi" <<'STUB'
#!/bin/sh
if [ "$1" = "data" ]; then
  cat <<'JSON'
{
  "calendars": {},
  "reminders": {}
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
case "\$*" in
  "search prs --review-requested=@me"*)
    cat <<'JSON'
[{"number": 1, "title": "GHTEST-review-me", "repository": {"name": "kb", "nameWithOwner": "athal7/kb"}, "url": "https://github.com/athal7/kb/pull/1"}]
JSON
    ;;
  "search prs --author=@me"*)
    cat <<'JSON'
[{"number": 3, "title": "GHTEST-authored-me", "repository": {"name": "kb", "nameWithOwner": "athal7/kb"}, "url": "https://github.com/athal7/kb/pull/3"}]
JSON
    ;;
  "search issues --assignee=@me"*)
    cat <<'JSON'
[{"number": 2, "title": "GHTEST-assigned-me", "repository": {"name": "kb", "nameWithOwner": "athal7/kb"}, "url": "https://github.com/athal7/kb/issues/2"}]
JSON
    ;;
  "search issues --owner=@me"*)
    cat <<'JSON'
[{"number": 2, "title": "GHTEST-assigned-me", "repository": {"name": "kb", "nameWithOwner": "athal7/kb"}, "url": "https://github.com/athal7/kb/issues/2"}, {"number": 4, "title": "GHTEST-repo-issue", "repository": {"name": "kb", "nameWithOwner": "athal7/kb"}, "url": "https://github.com/athal7/kb/issues/4"}]
JSON
    ;;
  "api user --jq .login")
    echo "ghtestuser"
    ;;
  "pr view 3 -R athal7/kb"*)
    cat <<'JSON'
{"mergeable": "CONFLICTING", "reviewDecision": "CHANGES_REQUESTED", "statusCheckRollup": [{"conclusion": "FAILURE"}], "comments": [{"author": {"login": "someone-else"}}]}
JSON
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

test_gh_global_search_scope() {
  local out
  out="$(HOME="$TEST_HOME" PATH="$GH_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST")"

  check "gh search prs (review-requested) invoked exactly once" \
    "$(grep -c '^search prs --review-requested=@me' "$GH_LOG")" "1"
  check "gh search prs (author) invoked exactly once" \
    "$(grep -c '^search prs --author=@me' "$GH_LOG")" "1"
  check "gh search issues (assignee) invoked exactly once" \
    "$(grep -c '^search issues --assignee=@me' "$GH_LOG")" "1"
  check "gh search issues (owner) invoked exactly once" \
    "$(grep -c '^search issues --owner=@me' "$GH_LOG")" "1"

  # Repo-scoped `gh pr list`/`gh issue list` must never be used: they only
  # filter within a single cwd-resolved repo, not across all of @me's repos.
  if grep -Eq '^pr list|^issue list' "$GH_LOG"; then
    bad "gh never invoked with repo-scoped 'pr list'/'issue list' (got: $(cat "$GH_LOG"))"
  else
    ok "gh never invoked with repo-scoped 'pr list'/'issue list'"
  fi

  check "gh search prs (review-requested) argv" \
    "$(grep '^search prs --review-requested=@me' "$GH_LOG")" \
    "search prs --review-requested=@me --state=open --limit 50 --json number,title,repository,url"
  check "gh search prs (author) argv" \
    "$(grep '^search prs --author=@me' "$GH_LOG")" \
    "search prs --author=@me --state=open --limit 50 --json number,title,repository,url"
  check "gh search issues (assignee) argv" \
    "$(grep '^search issues --assignee=@me' "$GH_LOG")" \
    "search issues --assignee=@me --state=open --limit 50 --json number,title,repository,url"
  check "gh search issues (owner) argv" \
    "$(grep '^search issues --owner=@me' "$GH_LOG")" \
    "search issues --owner=@me --state=open --limit 50 --json number,title,repository,url"

  if grep -Eq 'org:|user:' "$GH_LOG"; then
    bad "no org:/user: qualifier anywhere in gh invocations (got: $(cat "$GH_LOG"))"
  else
    ok "no org:/user: qualifier anywhere in gh invocations"
  fi

  # Confirm the {"name","nameWithOwner"} repository shape is parsed and the
  # STATUS/CONTEXT columns carry the right values (STATUS replaced the old
  # numeric weight; CONTEXT replaced the old "Repo: <name>" detail text).
  local pr_line issue_line
  pr_line="$(grep 'GHTEST-review-me' <<<"$out" || true)"
  issue_line="$(grep 'GHTEST-assigned-me' <<<"$out" || true)"

  case "$pr_line" in
    "REVIEW REQUESTED"*"athal7/kb"*) ok "review-requested PR gets REVIEW REQUESTED status with repo as context (got: $pr_line)" ;;
    *) bad "review-requested PR gets REVIEW REQUESTED status with repo as context (got: $pr_line)" ;;
  esac

  case "$issue_line" in
    "ASSIGNED"*"athal7/kb"*) ok "assigned issue gets ASSIGNED status with repo as context (got: $issue_line)" ;;
    *) bad "assigned issue gets ASSIGNED status with repo as context (got: $issue_line)" ;;
  esac

  # Authored PR with failing checks/changes-requested/conflict/new comments
  # is flagged NEEDS ATTENTION, with the specific reasons in the details
  # column, resolved via the `gh pr view` follow-up call.
  local authored_line
  authored_line="$(grep 'GHTEST-authored-me' <<<"$out" || true)"
  case "$authored_line" in
    "NEEDS ATTENTION"*"athal7/kb"*"Changes Requested, Merge Conflict, Checks Failing, New Comments"*)
      ok "authored PR needing attention gets NEEDS ATTENTION status with reasons in details (got: $authored_line)" ;;
    *) bad "authored PR needing attention gets NEEDS ATTENTION status with reasons in details (got: $authored_line)" ;;
  esac

  # Issue in an owned repo, not assigned to me, still surfaces (OPEN status).
  local repo_issue_line
  repo_issue_line="$(grep 'GHTEST-repo-issue' <<<"$out" || true)"
  case "$repo_issue_line" in
    "OPEN"*"athal7/kb"*) ok "owned-repo issue (not assigned to me) appears with OPEN status (got: $repo_issue_line)" ;;
    *) bad "owned-repo issue (not assigned to me) appears with OPEN status (got: $repo_issue_line)" ;;
  esac

  # De-dupe: GHTEST-assigned-me matches both the assignee and owner queries
  # (it's in the fixture's owner=@me response too) but must appear exactly
  # once, keeping the more specific "assigned" variant (ASSIGNED, not OPEN).
  local assigned_count
  assigned_count="$(grep -c 'GHTEST-assigned-me' <<<"$out")"
  check "issue matching both assignee and owner queries appears exactly once" "$assigned_count" "1"
  case "$issue_line" in
    "ASSIGNED"*) ok "de-duped issue keeps the more specific ASSIGNED status, not OPEN" ;;
    *) bad "de-duped issue keeps the more specific ASSIGNED status, not OPEN (got: $issue_line)" ;;
  esac
}
test_gh_global_search_scope

# ---------------------------------------------------------------------------
# repo_path resolution must match a GH repo against local directories by
# their actual `git remote origin` (not a maintained/committed mapping --
# personal directory shorthands would leak real repo/org names into this
# public dotfiles repo), so a repo cloned under a shorthand name (e.g.
# "bigproj" for a repo actually named "big-project-name") still resolves.
echo
echo "== repo_path git-remote auto-detection regression =="

REPODIR_BIN="$WORK/bin-repodirs"
mkdir -p "$REPODIR_BIN"

# A real local git repo whose directory name ("bigproj") does not match
# its own remote's repo name ("big-project-name") -- exactly the
# shorthand-clone case. Generic placeholder org/repo names throughout
# this test on purpose -- no real repos/orgs in test fixtures.
FAKE_CODE_DIR="$WORK/fakecode"
mkdir -p "$FAKE_CODE_DIR/bigproj"
env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_PREFIX git -C "$FAKE_CODE_DIR/bigproj" init -q
env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_PREFIX git -C "$FAKE_CODE_DIR/bigproj" remote add origin "https://github.com/myorg/big-project-name.git"

cat > "$REPODIR_BIN/chezmoi" <<STUB
#!/bin/sh
if [ "\$1" = "data" ]; then
  cat <<JSON
{
  "calendars": {},
  "reminders": {},
  "codeDir": "$FAKE_CODE_DIR"
}
JSON
  exit 0
fi
echo "fake chezmoi: unexpected invocation: \$*" >&2
exit 99
STUB
chmod +x "$REPODIR_BIN/chezmoi"

cat > "$REPODIR_BIN/gh" <<'STUB'
#!/bin/sh
case "$*" in
  "search prs --review-requested=@me"*)
    cat <<'JSON'
[{"number": 9, "title": "REPODIRTEST-shorthand", "repository": {"name": "big-project-name", "nameWithOwner": "myorg/big-project-name"}, "url": "https://github.com/myorg/big-project-name/pull/9"}]
JSON
    ;;
  *) echo "[]" ;;
esac
exit 0
STUB
chmod +x "$REPODIR_BIN/gh"

cat > "$REPODIR_BIN/ical" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$REPODIR_BIN/ical"

cat > "$REPODIR_BIN/remindctl" <<'STUB'
#!/bin/sh
echo "[]"
exit 0
STUB
chmod +x "$REPODIR_BIN/remindctl"

cat > "$REPODIR_BIN/security" <<'STUB'
#!/bin/sh
exit 1
STUB
chmod +x "$REPODIR_BIN/security"

test_repo_path_git_remote_autodetect() {
  local out repo_line
  out="$(HOME="$TEST_HOME" PATH="$REPODIR_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST")"
  repo_line="$(grep 'REPODIRTEST-shorthand' <<<"$out" || true)"
  case "$repo_line" in
    *"REPO_PATH:$FAKE_CODE_DIR/bigproj"*) ok "repo_path matches the shorthand-named local clone via its git remote (got: $repo_line)" ;;
    *) bad "repo_path matches the shorthand-named local clone via its git remote (got: $repo_line)" ;;
  esac
}
test_repo_path_git_remote_autodetect

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
# actions_for() is the single source of truth for which hotkeys exist per
# item type/context, consumed by both get_list() (footer hints) and act()
# (dispatch). These tests call it directly (via importlib) to pin down the
# key set per context, and confirm expect_keys() is exactly the union of
# every context's keys -- the property that keeps the --expect key set, the
# footer hints, and the dispatch table in sync.
#
# Keys are alt-prefixed (fzf's `alt-X` --expect syntax, verified against a
# real fzf binary via a pty probe: `ESC` followed by a literal character
# reliably fires that exact `alt-<char>` binding). The Linear cross-link
# variants (O/C/T) stay plain, non-alt, uppercase: the same pty probe showed
# `alt-O` (ESC then a bare capital letter) never fires, because fzf's input
# parser treats `ESC O <char>` exclusively as a VT100 SS3 escape sequence
# (used for arrow/function keys) and silently drops any `ESC O` prefix it
# doesn't recognize as one of those -- there is no generic `alt-O` event to
# bind to, at least in this fzf release, regardless of arbitrary wait time.
echo
echo "== actions_for()/expect_keys() single-source-of-truth parity =="

ACTIONS_FOR_HELPER() {
  python3 -c "
import importlib.util
from importlib.machinery import SourceFileLoader
loader = SourceFileLoader('attention_list', '$ATTENTION_LIST')
spec = importlib.util.spec_from_loader('attention_list', loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)
$1
"
}

check_keys() {
  local label="$1" expected="$2" py_call="$3"
  local actual
  actual="$(ACTIONS_FOR_HELPER "print(','.join(k for k, _ in $py_call))")"
  check "$label" "$actual" "$expected"
}

check_keys "CAL (no linked reminders) keys" "alt-y" \
  "m.actions_for('CAL')"
check_keys "CAL (1 linked reminder) keys" "alt-y,alt-x" \
  "m.actions_for('CAL', rem_ids=['r1'])"
check_keys "CAL (3 linked reminders: alt-x + digit overflow) keys" "alt-y,alt-x,1,2" \
  "m.actions_for('CAL', rem_ids=['r1', 'r2', 'r3'])"
check_keys "REM keys" "alt-x" \
  "m.actions_for('REM')"
check_keys "GH (no Linear link) keys" "alt-o,alt-s,alt-l,alt-a,alt-m,alt-c,alt-g" \
  "m.actions_for('GH')"
check_keys "GH (with Linear cross-link) keys" "alt-o,alt-s,alt-l,alt-a,alt-m,alt-c,alt-g,O,C,T" \
  "m.actions_for('GH', has_linear=True)"
check_keys "LIN keys" "alt-o,alt-s,alt-c,alt-t" \
  "m.actions_for('LIN')"
check_keys "unknown item type keys" "" \
  "m.actions_for('BOGUS')"

test_expect_keys_is_union_of_actions_for() {
  local expected actual
  expected="$(ACTIONS_FOR_HELPER "
contexts = [
    m.actions_for('CAL', rem_ids=[f'r{i}' for i in range(1, 10)]),
    m.actions_for('REM'),
    m.actions_for('GH', has_linear=False),
    m.actions_for('GH', has_linear=True),
    m.actions_for('LIN'),
]
seen = set()
keys = []
for actions in contexts:
    for key, _ in actions:
        if key not in seen:
            seen.add(key)
            keys.append(key)
print(','.join(keys))
")"
  actual="$(PATH="$STUB_BIN:$PATH" python3 "$ATTENTION_LIST" expect-keys)"
  check "expect-keys output equals the union of all actions_for() keys" "$actual" "$expected"
}
test_expect_keys_is_union_of_actions_for

test_no_quit_key() {
  local keys
  keys="$(PATH="$STUB_BIN:$PATH" python3 "$ATTENTION_LIST" expect-keys)"
  case ",$keys," in
    *,q,*) bad "expect-keys must not contain a 'q' quit key (got: $keys)" ;;
    *) ok "expect-keys contains no 'q' quit key (Esc at the dashboard is the only quit path)" ;;
  esac
}
test_no_quit_key

test_no_duplicate_keys_per_context() {
  local label="$1" py_call="$2"
  local keys dup
  keys="$(ACTIONS_FOR_HELPER "print(chr(10).join(k for k, _ in $py_call))")"
  dup="$(printf '%s\n' "$keys" | sort | uniq -d)"
  if [ -z "$dup" ]; then
    ok "$label: no duplicate hotkeys"
  else
    bad "$label: no duplicate hotkeys (dupes: $dup)"
  fi
}
test_no_duplicate_keys_per_context "CAL (3 linked reminders)" \
  "m.actions_for('CAL', rem_ids=['r1', 'r2', 'r3'])"
test_no_duplicate_keys_per_context "GH (with Linear cross-link)" \
  "m.actions_for('GH', has_linear=True)"

# ---------------------------------------------------------------------------
# hint_for() renders the exact footer text get_list() emits as each row's
# third (hidden) tab field. It must be built from actions_for() -- not a
# separately maintained string -- so the footer can never promise a hotkey
# act() doesn't actually honor.
echo
echo "== hint_for() footer text =="

check_hint() {
  local label="$1" expected="$2" py_call="$3"
  local actual
  actual="$(ACTIONS_FOR_HELPER "print($py_call)")"
  check "$label" "$actual" "$expected"
}

check_hint "GH (no Linear link) hint" \
  "⌥o open  ⌥s session  ⌥l lumen  ⌥a approve  ⌥m merge  ⌥c comment  ⌥g label" \
  "m.hint_for('GH')"
check_hint "REM hint" "⌥x complete" \
  "m.hint_for('REM')"

echo
echo "== slugify() title-to-slug =="

check "slugify: lowercases and hyphenates" \
  "$(ACTIONS_FOR_HELPER "print(m.slugify('Fix the login bug!'))")" \
  "fix-the-login-bug"
check "slugify: collapses repeated punctuation/whitespace" \
  "$(ACTIONS_FOR_HELPER "print(m.slugify('  Weird---Title!!  '))")" \
  "weird-title"
check "slugify: trims to max_len at a hyphen boundary, never mid-word" \
  "$(ACTIONS_FOR_HELPER "print(m.slugify('one two three four five six seven', max_len=15))")" \
  "one-two-three"
check "slugify: empty/non-alnum input falls back to a generic slug" \
  "$(ACTIONS_FOR_HELPER "print(m.slugify('!!!'))")" \
  "session"

test_get_list_emits_hint_field() {
  local out gh_line hint_field
  out="$(HOME="$TEST_HOME" PATH="$GH_BIN:$PATH" env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST")"
  gh_line="$(grep 'GHTEST-review-me' <<<"$out" || true)"
  # Field 3 (after the second tab) is the hint; awk splits on literal tabs.
  hint_field="$(awk -F'\t' '{print $3}' <<<"$gh_line")"
  case "$hint_field" in
    *"⌥o open"*"⌥m merge"*) ok "get_list() row carries a hint field with GH's hotkeys (got: $hint_field)" ;;
    *) bad "get_list() row carries a hint field with GH's hotkeys (got: $hint_field)" ;;
  esac
}
test_get_list_emits_hint_field

# ---------------------------------------------------------------------------
# act(key, line) dispatch: two positional args (fzf's --expect two-line
# output split into pressed key + highlighted row), one fzf process per
# dashboard render -- no nested action submenu, so these tests stub only
# the downstream commands (open/remindctl/gh), never fzf itself.
echo
echo "== act(key, line) dispatch =="

INTERACT_BIN="$WORK/bin-act-interact"
mkdir -p "$INTERACT_BIN"

OPEN_LOG="$WORK/open-invocations.log"; : > "$OPEN_LOG"
REMINDCTL_ACT_LOG="$WORK/remindctl-act-invocations.log"; : > "$REMINDCTL_ACT_LOG"
GH_ACT_LOG="$WORK/gh-act-invocations.log"; : > "$GH_ACT_LOG"
PBCOPY_LOG="$WORK/pbcopy-invocations.log"; : > "$PBCOPY_LOG"
AOE_CMD_LOG="$WORK/aoe-cmd-invocations.log"; : > "$AOE_CMD_LOG"

cat > "$INTERACT_BIN/open" <<STUB
#!/bin/sh
echo "\$*" >> "$OPEN_LOG"
exit 0
STUB
chmod +x "$INTERACT_BIN/open"

cat > "$INTERACT_BIN/remindctl" <<STUB
#!/bin/sh
echo "\$*" >> "$REMINDCTL_ACT_LOG"
exit 0
STUB
chmod +x "$INTERACT_BIN/remindctl"

cat > "$INTERACT_BIN/gh" <<STUB
#!/bin/sh
echo "\$*" >> "$GH_ACT_LOG"
exit 0
STUB
chmod +x "$INTERACT_BIN/gh"

cat > "$INTERACT_BIN/pbcopy" <<STUB
#!/bin/sh
cat >> "$PBCOPY_LOG"
exit 0
STUB
chmod +x "$INTERACT_BIN/pbcopy"

cat > "$INTERACT_BIN/aoe-cmd" <<STUB
#!/bin/sh
echo "\$*" >> "$AOE_CMD_LOG"
exit 0
STUB
chmod +x "$INTERACT_BIN/aoe-cmd"

# Fixture lines matching get_list()'s real 3-field output shape
# (display\tmetadata\thint). The hint field's exact content doesn't matter
# to act() (it only reads the display portion and metadata tail), so a
# placeholder is fine here.
TAB=$'\t'
FIX_GH_LINE="REVIEW REQUESTED  athal7/kb  Test PR   ${TAB}| TYPE:GH | ID:42 | SLUG:test-pr | DATABASE_ID: | URL:https://github.com/athal7/kb/pull/42 | REPO_PATH:/tmp/repo | LINEAR_DB_ID: | LINEAR_URL: | REMINDER_ID:${TAB}hint"
FIX_GH_LINKED_LINE="REVIEW REQUESTED  athal7/kb  Test PR  Linear ABC-1: TODO ${TAB}| TYPE:GH | ID:42 | SLUG:test-pr | DATABASE_ID: | URL:https://github.com/athal7/kb/pull/42 | REPO_PATH:/tmp/repo | LINEAR_DB_ID:db-uuid | LINEAR_URL:https://linear.app/abc/issue/ABC-1 | REMINDER_ID:${TAB}hint"
FIX_REM_LINE="HIGH  Personal  Buy milk   ${TAB}| TYPE:REM | ID:r1 | SLUG:buy-milk | DATABASE_ID: | URL: | REPO_PATH: | LINEAR_DB_ID: | LINEAR_URL: | REMINDER_ID:${TAB}hint"
FIX_CAL_LINE="ALL DAY  Work  Team Sync   ${TAB}| TYPE:CAL | ID:e1 | SLUG:team-sync | DATABASE_ID: | URL: | REPO_PATH: | LINEAR_DB_ID: | LINEAR_URL: | REMINDER_ID:${TAB}hint"
FIX_CAL_MULTI_LINE="ALL DAY  Work  Team Sync  Reminder: prep ${TAB}| TYPE:CAL | ID:e1 | SLUG:team-sync | DATABASE_ID: | URL: | REPO_PATH: | LINEAR_DB_ID: | LINEAR_URL: | REMINDER_ID:r1,r2,r3${TAB}hint"
FIX_LIN_LINE="TODO  MyProject  Fix bug   ${TAB}| TYPE:LIN | ID:ABC-1 | SLUG:fix-bug | DATABASE_ID:db-uuid | URL:https://linear.app/abc/issue/ABC-1 | REPO_PATH: | LINEAR_DB_ID: | LINEAR_URL: | REMINDER_ID:${TAB}hint"

# run_act <key> <line> [stdin] — invokes `attention-list act <key> <line>`,
# optionally feeding <stdin> (for merge-confirm/comment/label prompts, which
# now run as plain input() reads after fzf has already exited). Captures
# combined output/exit code into ACT_OUTPUT/ACT_RC.
run_act() {
  local key="$1" line="$2" stdin="${3-}"
  ACT_OUTPUT="$(printf '%s' "$stdin" | HOME="$TEST_HOME" PATH="$INTERACT_BIN:$PATH" \
    env -u LINEAR_API_TOKEN -u LINEAR_TOKEN python3 "$ATTENTION_LIST" act "$key" "$line" 2>&1)" && ACT_RC=0 || ACT_RC=$?
  if [ "$ACT_RC" -ne 0 ]; then
    printf '  (act output: %s)\n' "$ACT_OUTPUT" >&2
  fi
}

echo
echo "-- alt-key hotkey dispatch invokes the correct downstream command --"

: > "$OPEN_LOG"
run_act "alt-o" "$FIX_GH_LINE"
check "GH alt-o exits 0" "$ACT_RC" "0"
if grep -q 'https://github.com/athal7/kb/pull/42' "$OPEN_LOG"; then
  ok "GH alt-o invokes open with the item URL"
else
  bad "GH alt-o invokes open with the item URL (got: $(cat "$OPEN_LOG"))"
fi

: > "$REMINDCTL_ACT_LOG"
run_act "alt-x" "$FIX_REM_LINE"
check "REM alt-x exits 0" "$ACT_RC" "0"
if grep -q 'complete r1' "$REMINDCTL_ACT_LOG"; then
  ok "REM alt-x invokes remindctl complete on the item's own ID"
else
  bad "REM alt-x invokes remindctl complete on the item's own ID (got: $(cat "$REMINDCTL_ACT_LOG"))"
fi

: > "$PBCOPY_LOG"
run_act "alt-y" "$FIX_CAL_LINE"
check "CAL alt-y exits 0" "$ACT_RC" "0"
if grep -q 'Team Sync' "$PBCOPY_LOG"; then
  ok "CAL alt-y copies the row to the clipboard"
else
  bad "CAL alt-y copies the row to the clipboard (got: $(cat "$PBCOPY_LOG"))"
fi

echo
echo "-- CAL multi-reminder overflow: alt-x is first reminder, digits are the rest --"

: > "$REMINDCTL_ACT_LOG"
run_act "alt-x" "$FIX_CAL_MULTI_LINE"
check "CAL alt-x (first reminder) exits 0" "$ACT_RC" "0"
if grep -q 'complete r1' "$REMINDCTL_ACT_LOG"; then
  ok "CAL alt-x completes the first linked reminder (r1)"
else
  bad "CAL alt-x completes the first linked reminder (r1) (got: $(cat "$REMINDCTL_ACT_LOG"))"
fi

: > "$REMINDCTL_ACT_LOG"
run_act "1" "$FIX_CAL_MULTI_LINE"
check "CAL digit-overflow key '1' exits 0" "$ACT_RC" "0"
if grep -q 'complete r2' "$REMINDCTL_ACT_LOG"; then
  ok "CAL digit-overflow key '1' completes the second linked reminder (r2)"
else
  bad "CAL digit-overflow key '1' completes the second linked reminder (r2) (got: $(cat "$REMINDCTL_ACT_LOG"))"
fi

echo
echo "-- Linear cross-link plain-uppercase keys (O/C/T) --"

: > "$OPEN_LOG"
run_act "O" "$FIX_GH_LINKED_LINE"
check "GH linked item, key 'O' exits 0" "$ACT_RC" "0"
if grep -q 'https://linear.app/abc/issue/ABC-1' "$OPEN_LOG"; then
  ok "key 'O' opens the linked Linear issue, not the GH item"
else
  bad "key 'O' opens the linked Linear issue, not the GH item (got: $(cat "$OPEN_LOG"))"
fi

: > "$OPEN_LOG"
run_act "O" "$FIX_GH_LINE"
check "GH item with no Linear link, key 'O' exits 0 (no-op, not a crash)" "$ACT_RC" "0"
if [ -s "$OPEN_LOG" ]; then
  bad "key 'O' with no Linear link must not invoke open (got: $(cat "$OPEN_LOG"))"
else
  ok "key 'O' with no Linear link is a no-op"
fi

echo
echo "-- Enter (empty key): primary action for GH/LIN, no-op for CAL/REM --"

: > "$OPEN_LOG"
run_act "" "$FIX_GH_LINE"
check "Enter on GH exits 0" "$ACT_RC" "0"
if grep -q 'https://github.com/athal7/kb/pull/42' "$OPEN_LOG"; then
  ok "Enter on GH opens in browser (same as alt-o)"
else
  bad "Enter on GH opens in browser (same as alt-o) (got: $(cat "$OPEN_LOG"))"
fi

: > "$OPEN_LOG"
run_act "" "$FIX_LIN_LINE"
check "Enter on LIN exits 0" "$ACT_RC" "0"
if grep -q 'https://linear.app/abc/issue/ABC-1' "$OPEN_LOG"; then
  ok "Enter on LIN opens in browser (same as alt-o)"
else
  bad "Enter on LIN opens in browser (same as alt-o) (got: $(cat "$OPEN_LOG"))"
fi

: > "$PBCOPY_LOG"; : > "$REMINDCTL_ACT_LOG"
run_act "" "$FIX_CAL_LINE"
check "Enter on CAL exits 0 (no-op)" "$ACT_RC" "0"
if [ -s "$PBCOPY_LOG" ] || [ -s "$REMINDCTL_ACT_LOG" ]; then
  bad "Enter on CAL must not invoke any action (pbcopy: $(cat "$PBCOPY_LOG"); remindctl: $(cat "$REMINDCTL_ACT_LOG"))"
else
  ok "Enter on CAL takes no action"
fi

: > "$REMINDCTL_ACT_LOG"
run_act "" "$FIX_REM_LINE"
check "Enter on REM exits 0 (no-op)" "$ACT_RC" "0"
if [ -s "$REMINDCTL_ACT_LOG" ]; then
  bad "Enter on REM must not invoke any action (got: $(cat "$REMINDCTL_ACT_LOG"))"
else
  ok "Enter on REM takes no action"
fi

echo
echo "-- unmapped key for a row's type: brief note, exit 0, no traceback --"

: > "$OPEN_LOG"
run_act "alt-z" "$FIX_GH_LINE"
check "unmapped key exits 0 (not an error)" "$ACT_RC" "0"
case "$ACT_OUTPUT" in
  *Traceback*) bad "unmapped key must not print a traceback (got: $ACT_OUTPUT)" ;;
  *) ok "unmapped key prints a note instead of crashing (got: $ACT_OUTPUT)" ;;
esac
if [ -s "$OPEN_LOG" ]; then
  bad "unmapped key must not invoke any downstream action command (got: $(cat "$OPEN_LOG"))"
else
  ok "unmapped key does not invoke any downstream action command"
fi

echo
echo "-- no redundant quit key: 'q' is not a bound hotkey anywhere --"

: > "$OPEN_LOG"
run_act "q" "$FIX_GH_LINE"
check "'q' exits 0 like any other unmapped key (no special quit exit code)" "$ACT_RC" "0"
if [ -s "$OPEN_LOG" ]; then
  bad "'q' must not invoke any downstream action command (got: $(cat "$OPEN_LOG"))"
else
  ok "'q' does not invoke any downstream action command"
fi

echo
echo "-- merge gate (alt-m): confirm_and_merge() runs as a plain input() prompt, not a second fzf --"

: > "$GH_ACT_LOG"
run_act "alt-m" "$FIX_GH_LINE" "y
"
check "merge confirm 'y' exits 0" "$ACT_RC" "0"
if grep -q 'pr merge --squash --delete-branch 42 --repo athal7/kb' "$GH_ACT_LOG"; then
  ok "merge confirm 'y' invokes gh pr merge --squash --delete-branch"
else
  bad "merge confirm 'y' invokes gh pr merge --squash --delete-branch (got: $(cat "$GH_ACT_LOG"))"
fi

: > "$GH_ACT_LOG"
run_act "alt-m" "$FIX_GH_LINE" "n
"
check "merge confirm 'n' exits 0" "$ACT_RC" "0"
if [ -s "$GH_ACT_LOG" ]; then
  bad "merge confirm 'n' must not invoke gh pr merge (got: $(cat "$GH_ACT_LOG"))"
else
  ok "merge confirm 'n' does not invoke gh pr merge"
fi

: > "$GH_ACT_LOG"
run_act "alt-m" "$FIX_GH_LINE" ""
check "merge confirm EOF (no stdin) exits 0, canceled gracefully" "$ACT_RC" "0"
if [ -s "$GH_ACT_LOG" ]; then
  bad "merge confirm EOF must not invoke gh pr merge (got: $(cat "$GH_ACT_LOG"))"
else
  ok "merge confirm EOF does not invoke gh pr merge"
fi

echo
echo "-- session dispatch (alt-s): title-based slug, no issue-number/timestamp naming --"

: > "$AOE_CMD_LOG"
run_act "alt-s" "$FIX_GH_LINE"
check "GH alt-s exits 0" "$ACT_RC" "0"
gh_session_call="$(cat "$AOE_CMD_LOG")"
case "$gh_session_call" in
  *"-n test-pr -b -w test-pr "*)
    ok "GH alt-s names session/worktree branch from the title slug 'test-pr' (got: $gh_session_call)" ;;
  *)
    bad "GH alt-s names session/worktree branch from the title slug 'test-pr' (got: $gh_session_call)" ;;
esac
case "$gh_session_call" in
  *"issue-42"*) bad "GH alt-s must not name the session/branch after the issue number (got: $gh_session_call)" ;;
  *) ok "GH alt-s does not name the session/branch after the issue number" ;;
esac

: > "$AOE_CMD_LOG"
run_act "alt-s" "$FIX_GH_LINE"
second_call="$(cat "$AOE_CMD_LOG")"
check "GH alt-s produces the identical slug on a repeat invocation (no timestamp suffix)" "$second_call" "$gh_session_call"

: > "$AOE_CMD_LOG"
run_act "alt-s" "$FIX_LIN_LINE"
check "LIN alt-s exits 0" "$ACT_RC" "0"
if grep -q -- '-n fix-bug ' "$AOE_CMD_LOG"; then
  ok "LIN alt-s names the session from the title slug 'fix-bug' (got: $(cat "$AOE_CMD_LOG"))"
else
  bad "LIN alt-s names the session from the title slug 'fix-bug' (got: $(cat "$AOE_CMD_LOG"))"
fi

# ---------------------------------------------------------------------------
echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
