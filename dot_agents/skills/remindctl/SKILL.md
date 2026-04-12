---
name: remindctl
description: Read and write Apple Reminders via the native EventKit CLI
license: MIT
compatibility: macOS (requires remindctl CLI)
metadata:
  author: athal7
  version: "1.0"
  provides:
    - reminders
---

Requires: `remindctl` CLI (`steipete/tap/remindctl`).

No API keys needed — uses EventKit directly. On first run, macOS will prompt for Reminders access. Run `remindctl authorize` if access has not been granted yet.

## Read reminders

```bash
# Overdue
remindctl show --json overdue | jq -r '.[] | "OVERDUE: \(.title) [\(.listName)]"'

# Due today (incomplete only)
remindctl show --json today | jq -r '.[] | select(.isCompleted == false) | "TODAY: \(.title) [\(.listName)]"'

# Due this week
remindctl show --json week | jq -r '.[] | select(.isCompleted == false) | "\(.dueDate | split("T")[0]): \(.title) [\(.listName)]"'

# All incomplete with no due date
remindctl show --json all | jq -r '.[] |
  select(.isCompleted == false) |
  select(.dueDate == null) |
  "\(.priority // "none"): \(.title) [\(.listName)]"'

# Specific date
remindctl show --json 2026-04-15 | jq -r '.[] | "\(.title) [\(.listName)]"'

# Scoped to one list
remindctl show --json all --list Work | jq -r '.[] | select(.isCompleted == false) | .title'
```

JSON fields: `id`, `title`, `listName`, `dueDate` (ISO 8601 or null), `isCompleted`, `priority` ("high" | "medium" | "low" | "none"), `notes`.

## List reminder lists

```bash
# All lists
remindctl list --json | jq -r '.[] | "\(.title) (\(.count) reminders)"'

# Reminders in a specific list
remindctl list --json Work | jq -r '.[] | select(.isCompleted == false) | .title'
```

## Add a reminder

```bash
# Minimal
remindctl add "Buy oat milk"

# With list, due date, priority, and notes
remindctl add "Review PR" --list Work --due tomorrow --priority high --notes "See #1234"

# Due on a specific date
remindctl add "Tax deadline" --list Finance --due 2026-04-15

# Get JSON back
remindctl add "Deploy release" --list Work --due "next Monday" --json | jq '{id, title, dueDate}'
```

Accepted `--due` values: `today`, `tomorrow`, `next Monday` (natural language), or ISO date `YYYY-MM-DD`.
Priority values: `none`, `low`, `medium`, `high`.

## Edit a reminder

Use the `id` prefix or index from `show` output.

```bash
# Change title
remindctl edit 4A83 --title "Updated title"

# Reschedule
remindctl edit 4A83 --due 2026-04-20

# Raise priority and add notes
remindctl edit 4A83 --priority high --notes "Blocked on legal review"

# Move to another list
remindctl edit 4A83 --list Personal

# Clear due date
remindctl edit 4A83 --clear-due

# Mark complete via edit
remindctl edit 4A83 --complete
```

## Complete a reminder

```bash
# Single, by ID prefix
remindctl complete 4A83

# Single, by index from show output
remindctl complete 1

# Multiple at once
remindctl complete 1 2 3

# Dry-run preview
remindctl complete --dry-run 4A83
```

## Delete a reminder

```bash
remindctl delete 4A83
```

## Notes

- Always show the full proposed reminder details and get explicit user approval before creating, editing, completing, or deleting
- `id` is a short hex prefix (e.g. `4A83`) — use it for edits; it's stable across sessions
- Indexes from `show` output are positional and may shift — prefer ID prefixes for edits
- `--no-input` suppresses confirmation prompts in scripts; omit it when running interactively
- **Time gotcha:** `--due YYYY-MM-DD` defaults to midnight UTC, which displays as "12:00 AM" locally but is wrong for CT users (should be `05:00 UTC` = midnight CT). The local display masks the error. Always pass a full ISO datetime when matching existing reminders: `--due 2026-04-26T05:00:00`
- **Recurrence:** The JSON output does not expose recurrence fields — `remindctl` can create reminders but recurrence must be set manually in the Reminders app afterward
