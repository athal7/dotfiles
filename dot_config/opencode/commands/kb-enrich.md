---
description: Knowledge base enrichment — enrich profiles, journal, and decisions for each date since the last run
subtask: true
---

Enrich the knowledge base for every date since the last run using the `kb` CLI and `kb-git-activity` CLI tools. An explicit date or range given in arguments overrides.

$ARGUMENTS

## Step 1 — Resolve date range

To determine the last-run marker, query the daily journals. Work from the last-recorded journal date + 1 through today, inclusive. This makes a Monday run sweep the trailing weekend and lets a skipped run self-heal on the next run. If no prior journals are found, default to today. An explicit date or range in arguments overrides this.

## Step 2 — Load collectors

Collectors live at `~/.config/kb/collectors/*.md`. Which collectors run is determined by the enabled list in chezmoi local config:

```
chezmoi data --format json | jq -r '.kb.collectors[]'
```

Run only the listed collectors. If the key is absent, log "kb.collectors not configured" and stop.

## Step 3 — Run each collector

For each enabled collector, apply its embedded query recipe and triage/extraction rules against the resolved date window. Collectors are independent — run them in any order. The opencode collector handles its own internal openspec→exclusion→sessions sequencing.

## Step 4 — Write outputs

After all collectors have run, write the enrichment outputs exclusively using the `kb` and `kb-git-activity` CLI interfaces:

1. **Journal Rollup**: For each enriched date, automatically derive and append the daily git coding statistics by executing the command:
   ```bash
   kb-git-activity --dir ~/code --date <date>
   ```
   For non-git rollup and non-`/implement` activity, append rollup highlights under the correct daily section using:
   ```bash
   kb journal append --date <date> --section <section_name> --content <content>
   ```
   For `/implement` work, do NOT re-narrate the openspec change — reference the durable store artifacts (`design.md`/specs).

2. **Profiles**: Merge new facts (contact updates, project changes) into the knowledge-base people and project profiles. Query existing profile data using `kb people list` and `kb people show <name>` first to merge and update facts.

3. **Decisions**: Add key architectural decisions to the relevant product/project profiles.

4. **Action items**: Query the current list of action items using:
   ```bash
   kb action-items list
   ```
   Extract any newly identified action items from the enriched window's activity, then dedup against the active action items from `kb action-items list`. If the activity shows you already took the action (replied, reviewed, closed), drop it. Only items still open at window end proceed.

   Before filing any new items, check for pre-existing duplicates (both open and completed) using `kb action-items list` first. Match by the item's source URL first, falling back to a close title match. Skip filing anything for a matched item.

   For each surviving item, use your own judgement about where it belongs: a reminder, a tracked issue, a message to the relevant person or channel, or nothing at all if it's already tracked at its source. Default to creating a local reminder when nothing more fitting applies.

   **APM fix-ledger write-back.** Items surfaced from `fix/apm-*` worktree sessions are governed by `apm-fix-ledger.jsonl`. Only `pending` lines are candidates for review — skip `send_failed` lines entirely. For `pending` lines, ride the same batched action-item approval gate used for other remote writes — but once decided, resolve them by appending ONE new line to the ledger (keyed by `worktree` value).

   **Decision Log write-back.** Sync key decisions to Confluence if `chezmoi data --format json | jq -r '.kb.decision_log_container_page_id'` is configured. Check the ledger `decision-log-sync.jsonl` first: if a candidate decision was already marked `declined` in the last-line disposition, skip it. Otherwise search Confluence using the atlassian subagent for existing pages matching the title/date/label and skip duplicates. Create one page per new approved decision as a child of the container page with the `decision-log` label, and append the resolution line to the sync ledger.

Before finishing, account for every discrete fact or item any collector extracted: each one needs an explicit disposition, either filed (journal/profile/decision/action item) or deliberately skipped with a stated reason. Don't let an item fall through with no disposition.

## Privacy

Do not extract or store:
- Health information
- Compensation details
- Performance evaluations
- Legal or attorney-client privileged content
- Content from HR-related discussions
