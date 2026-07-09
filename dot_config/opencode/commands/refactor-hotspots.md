---
description: Weekly cross-repo friction-hotspot detection — find files agents repeatedly get stuck on and dispatch refactor sessions
subtask: true
---

Detect files, across every repo ever worked in, that agents repeatedly get stuck on — high cross-session edit/write churn, optionally with an elevated tool-error rate — and dispatch an autonomous refactor session per surviving candidate.

$ARGUMENTS

Optional argument: a repo name or path to scope detection to a single repo. Default: scan all repos in the session DB.

## Skills

- **opencode** — aoe dispatch verbs (`aoe add --worktree`, `aoe session start`, `aoe send`) for the fire-and-forget dispatch flow.

## Step 1 — Repo orientation

Where is friction concentrated, across every repo in the session DB (not just this one)? Group by `project.worktree` (opencode's pre-resolved STABLE primary-checkout path — never NULL, no collisions), NOT `session.directory` (92.5% are branch-suffixed worktree paths — an unstable grouping key). Min-volume floor `>= 200` filters small-N outliers (e.g. a repo at 79 calls / 7.6% error is noise, not a hotspot).

```bash
WINDOW_DAYS=30
DB=~/.local/share/opencode/opencode.db

sqlite3 -readonly "$DB" <<SQL
WITH tool_calls AS (
  SELECT p.session_id, s.project_id, json_extract(p.data,'$.state.status') AS status
  FROM part p JOIN session s ON s.id = p.session_id
  WHERE json_extract(p.data,'$.type') = 'tool'
    AND json_extract(p.data,'$.tool') IN ('edit','write','bash')
)
SELECT pr.worktree AS repo, COUNT(*) AS tool_calls,
       SUM(CASE WHEN tc.status='error' THEN 1 ELSE 0 END) AS errors,
       ROUND(100.0*SUM(CASE WHEN tc.status='error' THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_error
FROM tool_calls tc JOIN project pr ON pr.id = tc.project_id
GROUP BY pr.worktree HAVING tool_calls >= 200
ORDER BY errors DESC LIMIT 15;
SQL
```

## Step 2 — File hotspot detection

The **dispatchable tier**: `edit_calls >= 20 AND sessions_touched >= 5` — cross-session breadth is what makes friction durable, not one session's thrash. Normalizes worktree-branch-suffixed paths to a repo-relative file so the same file across worktrees collapses to one row.

```bash
sqlite3 -readonly "$DB" <<SQL
WITH edits AS (
  SELECT p.session_id, pr.worktree AS repo,
         json_extract(p.data,'$.state.input.filePath') AS file,
         json_extract(p.data,'$.state.status') AS status
  FROM part p JOIN session s ON s.id=p.session_id JOIN project pr ON pr.id=s.project_id
  WHERE json_extract(p.data,'$.tool') IN ('edit','write')
    AND json_extract(p.data,'$.state.input.filePath') IS NOT NULL
),
steps AS (SELECT *, instr(file,'/worktree/') AS pos_wt FROM edits),
steps2 AS (SELECT *, CASE WHEN pos_wt>0 THEN substr(file,pos_wt+10) END AS after_wt FROM steps),
steps3 AS (SELECT *, CASE WHEN after_wt IS NOT NULL THEN substr(after_wt,instr(after_wt,'/')+1) END AS after_hash FROM steps2),
normalized AS (
  SELECT session_id, repo, status,
    CASE
      WHEN file LIKE repo || '/%' THEN substr(file, length(repo)+2)
      WHEN after_hash IS NOT NULL THEN substr(after_hash, instr(after_hash,'/')+1)
      ELSE file
    END AS rel_file
  FROM steps3
)
SELECT repo, rel_file, COUNT(*) AS edit_calls,
       COUNT(DISTINCT session_id) AS sessions_touched,
       SUM(CASE WHEN status='error' THEN 1 ELSE 0 END) AS errors
FROM normalized GROUP BY repo, rel_file
HAVING edit_calls >= 20 AND sessions_touched >= 5
ORDER BY edit_calls DESC LIMIT 12;
SQL
```

**Single-session thrash (watch-only, NOT a dispatch signal):** 3+ edit/write touches to the SAME file within ONE session. Report as FYI in Step 6 — it isn't durable cross-repo friction, and this command doesn't act on it.

```bash
sqlite3 -readonly "$DB" <<SQL
WITH edits AS (
  SELECT p.session_id, json_extract(p.data,'$.state.input.filePath') AS file
  FROM part p
  WHERE json_extract(p.data,'$.tool') IN ('edit','write')
    AND json_extract(p.data,'$.state.input.filePath') IS NOT NULL
)
SELECT session_id, file, COUNT(*) AS touches
FROM edits GROUP BY session_id, file
HAVING COUNT(*) >= 3
ORDER BY touches DESC LIMIT 15;
SQL
```

## Step 3 — Pre-dispatch guard

For each file-hotspot candidate, resolve its `repo` (`project.worktree`) and verify on disk before dispatching: the path must **exist** and be a **git work tree** (`git -C "<repo>" rev-parse --is-inside-work-tree`). Skip ("repo unavailable") if either check fails — the repo may have been moved or deleted.

**Downgrade config/generated files** (`*.tmpl`, `*.json`, `*.lock`, lockfiles like `package-lock.json`, `Gemfile.lock`): tag as "config, not a refactor target" rather than dispatching — high edit volume there is often active by-design configuration, not "stuck" friction.

**Known limitation (do not solve now):** ~1/40 projects is a worktree-only scratch repo with no separate primary clone. Treat as report-only, don't dispatch.

## Step 4 — Dedup / in-flight check

Read `~/.config/opencode/hotspot-dispatch-log.json`, tolerating absence (treat missing file as "no prior dispatches"). Skip a candidate if it has a `dispatches[]` entry with matching `repo` + `rel_file` and `dispatch_date` within the last 180 days, UNLESS `edit_calls` has risen ≥50% versus the logged `signal.edit_calls` (the friction regressed — worth re-dispatching).

Also run `aoe list` (matching titles against the `hotspot-<slug>-*` naming convention used below) and `git -C "<repo>" branch --list 'refactor/hotspot-<slug>'` — if a live session or branch already targets that file, mark **"in flight — skip"**.

## Step 5 — Dispatch (autonomous, fire-and-forget)

For each surviving candidate, dispatch a refactor session. `aoe send` is fire-and-forget — it fires the prompt into the new session's tmux pane without waiting for the run to finish, which would blow this command's timeout budget across multiple hotspots.

`<slug>` is a deterministic slugification of `rel_file` (slashes and dots → dashes), used identically in the worktree branch name, the session title, and the log entry so the Step-4 `git branch --list`/`aoe list` dedup checks match on future runs.

```bash
add_output=$(aoe add "<repo>" --tool opencode --worktree "refactor/hotspot-<slug>" --new-branch --title "hotspot-<slug>-$(date +%Y%m%d-%H%M%S)")
SID=$(printf '%s\n' "$add_output" | awk '/^  ID:/ {print $2}')
aoe session start "$SID"
sleep 5   # let opencode's TUI finish booting in the fresh tmux pane before sending
aoe send "$SID" "As your first action, before anything else, read this repo's own AGENTS.md and any openspec/ specs. Determine whether <rel_file>'s high edit/error volume reflects genuine structural friction (agents keep getting stuck) versus intentional by-design churn (e.g. actively hand-tuned configuration, or a file whose spec mandates frequent change). If by-design, report 'not a refactor target' and stop — do not implement anything. Only if it's genuine friction: Workflow: implement. Propose a refactor of <rel_file> that reduces edit friction (split up, clarify structure, add missing docs/tests) WITHOUT changing external behavior. Evidence: <edit_calls> edit/write calls across <sessions_touched> sessions, <errors> tool errors (<pct_error>% where computable)."
```

After a successful dispatch, this command itself (not a human) appends to the log:

```bash
jq '.dispatches += [{repo:"<repo>",rel_file:"<rel_file>",dispatch_date:"'"$(date +%F)"'",branch:"refactor/hotspot-<slug>",signal:{edit_calls:<n>,sessions_touched:<m>,errors:<e>},status:"dispatched"}]' \
  ~/.config/opencode/hotspot-dispatch-log.json > /tmp/hdl.json && mv /tmp/hdl.json ~/.config/opencode/hotspot-dispatch-log.json
```

## Step 6 — Report

List: hotspots found, dispatches fired (with worktree path and branch name), and candidates skipped (with reason: in-flight, deduped, config-tagged, or repo-unavailable). Also mention any single-session-thrash rows as an FYI — report only, not actionable via this command; a human investigating that one session's transcript is the appropriate follow-up, not a cross-repo dispatch.

## File locations

| Target | Source |
|---|---|
| `~/.local/share/opencode/opencode.db` | Session data for hotspot detection |
| `~/.config/opencode/hotspot-dispatch-log.json` | `dot_config/opencode/create_hotspot-dispatch-log.json` — this command reads AND writes it (no human step required) |

Run `/refactor-hotspots` weekly.
