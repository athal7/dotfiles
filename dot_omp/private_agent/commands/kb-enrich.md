---
description: Enrich knowledge-base outputs from configured OMP-era collectors
---

Enrich the knowledge base for every date since the last run. An explicit date or range overrides the default.

$ARGUMENTS

1. Resolve the date range from `kb journal list`: enrich from the last recorded date plus one through today; with no journal entries, use today.
2. Read `chezmoi data --format json | jq -r '.kb.collectors[]'`. Run only the configured collector recipes under `~/.config/kb/collectors/`; stop if the collector list is absent.
3. Run each configured collector for the range. Treat OMP session JSONL files as the coding-session source. Use each session's plan and task state only as extraction context; retain every eligible session in aggregate journal counts without a separate durable-plan lookup.
4. Reconcile `~/.local/share/kb/apm-fix-ledger.jsonl` by worktree. Do not re-extract `filed`, `declined`, `noise-confirmed`, or `send_failed` sessions; surface pending fix drafts as action-item candidates and record self-classified noise as `noise-confirmed`.
5. Write journal sections with `kb journal append`, merge supported profile facts, and record decisions supported by OMP session evidence and configured collectors. Deduplicate action items against both current destination state and their underlying source before filing.
6. Create local reminders directly. Before any remote issue, message, or document write, show every destination and complete proposed content for approval. Preserve the collector privacy exclusions.
7. Account for every extracted fact with a filed or deliberately skipped disposition.
