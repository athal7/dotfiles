#!/usr/bin/env python3
"""Fetch and print events from ICS feeds for the next 14 days."""

import urllib.request
from datetime import date, timedelta

ICS_FEEDS = {
    "Libertyville Recreation": "https://www.libertyville.com/common/modules/iCalendar/iCalendar.aspx?catID=21&feed=calendar",
    "Libertyville Area Moms": "https://libertyvilleareamoms.com/?post_type=tribe_events&ical=1&eventDisplay=list",
}


def fetch_ics(name, url):
    try:
        from icalendar import Calendar
    except ImportError:
        print(f"[{name}] icalendar not installed — run: pip install icalendar")
        return []

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as r:
            cal = Calendar.from_ical(r.read())
    except Exception as e:
        print(f"[{name}] fetch failed: {e}")
        return []

    today = date.today()
    lookahead = today + timedelta(days=14)
    events = []
    for component in cal.walk():
        if component.name != "VEVENT":
            continue
        dtstart = component.get("DTSTART")
        if not dtstart:
            continue
        d = dtstart.dt
        if hasattr(d, "date"):
            d = d.date()
        if not (today <= d <= lookahead):
            continue
        events.append(
            {
                "source": name,
                "summary": str(component.get("SUMMARY", "")),
                "date": d,
                "location": str(component.get("LOCATION", "")),
                "url": str(component.get("URL", "")),
            }
        )
    return events


if __name__ == "__main__":
    all_events = []
    for name, url in ICS_FEEDS.items():
        all_events.extend(fetch_ics(name, url))

    all_events.sort(key=lambda e: e["date"])

    for e in all_events:
        loc = f" @ {e['location']}" if e["location"] else ""
        url = f"\n   {e['url']}" if e["url"] and e["url"] != "None" else ""
        print(f"{e['date']} [{e['source']}] {e['summary']}{loc}{url}")
