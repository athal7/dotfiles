---
name: post-meeting
description: Post-recording cleanup for minutes — wait for processing, update title from calendar, identify speakers, re-ingest knowledge base, add action items to reminders. Privacy-sensitive — use a local model only.
license: MIT
metadata:
  author: athal7
  version: "1.0"
  requires:
    - calendar
    - reminders
---

# Skill: Post-Meeting Cleanup

Assumes minutes markdown frontmatter (`speaker_map`, `recorded_by`, `speaker_label`,
`confidence`). Most steps work directly on the markdown file. The `minutes` CLI is used only
where it provides unique value: polling for job completion (Step 1), re-ingesting into the
knowledge base (Step 5), and optionally saving voice profiles (Step 3).

Accepts an optional meeting path or slug; if not provided, operates on the most recently
processed meeting.

---

## Step 1: Wait for processing, then resolve the meeting

The `post_record` hook fires when recording stops — **before** the processing pipeline
(transcribe → diarize → summarize → save) finishes. The meeting markdown file does not exist yet.

Poll `minutes jobs --json --limit 1` every 15 seconds until the most recent job reaches
`state: "complete"` (or `"failed"`). Cap at 20 minutes — if still not complete, report the
timeout and stop. On failure, report the error from the job and stop.

Once the job completes, its `output_path` is the meeting file. If a path or slug was provided by
the caller, use that instead. Read the full frontmatter: `title`, `date`, `duration`,
`speaker_map`, `attendees`, `action_items`, `recorded_by`.

---

## Step 2: Update the title

Use your `calendar` capability to list non-all-day, non-Busy events in a ±90-minute window around
the meeting's `date` field. Pass **local time** to the query bounds — the calendar provider
interprets time range bounds as local, not UTC.

Find the best match: prefer an event whose window contains the recording start time; fall back to
nearest start. Skip events with title `""` or `"Busy"`.

If a match is found and its title differs from the current `title:` field, rewrite that line in
the markdown frontmatter. Report what changed. If no match, note it and move on.

---

## Step 3: Identify speakers

Read `speaker_map` from the frontmatter and scan the transcript body for all `SPEAKER_N` and
`UNKNOWN` labels.

A speaker is **unidentified** if they have no `speaker_map` entry, or their entry has confidence
`low`, or their name is a placeholder (`Unknown`, `Speaker_1`, `Le Speaker_N`, etc.).

If there are unidentified speakers and a calendar event was matched in Step 2:
- Use your `calendar` capability (`show` with the event ID) to get the full attendee list.
- Include **all** attendees, including distribution lists — expand group addresses using your
  `docs` capability to look up group membership if needed.
- Cross-reference against already-identified names/emails in `speaker_map`.

For each unidentified speaker, sample 3–5 representative quotes from across the transcript (not
just the first few lines — spread them out to capture different parts of the conversation).
Present them to the user along with the candidate names.

**Auto-confirm** when unambiguous (1 unidentified + 1 unmatched attendee) — but still show the
sample quotes so the user can catch a misidentification.

**When ambiguous**, reason from the quotes and conversational cues. Confirm if >80% confident and
explain why. Otherwise present the samples and candidate names for the user to decide — do not
guess.

**Merged speakers**: the diarizer sometimes assigns two distinct voices to the same `SPEAKER_N`
label. Watch for this in the samples — if quotes for a single label show clearly different
speaking styles, vocabularies, or refer to themselves inconsistently, flag it as a possible merge
and ask the user whether to split. A split means renaming some `SPEAKER_N:` lines in the
transcript to a new label (e.g. `SPEAKER_N_B:`) and adding a separate `speaker_map` entry.

To confirm a speaker, write directly to the markdown file:
1. Add or update the `speaker_map` entry: set `name`, `confidence: high`, `source: manual`
2. Replace all `SPEAKER_N:` labels in the transcript body with the resolved name
3. Optionally run `minutes confirm --meeting <path> --speaker SPEAKER_N --name "<name>" --save-voice`
   if you want to save a voice profile for future auto-identification — but this is not required
   for the file to be correct

**`UNKNOWN` segments**: the diarizer uses `UNKNOWN` for speech it could not confidently assign to
any speaker cluster. These cannot be resolved — note the count in the report but do not attempt
to assign them. If the meeting has many `UNKNOWN` lines relative to total lines, flag it as a
diarization quality issue.

---

## Step 4: Add action items to reminders

Read `action_items` from the meeting frontmatter. For any entry whose `assignee` is a `SPEAKER_N`
label, look it up in `speaker_map` and rewrite the assignee to the resolved name in the file. Do
the same for any `entities.action_items` block if present. Write the file when done.

For each item assigned to `recorded_by` that is not already in reminders, add it via your
`reminders` capability with the meeting title as a note and any due date from the action item.

---

## Step 5: Re-ingest into knowledge base

The processing pipeline auto-ingests into the knowledge base **before** speaker confirmation,
so person profiles contain stale labels (`Speaker_0`, `Le Speaker_1`, etc.). Re-ingest now
that speakers are resolved:

1. **Delete stale profiles** generated by the auto-ingest. In the knowledge base `people/`
   directory, remove any files matching these patterns (case-insensitive):
   - `speaker*.md`, `le-speaker*.md`
   - `unknown.md`, `unassigned.md`, `none.md`
   - Any file whose `# Title` is clearly not a person name (e.g. `Team`, `Attendees`,
     `Respectfully`, email-address slugs like `jdoe-example-com.md`)

2. **Re-ingest** with corrected speaker names:
   ```
   minutes ingest <meeting-path>
   ```

3. **Check for duplicates.** The LLM summarizer sometimes uses first-name-only variants
   (e.g. `alex.md` alongside `alex-chen.md`). After re-ingest, scan for pairs where the
   short-name file's facts all come from the same meetings as the full-name file. Merge by
   appending unique fact lines from the short-name profile into the full-name profile under
   matching section headers, then delete the short-name file.

Record the counts (facts written, skipped, people updated, stale profiles removed, merges
performed) for the report.

If no speakers were confirmed in Step 3 (all were already identified or none could be resolved),
skip this step — the auto-ingest data is already correct.

---

## Step 6: Report

```
Meeting: <title>
Date: <date>

Title: updated to "<new title>" / no change (no matching event)
Speakers: <N> confirmed, <N> still unidentified [samples + candidates if any]
          UNKNOWN segments: <N> (flag if high relative to total lines)
Knowledge base: re-ingested (<N> facts, <N> stale profiles removed, <N> merges) / skipped (no speaker changes)
Reminders: <N> action items added / already tracked
```
