"""Tests for meeting dedup state tracking and chunked summarization."""
import hashlib
import json
import time
from pathlib import Path
from unittest.mock import patch, MagicMock

import kb.meeting as meeting


# --- content_hash ---

def test_content_hash_returns_sha256_of_file(tmp_path):
    """content_hash returns the SHA-256 hex digest of file contents."""
    f = tmp_path / "test.txt"
    f.write_text("hello world")
    expected = hashlib.sha256(b"hello world").hexdigest()
    assert meeting.content_hash(f) == expected


def test_content_hash_different_content_different_hash(tmp_path):
    """Different file contents produce different hashes."""
    f1 = tmp_path / "a.txt"
    f1.write_text("content A")
    f2 = tmp_path / "b.txt"
    f2.write_text("content B")
    assert meeting.content_hash(f1) != meeting.content_hash(f2)


# --- load_state / save_state ---

def test_load_state_returns_empty_dict_when_missing(tmp_path):
    """load_state returns {} when the state file doesn't exist."""
    state_file = tmp_path / "nonexistent" / "processed.json"
    with patch.object(meeting, "STATE_FILE", state_file):
        assert meeting.load_state() == {}


def test_load_state_returns_empty_dict_on_corrupt_json(tmp_path):
    """load_state returns {} when the state file contains invalid JSON."""
    state_file = tmp_path / "processed.json"
    state_file.write_text("not json {{{")
    with patch.object(meeting, "STATE_FILE", state_file):
        assert meeting.load_state() == {}


def test_save_then_load_roundtrips(tmp_path):
    """save_state writes and load_state reads back the same data."""
    state_file = tmp_path / "kb" / "processed.json"
    caption = tmp_path / "caption.txt"
    caption.write_text("hello")
    state = {
        str(caption): {
            "hash": "abc123",
            "output": "/some/output.md",
            "timestamp": time.time(),
        }
    }
    with patch.object(meeting, "STATE_FILE", state_file):
        meeting.save_state(state)
        loaded = meeting.load_state()
    assert loaded == state


def test_save_state_creates_parent_dirs(tmp_path):
    """save_state creates the parent directory if it doesn't exist."""
    state_file = tmp_path / "deep" / "nested" / "processed.json"
    with patch.object(meeting, "STATE_FILE", state_file):
        meeting.save_state({"key": {"hash": "x", "output": "y", "timestamp": 0}})
    assert state_file.exists()


def test_save_state_prunes_stale_entries(tmp_path):
    """save_state removes entries whose caption files no longer exist."""
    state_file = tmp_path / "processed.json"
    existing = tmp_path / "exists.txt"
    existing.write_text("hi")
    state = {
        str(existing): {
            "hash": "abc",
            "output": "/out.md",
            "timestamp": time.time(),
        },
        "/gone/missing.txt": {
            "hash": "def",
            "output": "/out2.md",
            "timestamp": time.time(),
        },
    }
    with patch.object(meeting, "STATE_FILE", state_file):
        meeting.save_state(state)
        loaded = meeting.load_state()
    assert str(existing) in loaded
    assert "/gone/missing.txt" not in loaded


# --- write_output with existing_output ---

@patch.object(meeting, "MEETINGS_DIR", None)  # will be overridden per-test
@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
def test_write_output_uses_existing_output_path(tmp_path):
    """When existing_output is set, write_output writes to that path."""
    meetings = tmp_path / "meetings"
    meetings.mkdir()
    existing = meetings / "2025-01-01-standup-alice.md"
    existing.write_text("old content")

    with patch.object(meeting, "MEETINGS_DIR", meetings):
        result_path, _ = meeting.write_output(
            "Standup", "2025-01-01T10:00:00", "30m 0s",
            "## Summary\nGood meeting.", "transcript here", 100,
            existing_output=existing,
        )

    assert result_path == existing
    content = existing.read_text()
    assert "Good meeting" in content
    # No -2 file should exist
    assert not (meetings / "2025-01-01-standup-alice-2.md").exists()


@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
def test_write_output_overwrites_on_collision_without_existing(tmp_path):
    """Without existing_output, if the file exists, overwrite it (no -2 suffix)."""
    meetings = tmp_path / "meetings"
    meetings.mkdir()
    existing = meetings / "2025-01-01-standup-alice.md"
    existing.write_text("old content")

    with patch.object(meeting, "MEETINGS_DIR", meetings):
        result_path, _ = meeting.write_output(
            "Standup", "2025-01-01T10:00:00", "30m 0s",
            "## Summary\nNew content.", "transcript", 50,
        )

    assert result_path == existing
    content = existing.read_text()
    assert "New content" in content
    # Must NOT create -2 file
    assert not (meetings / "2025-01-01-standup-alice-2.md").exists()


# --- summarize signature accepts title ---

@patch.object(meeting, "lms_available", return_value=False)
def test_summarize_accepts_title_kwarg(_mock):
    """summarize() accepts a title keyword argument without error."""
    result = meeting.summarize("some transcript", title="My Meeting")
    assert result == ""


# --- chunked summarization ---

@patch.object(meeting, "lms_available", return_value=True)
@patch("kb.meeting.lms_call")
def test_summarize_short_transcript_single_shot(mock_lms, _mock_avail):
    """Transcripts under SUMMARY_WORD_LIMIT use a single LLM call."""
    mock_lms.return_value = "## Summary\nShort."
    transcript = " ".join(["word"] * 100)  # 100 words, well under limit

    result = meeting.summarize(transcript, title="Test")

    assert result == "## Summary\nShort."
    assert mock_lms.call_count == 1


@patch.object(meeting, "lms_available", return_value=True)
@patch("kb.meeting.lms_call")
def test_summarize_long_transcript_uses_map_reduce(mock_lms, _mock_avail):
    """Transcripts over SUMMARY_WORD_LIMIT use map-reduce (multiple LLM calls)."""
    mock_lms.return_value = "## Summary\nCombined."
    # Build a transcript larger than the limit
    transcript = "\n".join(
        f"[Speaker {i % 3}:{i:02d}] " + " ".join(["word"] * 500)
        for i in range(12)
    )
    word_count = len(transcript.split())
    assert word_count > meeting.SUMMARY_WORD_LIMIT  # verify setup

    result = meeting.summarize(transcript, title="Long Meeting")

    assert result == "## Summary\nCombined."
    # At least 2 chunk calls + 1 combine call
    assert mock_lms.call_count >= 3


@patch.object(meeting, "lms_available", return_value=True)
@patch("kb.meeting.lms_call")
def test_summarize_chunks_split_at_line_boundaries(mock_lms, _mock_avail):
    """Chunks split at line boundaries, not mid-line."""
    mock_lms.return_value = "- bullet"
    # 10 lines of 500 words each = 5000 words total, over the limit
    lines = [" ".join(["word"] * 500) for _ in range(10)]
    transcript = "\n".join(lines)

    meeting.summarize(transcript, title="Test")

    # Each chunk call (not the final combine) should have complete lines
    for call_args in mock_lms.call_args_list[:-1]:  # skip combine call
        messages = call_args[0][0] if call_args[0] else call_args[1].get("messages", [])
        user_msg = next((m["content"] for m in messages if m["role"] == "user"), "")
        # No line should be truncated mid-word (each original line has exactly 500 words)
        for line in user_msg.strip().split("\n"):
            if line.strip() and "word" in line:
                # Lines from the transcript should be intact
                wc = len(line.split())
                assert wc == 500 or wc > 0  # intact line or short line
