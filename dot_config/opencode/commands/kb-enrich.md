---
description: Knowledge base enrichment — enrich profiles, journal, and decisions for each date since the last run
subtask: true
---

Enrich the knowledge base for every date since the last run. An explicit date or range given in arguments overrides.

$ARGUMENTS

## Step 1 — Resolve date range

The most recent `~/.local/share/kb/journal/YYYY-MM-DD.md` is the last-run marker: enrich each date from (last journal date + 1) through today, inclusive. This makes a Monday run sweep the trailing weekend and lets a skipped run self-heal on the next run. If no prior journal exists, default to today. An explicit date or range in arguments overrides this.

## Step 2 — Load collectors

Collectors live at `~/.config/kb/collectors/*.md`. Which collectors run is determined by the enabled list in chezmoi local config:

```
chezmoi data --format json | jq -r '.kb.collectors[]'
```

Run only the listed collectors. If the key is absent, log "kb.collectors not configured" and stop.

## Step 3 — Run each collector

For each enabled collector, apply its embedded query recipe and triage/extraction rules against the resolved date window. Collectors are independent — run them in any order. The opencode collector handles its own internal openspec→exclusion→sessions sequencing.

## Step 4 — Write outputs

After all collectors have run, write the enrichment outputs:

1. **Journal** — write one cross-project rollup journal file per enriched date at `~/.local/share/kb/journal/YYYY-MM-DD.md`, each with diff stats. By construction each is THIN: feed it only from the NON-excluded sessions (those not covered by an archived change) plus git diff-stats. For `/implement` work, do NOT re-narrate the openspec change — reference the durable store artifacts (`design.md`/specs already in the kb via the symlink). The journal's role is the cross-project rollup + non-`/implement` activity, not a reconstruction of openspec work.
2. **Profiles** — merge new facts into knowledge-base people and project profiles at `~/.local/share/kb/people/` and `~/.local/share/kb/projects/`.
3. **Decisions** — add any decisions to the decisions log. Pull key design decisions and rejected alternatives from the durable store's `~/.local/share/kb/openspec/*/changes/archive/YYYY-MM-DD-*/design.md` (READ, don't copy — the artifacts are already in the kb via the symlink). The decisions log is a distilled record anchored to its product/project, not a dump of the design files.
4. **Action items** — extract action items from the enriched window's activity, then dedup against that same activity: if it shows you already took the action (replied to the thread, reviewed the PR, closed the issue), drop it. Only items still open at window end proceed.

   Before filing anything, check for pre-existing duplicates against the likely destination's actual current state — not just this window's activity. A prior run, or activity outside this window, may have already resolved or already filed the same item. For a reminder, this means checking all reminders (open and completed), not only open ones — a completed item won't appear under "open" but still means it's already handled. Match by the item's source URL first, falling back to a close title match. Skip filing anything for a matched item.

   This check must reach past the destination itself to the *source* of the action item: re-verify the underlying thing is still true (a PR still unreviewed, a message still unsent, a config still unset) immediately before presenting for approval — not just whether a matching reminder exists. Collector data is a snapshot; hours can pass between collection and the approval/write phase, during which the user may have resolved the item through a channel the collector never checked.

   For each surviving item, use your own judgement about where it belongs rather than following a fixed rule: a reminder, a tracked issue, a message to the relevant person or channel, or nothing at all if it's already tracked at its source (e.g. an open issue surfaced by a collector — filing a duplicate would be worse than a reminder). Weigh the item's nature, which collector surfaced it, and where similar items already live. Default to a reminder when nothing more fitting applies. Preserve the item's source URL in whatever gets filed so it stays traceable back to its origin.

   - **Reminder** — local; create directly.
   - **Tracked issue or message** — remote-system writes. Batch multiple items: show the full content and destination for each, then create them all.

   Respect the Privacy rules below — never route privacy-excluded content to a shared destination.

   **APM fix-ledger write-back.** Items surfaced from `fix/apm-*` worktree sessions are governed by `~/.local/share/kb/apm-fix-ledger.jsonl`, not by the general filing rules above. Only `pending` lines are candidates for review — skip `send_failed` lines entirely: those sessions never received their prompt, so there's no session output to reconcile and no write-back to make; the `send_failed` line is already terminal as written by `fix-prod-errors`. For `pending` lines, ride the same batched action-item approval gate used for other remote writes — but once the human decides, resolve them by appending ONE new line to the ledger (same `worktree` value as the pending line; never edit or remove a prior line):

   - Approved/filed — `jq -nc --arg wt "$WT" --arg url "$TICKET_URL" --arg dec "$(date -Iseconds)" '{worktree:$wt, disposition:"filed", ticket_url:$url, decided:$dec}' >> ~/.local/share/kb/apm-fix-ledger.jsonl`
   - Declined — same shape with `disposition:"declined"` and a required `reason` field instead of `ticket_url`.
   - Session self-classified as noise (per the collector's `noise-confirmed` marking) — same shape with `disposition:"noise-confirmed"`; no human gate needed for this case.

   This ledger line **is** the item's explicit disposition record for APM-fix items — it satisfies the "every extracted item needs an explicit disposition" rule above — and it prevents a stale session from being re-proposed as a fresh draft if it's ever re-scanned by a later run. Re-read the ledger file fresh immediately before finalizing dispositions, not just from an earlier collector pass — `/fix-prod-errors` can dispatch new triage sessions asynchronously later in the same day, appending new `pending` lines after the window's initial scan.

   **Decision Log write-back.** Governed by `~/.local/share/kb/decision-log-sync.jsonl`, not the general filing rules above. This step is opt-in: it runs only if `chezmoi data --format json | jq -r '.kb.decision_log_container_page_id'` resolves to a real page ID. If the key is absent or empty, log "kb.decision_log_container_page_id not configured" and skip this step entirely — no Confluence write happens.

   Candidates are `## Key Decisions` entries from `~/.local/share/kb/projects/*.md` and `~/.local/share/kb/products/*.md` only (never `decisions/cross-cutting.md` or `decisions/archive.md` — out of scope for this feature). Apply a real bar before staging a candidate: it should be a genuinely significant product/architectural decision, ideally one reached by more than one person — routine solo policy or configuration choices (a CI gating rule, a scope-exclusion housekeeping call, a rollout-process tweak) belong in the profile's own `## Key Decisions` section but don't clear the bar for this external write-back. For each candidate, check the ledger first: a last-line disposition of `declined` for that decision means skip it, already ruled out on a prior run. Otherwise dispatch the atlassian subagent to search by the `decision-log` label plus a title/date match — one page per decision, so no in-page fuzzy matching is needed — and skip any candidate that already has a matching page.

   For each surviving candidate, stage one new child page: title is the decision statement (or a short slug of it), body carries the fields Decision, Date, Product/Project, Source (link), and Contributed-by (e.g. "kb-enrich automation"). For how to lay those fields out, check whether a skill or other documentation describes this Confluence space's page-authoring conventions and follow that structure; if none is found, fall back to a plain labeled list of the same fields. The container page lists its children via a plain Child Items macro sorted by native Created date, so no further per-page structured metadata is needed. Destined as a child of the configured container page and stamped with the `decision-log` label. Ride the same batched remote-write approval gate used for other action items above — show the full content and destination for each, then create them all.

   On approval, dispatch the atlassian subagent to create each approved page as a child of the container page with the label applied. Then resolve every candidate — approved or declined — by appending one line to the ledger (keyed by product/project slug + decision text, last line wins):

   - Created — disposition `created` plus the resulting Confluence page URL.
   - Declined — disposition `declined` plus a required `reason`.

   This ledger line is the decision's explicit disposition record and is what suppresses re-proposing an already-declined decision on a future run.

Before finishing, account for every discrete fact or item any collector extracted: each one needs an explicit disposition, either filed (journal/profile/decision/action item) or deliberately skipped with a stated reason (privacy exclusion, genuine duplicate, or triviality). Don't let an item fall through with no disposition. Apply this especially to single-source facts with no corroborating collector — a new contact, an informal one-off decision surfaced only in Slack — lack of corroboration is not itself a reason to skip.

## Privacy

Do not extract or store:
- Health information
- Compensation details
- Performance evaluations
- Legal or attorney-client privileged content
- Content from HR-related discussions
