#!/usr/bin/env bash
# Functional tests for the opencode-cleanup tooling. Plain bash, no bats.
# Everything runs against temp fixtures under a throwaway dir — NEVER the real
# opencode DB, worktrees, postgres, /tmp, or QA dir. Run by the pre-commit hook
# and standalone.
#
#   scripts/test-opencode-cleanup.sh

set -euo pipefail

# Isolate from any git env injected by a pre-commit hook (GIT_DIR/GIT_INDEX_FILE
# etc. would otherwise redirect our fixture git commands at the parent repo).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR GIT_NAMESPACE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES 2>/dev/null || true

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/dot_config/opencode/bin"
CLEANUP="$BIN/executable_opencode-cleanup"
DB_MAINTAIN="$BIN/executable_opencode-db-maintain"
DB_COMPACT="$BIN/executable_opencode-db-compact"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cleanup-test.XXXXXX")"
trap 'rm -rf "$WORK"; kill "${SENTINEL_PID:-}" 2>/dev/null || true' EXIT INT TERM

pass=0; fail=0
ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (want '$3' got '$2')"; fi; }

# Faithful copy of the live schema for the four tables we touch. Foreign keys are
# defined but, as in production, foreign_keys stays OFF so no cascade fires —
# this is exactly what makes children-first deletion mandatory.
make_db() {
	local db="$1"
	sqlite3 "$db" <<'SQL'
CREATE TABLE project (
  id text PRIMARY KEY, worktree text NOT NULL, vcs text, name text,
  icon_url text, icon_color text, time_created integer NOT NULL,
  time_updated integer NOT NULL, time_initialized integer, sandboxes text NOT NULL
);
CREATE TABLE session (
  id text PRIMARY KEY, project_id text NOT NULL, parent_id text, slug text NOT NULL,
  directory text NOT NULL, title text NOT NULL, version text NOT NULL, share_url text,
  time_created integer NOT NULL, time_updated integer NOT NULL,
  CONSTRAINT fk_s FOREIGN KEY (project_id) REFERENCES project(id) ON DELETE CASCADE
);
CREATE TABLE message (
  id text PRIMARY KEY, session_id text NOT NULL, time_created integer NOT NULL,
  time_updated integer NOT NULL, data text NOT NULL,
  CONSTRAINT fk_m FOREIGN KEY (session_id) REFERENCES session(id) ON DELETE CASCADE
);
CREATE TABLE part (
  id text PRIMARY KEY, message_id text NOT NULL, session_id text NOT NULL,
  time_created integer NOT NULL, time_updated integer NOT NULL, data text NOT NULL,
  CONSTRAINT fk_p FOREIGN KEY (message_id) REFERENCES message(id) ON DELETE CASCADE
);
SQL
}

q() { sqlite3 "$1" "$2"; }

# ---------------------------------------------------------------------------
echo "== DB maintain =="
test_db() {
	local db="$WORK/oc.db"
	make_db "$db"
	local now recent old
	now=$(( $(date +%s) * 1000 ))
	recent=$now
	old=$(( now - 200 * 86400 * 1000 ))   # ~200 days => beyond 90d retention

	q "$db" "INSERT INTO project VALUES ('p','/repo',NULL,NULL,NULL,NULL,0,0,NULL,'[]');"

	# session + 1 message + 1 part helper
	seed_session() { # id parent share_url time_updated
		q "$db" "INSERT INTO session VALUES ('$1','p',$( [ "$2" = "-" ] && echo NULL || echo "'$2'"),'s','/d','t','v',$( [ "$3" = "-" ] && echo NULL || echo "'$3'"),$4,$4);"
		q "$db" "INSERT INTO message VALUES ('m_$1','$1',$4,$4,'{}');"
		q "$db" "INSERT INTO part VALUES ('pt_$1','m_$1','$1',$4,$4,'{}');"
	}
	seed_session recent  - - "$recent"          # keep
	seed_session oldroot - - "$old"             # delete (old, unpublished)
	seed_session pub     - "https://x" "$old"   # keep (published, despite age)
	# parent/child: parent old -> child must go too
	seed_session par     - - "$old"
	seed_session child   par - "$recent"        # recent but parent doomed -> deleted

	# Orphans: part with no session; message with no session; part orphaned by msg.
	q "$db" "INSERT INTO part VALUES ('orphan_p','no_msg','no_session',0,0,'{}');"
	q "$db" "INSERT INTO message VALUES ('orphan_m','no_session',0,0,'{}');"
	q "$db" "INSERT INTO message VALUES ('m_real','recent',$recent,$recent,'{}');"
	q "$db" "INSERT INTO part VALUES ('part_nomsg','gone_msg','recent',0,0,'{}');"

	OPENCODE_DB="$db" CLEANUP_BATCH_SLEEP=0 bash "$DB_MAINTAIN" --older-than=90 --batch=2 >/dev/null

	check "recent session kept"        "$(q "$db" "SELECT COUNT(*) FROM session WHERE id='recent';")" 1
	check "old unpublished deleted"    "$(q "$db" "SELECT COUNT(*) FROM session WHERE id='oldroot';")" 0
	check "published kept"             "$(q "$db" "SELECT COUNT(*) FROM session WHERE id='pub';")" 1
	check "old parent deleted"         "$(q "$db" "SELECT COUNT(*) FROM session WHERE id='par';")" 0
	check "doomed child deleted"       "$(q "$db" "SELECT COUNT(*) FROM session WHERE id='child';")" 0
	check "no session-less parts"      "$(q "$db" "SELECT COUNT(*) FROM part WHERE session_id NOT IN (SELECT id FROM session);")" 0
	check "no session-less messages"   "$(q "$db" "SELECT COUNT(*) FROM message WHERE session_id NOT IN (SELECT id FROM session);")" 0
	check "no message-less parts"      "$(q "$db" "SELECT COUNT(*) FROM part WHERE message_id NOT IN (SELECT id FROM message);")" 0
	# children-first proof: every surviving part/message belongs to a session.
	check "no new orphans (children-first)" "$(q "$db" "SELECT (SELECT COUNT(*) FROM part WHERE session_id NOT IN (SELECT id FROM session)) + (SELECT COUNT(*) FROM message WHERE session_id NOT IN (SELECT id FROM session));")" 0
}
test_db

echo "== DB maintain: incremental_vacuum on auto_vacuum=0 does not error =="
test_vacuum() {
	local db="$WORK/oc2.db"; make_db "$db"
	check "auto_vacuum starts 0" "$(q "$db" "PRAGMA auto_vacuum;")" 0
	if OPENCODE_DB="$db" CLEANUP_BATCH_SLEEP=0 bash "$DB_MAINTAIN" --older-than=90 >/dev/null 2>&1; then
		ok "vacuum no-op succeeded"
	else
		bad "vacuum no-op errored"
	fi
}
test_vacuum

echo "== DB maintain: dry-run mutates nothing =="
test_db_dryrun() {
	local db="$WORK/oc3.db"; make_db "$db"
	q "$db" "INSERT INTO project VALUES ('p','/r',NULL,NULL,NULL,NULL,0,0,NULL,'[]');"
	q "$db" "INSERT INTO session VALUES ('old','p',NULL,'s','/d','t','v',NULL,0,0);"
	q "$db" "INSERT INTO part VALUES ('o','nm','ns',0,0,'{}');"
	OPENCODE_DB="$db" bash "$DB_MAINTAIN" --dry-run --older-than=90 >/dev/null
	check "dry-run keeps old session" "$(q "$db" "SELECT COUNT(*) FROM session;")" 1
	check "dry-run keeps orphan part" "$(q "$db" "SELECT COUNT(*) FROM part;")" 1
}
test_db_dryrun

# ---------------------------------------------------------------------------
echo "== Worktree classification =="
test_worktrees() {
	local repo="$WORK/repo" base="$WORK/wtbase/projX"
	mkdir -p "$base"
	git init -q "$repo"
	git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
	git -C "$repo" commit -q --allow-empty -m init

	# active worktree (recent, clean)
	git -C "$repo" worktree add -q -b feat-active "$base/active" >/dev/null 2>&1

	# dirty worktree
	git -C "$repo" worktree add -q -b feat-dirty "$base/dirty" >/dev/null 2>&1
	echo change > "$base/dirty/file.txt"

	# stale registered worktree: registered, but the on-disk dir is removed.
	git -C "$repo" worktree add -q -b feat-stale "$base/stale" >/dev/null 2>&1
	rm -rf "$base/stale"

	# unregistered tmp-only stub, made old.
	mkdir -p "$base/stub/tmp"
	touch -t 202001010000 "$base/stub" "$base/stub/tmp"

	# An empty DB so session lookups return nothing (no recent sessions).
	local db="$WORK/wt.db"; make_db "$db"

	local out
	out="$(OPENCODE_DB="$db" OPENCODE_WORKTREE_BASE="$WORK/wtbase" \
		bash "$CLEANUP" --worktrees --dry-run --older-than=7 2>&1)"

	if grep -q "active-keep .*/active/" <<<"$out"; then ok "active -> active-keep"; else bad "active classification"; printf '%s\n' "$out"; fi
	if grep -q "dirty-skip .*/dirty/" <<<"$out"; then ok "dirty -> dirty-skip"; else bad "dirty classification"; fi
	if grep -q "stub-remove .*/stub/" <<<"$out"; then ok "old stub -> stub-remove"; else bad "stub classification"; fi
	if grep -q "stale-prune .*/stale" <<<"$out"; then ok "missing registered -> stale-prune"; else bad "stale classification"; fi
	# Safety: dirty must never be slated for removal.
	if grep -q "active-remove .*/dirty/" <<<"$out"; then bad "dirty wrongly marked for removal"; else ok "dirty never removed"; fi
}
test_worktrees

# ---------------------------------------------------------------------------
echo "== Postgres keep-set (pure function) =="
test_pg() {
	# shellcheck source=/dev/null
	CLEANUP_LIB=1 . "$CLEANUP"

	local all_dbs keep drop
	all_dbs="$(cat <<'EOF'
postgres
template0
template1
myapp_development
myapp_development_cable
myapp_development_cache
myapp_development_queue
myapp_test
myapp_test-0
myapp_test_cable
feat-live_myapp_development
feat-live_myapp_development_cable
feat-dead_myapp_development
feat-dead_myapp_development_queue
some-very-long-branch-name-that-exceeds-the-limit-aaaa_myapp_develo
EOF
)"
	# Live checkouts: main (empty prefix) + feat-live + a long branch that
	# truncates to the same 63-char name present above.
	keep="$(cat <<'EOF'
myapp_development
myapp_development_cable
myapp_development_cache
myapp_development_queue
feat-live_myapp_development
feat-live_myapp_development_cable
some-very-long-branch-name-that-exceeds-the-limit-aaaa_myapp_development
EOF
)"
	drop="$(compute_pg_drop_set "myapp" "$keep" "$all_dbs")"

	if ! grep -q '^feat-dead_myapp_development$' <<<"$drop"; then bad "dead branch not in drop-set"; else ok "dead branch dropped"; fi
	if grep -q 'myapp_test' <<<"$drop"; then bad "test db in drop-set"; else ok "test dbs protected"; fi
	if grep -q '^myapp_development' <<<"$drop"; then bad "base dev db in drop-set"; else ok "base dev dbs protected"; fi
	if grep -q 'feat-live' <<<"$drop"; then bad "live branch in drop-set"; else ok "live branch kept"; fi
	if grep -qE 'postgres|template' <<<"$drop"; then bad "system db in drop-set"; else ok "system dbs ignored"; fi
	# 63-char truncation collision: the long live branch protects the truncated db.
	if grep -q 'some-very-long-branch' <<<"$drop"; then bad "truncated-63 collision not honored"; else ok "truncated-63 collision honored"; fi
}
test_pg

echo "== Postgres app token from database.yml (anchor must not win) =="
test_pg_app_token() {
	# shellcheck source=/dev/null
	CLEANUP_LIB=1 . "$CLEANUP"

	# Faithful myapp shape: a YAML anchor `&primary_development` appears BEFORE the
	# real `database:` value line. The token must come from the value, not the key.
	local repo="$WORK/myapprepo"; mkdir -p "$repo/config"
	cat >"$repo/config/database.yml" <<'EOF'
development:
  primary: &primary_development
    database: <%= ENV.fetch("DATABASE_PREFIX", "") %>myapp_development
  cache:
    <<: *primary_development
    database: <%= ENV.fetch("DATABASE_PREFIX", "") %>myapp_development_cache
test:
  database: myapp_test
EOF
	check "app token from database: value" "$(pg_app_for_repo "$repo")" myapp
}
test_pg_app_token

# ---------------------------------------------------------------------------
echo "== tmp scratch (dry-run + exclusions) =="
test_tmp() {
	local tmp="$WORK/tmpdir"; mkdir -p "$tmp"
	: >"$tmp/scratch1.md"; : >"$tmp/scratch2.json"
	: >"$tmp/keep.lock"; : >"$tmp/LCK.x"; : >"$tmp/com.apple.foo"
	mkdir -p "$tmp/TemporaryDirectory.abc"
	local out
	out="$(CLEANUP_TMP_DIR="$tmp" bash "$CLEANUP" --tmp --dry-run 2>&1)"
	if grep -q '2 scratch file' <<<"$out"; then ok "counts only non-excluded files"; else bad "tmp count"; printf '%s\n' "$out"; fi
	if grep -qE 'keep.lock|LCK|com.apple|TemporaryDirectory' <<<"$out"; then bad "excluded file listed"; else ok "exclusions honored"; fi
	# nothing actually deleted
	check "tmp dry-run deletes nothing" "$(find "$tmp" -maxdepth 1 -type f | wc -l | tr -d ' ')" 5
}
test_tmp

echo "== QA prune (dry-run + depth) =="
test_qa() {
	local qa="$WORK/qa"; mkdir -p "$qa/projA" "$qa/demos"
	mkdir -p "$qa/projA/qa-old" "$qa/projA/qa-new"
	touch -t 202001010000 "$qa/projA/qa-old"
	: >"$qa/demos/demo-old.html"; touch -t 202001010000 "$qa/demos/demo-old.html"
	: >"$qa/demos/demo-new.html"
	local out
	out="$(OPENCODE_QA_DIR="$qa" bash "$CLEANUP" --qa --dry-run 2>&1)"
	if grep -q '2 QA artifact' <<<"$out"; then ok "counts old session + old deck"; else bad "qa count"; printf '%s\n' "$out"; fi
	if grep -q 'qa-new' <<<"$out"; then bad "recent session listed"; else ok "recent session excluded"; fi
	if grep -q 'demo-new' <<<"$out"; then bad "recent deck listed"; else ok "recent deck excluded"; fi
}
test_qa

# ---------------------------------------------------------------------------
echo "== db-compact =="
test_compact() {
	local db="$WORK/compact.db"; make_db "$db"
	local out
	out="$(OPENCODE_DB="$db" bash "$DB_COMPACT" --dry-run 2>&1)"
	if grep -q 'dry-run) Plan' <<<"$out"; then ok "dry-run reports plan"; else bad "compact dry-run"; printf '%s\n' "$out"; fi
	if grep -q 'VACUUM' <<<"$out"; then ok "plan mentions VACUUM"; else bad "plan missing VACUUM"; fi

	# Live-holder classification (white-box, injected fixtures). Source the
	# script as a library (CLEANUP_LIB=1) and override the lsof PID enumeration
	# and the per-PID `ps` lookup with synthetic data so we can exercise the
	# classifier without any live process. Every resolved PID is a live holder —
	# no exemptions (no daemon, no Desktop app to special-case anymore).
	# shellcheck source=/dev/null
	(
		CLEANUP_LIB=1 OPENCODE_DB="$db" . "$DB_COMPACT"
		set +e   # the sourced lib enables `set -e`; grep/test guards below need it off

		# shellcheck disable=SC2329,SC2317  # invoked indirectly via db_live_holders
		db_pid_command() {
			case "$1" in
				101) echo "/opt/homebrew/bin/opencode" ;;
				103) echo "/usr/local/bin/opencode serve --hostname 127.0.0.1" ;;
				*)   echo "" ;;
			esac
		}

		# A live opencode TUI process is a holder.
		# shellcheck disable=SC2329,SC2317  # invoked indirectly via db_live_holders
		db_holder_pids() { printf '%s\n' 101; }
		db_live_holders | grep -q '^101' && echo TUI_LIVE_OK

		# A hand-started `opencode serve` is also a holder — no exemption.
		# shellcheck disable=SC2329,SC2317  # invoked indirectly via db_live_holders
		db_holder_pids() { printf '%s\n' 103; }
		db_live_holders | grep -q '^103' && echo SERVE_LIVE_OK

		# An already-gone PID (empty resolved command) is NOT a holder.
		# shellcheck disable=SC2329,SC2317  # invoked indirectly via db_live_holders
		db_holder_pids() { printf '%s\n' 999; }
		[ -z "$(db_live_holders)" ] && echo GONE_PID_NOT_HOLDER_OK

		# No holders at all -> nothing live.
		# shellcheck disable=SC2329,SC2317  # invoked indirectly via db_live_holders
		db_holder_pids() { :; }
		[ -z "$(db_live_holders)" ] && echo NONE_OK
	) >"$WORK/compact.cls" 2>&1
	check "TUI process is a holder"      "$(grep -c TUI_LIVE_OK "$WORK/compact.cls" | tr -d ' ')" 1
	check "opencode serve is a holder"   "$(grep -c SERVE_LIVE_OK "$WORK/compact.cls" | tr -d ' ')" 1
	check "gone PID is not a holder"     "$(grep -c GONE_PID_NOT_HOLDER_OK "$WORK/compact.cls" | tr -d ' ')" 1
	check "no holders -> none live"      "$(grep -c NONE_OK "$WORK/compact.cls" | tr -d ' ')" 1
}
test_compact

# ---------------------------------------------------------------------------
echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
