#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "aiocache",
#   "fastmcp>=2.12.5",
#   "httpx",
#   "markdownify",
#   "pydantic>=2.0",
# ]
# ///
#
# Granola MCP Server (Read-Only)
#
# Provides read-only access to Granola meeting notes and data via MCP.
# Reads auth tokens from local Granola app data.

from __future__ import annotations

import json
import re
import tempfile
from collections.abc import Sequence
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from typing import Literal

import httpx
import markdownify
import pydantic
from aiocache import Cache, cached
from mcp.server.fastmcp import Context, FastMCP
from mcp.types import ToolAnnotations


# =============================================================================
# Pydantic Models (simplified for read-only use)
# =============================================================================


class BaseModel(pydantic.BaseModel):
    model_config = pydantic.ConfigDict(extra="forbid", strict=True)


class PersonName(BaseModel):
    fullName: str
    givenName: str | None = None
    familyName: str | None = None


class PersonDetails(BaseModel):
    name: PersonName
    avatar: str | None = None
    jobTitle: str | None = None
    linkedin: dict | None = None
    twitter: dict | None = None
    employment: dict | None = None
    location: str | None = None


class CompanyDetails(BaseModel):
    name: str | None = None
    logo: str | None = None
    domain: str | None = None
    description: str | None = None


class PersonInfo(BaseModel):
    person: PersonDetails | None = None
    company: CompanyDetails | None = None
    group: dict | None = None


class Creator(BaseModel):
    name: str
    email: str
    details: PersonInfo


class Attendee(BaseModel):
    name: str | None = None
    email: str
    details: PersonInfo | None = None


class People(BaseModel):
    title: str | None = None
    creator: Creator
    attendees: Sequence[Attendee]
    created_at: str | None = None
    sharing_link_visibility: str | None = None
    url: str | None = None
    conferencing: dict | None = None
    manual_attendee_edits: Sequence[dict] | None = None


class ProseMirrorAttrs(BaseModel):
    model_config = pydantic.ConfigDict(extra="allow", strict=True)
    id: str | None = None
    timestamp: str | None = None


class ProseMirrorNode(BaseModel):
    model_config = pydantic.ConfigDict(extra="allow", strict=True)
    type: str
    attrs: ProseMirrorAttrs | None = None
    content: Sequence[ProseMirrorNode] | None = None


class ProseMirrorDoc(BaseModel):
    model_config = pydantic.ConfigDict(extra="allow", strict=True)
    type: Literal["doc"]
    content: Sequence[ProseMirrorNode]


class GranolaDocument(BaseModel):
    model_config = pydantic.ConfigDict(extra="allow", strict=True)
    id: str
    created_at: str
    notes: ProseMirrorDoc | None = None
    user_id: str
    notes_plain: str | None = None
    transcribe: bool
    updated_at: str
    public: bool
    meeting_end_count: int
    has_shareable_link: bool
    creation_source: str
    subscription_plan_id: str
    privacy_mode_enabled: bool
    workspace_id: str | None
    sharing_link_visibility: str
    people: People | None
    title: str | None
    google_calendar_event: dict | None = None
    deleted_at: str | None = None
    type: str | None
    overview: str | None = None
    notes_markdown: str | None = None


class DocumentsResponse(BaseModel):
    docs: Sequence[GranolaDocument]
    deleted: Sequence[str]


class BatchDocumentsResponse(BaseModel):
    docs: Sequence[GranolaDocument]


class MeetingListItem(BaseModel):
    id: str
    title: str
    created_at: str
    type: str | None
    has_notes: bool
    participant_count: int
    participants: list[dict] | None = None


class MeetingList(BaseModel):
    id: str
    title: str
    description: str | None
    visibility: str
    document_ids: Sequence[str]
    document_count: int
    created_at: str
    updated_at: str


class MeetingListsResult(BaseModel):
    lists: Sequence[MeetingList]
    total_count: int


class TranscriptSegment(BaseModel):
    document_id: str
    id: str
    start_timestamp: str
    end_timestamp: str
    text: str
    source: str
    is_final: bool


class DocumentPanel(BaseModel):
    model_config = pydantic.ConfigDict(extra="allow", strict=True)
    id: str
    created_at: str
    title: str
    document_id: str
    content: ProseMirrorDoc | str
    template_slug: str | None = None
    updated_at: str


class NoteDownloadResult(BaseModel):
    path: str
    size_bytes: int
    section_count: int
    bullet_count: int
    heading_breakdown: dict[str, int]
    word_count: int
    panel_title: str
    template_slug: str | None


class TranscriptDownloadResult(BaseModel):
    path: str
    size_bytes: int
    segment_count: int
    duration_seconds: int
    microphone_segments: int
    system_segments: int


class PrivateNoteDownloadResult(BaseModel):
    path: str
    size_bytes: int
    word_count: int
    line_count: int


class ResolveUrlResult(BaseModel):
    document_id: str
    url_type: str
    original_url: str
    resolved_from_redirect: bool = False


# =============================================================================
# Helper Functions
# =============================================================================


def get_auth_token() -> str:
    """Read WorkOS access token from Granola's local storage."""
    granola_dir = Path.home() / "Library" / "Application Support" / "Granola"
    supabase_file = granola_dir / "supabase.json"

    if not supabase_file.exists():
        raise FileNotFoundError(
            f"Granola auth file not found at {supabase_file}. "
            "Is Granola installed and authenticated?"
        )

    with open(supabase_file) as f:
        data = json.load(f)

    if "workos_tokens" not in data:
        raise ValueError("No workos_tokens found in Granola auth file")

    tokens = json.loads(data["workos_tokens"])

    if "access_token" not in tokens:
        raise ValueError("No access_token in workos_tokens")

    return tokens["access_token"]


def get_auth_headers() -> dict[str, str]:
    """Get HTTP headers with authentication."""
    token = get_auth_token()
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


def convert_utc_to_local(utc_timestamp: str | None) -> str | None:
    """Convert UTC ISO timestamp to system local timezone."""
    if utc_timestamp is None:
        return None
    utc_dt = datetime.fromisoformat(utc_timestamp.replace("Z", "+00:00"))
    local_dt = utc_dt.astimezone()
    return local_dt.isoformat()


def analyze_markdown_metadata(markdown: str) -> dict:
    """Extract structural and content metrics from markdown."""
    lines = markdown.split("\n")
    heading_breakdown = {"h1": 0, "h2": 0, "h3": 0}
    section_count = 0

    for line in lines:
        if line.startswith("### "):
            heading_breakdown["h3"] += 1
            section_count += 1
        elif line.startswith("## "):
            heading_breakdown["h2"] += 1
        elif line.startswith("# "):
            heading_breakdown["h1"] += 1

    bullet_count = sum(1 for line in lines if re.match(r"^\s*[-*]\s", line))
    words = markdown.split()
    word_count = len([w for w in words if w.strip()])

    return {
        "section_count": section_count,
        "bullet_count": bullet_count,
        "heading_breakdown": heading_breakdown,
        "word_count": word_count,
    }


def extract_text(node: dict) -> str:
    """Recursively extract all text from a ProseMirror node."""
    if isinstance(node, str):
        return node
    if not isinstance(node, dict):
        return ""

    if node.get("type") == "text":
        text = node.get("text", "")
        marks = node.get("marks", [])
        for mark in marks:
            mark_type = mark.get("type")
            if mark_type == "bold":
                text = f"**{text}**"
            elif mark_type == "italic":
                text = f"*{text}*"
            elif mark_type == "code":
                text = f"`{text}`"
            elif mark_type == "link":
                href = mark.get("attrs", {}).get("href", "")
                if href:
                    text = f"[{text}]({href})"
        return text

    content = node.get("content", [])
    texts = [extract_text(child) for child in content]
    node_type = node.get("type", "")
    if node_type in ["paragraph", "listItem"]:
        result = " ".join(text for text in texts if text)
        result = re.sub(r" +", " ", result)
        return result
    else:
        return "".join(texts)


def prosemirror_to_markdown(content: dict, depth: int = 0) -> str:
    """Convert ProseMirror JSON to Markdown."""
    if not isinstance(content, dict):
        return ""

    node_type = content.get("type", "")

    if node_type == "doc":
        children = content.get("content", [])
        return "\n\n".join(prosemirror_to_markdown(child, depth) for child in children)

    if node_type == "heading":
        level = content.get("attrs", {}).get("level", 1)
        text = extract_text(content)
        return f"{'#' * level} {text}"

    if node_type == "paragraph":
        text = extract_text(content)
        return text if text else ""

    if node_type == "horizontalRule":
        return "---"

    if node_type == "bulletList":
        items = content.get("content", [])
        lines = []
        indent = "  " * depth
        for item in items:
            if item.get("type") == "listItem":
                item_content = item.get("content", [])
                first_line_parts = []
                nested_content = []
                for node in item_content:
                    if node.get("type") == "paragraph":
                        text = extract_text(node)
                        if text:
                            first_line_parts.append(text)
                    elif node.get("type") in ["bulletList", "orderedList"]:
                        nested_md = prosemirror_to_markdown(node, depth + 1)
                        if nested_md:
                            nested_content.append(nested_md)
                first_line_text = " ".join(first_line_parts)
                lines.append(f"{indent}- {first_line_text}")
                lines.extend(nested_content)
        return "\n".join(lines)

    if node_type == "codeBlock":
        text = extract_text(content)
        return f"```\n{text}\n```"

    return extract_text(content)


# =============================================================================
# MCP Server
# =============================================================================

_temp_dir: tempfile.TemporaryDirectory | None = None
_export_dir: Path | None = None
_http_client: httpx.AsyncClient | None = None


@asynccontextmanager
async def lifespan(server):
    """Manage resources - cleanup on shutdown."""
    global _temp_dir, _export_dir, _http_client
    _temp_dir = tempfile.TemporaryDirectory()
    _export_dir = Path(_temp_dir.name)
    _http_client = httpx.AsyncClient(timeout=30.0)
    try:
        yield {}
    finally:
        if _http_client:
            await _http_client.aclose()
        if _temp_dir:
            _temp_dir.cleanup()


mcp = FastMCP("granola", lifespan=lifespan)

_DOCUMENT_ID_PATTERN = re.compile(r"/d/([a-f0-9-]+)")


def _extract_document_id(url: str) -> str | None:
    """Extract document ID from a URL containing /d/{id} path."""
    match = _DOCUMENT_ID_PATTERN.search(url)
    return match.group(1) if match else None


@cached(ttl=None, cache=Cache.MEMORY)
async def _get_documents_cached(
    limit: int, offset: int, list_id: str | None = None
) -> list:
    """Fetch documents from API with caching."""
    headers = get_auth_headers()
    url = "https://api.granola.ai/v2/get-documents"
    payload = {"limit": limit, "offset": offset, "include_last_viewed_panel": False}
    if list_id:
        payload["list_id"] = list_id
    response = await _http_client.post(url, json=payload, headers=headers)
    response.raise_for_status()
    data = DocumentsResponse.model_validate(response.json())
    return data.docs


@cached(ttl=86400, cache=Cache.MEMORY)
async def _resolve_sharing_token(token: str) -> str:
    """Resolve a sharing token to document ID via HTTP redirect."""
    url = f"https://notes.granola.ai/t/{token}"
    response = await _http_client.get(url, follow_redirects=False, timeout=10.0)
    if 300 <= response.status_code < 400:
        location = response.headers.get("location", "")
        document_id = _extract_document_id(location)
        if document_id:
            return document_id
        raise ValueError(f"Unexpected redirect location: {location}")
    if response.status_code == 404:
        raise ValueError(f"Sharing token not found: {token}")
    raise ValueError(f"Unexpected response status: {response.status_code}")


# =============================================================================
# MCP Tools (Read-Only)
# =============================================================================


@mcp.tool(annotations=ToolAnnotations(title="List Meetings", readOnlyHint=True))
async def list_meetings(
    title_contains: str | None = None,
    case_sensitive: bool = False,
    list_id: str | None = None,
    created_at_gte: str | None = None,
    created_at_lte: str | None = None,
    limit: int = 20,
    include_participants: bool = False,
) -> list[MeetingListItem]:
    """List meetings. Filter by title, list_id, or date range (ISO 8601). Limit 0 = all."""

    async def document_generator():
        offset = 0
        batch_size = 40
        while True:
            batch = await _get_documents_cached(
                limit=batch_size, offset=offset, list_id=list_id
            )
            if not batch:
                break
            for doc in batch:
                yield doc
            offset += batch_size

    results = []
    async for doc in document_generator():
        if title_contains:
            title = doc.title or ""
            if case_sensitive:
                if title_contains not in title:
                    continue
            else:
                if title_contains.lower() not in title.lower():
                    continue

        if created_at_gte or created_at_lte:
            created = datetime.fromisoformat(doc.created_at.replace("Z", "+00:00"))
            if created_at_gte:
                filter_start = datetime.fromisoformat(
                    created_at_gte + "T00:00:00+00:00"
                )
                if created < filter_start:
                    continue
            if created_at_lte:
                filter_end = datetime.fromisoformat(created_at_lte + "T23:59:59+00:00")
                if created > filter_end:
                    continue

        participant_count = len(doc.people.attendees) if doc.people else 0
        participants = None
        if include_participants and doc.people:
            participants = []
            for attendee in doc.people.attendees:
                company_name = None
                job_title = None
                name = attendee.name
                if attendee.details:
                    if attendee.details.company:
                        company_name = attendee.details.company.name
                    if attendee.details.person:
                        job_title = attendee.details.person.jobTitle
                        if not name and attendee.details.person.name:
                            name = attendee.details.person.name.fullName
                participants.append(
                    {
                        "name": name,
                        "email": attendee.email,
                        "company_name": company_name,
                        "job_title": job_title,
                    }
                )

        results.append(
            MeetingListItem(
                id=doc.id,
                title=doc.title or "(Untitled)",
                created_at=convert_utc_to_local(doc.created_at),
                type=doc.type,
                has_notes=bool(doc.notes or doc.notes_markdown),
                participant_count=participant_count,
                participants=participants,
            )
        )

        if limit > 0 and len(results) >= limit:
            break

    return results


@mcp.tool(
    annotations=ToolAnnotations(title="Download Meeting Notes", readOnlyHint=True)
)
async def download_note(document_id: str, filename: str) -> NoteDownloadResult:
    """Download AI-generated meeting notes to temp Markdown file."""
    headers = get_auth_headers()

    doc_url = "https://api.granola.ai/v2/get-documents"
    doc_response = await _http_client.post(
        doc_url, json={"id": document_id}, headers=headers
    )
    doc_response.raise_for_status()
    doc_data = DocumentsResponse.model_validate(doc_response.json())
    if not doc_data.docs:
        raise ValueError(f"Document {document_id} not found")
    document = doc_data.docs[0]

    panels_url = "https://api.granola.ai/v1/get-document-panels"
    panels_response = await _http_client.post(
        panels_url, json={"document_id": document_id}, headers=headers
    )
    panels_response.raise_for_status()
    panels_data = panels_response.json()
    if not panels_data:
        raise ValueError(f"No panels found for document {document_id}")

    panels = [DocumentPanel.model_validate(p) for p in panels_data]
    summary_panel = None
    for panel in panels:
        if panel.template_slug == "v2:meeting-summary-consolidated":
            summary_panel = panel
            break
    if not summary_panel:
        summary_panel = panels[0]

    if isinstance(summary_panel.content, str):
        notes_markdown = markdownify.markdownify(
            summary_panel.content, heading_style="ATX", bullets="-", default_title=True
        ).strip()
    else:
        notes_markdown = prosemirror_to_markdown(summary_panel.content)

    created = datetime.fromisoformat(document.created_at.replace("Z", "+00:00"))
    created_local = created.astimezone()
    date_str = created_local.strftime("%a, %d %b %y")
    title = document.title or "(Untitled)"
    markdown = f"# {title}\n\n{date_str}\n\n{notes_markdown}"
    metadata = analyze_markdown_metadata(markdown)

    file_path = _export_dir / filename
    file_path.write_text(markdown, encoding="utf-8")

    return NoteDownloadResult(
        path=str(file_path),
        size_bytes=len(markdown.encode("utf-8")),
        section_count=metadata["section_count"],
        bullet_count=metadata["bullet_count"],
        heading_breakdown=metadata["heading_breakdown"],
        word_count=metadata["word_count"],
        panel_title=summary_panel.title,
        template_slug=summary_panel.template_slug,
    )


@mcp.tool(
    annotations=ToolAnnotations(title="Download Meeting Transcript", readOnlyHint=True)
)
async def download_transcript(
    document_id: str, filename: str
) -> TranscriptDownloadResult:
    """Download meeting transcript to temp Markdown file."""
    headers = get_auth_headers()

    doc_url = "https://api.granola.ai/v2/get-documents"
    doc_response = await _http_client.post(
        doc_url, json={"id": document_id}, headers=headers
    )
    doc_response.raise_for_status()
    doc_data = DocumentsResponse.model_validate(doc_response.json())
    if not doc_data.docs:
        raise ValueError(f"Document {document_id} not found")
    document = doc_data.docs[0]

    url = "https://api.granola.ai/v1/get-document-transcript"
    response = await _http_client.post(
        url, json={"document_id": document_id}, headers=headers
    )
    response.raise_for_status()
    segments = [TranscriptSegment.model_validate(seg) for seg in response.json()]
    if not segments:
        raise ValueError(f"No transcript available for document {document_id}")

    total_segments = len(segments)
    microphone_count = sum(1 for s in segments if s.source == "microphone")
    system_count = sum(1 for s in segments if s.source == "system")

    start = datetime.fromisoformat(segments[0].start_timestamp.replace("Z", "+00:00"))
    end = datetime.fromisoformat(segments[-1].end_timestamp.replace("Z", "+00:00"))
    duration = end - start

    created = datetime.fromisoformat(document.created_at.replace("Z", "+00:00"))
    created_local = created.astimezone()
    date_str = created_local.strftime("%b %-d")

    title = document.title or "(Untitled)"
    lines = [f"Meeting Title: {title}", f"Date: {date_str}", "", "Transcript:", " "]

    combined_segments = []
    current_label = None
    current_texts = []

    for segment in segments:
        label = "Me" if segment.source == "microphone" else "Them"
        if label == current_label:
            current_texts.append(segment.text)
        else:
            if current_label is not None:
                combined_text = " ".join(current_texts)
                combined_segments.append(f"{current_label}: {combined_text}")
            current_label = label
            current_texts = [segment.text]

    if current_label is not None:
        combined_text = " ".join(current_texts)
        combined_segments.append(f"{current_label}: {combined_text}")

    lines.extend(combined_segments)
    transcript_md = "\n".join(lines)

    file_path = _export_dir / filename
    file_path.write_text(transcript_md, encoding="utf-8")

    return TranscriptDownloadResult(
        path=str(file_path),
        size_bytes=len(transcript_md.encode("utf-8")),
        segment_count=total_segments,
        duration_seconds=int(duration.total_seconds()),
        microphone_segments=microphone_count,
        system_segments=system_count,
    )


@mcp.tool(
    annotations=ToolAnnotations(title="Download Private Notes", readOnlyHint=True)
)
async def download_private_notes(
    document_id: str, filename: str
) -> PrivateNoteDownloadResult:
    """Download user's private notes (not AI-generated) to temp Markdown file."""
    headers = get_auth_headers()

    doc_url = "https://api.granola.ai/v2/get-documents"
    doc_response = await _http_client.post(
        doc_url, json={"id": document_id}, headers=headers
    )
    doc_response.raise_for_status()
    doc_data = DocumentsResponse.model_validate(doc_response.json())
    if not doc_data.docs:
        raise ValueError(f"Document {document_id} not found")
    document = doc_data.docs[0]

    if not document.notes_markdown:
        raise ValueError(f"No private notes available for document {document_id}")

    created = datetime.fromisoformat(document.created_at.replace("Z", "+00:00"))
    created_local = created.astimezone()
    date_str = created_local.strftime("%a, %d %b %y")

    title = document.title or "(Untitled)"
    markdown = f"# {title}\n\n{date_str}\n\n{document.notes_markdown}"

    lines = markdown.split("\n")
    line_count = len(lines)
    words = markdown.split()
    word_count = len([w for w in words if w.strip()])

    file_path = _export_dir / filename
    file_path.write_text(markdown, encoding="utf-8")

    return PrivateNoteDownloadResult(
        path=str(file_path),
        size_bytes=len(markdown.encode("utf-8")),
        word_count=word_count,
        line_count=line_count,
    )


@mcp.tool(annotations=ToolAnnotations(title="Get Meeting Lists", readOnlyHint=True))
async def get_meeting_lists() -> MeetingListsResult:
    """Get all meeting lists/collections with their document IDs."""
    headers = get_auth_headers()
    url = "https://api.granola.ai/v1/get-document-lists-metadata"
    payload = {"include_document_ids": True, "include_only_joined_lists": False}

    response = await _http_client.post(url, json=payload, headers=headers)
    response.raise_for_status()

    data = response.json()
    lists_data = data.get("lists", {})

    meeting_lists = []
    for list_id, list_info in lists_data.items():
        doc_ids = list_info.get("document_ids", [])
        meeting_list = MeetingList(
            id=list_id,
            title=list_info.get("title", ""),
            description=list_info.get("description"),
            visibility=list_info.get("visibility", ""),
            document_ids=doc_ids,
            document_count=len(doc_ids),
            created_at=convert_utc_to_local(list_info.get("created_at", "")),
            updated_at=convert_utc_to_local(list_info.get("updated_at", "")),
        )
        meeting_lists.append(meeting_list)

    return MeetingListsResult(lists=meeting_lists, total_count=len(meeting_lists))


@mcp.tool(annotations=ToolAnnotations(title="Get Meetings", readOnlyHint=True))
async def get_meetings(document_ids: list[str]) -> list[MeetingListItem]:
    """Fetch multiple meetings by document IDs (batch retrieval)."""
    headers = get_auth_headers()
    url = "https://api.granola.ai/v1/get-documents-batch"
    payload = {"document_ids": document_ids}

    response = await _http_client.post(url, json=payload, headers=headers)
    response.raise_for_status()

    data = BatchDocumentsResponse.model_validate(response.json())

    meetings = []
    for doc in data.docs:
        participant_count = 0
        participants = []
        if doc.people:
            participant_count = len(doc.people.attendees)
            for attendee in doc.people.attendees:
                company_name = None
                job_title = None
                name = attendee.name
                if attendee.details:
                    if attendee.details.company:
                        company_name = attendee.details.company.name
                    if attendee.details.person:
                        job_title = attendee.details.person.jobTitle
                        if not name and attendee.details.person.name:
                            name = attendee.details.person.name.fullName
                participants.append(
                    {
                        "name": name,
                        "email": attendee.email,
                        "company_name": company_name,
                        "job_title": job_title,
                    }
                )

        meetings.append(
            MeetingListItem(
                id=doc.id,
                title=doc.title or "(Untitled)",
                created_at=convert_utc_to_local(doc.created_at),
                type=doc.type,
                has_notes=bool(doc.notes or doc.notes_markdown),
                participant_count=participant_count,
                participants=participants,
            )
        )

    return meetings


@mcp.tool(annotations=ToolAnnotations(title="Resolve Granola URL", readOnlyHint=True))
async def resolve_url(url: str) -> ResolveUrlResult:
    """Resolve a Granola /t/ or /d/ URL to its document ID."""
    if "notes.granola.ai" not in url:
        raise ValueError(
            "Invalid Granola URL. Expected format: https://notes.granola.ai/t/... or /d/..."
        )

    document_id = _extract_document_id(url)
    if document_id:
        return ResolveUrlResult(
            document_id=document_id,
            url_type="direct",
            original_url=url,
            resolved_from_redirect=False,
        )

    t_match = re.search(r"/t/([a-f0-9-]+)", url)
    if t_match:
        token = t_match.group(1)
        document_id = await _resolve_sharing_token(token)
        return ResolveUrlResult(
            document_id=document_id,
            url_type="sharing",
            original_url=url,
            resolved_from_redirect=True,
        )

    raise ValueError(
        f"Could not parse Granola URL. Expected /t/ or /d/ path in URL: {url}"
    )


# =============================================================================
# Main Entry Point
# =============================================================================


def main() -> None:
    """Main entry point for the Granola MCP server."""
    print("Starting Granola MCP server (read-only)")
    mcp.run()


if __name__ == "__main__":
    main()
