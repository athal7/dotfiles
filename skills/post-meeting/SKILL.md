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

Accepts an optional meeting path or slug; if not provided, operates on the most recently processed meeting.

---

## Step 1: Wait for processing, then resolve the meeting

Poll `minutes jobs --json --limit 1` every 15 seconds until the most recent job reaches `state: "complete"` (or `"failed"`). Cap at 20 minutes — report timeout and stop if not complete. On failure, report the error and stop.

Once complete, its `output_path` is the meeting file. If a path or slug was provided, use that instead. Read the full frontmatter: `title`, `date`, `duration`, `speaker_map`, `attendees`, `action_items`, `recorded_by`.

**If re-processing is needed** (e.g. to use a better model or to pick up sibling stems): `minutes process` will fail with "Ill-formed WAVE file" if the base `.wav` is a QuickTime/AAC file (common with ReplayKit captures). The sibling `.voice.wav` and `.system.wav` stems are valid RIFF WAVs but are ignored when the base file fails. Workaround: convert the base file with `ffmpeg -i <slug>.wav -ar 16000 -ac 1 -c:a pcm_s16le <slug>_converted.wav`, then copy it over the original (`mv <slug>_converted.wav <slug>.wav`) so `minutes process` finds a valid RIFF file alongside the existing stems.

---

## Step 2: Update the title

Use your `calendar` capability to list non-all-day, non-Busy events in a ±90-minute window around the meeting's `date` field. Pass **local time** to the query bounds.

Find the best match: prefer an event whose window contains the recording start time; fall back to nearest start. Skip events titled `""` or `"Busy"`.

If a match is found and its title differs from `title:` in the frontmatter, rewrite that line. Report what changed. If no match, note it and move on.

---

## Step 3: Resolve attendee names and identify speakers

If a calendar event was matched in Step 2, fetch the full attendee list (`show` with the event ID).

### 3a: Resolve short and garbled names in frontmatter

The LLM summarizer writes names as it hears them — first-name-only, phonetic mishearings, placeholders. **Run before speaker identification and before Steps 4–5.**

1. Build a canonical name map from the attendee list. For each email, derive the full name; if absent, look up in the KB or past meetings.
2. Scan all name-bearing fields: `attendees`, `people`, `entities.people` (slugs, labels, aliases), `action_items[].assignee`, `intents[].who`. Collect all distinct name values.
3. For each name that does not exactly match a canonical full name:
   - Clear short form, phonetic variant, or `Name: Role` → replace with canonical full name
   - Placeholder (`The Speaker`, `[speaker_2]`, `unassigned`) → resolve from context, otherwise `Unknown`
   - Verbose composite (`Person A and @Person B`) → replace with primary assignee's canonical name
   - Colon-separated role suffix → strip to just the canonical name
   - **Fused/hallucinated names** — the summarizer sometimes fuses adjacent words into a fake person (e.g. hearing "Alex and Sam" and writing "Alex Sam", or phonetically garbling a company name into a person). After substitution, check remaining names against the canonical attendee list and the KB. Any name that matches neither a known person nor a known organization: flag it, show the transcript context where it appeared, and ask the user whether it's a real person (and who), a company/org name, or a transcription artifact to remove.
4. In `entities.people`: update `slug`, `label`, and `aliases` to match canonical names. Remove duplicates and non-person entities.
5. Deduplicate `attendees` and `people` lists after substitution.
6. Write the updated frontmatter back to the file.

### 3b: Identify speakers

Read `speaker_map` and scan the transcript for all `SPEAKER_N` and `UNKNOWN` labels.

A speaker is **unidentified** if they have no `speaker_map` entry, their entry has confidence `low`, or their name is a placeholder (`Unknown`, `Speaker_1`, `Le Speaker_N`, etc.).

**Check diarization quality first.** Flag as poor quality if either condition holds:
- UNKNOWN lines exceed 10% of total transcript lines
- Fewer than half of `speaker_map` entries have confidence `high`

**For every unidentified speaker — regardless of how many there are — always do this:**

1. Sample 3–5 representative quotes spread across the transcript (not just the first lines).
2. Present the quotes and candidate names from the attendee list to the user. Wait for their response before writing anything.
3. If the user confirms: write the `speaker_map` entry (`name`, `confidence: high`, `source: manual`), replace all `SPEAKER_N:` labels in the transcript body, then run `minutes confirm --meeting <path> --speaker SPEAKER_N --name "<name>" --save-voice`.

**Upgrade `medium/deterministic` confidence entries:** if `speaker_map` already contains an entry with `confidence: medium` and `source: deterministic`, verify it before proceeding. If the mapped speaker is `recorded_by` and the transcript is consistent with that person speaking throughout (no obvious voice shifts, content matches their role), upgrade the entry to `confidence: high, source: manual` and replace any remaining `SPEAKER_N:` labels in the transcript body. If it cannot be verified, treat it as unidentified and present samples.

**Auto-confirm is only permitted when:**
- Diarization quality is good (not flagged above), AND
- Exactly 1 unidentified speaker remains AND exactly 1 unmatched attendee exists

Even when auto-confirming, still show the sample quotes and your reasoning so the user can catch a misidentification. Wait for acknowledgment before writing.

**If diarization quality is poor:** do not auto-confirm anyone. Present all unidentified speakers with samples and ask the user to resolve them before proceeding.

**Merged speakers:** if quotes for a single `SPEAKER_N` label show clearly different speaking styles, vocabulary shifts, or inconsistent self-references — or if the meeting had a structured turn-taking format (standup, round-robin demo) where multiple people clearly spoke in sequence — flag it as a probable merge before confirming. Ask the user to confirm the split. Once confirmed, use the same facilitation-cue approach as UNKNOWN segments: scan for names being called, turn-taking signals, and self-identifying statements to map individual transcript lines to speakers. Rename affected lines to new labels (e.g. `SPEAKER_N_B:`) and add separate `speaker_map` entries for each sub-cluster.

**`UNKNOWN` segments:** when diarization quality is poor, do not just note the count — attempt to resolve them. Scan for facilitation cues in the transcript: speakers being called on by name (`"Alex, how about you?"`, `"thanks, thank you Sam"`), turn-taking patterns, and self-identifying statements. Present these cues and 2–3 sample quotes from each distinct UNKNOWN run to the user and ask them to identify the speaker. Once confirmed, relabel the matching transcript lines with the resolved name. Only mark a segment permanently unresolvable if no cues exist and the user cannot identify it from the samples.

---

## Step 4: Add action items to reminders

Collect items assigned to `recorded_by` from **both** of these structures — they are parallel and both must be checked:

- `action_items[]` — top-level list; check `assignee`
- `intents[]` where `kind: action-item` or `kind: commitment` — check `who`

**Do not skip `intents`** — the pipeline writes commitments here that do not appear in `action_items`. A commitment entry looks like: `{ kind: commitment, who: "Alex", text: "Will follow up with Sam about the proposal" }`.

For any entry whose `assignee`/`who` is still a `SPEAKER_N` label, look it up in `speaker_map` and rewrite it in the file before adding the reminder.

Add each item not already in reminders via your `reminders` capability, with the meeting title as a note and any due date from the entry.

---

## Step 5: Re-ingest into knowledge base

Skip only if Steps 3a, 3b, and 4 made no changes to the file.

1. **Delete stale profiles** in `people/`: `speaker*.md`, `le-speaker*.md`, `unknown.md`, `unassigned.md`, `none.md`, and any file whose title is clearly not a person name.
2. **Re-ingest:** `minutes ingest <meeting-path>`
3. **Check for new stale profiles.** For each slug that doesn't match a canonical attendee name: merge into the canonical profile if resolvable, otherwise delete. If it keeps regenerating, trace and fix the source field in the frontmatter.
4. **Check for duplicates** (e.g. `alex.md` alongside `alex-chen.md`). Merge unique facts into the full-name profile and delete the short-name file.
5. **Check for joint-attribution profiles** — slugs of the form `person-a-and-person-b.md`. These should never exist. For each: copy the facts to each person's individual profile, then delete the joint file.

Record counts (facts written, skipped, people updated, stale profiles removed, merges) for the report.

---

## Step 6: Delete audio files

Delete all audio files for the meeting using `rm -f`:
- `<meeting-slug>.wav`
- `<meeting-slug>.voice.wav`
- `<meeting-slug>.system.wav`
- `<meeting-slug>.embeddings`

Record which files were deleted (and which were absent) for the report.

---

## Step 7: Report

```
Meeting: <title>
Date: <date>

Title: updated to "<new title>" / no change (no matching event)
Speakers: <N> confirmed, <N> still unidentified [samples + candidates if any]
          UNKNOWN segments: <N> (flag if high relative to total lines)
Knowledge base: re-ingested (<N> facts, <N> stale profiles removed, <N> merges) / skipped (no changes)
Reminders: <N> action items added / already tracked
Audio: <N> files deleted (<total MB>)
```
