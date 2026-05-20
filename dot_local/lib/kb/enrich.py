"""kb-enrich — update knowledge base from conversations and project metadata.
Scans Slack DMs/channels (via LLM), Linear projects (metadata only), and more.
"""
import json, re, sys, time
from datetime import datetime, timezone

from kb.util import get_identity_name, log as _log
from kb.llm import lms_available, lms_call, clean_json
from kb.profiles import KB_DIR, update_people, update_projects, update_decisions, load_kb_people, consolidate_profiles
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
        # Consolidate bloated profiles
        consolidated = consolidate_profiles(log_prefix=LOG_PREFIX)
        save_state()
        log(f"Done — {total_updates} total KB updates, {consolidated} consolidated")
    else:
        log("Dry run complete — no LLM calls or KB writes made")


def _write_linear_field(profile_path, value, dry_run):
    """Add or update the `- **Linear**: ...` field in a profile. Returns True if changed."""
    content = profile_path.read_text()
    if re.search(r"^- \*\*Linear\*\*:", content, re.MULTILINE):
        new_content = re.sub(
            r"^- \*\*Linear\*\*:.*$",
            f"- **Linear**: {value}",
            content, count=1, flags=re.MULTILINE)
    else:
        new_content = re.sub(
            r"^(# .+)$",
            f"\\1\n- **Linear**: {value}",
            content, count=1, flags=re.MULTILINE)
    if new_content == content:
        return False
    if not dry_run:
        profile_path.write_text(new_content)
    return True


def load_product_labels():
    """Load Linear label -> product profile slug mapping from product-labels.json."""
    labels_file = KB_DIR / "product-labels.json"
    if labels_file.exists():
        try:
            return json.loads(labels_file.read_text())
        except json.JSONDecodeError:
            pass
    return {}


def process_linear(args):
    """Enrich KB profiles from Linear: labels for products, URLs for projects."""
    from kb.linear import get_linear_token, fetch_all_projects
    from kb.profiles import load_project_map, normalize_project
    from kb.util import slugify

    token = get_linear_token()
    if not token:
        log("ERROR: Could not retrieve Linear API key from keychain")
        return

    projects = fetch_all_projects(token, log_prefix=LOG_PREFIX)
    if not projects:
        log("No Linear projects found")
        return
    log(f"Fetched {len(projects)} Linear projects")

    projects_dir = KB_DIR / "projects"
    if not projects_dir.is_dir():
        log("No KB projects directory")
        return

    project_map = load_project_map()
    updated = 0

    # --- Phase 1: Product label enrichment ---
    product_labels = load_product_labels()

    # Collect which labels apply to which product slugs
    product_label_sets = {}  # slug -> set of label names
    for lp in projects:
        for label in lp.get("labels", []):
            slug = product_labels.get(label)
            if slug:
                product_label_sets.setdefault(slug, set()).add(label)

    for slug, labels in product_label_sets.items():
        profile_path = projects_dir / f"{slug}.md"
        if not profile_path.exists():
            continue

        label_value = ", ".join(f"label:{l}" for l in sorted(labels))

        if args.dry_run:
            log(f"  {slug}: would set Linear labels {label_value}")
            updated += 1
            continue

        if _write_linear_field(profile_path, label_value, dry_run=False):
            log(f"  {slug}: set Linear labels")
            updated += 1

    # --- Phase 2: Project URL enrichment ---
    for lp in projects:
        linear_name = lp["name"]
        linear_url = lp["url"]

        # Normalize through projects.json
        canonical = normalize_project(linear_name, project_map)
        if not canonical:  # suppressed
            continue
        slug = slugify(canonical)
        profile_path = projects_dir / f"{slug}.md"

        if not profile_path.exists():
            # Fallback: slugify the Linear name directly
            slug2 = slugify(linear_name)
            profile_path2 = projects_dir / f"{slug2}.md"
            if profile_path2.exists():
                profile_path = profile_path2
            else:
                continue  # no matching KB profile

        content = profile_path.read_text()

        # Already has this exact URL — skip
        if linear_url in content:
            continue

        if args.dry_run:
            log(f"  {canonical}: would add Linear URL {linear_url}")
            updated += 1
            continue

        if _write_linear_field(profile_path, linear_url, dry_run=False):
            log(f"  {canonical}: added Linear URL")
            updated += 1

    log(f"Linear enrichment: {updated} profiles updated")


def process_github(args):
    """Enrich KB project profiles with GitHub repo URLs."""
    from kb.github import fetch_org_repos

    repos_file = KB_DIR / "github-repos.json"
    if not repos_file.exists():
        log("No github-repos.json found — skipping GitHub enrichment")
        return
    try:
        repo_map = json.loads(repos_file.read_text())
    except json.JSONDecodeError:
        log("Invalid github-repos.json — skipping")
        return

    org = repo_map.pop("_org", "")
    if not org:
        log("No _org key in github-repos.json — skipping")
        return

    repos = fetch_org_repos(org, log_prefix=LOG_PREFIX)
    if not repos:
        log("No GitHub repos fetched")
        return
    log(f"Fetched {len(repos)} repos from {org}")

    projects_dir = KB_DIR / "projects"
    if not projects_dir.is_dir():
        return

    updated = 0
    for repo in repos:
        repo_name = repo["name"]
        profile_slug = repo_map.get(repo_name)
        if not profile_slug:
            continue

        profile_path = projects_dir / f"{profile_slug}.md"
        if not profile_path.exists():
            continue

        repo_url = repo["url"]
        content = profile_path.read_text()

        if repo_url in content:
            continue

        if args.dry_run:
            log(f"  {profile_slug}: would add GitHub URL {repo_url}")
            updated += 1
            continue

        if re.search(r"^- \*\*GitHub\*\*:", content, re.MULTILINE):
            # Append to existing field (a project can have multiple repos)
            existing_match = re.search(r"^(- \*\*GitHub\*\*: .+)$", content, re.MULTILINE)
            if existing_match and repo_url not in existing_match.group(1):
                content = content.replace(
                    existing_match.group(1),
                    f"{existing_match.group(1)}, {repo_url}")
        else:
            # Insert after Linear field if present, otherwise after # Name header
            if re.search(r"^- \*\*Linear\*\*:", content, re.MULTILINE):
                content = re.sub(
                    r"^(- \*\*Linear\*\*: .+)$",
                    f"\\1\n- **GitHub**: {repo_url}",
                    content, count=1, flags=re.MULTILINE)
            else:
                content = re.sub(
                    r"^(# .+)$",
                    f"\\1\n- **GitHub**: {repo_url}",
                    content, count=1, flags=re.MULTILINE)

        profile_path.write_text(content)
        log(f"  {profile_slug}: added GitHub URL")
        updated += 1

    log(f"GitHub enrichment: {updated} profiles updated")


def main(args):
    import argparse
    parser = argparse.ArgumentParser(description="Update knowledge base from conversations")
    parser.add_argument("--slack", action="store_true", help="Enrich from Slack only")
    parser.add_argument("--linear", action="store_true", help="Enrich project metadata from Linear")
    parser.add_argument("--github", action="store_true", help="Enrich project profiles with GitHub repo URLs")
    parser.add_argument("--since", type=float, metavar="HOURS", help="Override state file, fetch from N hours ago")
    parser.add_argument("--dry-run", action="store_true", help="Fetch and format but skip LLM calls")
    parsed = parser.parse_args(args)

    # Default: all sources when no specific flag given
    no_source_flag = not parsed.slack and not parsed.linear and not parsed.github
    do_slack = parsed.slack or no_source_flag
    do_linear = parsed.linear or no_source_flag
    do_github = parsed.github or no_source_flag

    if do_linear:
        process_linear(parsed)

    if do_github:
        process_github(parsed)

    if do_slack:
        process_slack(parsed)
