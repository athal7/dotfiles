# cal package

Python package at `~/.local/lib/cal/`. Entry point: `python3 -m cal {babysitter,family,lunch,sync}`. Requires `PYTHONPATH=~/.local/lib`.

## Config source

All calendar config comes from `chezmoi data` (`.chezmoidata/local.yaml`):
- `calendars` — calendar names, sync rules, inbound windows, ignore patterns
- `feeds` — ICS feed URLs for family-scheduler
- `reminders` — reminders list config for babysitter-check

## Dependencies

- `icalendar` (third-party) — installed via `dot_config/mise/default-python-packages`, not pip/uv. Used only by `family.py` for ICS feed parsing (lazy import with ImportError fallback).
- `ical` CLI, `remindctl`, `chezmoi` — called via subprocess from `util.py` and subcommand modules.

## util.py patterns

- `ical_bin()` uses `functools.lru_cache` — cached for process lifetime, no repeated `which` calls.
- `ical()` catches `json.JSONDecodeError` and returns `[]` — ical CLI can return non-JSON on errors.
- `log(msg, tag)` writes to both stdout and syslog via `logger -t`. Each subcommand passes its own tag to preserve per-service log identity.
