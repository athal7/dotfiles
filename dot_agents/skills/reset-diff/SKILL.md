---
name: reset-diff
description: Reset "Modified Files" sidebar to match actual git state
license: MIT
metadata:
  author: athal7
  version: "1.0"
---

Reset the "Modified Files" panel so it reflects only this branch's changes against the default branch — not commits merged/rebased in from main. Run this after committing, rebasing, or merging when the sidebar shows stale or noisy diffs.

The baseline is set to `git merge-base HEAD <default-branch>`, so the panel shows exactly what this branch contributed, regardless of how it was updated against the upstream.

The session is always auto-detected from the current working directory (most recently updated session matching `pwd`).

## Steps

All steps use `DB=~/.local/share/opencode/opencode.db`. Run each step as a single bash invocation with all variables inline — do not rely on variables persisting between separate bash calls.

### 1. Resolve session

Auto-detect from the current working directory:

```bash
DB=~/.local/share/opencode/opencode.db
SESSION=$(sqlite3 "$DB" "SELECT id FROM session WHERE directory = '$(pwd)' ORDER BY time_updated DESC LIMIT 1")
[ -z "$SESSION" ] && { echo "error: no session found for $(pwd)"; exit 1; }
echo "session: $SESSION"

sqlite3 "$DB" "SELECT s.id, s.directory, s.project_id, p.vcs
  FROM session s LEFT JOIN project p ON p.id = s.project_id
  WHERE s.id = '$SESSION'"
```

If not found, report error. If `vcs` is not `git`, report "nothing to change" and stop.
Save SESSION_ID, DIRECTORY, and PROJECT_ID for subsequent steps.

### 2. Clear stale snapshots and patch parts

Remove `snapshot` from all step-start/step-finish parts, and delete `patch` parts for committed files. The `patch` parts are critical — `summarizeSession` uses them to filter which files appear in the sidebar. If they're not cleared, resuming the session will reconstruct the old diff.

Use `\$` to escape `$` in JSON paths inside bash double-quoted strings:

```bash
DB=~/.local/share/opencode/opencode.db
SESSION='<SESSION_ID>'
sqlite3 "$DB" "
  UPDATE part SET data = json_remove(data, '\$.snapshot')
  WHERE session_id = '$SESSION'
    AND (json_extract(data, '\$.type') = 'step-start' OR json_extract(data, '\$.type') = 'step-finish')
    AND json_extract(data, '\$.snapshot') IS NOT NULL;
  SELECT 'cleared snapshots: ' || changes();
"
```

Then remove `patch` parts whose files are no longer uncommitted. Run in one bash call (use `workdir` set to the session's directory):

```bash
DB=~/.local/share/opencode/opencode.db
SESSION='<SESSION_ID>'

# Get list of currently uncommitted files (tracked changes + untracked)
UNCOMMITTED=$(mktemp)
{ git diff --name-only HEAD -- . 2>/dev/null; git ls-files --others --exclude-standard -- . 2>/dev/null; } | sort -u > "$UNCOMMITTED"

# Get all patch part IDs and their files
sqlite3 "$DB" "SELECT id, json_extract(data, '\$.files') FROM part WHERE session_id = '$SESSION' AND json_extract(data, '\$.type') = 'patch'" | \
while IFS='|' read -r part_id files_json; do
  # Check if ANY file in this patch is still uncommitted
  keep=false
  for f in $(echo "$files_json" | jq -r '.[]' 2>/dev/null); do
    relpath=$(echo "$f" | sed "s|^$(git rev-parse --show-toplevel)/||")
    if grep -qxF "$relpath" "$UNCOMMITTED"; then
      keep=true
      break
    fi
  done
  if [ "$keep" = false ]; then
    echo "$part_id"
  fi
TODELETE=$(mktemp)
done > "$TODELETE"

COUNT=$(wc -l < "$TODELETE" | tr -d ' ')
if [ "$COUNT" -gt 0 ]; then
  # Build comma-separated quoted list for SQL IN clause
  IDS=$(awk '{printf "\x27%s\x27,", $0}' "$TODELETE" | sed 's/,$//')
  sqlite3 "$DB" "DELETE FROM part WHERE id IN ($IDS); SELECT 'deleted patches: ' || changes();"
else
  echo "deleted patches: 0"
fi

rm -f "$UNCOMMITTED" "$TODELETE"
```

### 3. Create baseline snapshots

The baseline (`FROM`) is the merge-base of HEAD with the default branch, so the panel shows only this branch's unique changes — not commits merged/rebased in from main.

Run in one bash call, using `workdir` set to the session's directory:

```bash
DB=~/.local/share/opencode/opencode.db
SESSION='<SESSION_ID>'
PROJECT='<PROJECT_ID>'
WORKTREE=$(git rev-parse --show-toplevel)
REAL_GIT=$(git rev-parse --absolute-git-dir)
SNAPSHOT_GIT=~/.local/share/opencode/snapshot/$PROJECT

# Init snapshot repo if needed
mkdir -p "$SNAPSHOT_GIT/objects/info"
[ -f "$SNAPSHOT_GIT/HEAD" ] || GIT_DIR="$SNAPSHOT_GIT" GIT_WORK_TREE="$WORKTREE" git init --quiet
grep -qxF "$REAL_GIT/objects" "$SNAPSHOT_GIT/objects/info/alternates" 2>/dev/null || \
  echo "$REAL_GIT/objects" >> "$SNAPSHOT_GIT/objects/info/alternates"

# Detect default branch (prefer origin/HEAD, fall back to main, then master)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
if [ -z "$DEFAULT_BRANCH" ]; then
  for b in main master; do
    if git rev-parse --verify "origin/$b" >/dev/null 2>&1; then
      DEFAULT_BRANCH="$b"; break
    fi
  done
fi
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="main"

# FROM = merge-base of HEAD with default branch (shows only this branch's changes)
# Falls back to HEAD tree if merge-base fails (e.g. no remote, initial branch)
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  MERGE_BASE=$(git merge-base HEAD "origin/$DEFAULT_BRANCH" 2>/dev/null || git merge-base HEAD "$DEFAULT_BRANCH" 2>/dev/null)
  if [ -n "$MERGE_BASE" ]; then
    FROM=$(git rev-parse "${MERGE_BASE}^{tree}")
    echo "baseline: merge-base with $DEFAULT_BRANCH (${MERGE_BASE:0:12})"
  else
    FROM=$(git rev-parse HEAD^{tree})
    echo "baseline: HEAD (no merge-base found, default branch: $DEFAULT_BRANCH)"
  fi
else
  FROM=$(git hash-object -t tree /dev/null)
  echo "baseline: empty tree (no commits)"
fi
git --git-dir "$SNAPSHOT_GIT" --work-tree "$WORKTREE" read-tree "$FROM"
git --git-dir "$SNAPSHOT_GIT" --work-tree "$WORKTREE" add -A -- .
TO=$(git --git-dir "$SNAPSHOT_GIT" --work-tree "$WORKTREE" write-tree)

# Inject baseline parts anchored to first assistant message
MSG_ID=$(sqlite3 "$DB" "SELECT id FROM message WHERE session_id = '$SESSION' AND json_extract(data, '\$.role') = 'assistant' ORDER BY id ASC LIMIT 1")
NOW=$(date +%s)000

sqlite3 "$DB" "
  INSERT OR REPLACE INTO part (id, message_id, session_id, time_created, time_updated, data)
  VALUES
    ('prt_reset_start_$SESSION', '$MSG_ID', '$SESSION', $NOW, $NOW,
     '{\"type\":\"step-start\",\"snapshot\":\"$FROM\"}'),
    ('prt_reset_finish_$SESSION', '$MSG_ID', '$SESSION', $NOW, $NOW,
     '{\"type\":\"step-finish\",\"reason\":\"stop\",\"cost\":0,\"tokens\":{\"input\":0,\"output\":0,\"reasoning\":0,\"cache\":{\"read\":0,\"write\":0}},\"snapshot\":\"$TO\"}')
"
echo "baseline: ${FROM:0:12} -> ${TO:0:12}"
```

### 4. Write diff manifest and update summary

Build the session_diff JSON using the same merge-base as step 3. All in one bash call (use `workdir` set to the session's directory):

```bash
DB=~/.local/share/opencode/opencode.db
SESSION='<SESSION_ID>'
STORAGE=~/.local/share/opencode/storage/session_diff/${SESSION}.json

# Detect default branch (same logic as step 3)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
if [ -z "$DEFAULT_BRANCH" ]; then
  for b in main master; do
    if git rev-parse --verify "origin/$b" >/dev/null 2>&1; then
      DEFAULT_BRANCH="$b"; break
    fi
  done
fi
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="main"

# Use merge-base as diff base (same as step 3 baseline)
MERGE_BASE=$(git merge-base HEAD "origin/$DEFAULT_BRANCH" 2>/dev/null || git merge-base HEAD "$DEFAULT_BRANCH" 2>/dev/null)
DIFF_BASE=${MERGE_BASE:-HEAD}

# Collect name-status upfront into a temp file for O(1) lookups
STATFILE=$(mktemp)
git -c core.quotepath=false diff --no-ext-diff --no-renames --name-status "$DIFF_BASE" -- . 2>/dev/null > "$STATFILE"

{
  # Tracked changes vs merge-base
  git -c core.quotepath=false diff --no-ext-diff --no-renames --numstat "$DIFF_BASE" -- . 2>/dev/null | \
    awk -F'\t' 'NF>=3 { a=($1=="-"?0:$1); d=($2=="-"?0:$2); print $3"\t"a"\t"d }' | \
    while IFS=$'\t' read -r f a d; do
      st=$(awk -F'\t' -v file="$f" '$2==file { if ($1~/^A/) print "added"; else if ($1~/^D/) print "deleted"; else print "modified"; exit }' "$STATFILE")
      [ -z "$st" ] && st="modified"
      jq -n --arg f "$f" --argjson a "$a" --argjson d "$d" --arg s "$st" \
        '{file:$f, before:"", after:"", additions:$a, deletions:$d, status:$s}'
    done

  # Untracked files
  git -c core.quotepath=false ls-files --others --exclude-standard -- . 2>/dev/null | \
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      jq -n --arg f "$f" '{file:$f, before:"", after:"", additions:0, deletions:0, status:"added"}'
    done
} | jq -s 'sort_by(.file)' > "$STORAGE"

rm -f "$STATFILE"

FILES=$(jq 'length' "$STORAGE")
ADDITIONS=$(jq '[.[].additions] | add // 0' "$STORAGE")
DELETIONS=$(jq '[.[].deletions] | add // 0' "$STORAGE")

sqlite3 "$DB" "
  UPDATE session
  SET summary_additions = $ADDITIONS, summary_deletions = $DELETIONS,
      summary_files = $FILES, summary_diffs = NULL, revert = NULL
  WHERE id = '$SESSION'
"

echo "files: $FILES (+$ADDITIONS -$DELETIONS)"
echo "storage: $STORAGE"
```

### 5. Report

Print a summary:
- Session ID
- Cleared snapshot count (from step 2)
- Deleted patch count (from step 2)
- Baseline hashes (from step 3)
- Uncommitted file count and totals (from step 4)
- Storage path

The sidebar will update on the next prompt in that session (triggers `summarizeSession` which reads the new baseline).
