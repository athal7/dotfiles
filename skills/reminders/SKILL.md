---
name: reminders
description: macOS Reminders via remindctl CLI
license: MIT
---

`remindctl` CLI — call directly via Bash; read `remindctl --help` on demand.

`show upcoming` only returns reminders with a due date — use `show all` to include undated items.

`show open` is the filter for incomplete reminders — not a `--open` flag. Example: `remindctl show open --list "Work" --json`.

`complete` accepts a reminder UUID as a positional argument. Title-based matching is fragile (must be exact). Prefer completing by UUID: `remindctl complete <UUID>`. Get UUIDs from `--json` output.
