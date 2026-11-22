---
name: reminders
description: Use when reading, adding, or completing macOS Reminders with remindctl — the filters and query combinations that silently return nothing, so an existing or just-created reminder looks missing.
license: MIT
---

`remindctl` CLI — call directly via Bash; read `remindctl --help` on demand.

`show upcoming` only returns reminders with a due date — use `show all` to include undated items.

`show open` is the filter for incomplete reminders — not a `--open` flag. Example: `remindctl show open --list "Work" --json`.

`complete` accepts a reminder UUID as a positional argument. Title-based matching is fragile (must be exact). Prefer completing by UUID: `remindctl complete <UUID>`. Get UUIDs from `--json` output.

`--list` + `--json` together can return an empty array even when the list has items — that combination is unreliable. For an authoritative dump use `remindctl show all --json` WITHOUT `--list`, then filter by `list`/`title` in code.

`show open` excludes overdue items — a reminder due earlier the same day (e.g. due at local midnight) is already overdue and won't appear, including a just-created due-today reminder. Use `show all` or `show overdue` to see it.

Verify additions against `show all --json`, not text/`--quiet` output: `add --quiet` succeeds silently and a freshly-added item may not show up in an immediate follow-up `show` query — re-adding to "fix" the apparent miss creates duplicates.
