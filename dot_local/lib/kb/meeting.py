"""meeting — convert a Zoom caption file into a meeting markdown file.
Summarizes via LM Studio, writes to ~/meetings/, updates knowledge base.
"""
import hashlib, json, os, re, subprocess, sys, time, traceback
from datetime import datetime
from pathlib import Path

from kb.util import slugify, get_identity_name, log as _log
from kb.llm import LMS_MODEL, lms_available, lms_call, clean_json
from kb.profiles import MEETINGS_DIR, KB_DIR, update_people, update_projects, update_decisions, consolidate_profiles

LOG_PREFIX = "meeting-postprocess"

def log(msg):
    _log(msg, prefix=LOG_PREFIX)

ZOOM_DIR = Path.home() / "Documents" / "Zoom"
IDENTITY_NAME = get_identity_name()
STATE_FILE = Path.home() / ".local" / "state" / "kb" / "processed.json"
SUMMARY_WORD_LIMIT = 4000  # safe limit for qwen3-8b with prompt overhead
CHUNK_WORD_TARGET = 3000   # words per chunk in map-reduce


def content_hash(path):
    """Return SHA-256 hex digest of a file's contents."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_state():
    """Read the dedup state file. Returns {} if missing or corrupt."""
    try:
        return json.loads(STATE_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}


def save_state(state):
    """Write the dedup state file, pruning entries whose caption files no longer exist."""
    pruned = {
        k: v for k, v in state.items()
        if Path(k).exists()
    }
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(pruned, indent=2))


def find_caption(args):
    if args:
        return Path(args[0])
    cutoff = datetime.now().timestamp() - 7200
    best, best_mtime = None, 0
    for p in ZOOM_DIR.rglob("meeting_saved_closed_caption.txt"):
        mt = p.stat().st_mtime
        if mt > cutoff and mt > best_mtime:
            best, best_mtime = p, mt
    return best


def get_title(caption_path):
    title = os.environ.get("MEETING_TITLE", "")
    if not title:
        folder = caption_path.parent.name
        m = re.match(r"^\d{4}-\d{2}-\d{2} \d+\.\d+\.\d+ (.+)$", folder)
        title = m.group(1) if m else ""
    if not title:
        try:
            mtime = datetime.fromtimestamp(caption_path.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
            result = subprocess.run(
                ["ical", "list", "-f", mtime, "-t", "+90m", "-n", "1", "-o", "json"],
                capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                data = json.loads(result.stdout)
                if data and data[0].get("title"):
                    title = data[0]["title"]
        except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError, IndexError, KeyError):
            pass
    return title or "Zoom Meeting"


def load_name_map():
    """Load display name -> canonical name mapping from knowledge/names.json."""
    names_file = MEETINGS_DIR / "knowledge" / "names.json"
    if names_file.exists():
        try:
            return json.loads(names_file.read_text())
        except json.JSONDecodeError:
            pass
    return {}


def normalize_name(name, name_map):
    """Map a Zoom display name to its canonical form."""
    if name in name_map:
        return name_map[name]
    # Try case-insensitive match
    lower = name.lower()
    for k, v in name_map.items():
        if k.lower() == lower:
            return v
    return name


def parse_transcript(caption_path):
    name_map = load_name_map()
    lines = caption_path.read_text().split("\n")
    entries, i = [], 0
    while i < len(lines):
        m = re.match(r"^\[(.+)\] (\d+):(\d+):(\d+)$", lines[i])
        if m and i + 1 < len(lines):
            speaker = normalize_name(m.group(1), name_map)
            secs = int(m.group(2)) * 3600 + int(m.group(3)) * 60 + int(m.group(4))
            entries.append((speaker, secs, lines[i + 1]))
            i += 2
        else:
            i += 1
    if not entries:
        return "", 0, "unknown"
    start = entries[0][1]
    dur_secs = entries[-1][1] - start
    if dur_secs < 0:
        dur_secs = 0
    duration = f"{dur_secs // 60}m {dur_secs % 60}s"
    parsed = []
    for speaker, secs, text in entries:
        rel = secs - start
        mm, ss = divmod(rel, 60)
        parsed.append(f"[{speaker} {mm}:{ss:02d}] {text}")
    transcript = "\n".join(parsed)
    return transcript, len(transcript.split()), duration


def _chunk_transcript(transcript, target_words=CHUNK_WORD_TARGET):
    """Split transcript into chunks of ~target_words, breaking at line boundaries."""
    lines = transcript.split("\n")
    chunks, current, current_wc = [], [], 0
    for line in lines:
        line_wc = len(line.split())
        if current and current_wc + line_wc > target_words:
            chunks.append("\n".join(current))
            current, current_wc = [], 0
        current.append(line)
        current_wc += line_wc
    if current:
        chunks.append("\n".join(current))
    return chunks


def summarize(transcript, title=""):
    if not lms_available():
        log("LM Studio not available — skipping summary")
        return ""

    word_count = len(transcript.split())
    log(f"Summarizing via LM Studio ({LMS_MODEL}), {word_count} words...")

    if word_count <= SUMMARY_WORD_LIMIT:
        # Single-shot summarization
        result = lms_call([
            {"role": "system", "content": "You are a meeting summarizer. Output ONLY markdown sections: ## Summary (3-5 sentences), ## Key Points (bullets), ## Action Items (bullets with owner, or \"- none\"), ## Open Questions (bullets or \"- none\"). No preamble, no reasoning, no thinking tags."},
            {"role": "user", "content": f"/no_think\n\nMeeting transcript:\n\n{transcript}\n\n/no_think Generate the markdown summary now."}
        ], max_tokens=2000, timeout=300, log_prefix=LOG_PREFIX)
        summary = result or ""
    else:
        # Map-reduce for long transcripts
        chunks = _chunk_transcript(transcript)
        log(f"Transcript too long for single pass — splitting into {len(chunks)} chunks")
        chunk_summaries = []
        for i, chunk in enumerate(chunks):
            log(f"  Summarizing chunk {i+1}/{len(chunks)}...")
            result = lms_call([
                {"role": "system", "content": "Summarize this section of a meeting transcript. Focus on key points, decisions, and action items. Output 3-5 bullet points. No preamble, no reasoning, no thinking tags."},
                {"role": "user", "content": f"/no_think\n\n{chunk}\n\n/no_think"}
            ], max_tokens=1000, timeout=120, log_prefix=LOG_PREFIX)
            if result:
                chunk_summaries.append(result)
        if not chunk_summaries:
            log("WARNING: All chunk summaries failed")
            return ""
        combined_input = "\n\n---\n\n".join(
            f"Section {i+1}:\n{s}" for i, s in enumerate(chunk_summaries)
        )
        title_hint = f" titled '{title}'" if title else ""
        result = lms_call([
            {"role": "system", "content": "You are a meeting summarizer. Combine section summaries into a single cohesive summary. Output ONLY markdown sections: ## Summary (3-5 sentences), ## Key Points (bullets), ## Action Items (bullets with owner, or \"- none\"), ## Open Questions (bullets or \"- none\"). No preamble, no reasoning, no thinking tags."},
            {"role": "user", "content": f"/no_think\n\nThese are summaries of consecutive sections of a meeting{title_hint}. Combine them into a single cohesive summary.\n\n{combined_input}\n\n/no_think"}
        ], max_tokens=2000, timeout=300, log_prefix=LOG_PREFIX)
        summary = result or ""

    if summary:
        log(f"Summary: {len(summary.split())} words")
    else:
        log("WARNING: LM Studio returned empty summary")
    return summary


def write_output(title, date_str, duration, summary, transcript, word_count, existing_output=None):
    slug = slugify(title)
    first_name = IDENTITY_NAME.split()[0].lower() if IDENTITY_NAME else "unknown"
    date_prefix = date_str[:10]
    if existing_output:
        output = Path(existing_output)
    else:
        output = MEETINGS_DIR / f"{date_prefix}-{slug}-{first_name}.md"
    status = "complete" if summary else "degraded"
    parts = [
        "---",
        f"title: {title}",
        "type: meeting",
        f"date: {date_str}",
        f"duration: {duration}",
        f"status: {status}",
        f"source: zoom-capture",
        f"recorded_by: {IDENTITY_NAME}",
        "---",
        "",
    ]
    if summary:
        parts.extend([summary, ""])
    parts.extend(["## Transcript", "", transcript, ""])
    MEETINGS_DIR.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(parts))
    log(f"Wrote: {output} ({word_count} words)")
    return output, date_prefix


def extract_from_existing_md(md_path):
    """Extract summary, title, date from an existing meeting markdown file."""
    content = md_path.read_text()
    title_m = re.search(r"^title:\s*(.+)$", content, re.MULTILINE)
    title = title_m.group(1).strip() if title_m else md_path.stem
    date_m = re.search(r"^date:\s*(\S+)", content, re.MULTILINE)
    date_str = date_m.group(1) if date_m else ""
    # Extract summary sections (everything between frontmatter and ## Transcript)
    summary = ""
    if "---" in content:
        after_front = content.split("---", 2)[-1].strip()
        if "## Transcript" in after_front:
            summary = after_front.split("## Transcript")[0].strip()
        else:
            summary = after_front
    # Extract speaker names from transcript
    transcript = content.split("## Transcript", 1)[-1] if "## Transcript" in content else ""
    speakers = sorted(set(re.findall(r"^\[([^\]]+?) \d+:\d{2}\]", transcript, re.MULTILINE)))
    return title, date_str, summary, speakers


def get_reminders_list():
    """Find which reminders list has post_meeting: true in chezmoi data."""
    try:
        result = subprocess.run(
            ["chezmoi", "data", "--format=json"],
            capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            data = json.loads(result.stdout)
            for key, cfg in data.get("reminders", {}).items():
                if cfg.get("post_meeting"):
                    return cfg.get("name", key)
    except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
        pass
    return None


def report_error(title, error_msg):
    """Add a reminder about a processing error so the user notices."""
    try:
        list_name = get_reminders_list()
        if not list_name:
            return
        subprocess.run(
            ["remindctl", "add", "--list", list_name,
             f"meeting-postprocess failed: {title}: {error_msg}"],
            capture_output=True, text=True, timeout=10)
    except Exception:
        pass  # best-effort


def add_reminders(summary, title):
    """Extract action items assigned to me from the summary and add to Reminders.

    Returns True if all items were added (or there was nothing to add),
    False if any remindctl add call failed.
    """
    if not summary:
        return True
    try:
        subprocess.run(["remindctl", "--help"], capture_output=True, timeout=3)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        log("WARNING: remindctl not available")
        return False

    list_name = get_reminders_list()
    if not list_name:
        log("WARNING: No reminders list configured with post_meeting: true")
        return False

    # Find the Action Items section
    in_actions = False
    items = []
    for line in summary.split("\n"):
        if re.match(r"^##\s*Action Items", line, re.IGNORECASE):
            in_actions = True
            continue
        if in_actions and line.startswith("## "):
            break
        if in_actions and line.strip().startswith(("- ", "* ")):
            item = line.strip().lstrip("-* ").strip()
            if item.lower() != "none":
                items.append(item)

    # Filter to items assigned to me (first name match)
    first_name = IDENTITY_NAME.split()[0].lower() if IDENTITY_NAME else ""
    my_items = [i for i in items if first_name and first_name in i.lower()]
    if not my_items:
        return True

    added = 0
    failed = 0
    for item in my_items:
        try:
            result = subprocess.run(
                ["remindctl", "add", "--list", list_name, "--notes", title, item],
                capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                added += 1
            else:
                failed += 1
                log(f"WARNING: remindctl add failed (exit {result.returncode}): {result.stderr.strip()}")
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            failed += 1
            log(f"WARNING: remindctl add error: {e}")
    if added:
        log(f"Reminders: {added} action items added to {list_name} list")
    if failed:
        log(f"WARNING: {failed}/{len(my_items)} reminder(s) failed to add")
    return failed == 0


def update_knowledge_base(summary, title, date_prefix, speakers):
    """Update all KB categories from the meeting summary in one LLM call."""
    kb_dir = MEETINGS_DIR / "knowledge"
    if not kb_dir.exists():
        kb_dir.mkdir(parents=True)
    for sub in ["people", "projects", "decisions"]:
        (kb_dir / sub).mkdir(exist_ok=True)

    if not summary or not lms_available():
        log("KB: skipped (no summary or LM Studio unavailable)")
        return

    meeting_ref = f"{date_prefix}: {title}"

    # Build known-names hint so the LLM uses canonical names
    known_people = [p.stem.replace("-", " ").title() for p in (kb_dir / "people").glob("*.md")]
    known_hint = f"\nKnown people (use these exact names): {', '.join(known_people)}" if known_people else ""

    # One LLM call to extract all KB updates from the summary
    speakers_hint = f"\nMeeting attendees (present but not necessarily involved in all topics): {', '.join(speakers)}" if speakers else ""
    result = lms_call([
        {"role": "system", "content": (
            "Extract knowledge base updates from a meeting summary. Output JSON with these keys:\n"
            '  "people": {"Person Name": ["fact1", "fact2"]},\n'
            '  "projects": {"Project Name": ["update1", "update2"]},\n'
            '  "decisions": ["Decision 1", "Decision 2"]\n'
            "Rules:\n"
            "- Only substantive facts — decisions, commitments, status changes, role/responsibility info.\n"
            "- CRITICAL ATTRIBUTION: Only attribute a fact to the person who is RESPONSIBLE for or DIRECTLY working on it. "
            "If a topic was discussed in a meeting, do NOT add it to every attendee's profile — only to the people who own or are assigned that work. "
            "Meeting attendance \u2260 involvement.\n"
            "- Skip filler, meeting logistics, and general discussion topics.\n"
            "- Use the canonical names listed below when referring to known people.\n"
            f"- Do NOT include the meeting organizer/recorder ({IDENTITY_NAME}) in people unless they took on specific action items.\n"
            "- Output ONLY valid JSON, no commentary."
        )},
        {"role": "user", "content": f"/no_think\n\nMeeting: {title} ({date_prefix})\nRecorded by: {IDENTITY_NAME}{known_hint}{speakers_hint}\n\n{summary}\n\n/no_think"}
    ], max_tokens=2000, log_prefix=LOG_PREFIX)

    if not result:
        return

    try:
        result = clean_json(result)
        extracted = json.loads(result)
    except json.JSONDecodeError:
        log("WARNING: KB extraction returned invalid JSON")
        return

    updated = 0

    # People
    people_count = update_people(extracted.get("people", {}), title, date_prefix, log_prefix=LOG_PREFIX)
    updated += people_count

    # Projects
    project_count = update_projects(extracted.get("projects", {}), title, date_prefix, log_prefix=LOG_PREFIX)
    updated += project_count

    # Decisions
    decision_count = update_decisions(extracted.get("decisions", []), title, date_prefix, log_prefix=LOG_PREFIX)
    updated += decision_count

    # Consolidate bloated profiles
    consolidated = consolidate_profiles(log_prefix=LOG_PREFIX)

    log(f"Knowledge base: {updated} updates, {consolidated} consolidated")


def main(args):
    if args and args[0] in ("-h", "--help"):
        print("Usage: python3 -m kb meeting [/path/to/caption.txt]", file=sys.stderr)
        print("       If no path given, finds most recent caption in ~/Documents/Zoom/", file=sys.stderr)
        sys.exit(0)
    caption_path = find_caption(args)
    if caption_path is None:
        log(f"No recent caption file found in {ZOOM_DIR}")
        return
    caption_path = Path(caption_path)
    if not caption_path.is_file():
        log(f"ERROR: file not found: {caption_path}")
        sys.exit(1)

    # Detect input type: existing .md or Zoom caption .txt
    if caption_path.suffix == ".md":
        # Existing meeting — just update KB + reminders, don't rewrite
        title, date_str, summary, speakers = extract_from_existing_md(caption_path)
        date_prefix = date_str[:10] if date_str else "unknown"
        log(f"Existing meeting: {title} ({date_prefix})")
        if summary:
            update_knowledge_base(summary, title, date_prefix, speakers)
            if add_reminders(summary, title) is False:
                report_error(title, "reminders failed")
        else:
            log("No summary found — skipping KB update")
        log("Done")
        return

    # Dedup guard — skip if caption is unchanged since last run
    caption_key = str(caption_path.resolve())
    file_hash = content_hash(caption_path)
    state = load_state()
    existing_output = None
    if caption_key in state:
        prev = state[caption_key]
        if prev.get("hash") == file_hash:
            log("Already processed (unchanged), skipping")
            return
        log("Caption updated, reprocessing")
        existing_output = Path(prev["output"]) if prev.get("output") else None

    # New Zoom caption — full pipeline
    title = get_title(caption_path)
    log(f"Title: {title}")
    transcript, word_count, duration = parse_transcript(caption_path)
    log(f"Transcript: {word_count} words")
    if word_count < 10:
        log("Transcript too short — skipping")
        return
    mtime = caption_path.stat().st_mtime
    date_str = datetime.fromtimestamp(mtime).astimezone().strftime("%Y-%m-%dT%H:%M:%S%z")
    warnings = []
    summary = summarize(transcript, title=title)
    if not summary:
        warnings.append("summary failed")
    output_path, date_prefix = write_output(
        title, date_str, duration, summary, transcript, word_count,
        existing_output=existing_output,
    )
    # Update dedup state
    state[caption_key] = {
        "hash": file_hash,
        "output": str(output_path),
        "timestamp": time.time(),
    }
    save_state(state)

    speakers = sorted(set(re.findall(r"^\[([^\]]+?) \d+:\d{2}\]", transcript, re.MULTILINE)))
    update_knowledge_base(summary, title, date_prefix, speakers)
    if add_reminders(summary, title) is False:
        warnings.append("reminders failed")
    if warnings:
        report_error(title, "; ".join(warnings))
    log("Done")
