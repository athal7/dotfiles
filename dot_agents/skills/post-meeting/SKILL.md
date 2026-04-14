---
name: post-meeting
description: Post-recording cleanup for minutes — update title from calendar, identify speakers, add action items to reminders. Privacy-sensitive — use a local model only.
license: MIT
metadata:
  author: athal7
  version: "1.0"
  requires:
    - calendar
    - reminders
---

# Skill: Post-Meeting Cleanup

**Tightly coupled to the `minutes` CLI.** Assumes minutes markdown frontmatter (`speaker_map`,
`recorded_by`, `speaker_label`, `confidence`) and uses `minutes list`, `minutes actions`, and
`minutes confirm` directly.

Accepts an optional meeting path or slug; if not provided, operates on the most recently
processed meeting.

---

## Step 1: Resolve the meeting

Run `minutes list` to find the meeting. If a path was provided, use it directly; otherwise take
the first result. Read the full frontmatter from the markdown file: `title`, `date`, `duration`,
`speaker_map`, `attendees`, `action_items`, `recorded_by`.

---

## Step 2: Update the title

Use your `calendar` capability to list non-all-day, non-Busy events in a ±90-minute window around
the meeting's `date` field. Pass **local time** to the query bounds — the ical CLI interprets
`--from`/`--to` as local, not UTC.

Find the best match: prefer an event whose window contains the recording start time; fall back to
nearest start. Skip events with title `""` or `"Busy"`.

If a match is found and its title differs from the current `title:` field, rewrite that line in
the markdown frontmatter. Report what changed. If no match, note it and move on.

---

## Step 3: Identify speakers

Read `speaker_map` from the frontmatter and scan the transcript body for all `SPEAKER_N` labels.

A speaker is **unidentified** if they have no `speaker_map` entry, or their entry has confidence
`low`, or their name is a placeholder (`Unknown`, `Speaker_1`, etc.).

If there are unidentified speakers and a calendar event was matched in Step 2:
- Use your `calendar` capability (`show` with the event ID) to get the full attendee list.
- Build candidates: exclude `recorded_by`, exclude distribution lists (group domains, `+` in local part).
- Cross-reference against already-identified names/emails in `speaker_map`.

**Auto-confirm** when unambiguous (1 unidentified + 1 unmatched attendee):
```
minutes confirm --meeting <path> --speaker SPEAKER_N --name "<name>"
```

**When ambiguous**, sample a few transcript lines per unidentified speaker and reason from
conversational cues. Confirm if >80% confident and explain why. Otherwise present the samples and
candidate names for the user to decide — do not guess.

---

## Step 4: Add action items to reminders

Run `minutes actions --assignee <recorded_by name>` to get open action items. For each one not
already in Work reminders, add it via your `reminders` capability with the meeting title as a
note and any due date from the action item.

Check the reminders list first to avoid duplicates.

---

## Step 5: Report

```
Meeting: <title>
Date: <date>

Title: updated to "<new title>" / no change (no matching event)
Speakers: <N> confirmed, <N> still unidentified [samples + candidates if any]
Reminders: <N> action items added / already tracked
```
