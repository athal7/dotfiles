"""KB profile merge logic — people, projects, decisions."""
import os, re
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
                "\n## Current\n- What they're working on, their responsibilities\n"
                "\n## Style\n- How they communicate (direct/detailed, technical/non-technical, preferences observed)\n"
                "\n## Personal\n- Interests, family mentions, hobbies, location, anything personal shared in conversation\n"
                "\n## Key Decisions\n- Important decisions they've made or been part of (with date)\n"
                "\nRules: Merge new facts into the existing profile. Update fields that changed. "
                "Drop outdated info that's been superseded. Keep it concise — this is a reference card, not a transcript. "
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


def update_projects(project_facts, context_label, date_prefix, log_prefix="kb"):
    """Merge project facts into KB profiles."""
    projects_dir = KB_DIR / "projects"
    projects_dir.mkdir(parents=True, exist_ok=True)
    updated = 0
    for project, updates in project_facts.items():
        slug = slugify(project)
        if not slug:
            continue
        profile = projects_dir / f"{slug}.md"
        existing = profile.read_text() if profile.exists() else ""
        new_facts = "\n".join(f"- {u}" for u in updates)
        updated_profile = lms_call([
            {"role": "system", "content": (
                "Update a project's knowledge base profile. The profile should reflect current state, NOT be a meeting log. "
                "Format:\n# Project Name\n\n## Status\n- Current state, what's active, what's blocked\n"
                "\n## Key Decisions\n- Important decisions (with date)\n"
                "\n## People\n- Key people involved and their roles\n"
                "\nRules: Merge new info. Update status if changed. Drop superseded decisions. Keep concise. "
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
