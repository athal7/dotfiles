"""
sync-calendars - Mirror busy blocks between configured calendars.

For each calendar with sync_to set, finds real events and ensures matching
"Busy" blocks exist on destination calendars. Cleans up stale mirrors when
the source event is gone.

Requires: ical, chezmoi
"""

import json
from datetime import date, datetime, timedelta
from pathlib import Path

from cal.util import chezmoi_data, ical, ical_write, local_tz, log, to_local

MARKER = "Managed by sync-calendars"
WEEKS = 4

TAG = "sync-calendars"


def mirror_title(event, title_mappings, default_title="Busy", passthrough=False):
    """Return the title to use for the mirror event."""
    title = event.get("title", "").strip()
    if passthrough:
        return title
    lower = title.lower()
    for pattern, mapped in title_mappings.items():
        if pattern.lower() in lower:
            return mapped
    return default_title


DAY_MAP = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}


def in_inbound_window(event, tz, inbound_start=None, inbound_end=None, inbound_days=None):
    """Return True if event falls within the target calendar's inbound window."""
    start = to_local(event["start_date"], tz)
    if inbound_days is not None:
        allowed = {DAY_MAP[d.lower()] for d in inbound_days if d.lower() in DAY_MAP}
        if start.weekday() not in allowed:
            return False
    if inbound_start is not None and start.hour < inbound_start:
        return False
    if inbound_end is not None and start.hour >= inbound_end:
        return False
    return True


def is_excluded(event, src_label, sync_exclude):
    """Return True if this event should be skipped based on syncExclude config."""
    title = event.get("title", "").strip().lower()
    for pattern, cal_label in sync_exclude.items():
        if pattern.lower() == title:
            if cal_label == "*" or cal_label == src_label:
                return True
    return False


def is_locally_ignored(event, ignore_patterns):
    """Return True if the event title matches any per-calendar ignore pattern (substring, case-insensitive)."""
    if not ignore_patterns:
        return False
    title = event.get("title", "").strip().lower()
    return any(pattern.lower() in title for pattern in ignore_patterns)


def events_for(calendar, src_label, from_date, to_date, tz, sync_exclude, ignore_patterns=None):
    """Fetch real (non-mirror) events for a calendar."""
    events = ical("list", "-c", calendar, "--from", from_date, "--to", to_date, "-o", "json")
    return [
        e for e in events
        if not e.get("all_day")
        and e.get("notes", "").strip() != MARKER
        and e.get("title", "").lower() != "out of office"
        and e.get("availability") != "free"
        and e.get("status") != "cancelled"
        and not is_excluded(e, src_label, sync_exclude)
        and not is_locally_ignored(e, ignore_patterns)
    ]


def mirrors_for(calendar, from_date, to_date):
    """Fetch mirror events managed by this script."""
    events = ical("list", "-c", calendar, "--from", from_date, "--to", to_date, "-o", "json")
    return [e for e in events if e.get("notes", "").strip() == MARKER]


STATE_FILE = Path.home() / ".local/share/sync-calendars/state.json"


def load_last_run():
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text())
            return {tuple(k) for k in data.get("last_run", [])}
        except Exception:
            pass
    return set()


def save_last_run(keys):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(
        {"last_run": [list(k) for k in sorted(keys)]},
        indent=2
    ))


def main():
    data = chezmoi_data()
    calendars = data.get("calendars", {})  # {label: {name, sync_to, ...}}
    sync_exclude = calendars.get("syncExclude", {})
    from_date = str(date.today())
    tz = local_tz()

    # Filter to real calendar entries (exclude syncExclude sub-key)
    cal_entries = {k: v for k, v in calendars.items() if isinstance(v, dict)}

    if len(cal_entries) < 2:
        log("Need at least 2 calendars configured, skipping", TAG)
        return

    # Derive sync rules and writable calendars from attributes
    sync_rules = {
        label: cal.get("sync_to", [])
        for label, cal in cal_entries.items()
        if cal.get("sync_to")
    }
    write_labels = {k: v["name"] for k, v in cal_entries.items()}

    # Fetch real events from all source calendars, respecting per-calendar lookahead
    max_weeks = max(
        (cal.get("lookahead_weeks", WEEKS) for cal in cal_entries.values()),
        default=WEEKS
    )
    mirror_to_date = str(date.today() + timedelta(weeks=max_weeks))

    all_events = {
        label: events_for(
            cal["name"], label, from_date,
            str(date.today() + timedelta(weeks=cal.get("lookahead_weeks", WEEKS))),
            tz, sync_exclude, cal.get("ignore_patterns")
        )
        for label, cal in cal_entries.items()
        if label in sync_rules
    }

    # Fetch existing mirrors from writable calendars (use max window to catch all stale entries)
    all_mirrors = {
        label: mirrors_for(name, from_date, mirror_to_date)
        for label, name in write_labels.items()
    }

    # Phase 1: remove stale mirrors (no matching source event)
    # Build set of expected (dst_label, start, end) from current source events
    expected = set()
    for src_label, dst_labels in sync_rules.items():
        if src_label not in cal_entries:
            continue
        for event in all_events.get(src_label, []):
            for dst_label in dst_labels:
                if dst_label not in write_labels:
                    continue
                dst_cal = cal_entries.get(dst_label, {})
                if not in_inbound_window(event, tz,
                                         dst_cal.get("inbound_start"),
                                         dst_cal.get("inbound_end"),
                                         dst_cal.get("inbound_days")):
                    continue
                expected.add((dst_label, event["start_date"], event["end_date"]))

    for dst_label, mirrors in all_mirrors.items():
        for mirror in mirrors:
            key = (dst_label, mirror["start_date"], mirror["end_date"])
            if key not in expected:
                log(f"Removing stale mirror from {write_labels[dst_label]} ({mirror['start_date'][:16]}): {mirror['title']}", TAG)
                ical_write("delete", mirror["id"], "--force")

    # Phase 2: create missing mirrors
    # Build set of already-mirrored (dst_label, start, end)
    mirrored = {
        (dst_label, m["start_date"], m["end_date"])
        for dst_label, mirrors in all_mirrors.items()
        for m in mirrors
    }

    last_run = load_last_run()
    # Keys managed last run that should still exist but are gone from the calendar
    # → user deleted them intentionally; don't re-create
    user_deleted = {k for k in last_run if k in expected and k not in mirrored}
    if user_deleted:
        for k in sorted(user_deleted):
            log(f"Skipping user-deleted mirror: {k[0]} {k[1][:16]}", TAG)

    # Also track what we create this run to avoid duplicates
    created = set()

    for src_label, dst_labels in sync_rules.items():
        if src_label not in cal_entries:
            continue
        src_cal = cal_entries[src_label]
        default_title = src_cal.get("default_title", "Busy")
        title_mappings = src_cal.get("title_mappings", {})
        passthrough = src_cal.get("passthrough", False)
        for event in all_events.get(src_label, []):
            start, end = event["start_date"], event["end_date"]
            title = mirror_title(event, title_mappings, default_title, passthrough)
            location = event.get("location", "").strip() if passthrough else ""

            for dst_label in dst_labels:
                if dst_label not in write_labels:
                    continue
                dst_cal = cal_entries.get(dst_label, {})
                inbound_start = dst_cal.get("inbound_start")
                inbound_end = dst_cal.get("inbound_end")
                inbound_days = dst_cal.get("inbound_days")
                if not in_inbound_window(event, tz, inbound_start, inbound_end, inbound_days):
                    continue
                key = (dst_label, start, end)
                if key in mirrored or key in created:
                    continue
                if key in user_deleted:
                    continue
                # Skip if a real event already covers this slot on dst
                if any(e["start_date"] == start and e["end_date"] == end
                       for e in all_events.get(dst_label, [])):
                    continue

                log(f"Adding '{title}' to {write_labels[dst_label]} ({start[:16]})", TAG)
                add_args = ["add", title,
                            "-c", write_labels[dst_label],
                            "-s", start,
                            "-e", end,
                            "--notes", MARKER,
                            "--no-alert"]
                if location:
                    add_args += ["--location", location]
                ical_write(*add_args)
                created.add(key)

    active = {k for k in mirrored if k in expected} | created | user_deleted
    save_last_run(active)

    log("done", TAG)
