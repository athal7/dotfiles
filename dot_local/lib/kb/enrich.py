"""kb-enrich — update knowledge base from Slack conversations.
Scans DMs and private channels, extracts via LM Studio, merges into KB.
"""
import json, re, sys, time
from datetime import datetime, timezone

from kb.util import get_identity_name, log as _log
from kb.llm import lms_available, lms_call, clean_json
from kb.profiles import KB_DIR, update_people, update_projects, update_decisions, load_kb_people
from kb.slack import get_slack_token, slack_api

LOG_PREFIX = "kb-enrich"

def log(msg):
    _log(msg, prefix=LOG_PREFIX)

IDENTITY_NAME = get_identity_name()
STATE_FILE = KB_DIR / ".enrich-state.json"


# ---------------------------------------------------------------------------
# State management
# ---------------------------------------------------------------------------

def load_state():
    """Load last-run timestamp. Returns epoch float."""
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text())
            return data.get("last_run", 0)
        except json.JSONDecodeError:
            pass
    return 0


def save_state():
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps({"last_run": time.time()}) + "\n")


# ---------------------------------------------------------------------------
# Message formatting
# ---------------------------------------------------------------------------

SKIP_SUBTYPES = {"bot_message", "channel_join", "channel_leave", "group_join", "group_leave"}


def format_slack_text(text, kb_map):
    """Clean Slack markup to plain text, replacing user IDs with canonical names."""
    # Replace user mentions
    def replace_mention(m):
        uid = m.group(1)
        info = kb_map.get(uid)
        return info["name"] if info else "Unknown"
    text = re.sub(r"<@(U[A-Z0-9]+)>", replace_mention, text)
    # Replace links with display text
    text = re.sub(r"<(https?://[^|>]+)\|([^>]+)>", r"\2", text)
    # Replace bare links
    text = re.sub(r"<(https?://[^>]+)>", r"\1", text)
    # Strip emoji codes to just the name
    text = re.sub(r":([a-z0-9_+-]+):", r"\1", text)
    return text


def format_conversation(messages, kb_map, own_user_id):
    """Format messages into 'Name: text' lines. Returns formatted string."""
    lines = []
    for msg in messages:
        subtype = msg.get("subtype", "")
        if subtype in SKIP_SUBTYPES:
            continue
        text = msg.get("text", "").strip()
        if not text:
            continue
        user_id = msg.get("user", "")
        info = kb_map.get(user_id)
        if info:
            name = info["name"]
        elif user_id == own_user_id:
            name = IDENTITY_NAME
        else:
            name = "Unknown"
        cleaned = format_slack_text(text, kb_map)
        lines.append(f"{name}: {cleaned}")
    # Truncate to ~3000 words
    result = "\n".join(lines)
    words = result.split()
    if len(words) > 3000:
        result = " ".join(words[:3000])
    return result


# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

def extract_from_conversation(formatted_text, context_label, known_names):
    """One LLM call per conversation to extract KB-relevant content."""
    names_hint = f"\nKnown people (use these exact canonical names): {', '.join(known_names)}" if known_names else ""
    result = lms_call([
        {"role": "system", "content": (
            "Extract knowledge base updates from a Slack conversation. Output JSON with these keys:\n"
            '  "people": {"Person Name": ["fact1", "fact2"]},\n'
            '  "projects": {"Project Name": ["update1", "update2"]},\n'
            '  "decisions": ["Decision 1", "Decision 2"]\n'
            "Rules:\n"
            "- Style observations: note formality, message length patterns, emoji use, directness, communication preferences\n"
            "- Personal details mentioned casually (hobbies, family, location, schedule preferences)\n"
            "- Project status signals: blockers, progress, launches, decisions\n"
            "- Decisions made or agreed upon in the conversation\n"
            "- Skip mundane logistics (\"sounds good\", \"thanks\", scheduling back-and-forth)\n"
            "- Use the canonical names listed below when referring to known people\n"
            "- Output ONLY valid JSON, no commentary"
        )},
        {"role": "user", "content": (
            f"/no_think\n\nConversation context: {context_label}\n"
            f"Perspective: {IDENTITY_NAME}'s Slack{names_hint}\n\n"
            f"{formatted_text}\n\n/no_think"
        )}
    ], max_tokens=2000, timeout=120, log_prefix=LOG_PREFIX)
    return result


# ---------------------------------------------------------------------------
# Conversation fetching and processing
# ---------------------------------------------------------------------------

def fetch_conversations(token, kb_map, oldest):
    """Fetch DMs and private channels, filter to KB-relevant ones."""
    conversations = []
    cursor = ""
    while True:
        params = {"types": "im,mpim,private_channel", "limit": "200"}
        if cursor:
            params["cursor"] = cursor
        data = slack_api("conversations.list", token, params, log_prefix=LOG_PREFIX)
        if not data:
            break
        for ch in data.get("channels", []):
            ch_type = ch.get("is_im", False)
            if ch_type:
                # DM — only process if the other user is in KB
                other_user = ch.get("user", "")
                if other_user in kb_map:
                    conversations.append({
                        "id": ch["id"],
                        "type": "dm",
                        "user_id": other_user,
                        "name": kb_map[other_user]["name"],
                    })
            else:
                # mpim or private_channel — always include
                conversations.append({
                    "id": ch["id"],
                    "type": ch.get("name_normalized", ch.get("name", "private-channel")),
                    "name": ch.get("name", ch.get("name_normalized", "private-channel")),
                })
        cursor = data.get("response_metadata", {}).get("next_cursor", "")
        if not cursor:
            break
    return conversations


def fetch_messages(token, channel_id, oldest):
    """Fetch messages from a conversation since oldest timestamp. Returns list of messages."""
    messages = []
    cursor = ""
    while len(messages) < 200:
        params = {"channel": channel_id, "oldest": str(oldest), "limit": "200"}
        if cursor:
            params["cursor"] = cursor
        data = slack_api("conversations.history", token, params, log_prefix=LOG_PREFIX)
        if not data:
            break
        messages.extend(data.get("messages", []))
        cursor = data.get("response_metadata", {}).get("next_cursor", "")
        if not cursor:
            break
    # Slack returns newest-first; reverse to chronological
    messages.reverse()
    return messages[:200]


def process_slack(args):
    """Main Slack processing pipeline."""
    token = get_slack_token()
    if not token:
        log("ERROR: Could not retrieve Slack token from keychain")
        sys.exit(1)

    # Check LM Studio before doing any work
    if not args.dry_run and not lms_available():
        log("ERROR: LM Studio is unavailable — exiting")
        sys.exit(1)

    kb_map = load_kb_people()
    if not kb_map:
        log("No KB profiles with Slack IDs found — nothing to scan")
        return
    log(f"Loaded {len(kb_map)} KB profiles with Slack IDs")

    # Get own user ID
    auth_data = slack_api("auth.test", token, log_prefix=LOG_PREFIX)
    if not auth_data:
        log("ERROR: Slack auth.test failed")
        sys.exit(1)
    own_user_id = auth_data.get("user_id", "")
    log(f"Authenticated as {auth_data.get('user', 'unknown')} ({own_user_id})")

    # Determine oldest timestamp
    if args.since:
        oldest = time.time() - (args.since * 3600)
    else:
        state_ts = load_state()
        oldest = state_ts if state_ts > 0 else time.time() - 86400
    oldest_dt = datetime.fromtimestamp(oldest, tz=timezone.utc)
    log(f"Scanning messages since {oldest_dt:%Y-%m-%d %H:%M:%S UTC}")

    # Fetch conversations
    conversations = fetch_conversations(token, kb_map, oldest)
    log(f"Found {len(conversations)} relevant conversations")

    date_prefix = datetime.now().strftime("%Y-%m-%d")
    known_names = [info["name"] for info in kb_map.values()]
    total_updates = 0

    for conv in conversations:
        time.sleep(1)  # Rate limit
        messages = fetch_messages(token, conv["id"], oldest)
        if len(messages) < 3:
            continue

        if conv.get("type") == "dm":
            context_label = f"DM with {conv['name']}"
        else:
            context_label = f"#{conv['name']}"

        formatted = format_conversation(messages, kb_map, own_user_id)
        if not formatted.strip():
            continue

        word_count = len(formatted.split())
        log(f"  {context_label}: {len(messages)} messages, {word_count} words")

        if args.dry_run:
            print(f"\n--- {context_label} ({len(messages)} messages, {word_count} words) ---")
            # Show first 500 chars as preview
            print(formatted[:500])
            if len(formatted) > 500:
                print("  ...")
            continue

        # LLM extraction
        result = extract_from_conversation(formatted, context_label, known_names)
        if not result:
            log(f"  {context_label}: extraction returned empty")
            continue

        try:
            result = clean_json(result)
            extracted = json.loads(result)
        except json.JSONDecodeError:
            log(f"  WARNING: {context_label}: extraction returned invalid JSON")
            continue

        # KB merge
        people_count = update_people(extracted.get("people", {}), context_label, date_prefix, log_prefix=LOG_PREFIX)
        project_count = update_projects(extracted.get("projects", {}), context_label, date_prefix, log_prefix=LOG_PREFIX)
        decision_count = update_decisions(extracted.get("decisions", []), context_label, date_prefix, log_prefix=LOG_PREFIX)
        conv_updates = people_count + project_count + decision_count
        total_updates += conv_updates
        log(f"  {context_label}: {conv_updates} KB updates ({people_count} people, {project_count} projects, {decision_count} decisions)")

    if not args.dry_run:
        save_state()
        log(f"Done — {total_updates} total KB updates")
    else:
        log("Dry run complete — no LLM calls or KB writes made")


def main(args):
    import argparse
    parser = argparse.ArgumentParser(description="Update knowledge base from conversations")
    parser.add_argument("--slack", action="store_true", help="Enrich from Slack only")
    parser.add_argument("--email", action="store_true", help="Enrich from email only")
    parser.add_argument("--since", type=float, metavar="HOURS", help="Override state file, fetch from N hours ago")
    parser.add_argument("--dry-run", action="store_true", help="Fetch and format but skip LLM calls")
    parsed = parser.parse_args(args)

    # Default: both sources
    do_slack = parsed.slack or (not parsed.slack and not parsed.email)
    do_email = parsed.email or (not parsed.slack and not parsed.email)

    if do_email:
        log("Email enrichment not yet implemented")
        if not do_slack:
            return

    if do_slack:
        process_slack(parsed)
