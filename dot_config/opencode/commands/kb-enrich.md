---
description: Daily knowledge base enrichment — enrich profiles, journal, and decisions for each date since the last run
subtask: true
---

Run the daily knowledge base enrichment. By default enrich every date since the last run (see **Date range** below), not just today; honor an explicit date or range given in arguments instead.

$ARGUMENTS

## Sources

Check activity across all available sources:

- **opencode** coding sessions
- **slack** chat messages and threads
- **zoom** meeting transcripts
- **linear** issues and comments
- **gh** code reviews, PRs, and issues
- **openspec durable store (AUTHORITATIVE for `/implement` work)** — each worktree's `openspec/` carries two narrow symlinks into a durable per-repo store at `~/.local/share/kb/openspec/<repo-slug>/` (`openspec/specs` → store `specs/`, `openspec/changes/archive` → store `changes/archive/`). At Ship, `openspec archive` moves a completed change through the `changes/archive` symlink into the store, so its artifacts persist regardless of when work shipped. For each date being enriched, read `~/.local/share/kb/openspec/*/changes/archive/<date>-*/design.md` for decisions, the "why", and rejected alternatives, and read each store's durable `specs/` for the standing requirements. These structured artifacts are the source of truth for the reasoning behind completed `/implement` work — use them instead of reconstructing it from full (token-expensive, lossy) session transcripts.

### Session exclusion — the core token-saving dedup

The openspec store is authoritative for `/implement` work, so the sessions that PRODUCED an archived change must be EXCLUDED from transcript reads. Build the exclusion set and skip those sessions:

1. **Collect excluded worktrees.** For each date being enriched, read every `~/.local/share/kb/openspec/*/changes/archive/<date>-*/kb-meta.yaml` and collect its `worktree:` value (the absolute repo/worktree root, stamped at archive). That set is the exclusion list.
2. **Skip those sessions.** When scanning **opencode** sessions, a session is identified by its `directory` column in the `session` table of `~/.local/share/opencode/opencode.db`. SKIP any session whose `directory` is in the exclusion set — for those, narrate from the change's `design.md`/specs, not the transcript. Only sessions NOT covered by an archived change get a transcript read.
3. **Filter at query time.** Pass the collected worktrees as the `NOT IN (...)` list and bound by the date window (`time_updated` is epoch-ms):

   ```sql
   SELECT id, directory, title, time_updated
   FROM session
   WHERE time_updated BETWEEN :start_ms AND :end_ms
     AND directory NOT IN ('/abs/worktree/a', '/abs/worktree/b');
   -- returned sessions are the ONLY ones that need a transcript read;
   -- excluded directories are covered by the durable change artifacts instead.
   ```

**Benign failure modes** (neither loses correctness): a missed match (stale/absent `kb-meta.yaml`) just wastes one transcript read; an over-match (a session in an excluded worktree that wasn't really part of the change) just relies on the better, distilled artifact instead of the transcript.

## Enrichment Steps

1. **Extract** people facts, project updates, and decisions from each source
2. **Journal** — write one cross-project rollup journal file per enriched date, each with diff stats. By construction each is THIN: feed it only from the NON-excluded sessions (those not covered by an archived change) plus git diff-stats. For `/implement` work, do NOT re-narrate the openspec change — reference the durable store artifacts (`design.md`/specs already in the kb via the symlink). The journal's role is the cross-project rollup + non-`/implement` activity, not a reconstruction of openspec work. Keep it; just don't duplicate the store.
3. **Profiles** — merge new facts into knowledge-base people and project profiles
4. **Decisions** — add any decisions to the decisions log. Pull key design decisions and rejected alternatives from the durable store's `~/.local/share/kb/openspec/*/changes/archive/<date>-*/design.md` (READ, don't copy — the artifacts are already in the kb). The decisions log is a distilled record anchored to its product/project, not a dump of the design files.
5. **Action items** — extract action items from the enriched window's activity. Cross-reference within the same activity data — if the activity shows you already took the action (replied to the thread, reviewed the PR, closed the issue), skip the reminder. Only create reminders for items that were not resolved within the enriched window.

## Privacy

Do not extract or store:
- Health information
- Compensation details
- Performance evaluations
- Legal or attorney-client privileged content
- Content from HR-related discussions

## Date range

Enrich the gap since the last run, not a hard single day. The most recent `~/.local/share/kb/journal/YYYY-MM-DD.md` is the last-run marker: enrich each date from (last journal date + 1) through today, inclusive. This makes a Monday run sweep the trailing weekend and lets a skipped run self-heal on the next run. If no prior journal exists, default to today. An explicit date or range in arguments overrides this.
