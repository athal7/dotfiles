---
description: Daily production error triage — query APM errors and dispatch worktree fix sessions
subtask: true
---

Triage production errors from Elastic APM and dispatch a fix session for the top recurring error groups **in repos we own**.

$ARGUMENTS

Optional argument: a time-range override (e.g. `48h`). Default: last 24h.

## Skills

- **elasticsearch** — APM error query (`logs-apm.error-*`) and auth.
- **opencode** — aoe dispatch verbs (`aoe add --worktree`, `aoe session start`, `aoe send`) for the fire-and-forget dispatch flow.

## Steps

1. **Map service → repo first.** Run `chezmoi data | jq -r '.prod_services'` for the `service.name → repo` map; the repo lives at `~/code/<repo>`. Match on the **exact `service.name` key** only — do not infer a mapping from hostnames, URLs, prior branch names, or a same/similar-named directory under `~/code/`.

2. **Find the top error groups among mapped services.** Query APM errors over the window, aggregate by `error.grouping_key` ranked by occurrence count, and take the **top 3 groups whose `service.name` has an exact key in `prod_services`** — all recurring errors qualify, no minimum threshold. Unmapped-service groups (e.g. scanner/bot noise) do not consume one of the 3 slots — exclude them from the ranking entirely, even if they have a far higher raw count than any mapped group. For each of the top 3 mapped groups, capture `service.name`, `error.exception.type`, `error.exception.message`, the occurrence count, and a sample `trace.id`.

   Separately, note in the report the highest-volume *unmapped* service/group seen in the same window (name + count only) so scanner/bot noise stays visible without ever triggering a fix session.

3. **Dispatch a triage + fix session** for each of the top 3 mapped groups on a `fix/apm-<date>-<service>` branch (append a short slug if multiple groups share a service, to keep branch names distinct):

   ```bash
   add_output=$(aoe add "<repo>" --tool opencode --worktree "fix/apm-<date>-<service>" --new-branch --title "apm-<service>-$(date +%Y%m%d-%H%M%S)")
   SID=$(printf '%s\n' "$add_output" | awk '/^  ID:/ {print $2}')
   aoe session start "$SID"
   sleep 5   # let opencode's TUI finish booting in the fresh tmux pane before sending
   aoe send "$SID" "<prompt carrying the error context>"
   ```

   The prompt should carry the error context (service, exception type + message, occurrence count, sample `trace.id`, and the request URL/transaction if available) and instruct the session to **first determine whether the error is a genuine defect or expected noise** — e.g. a 404 from a bot or bad slug, a deleted record, a probe — by reading the relevant code path and reproducing if feasible. Only if it is a real defect should it run `Workflow: implement.` to propose a fix; otherwise it should report the error as expected noise and, where appropriate, suggest an APM ignore rule (`transaction_ignore_urls` or error filtering) rather than a code change. Note that an error surfacing as a 404 may still be a real bug (e.g. our own broken asset/link causing the request) — do not dismiss by status code alone. `aoe send` is fire-and-forget — it fires the prompt into the new session's tmux pane without waiting for the run to finish.

4. **Report** — error groups found (with counts), sessions dispatched (worktree paths + branch names), and the top unmapped noise service/group noted for awareness.
