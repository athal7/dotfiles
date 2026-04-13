---
name: remindctl
description: Read and write Apple Reminders via the native EventKit CLI
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides:
    - reminders
---

# Skill: remindctl

Run `remindctl --help` and `remindctl <command> --help` to discover commands. This skill only documents silent failure modes that help text won't surface.

## Due date midnight UTC trap

`--due YYYY-MM-DD` defaults to midnight UTC. The local display masks the error — it shows "12:00 AM" but resolves to the wrong day in non-UTC timezones. Always pass a full ISO datetime:

```bash
# Wrong — midnight UTC, wrong local time outside UTC
remindctl add "Task" --due 2026-04-26

# Correct — explicit local midnight (e.g. CT = UTC-5)
remindctl add "Task" --due 2026-04-26T05:00:00
```

## `upcoming` scope excludes undated items

`remindctl show upcoming` only returns future-dated items. To include incomplete reminders with no due date, use `all`:

```bash
remindctl show --json all | jq '[.[] | select(.isCompleted == false) | select(.dueDate == null)]'
```
