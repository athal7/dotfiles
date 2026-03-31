#!/usr/bin/env python3
"""Convert Granola cache-v6.json to granola-archivist markdown format for minutes import."""
import json, re, os, sys
from pathlib import Path
from datetime import datetime, timezone

cache_path = Path.home() / "Library/Application Support/Granola/cache-v6.json"
output_dir = Path.home() / ".granola-archivist/output"
output_dir.mkdir(parents=True, exist_ok=True)

with open(cache_path) as f:
    data = json.load(f)

docs = data["cache"]["state"]["documents"]
if isinstance(docs, dict):
    docs = list(docs.values())

written = 0
skipped = 0

for doc in docs:
    # Skip deleted/trashed docs
    if doc.get("deleted_at") or doc.get("was_trashed"):
        continue
    # Skip docs with no real content
    title = (doc.get("title") or "").strip()
    if not title:
        continue

    created_at_raw = doc.get("created_at", "")
    try:
        dt = datetime.fromisoformat(created_at_raw.replace("Z", "+00:00"))
        # Format matches what granola-archivist produces: "2026-01-19 @ 20:27"
        date_str = dt.astimezone().strftime("%Y-%m-%d @ %H:%M")
        date_prefix = dt.astimezone().strftime("%Y-%m-%d")
    except Exception:
        date_str = created_at_raw
        date_prefix = "0000-00-00"

    # Attendees
    people = doc.get("people") or {}
    attendees = []
    creator = people.get("creator", {})
    if creator.get("name"):
        attendees.append(creator["name"])
    for a in people.get("attendees", []):
        name = (a.get("details", {}) or {}).get("person", {}).get("name", {}).get("fullName") \
               or a.get("name") or a.get("email", "")
        if name and name not in attendees:
            attendees.append(name)
    attendees_str = ", ".join(attendees) if attendees else "None"

    notes = (doc.get("notes_markdown") or "").strip()

    # Build the exact format minutes importer expects
    content = f"# Meeting: {title}\n"
    content += f"Date: {date_str}\n"
    content += f"Attendees: {attendees_str}\n\n"
    content += f"## Your Notes\n\n{notes}\n\n"
    content += f"## Transcript\n\n"  # no local transcript available

    # Slugify title for filename
    slug = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')[:60]
    filename = f"{date_prefix}-{slug}.md"
    out_path = output_dir / filename

    if out_path.exists():
        skipped += 1
        continue

    out_path.write_text(content)
    os.chmod(out_path, 0o600)
    written += 1

print(f"Exported {written} meetings to {output_dir} ({skipped} skipped as duplicates)")
