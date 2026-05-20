"""Shared utilities for the kb package."""
import json, os, re, subprocess, sys
from datetime import datetime


def slugify(text):
    s = text.lower()
    s = re.sub(r"[^a-z0-9 ]", "", s)
    s = s.strip().replace(" ", "-")
    return re.sub(r"-{2,}", "-", s)


def get_identity_name():
    """Get identity from chezmoi data, fall back to env var."""
    name = os.environ.get("IDENTITY_NAME")
    if name:
        return name
    try:
        result = subprocess.run(
            ["chezmoi", "data", "--format=json"],
            capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            data = json.loads(result.stdout)
            return data.get("fullName", "Unknown")
    except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
        pass
    return "Unknown"


def log(msg, prefix="kb"):
    print(f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {prefix}: {msg}", file=sys.stderr)
