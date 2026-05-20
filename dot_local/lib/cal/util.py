"""Shared utilities for the cal package."""
import functools
import json
import os
import subprocess
from datetime import datetime
from zoneinfo import ZoneInfo


@functools.lru_cache(maxsize=1)
def ical_bin():
    """Find ical binary, caching result."""
    from pathlib import Path
    return (
        subprocess.run(["which", "ical"], capture_output=True, text=True).stdout.strip()
        or str(Path.home() / ".local/bin/ical")
    )


def ical(*args):
    """Run ical CLI and parse JSON output."""
    result = subprocess.run([ical_bin(), *args], capture_output=True, text=True)
    try:
        return json.loads(result.stdout or "[]")
    except json.JSONDecodeError:
        return []


def ical_write(*args):
    """Run ical CLI for write operations (no JSON parsing)."""
    subprocess.run([ical_bin(), *args], capture_output=True, text=True)


def chezmoi_data():
    """Load chezmoi template data as dict."""
    result = subprocess.run(
        ["chezmoi", "data", "--format", "json"],
        capture_output=True, text=True,
    )
    return json.loads(result.stdout)


def local_tz():
    """Get local timezone from /etc/localtime symlink."""
    return ZoneInfo(os.readlink("/etc/localtime").split("zoneinfo/")[-1])


def to_local(dt_str, tz):
    """Parse ISO datetime string to timezone-aware local datetime."""
    return datetime.fromisoformat(dt_str.replace("Z", "+00:00")).astimezone(tz)


def log(msg, tag):
    """Log to stdout and syslog."""
    print(f"{datetime.now().strftime('%H:%M:%S')} {msg}", flush=True)
    subprocess.run(["logger", "-t", tag, msg], capture_output=True)


def is_eligible(dt, evening_start=17):
    """Return True for weekends (all day) or weekday evenings (after evening_start)."""
    if dt.weekday() >= 5:
        return True
    return dt.hour >= evening_start
