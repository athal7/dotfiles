---
name: post-meeting
description: Post-recording cleanup for minutes — wait for processing, update title from calendar, identify speakers, re-ingest knowledge base, add action items to reminders. Privacy-sensitive — use a local model only.
license: MIT
metadata:
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

## Step 3: Resolve attendee names and identify speakers

If a calendar event was matched in Step 2, fetch the full attendee list now — it is needed for
both name resolution and speaker identification:
- Use your `calendar` capability (`show` with the event ID).
- Include **all** attendees, including distribution lists — expand group addresses using your
  `docs` capability to look up group membership if needed.

### 3a: Resolve short and garbled names in frontmatter

The LLM summarizer writes attendee names as it hears them — often first-name-only, phonetic
mishearings, or placeholder labels. These produce garbage KB profiles on every ingest. **Run this
step before speaker identification and before Steps 4–5**, so all subsequent work uses canonical
names.

1. Build a canonical name map from the calendar attendee list. For each attendee email, derive the
   full name from the `name` field; if absent or just an email address, look up the person in the
   KB or past meetings.

2. Scan every name-bearing field in the frontmatter: `attendees`, `people`, `entities.people`
   (slugs, labels, aliases), `action_items[].assignee`, `intents[].who` (all kinds: action-item,
   commitment, decision). Collect all distinct name values.

3. For each name value that does not exactly match a canonical full name:
   - If it is a clear short form, phonetic variant, or role-decorated form (e.g. first name only,
     phonetic mishearing, or `Name: Role description`) of a calendar attendee → replace with the
     canonical full name.
   - If it is a placeholder (`The Speaker`, `[speaker_2]`, `[the Team]`, `unassigned`) → replace
     with the resolved person if determinable from context, otherwise `Unknown`.
   - If it is a verbose composite (e.g. `Person A and @Person B`) → replace with the primary
     assignee's canonical name.
   - If it contains a colon-separated role suffix (`Name: Role description`) → strip to just the
     canonical name.

4. In `entities.people`: update each entry's `slug`, `label`, and `aliases` to match the canonical
   name. Remove duplicate entries that resolve to the same person. Remove entries for non-person
   entities (`[the Team]`, `Attendees`, etc.).

5. Deduplicate `attendees` and `people` lists after substitution.

6. Write the updated frontmatter back to the file.

After this step, every name in the frontmatter should be a full canonical name that matches an
existing KB profile slug — so re-ingest in Step 5 writes to the right files and creates no new
short-name duplicates.

### 3b: Identify unresolved diarizer speakers

Read `speaker_map` from the frontmatter and scan the transcript body for all `SPEAKER_N` and
`UNKNOWN` labels.

A speaker is **unidentified** if they have no `speaker_map` entry, or their entry has confidence
`low`, or their name is a placeholder (`Unknown`, `Speaker_1`, `Le Speaker_N`, etc.).

Cross-reference unidentified speakers against the canonical attendee list from Step 3 (minus
anyone already identified in `speaker_map`).

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

Collect all items assigned to `recorded_by` from **both** `action_items` and `intents` (all
entries with `kind: action-item` or `kind: commitment`). These are parallel structures the
pipeline writes — treat them equivalently.

For any entry whose `assignee` / `who` is still a `SPEAKER_N` label, look it up in `speaker_map`
and rewrite it to the resolved name in the file. Write the file when done.

For each item assigned to `recorded_by` that is not already in reminders, add it via your
`reminders` capability with the meeting title as a note and any due date from the action item.

---

## Step 5: Re-ingest into knowledge base

The processing pipeline auto-ingests into the knowledge base **before** any cleanup, so profiles
may contain stale labels. Re-ingest now that names and speakers are resolved.

Skip this step only if Steps 3a, 3b, and 4 made **no changes** to the file whatsoever.

1. **Delete stale profiles** generated by the auto-ingest. In the knowledge base `people/`
   directory, remove any files matching these patterns (case-insensitive):
   - `speaker*.md`, `le-speaker*.md`
   - `unknown.md`, `unassigned.md`, `none.md`
   - Any file whose `# Title` is clearly not a person name (e.g. `Team`, `Attendees`,
     `Respectfully`, email-address slugs like `jdoe-example-com.md`)

2. **Re-ingest** with corrected names:
   ```
   minutes ingest <meeting-path>
   ```

3. **Check for new stale profiles.** After re-ingest, scan the `people/` directory for any
   profiles whose slug does not match a canonical attendee name — these indicate name-bearing
   fields that were missed in Step 3a. For each:
   - If it maps to a known person (short name, variant), merge its facts into the canonical
     profile and delete it.
   - If it is a non-person entity or unresolvable placeholder, delete it.
   - If it keeps regenerating, trace it back to the frontmatter field that is still producing it
     and fix that field.

4. **Check for duplicates.** The LLM summarizer sometimes uses first-name-only variants
   (e.g. `alex.md` alongside `alex-chen.md`). After re-ingest, scan for pairs where the
   short-name file's facts all come from the same meetings as the full-name file. Merge by
   appending unique fact lines from the short-name profile into the full-name profile under
   matching section headers, then delete the short-name file.

Record the counts (facts written, skipped, people updated, stale profiles removed, merges
performed) for the report.

---

## Step 6: Delete audio files

After re-ingest is complete, delete all audio files for the meeting. minutes never auto-prunes audio — without explicit deletion, .wav, .voice.wav, and .system.wav files accumulate indefinitely. There is no need to keep audio after post-meeting cleanup is done.

For each of the four files, delete if present:
- `<meeting-slug>.wav`
- `<meeting-slug>.voice.wav`
- `<meeting-slug>.system.wav`
- `./<meeting-slug>.embeddings` — hidden file storing diarizer voice vectors; safe to delete once processing is done

Use `rm -f` for all four patterns since not all will exist for every recording (e.g. voice-only recordings have no .system.wav). `minutes delete --with-audio` only targets the merged .wav and may miss stems and the embeddings file.

Record which files were deleted (and which were absent) for the report.

---

## Step 7: Report

```
Meeting: <title>
Date: <date>

Title: updated to "<new title>" / no change (no matching event)
Speakers: <N> confirmed, <N> still unidentified [samples + candidates if any]
          UNKNOWN segments: <N> (flag if high relative to total lines)
Knowledge base: re-ingested (<N> facts, <N> stale profiles removed, <N> merges) / skipped (no speaker changes)
Reminders: <N> action items added / already tracked
Audio: <N> files deleted (<total MB>)
```
