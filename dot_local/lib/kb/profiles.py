"""KB profile merge logic — people, projects, decisions."""
import json, os, re
from pathlib import Path
from kb.util import slugify, log
from kb.llm import lms_call

MEETINGS_DIR = Path(os.environ.get("MEETINGS_DIR", Path.home() / "meetings"))
KB_DIR = MEETINGS_DIR / "knowledge"


def load_kb_people():
    """Load KB profiles and extract Slack user IDs. Returns {slack_id: {name, slug}}."""
    people_dir = KB_DIR / "people"
    if not people_dir.is_dir():
        return {}
    kb_map = {}
    slack_re = re.compile(r"-\s*\*\*Slack\*\*:\s*<@(U[A-Z0-9]+)>")
    name_re = re.compile(r"^#\s+(.+)$", re.MULTILINE)
    for profile in people_dir.glob("*.md"):
        content = profile.read_text()
        slack_m = slack_re.search(content)
        if not slack_m:
            continue
        slack_id = slack_m.group(1)
        name_m = name_re.search(content)
        canonical_name = name_m.group(1).strip() if name_m else profile.stem.replace("-", " ").title()
        kb_map[slack_id] = {"name": canonical_name, "slug": profile.stem}
    return kb_map


def update_people(people_facts, context_label, date_prefix, log_prefix="kb"):
    """Merge people facts into KB profiles."""
    people_dir = KB_DIR / "people"
    people_dir.mkdir(parents=True, exist_ok=True)
    updated = 0
    for name, facts in people_facts.items():
        slug = slugify(name)
        if not slug:
            continue
        profile = people_dir / f"{slug}.md"
        existing = profile.read_text() if profile.exists() else ""
        new_facts = "\n".join(f"- {f}" for f in facts)
        updated_profile = lms_call([
            {"role": "system", "content": (
                "Update a person's knowledge base profile. The profile should be a distilled summary, NOT a meeting log. "
                "Format:\n# Name\n- **Email**: value\n- **Slack**: value\n- **Title**: value\n- **Team**: value\n"
                "(Only include a contact field if the value is known — omit the line entirely otherwise.)\n"
                "\n## Current\n- What they're actively working on RIGHT NOW (max 5 bullets)\n"
                "\n## Style\n- How they communicate (direct/detailed, technical/non-technical, preferences observed)\n"
                "\n## Personal\n- Interests, family mentions, hobbies, location, anything personal shared in conversation\n"
                "\n## Key Decisions\n- Important decisions they've made or been part of (with date, max 10)\n"
                "\nRules: Merge new facts into the existing profile. Update fields that changed. "
                "AGGRESSIVELY drop outdated info: if something in Current was from weeks ago and isn't mentioned in new info, remove it. "
                "Current = what they're doing THIS WEEK, not a history. Key Decisions = only the most important and recent. "
                "Keep it concise — this is a reference card, not a transcript. "
                "IMPORTANT: Preserve all existing contact fields (Email, Slack, Title, Team) — never remove them. "
                "Omit any section or field entirely if there's no information — never write placeholders like '(if known)' or '(No details)'. Output ONLY the markdown."
            )},
            {"role": "user", "content": (
                f"/no_think\n\n{'Existing profile:\n' + existing if existing else 'New person — no existing profile.'}\n\n"
                f"New info from: {context_label} ({date_prefix})\n{new_facts}\n\n/no_think"
            )}
        ], max_tokens=1500, log_prefix=log_prefix)
        if updated_profile:
            updated_profile = updated_profile.strip()
            if not updated_profile.startswith(f"# {name}"):
                updated_profile = re.sub(r"^#\s+.*$", f"# {name}", updated_profile, count=1, flags=re.MULTILINE)
            profile.write_text(updated_profile.rstrip("\n") + "\n")
            updated += 1
    return updated


def consolidate_profiles(log_prefix="kb"):
    """Consolidate bloated people and project profiles. Run after updates."""
    max_lines = 40
    consolidated = 0
    for subdir in ["people", "projects"]:
        profile_dir = KB_DIR / subdir
        if not profile_dir.is_dir():
            continue
        for profile in profile_dir.glob("*.md"):
            content = profile.read_text()
            lines = content.strip().split("\n")
            if len(lines) <= max_lines:
                continue
            log(f"Consolidating {subdir}/{profile.name} ({len(lines)} lines)", prefix=log_prefix)
            result = lms_call([
                {"role": "system", "content": (
                    "Condense this knowledge base profile. It has grown too long. Rules:\n"
                    "- Current section: keep only the 3-5 MOST RECENT and ACTIVE items. Drop anything completed or stale.\n"
                    "- Key Decisions: keep only the 5-8 most important. Drop minor or superseded ones.\n"
                    "- Style/Personal: keep as-is (these are already concise).\n"
                    "- Contact/link fields (Email, Slack, Title, Team, Linear, GitHub): preserve exactly as they are.\n"
                    "- Target: under 35 lines total.\n"
                    "- Output ONLY the condensed markdown."
                )},
                {"role": "user", "content": f"/no_think\n\n{content}\n\n/no_think"}
            ], max_tokens=1500, log_prefix=log_prefix)
            if result:
                result = result.strip()
                # Preserve original name header
                name_m = re.search(r"^#\s+(.+)$", content, re.MULTILINE)
                if name_m:
                    expected_header = f"# {name_m.group(1).strip()}"
                    if not result.startswith(expected_header):
                        # Try to replace an existing header
                        if re.match(r"^#\s+", result):
                            result = re.sub(r"^#\s+.*$", expected_header, result, count=1, flags=re.MULTILINE)
                        else:
                            # LLM omitted header entirely — prepend it
                            result = expected_header + "\n" + result
                profile.write_text(result.rstrip("\n") + "\n")
                new_lines = len(result.strip().split("\n"))
                log(f"  → {new_lines} lines", prefix=log_prefix)
                consolidated += 1
    return consolidated


def load_project_map():
    """Load project name -> canonical name mapping."""
    projects_file = KB_DIR / "projects.json"
    if projects_file.exists():
        try:
            return json.loads(projects_file.read_text())
        except json.JSONDecodeError:
            pass
    return {}


def normalize_project(name, project_map):
    """Map a project name to its canonical form. Returns empty string to suppress."""
    if name in project_map:
        return project_map[name]
    lower = name.lower()
    for k, v in project_map.items():
        if k.lower() == lower:
            return v
    return name


def update_projects(project_facts, context_label, date_prefix, log_prefix="kb"):
    """Merge project facts into KB profiles."""
    projects_dir = KB_DIR / "projects"
    projects_dir.mkdir(parents=True, exist_ok=True)
    updated = 0
    project_map = load_project_map()
    for project, updates in project_facts.items():
        project = normalize_project(project, project_map)
        if not project:  # suppressed
            continue
        slug = slugify(project)
        if not slug:
            continue
        profile = projects_dir / f"{slug}.md"
        existing = profile.read_text() if profile.exists() else ""
        new_facts = "\n".join(f"- {u}" for u in updates)
        updated_profile = lms_call([
            {"role": "system", "content": (
                "Update a project's knowledge base profile. The profile should reflect current state, NOT be a meeting log. "
                "Format:\n# Project Name\n- **Linear**: project URL\n- **GitHub**: repo URL\n"
                "(Only include a link field if the URL is known — omit the line entirely otherwise.)\n"
                "\n## Status\n- Current state, what's active, what's blocked\n"
                "\n## Key Decisions\n- Important decisions (with date)\n"
                "\n## People\n- Key people involved and their roles\n"
                "\nRules: Merge new info. Update status if changed. Drop superseded decisions. Keep concise. "
                "IMPORTANT: Preserve all existing link fields (Linear, GitHub) — never remove them. "
                "Output ONLY the markdown."
            )},
            {"role": "user", "content": (
                f"/no_think\n\n{'Existing profile:\n' + existing if existing else 'New project — no existing profile.'}\n\n"
                f"New info from: {context_label} ({date_prefix})\n{new_facts}\n\n/no_think"
            )}
        ], max_tokens=1500, log_prefix=log_prefix)
        if updated_profile:
            updated_profile = updated_profile.strip()
            if not updated_profile.startswith(f"# {project}"):
                updated_profile = re.sub(r"^#\s+.*$", f"# {project}", updated_profile, count=1, flags=re.MULTILINE)
            profile.write_text(updated_profile.rstrip("\n") + "\n")
            updated += 1
    return updated


def update_decisions(decisions, context_label, date_prefix, log_prefix="kb"):
    """Append decisions to log.md with dedup and consolidation."""
    if not decisions:
        return 0
    decisions_dir = KB_DIR / "decisions"
    decisions_dir.mkdir(parents=True, exist_ok=True)
    decisions_file = decisions_dir / "log.md"
    existing = decisions_file.read_text() if decisions_file.exists() else "# Decisions\n"
    meeting_ref = f"{context_label} ({date_prefix})"
    if meeting_ref in existing:
        return 0
    additions = f"\n\n## {context_label} ({date_prefix})\n" + "\n".join(f"- {d}" for d in decisions)
    sections = re.findall(r"^## ", existing, re.MULTILINE)
    written = False
    if len(sections) > 20:
        consolidated = lms_call([
            {"role": "system", "content": (
                "Consolidate this decision log. When a later decision supersedes an earlier one, "
                "keep only the latest version and note it replaced the old one. Remove duplicates. "
                "Keep the chronological '## Meeting (date)' structure. Halve the length. "
                "Output ONLY the updated markdown."
            )},
            {"role": "user", "content": f"/no_think\n\n{existing}{additions}\n\n/no_think"}
        ], max_tokens=4000, log_prefix=log_prefix)
        if consolidated and consolidated.startswith("#"):
            decisions_file.write_text(consolidated.rstrip("\n") + "\n")
            written = True
    if not written:
        decisions_file.write_text(existing.rstrip("\n") + additions + "\n")
    return 1
