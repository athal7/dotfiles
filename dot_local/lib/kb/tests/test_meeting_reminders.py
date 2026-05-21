"""Tests for add_reminders action-item extraction and remindctl invocation."""
from unittest.mock import patch, MagicMock, call
import subprocess

import kb.meeting as meeting


SUMMARY_WITH_ACTION = """\
## Summary
We discussed the roadmap.

## Action Items
- Alice will update the design doc
- Bob will review the PR
"""

SUMMARY_TWO_ALICE_ITEMS = """\
## Summary
Sprint planning.

## Action Items
- Alice will update the design doc
- Alice will file the bug report
- Bob will review the PR
"""


@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
@patch.object(meeting, "get_reminders_list", return_value="Meetings")
@patch("subprocess.run")
def test_add_reminders_uses_notes_flag(mock_run, _mock_list):
    """Regression: remindctl flag is --notes (not --note)."""
    # First call is the remindctl --help check; second is the actual add
    mock_run.return_value = MagicMock(returncode=0)

    meeting.add_reminders(SUMMARY_WITH_ACTION, "Daily standup")

    # Find the 'add' invocation (skip the --help probe)
    add_calls = [
        c for c in mock_run.call_args_list
        if "add" in c[0][0]
    ]
    assert len(add_calls) == 1
    cmd = add_calls[0][0][0]
    assert "--notes" in cmd, f"Expected --notes in command, got: {cmd}"
    assert "--note" not in cmd or "--notes" in cmd  # --notes contains --note as substring; check exact token
    # Verify the exact flag token
    flag_index = cmd.index("--notes")
    assert cmd[flag_index] == "--notes"


# --- Return value tests ---

@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
@patch.object(meeting, "get_reminders_list", return_value="Meetings")
@patch("subprocess.run")
def test_returns_true_when_all_succeed(mock_run, _mock_list):
    """add_reminders returns True when all remindctl add calls succeed."""
    mock_run.return_value = MagicMock(returncode=0)
    result = meeting.add_reminders(SUMMARY_WITH_ACTION, "Standup")
    assert result is True


@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
@patch.object(meeting, "get_reminders_list", return_value="Meetings")
@patch("subprocess.run")
def test_returns_false_when_remindctl_fails(mock_run, _mock_list):
    """add_reminders returns False when a remindctl add call fails."""
    def side_effect(cmd, **kwargs):
        if "--help" in cmd:
            return MagicMock(returncode=0)
        return MagicMock(returncode=1, stderr="list not found")
    mock_run.side_effect = side_effect

    result = meeting.add_reminders(SUMMARY_WITH_ACTION, "Standup")
    assert result is False


@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
@patch.object(meeting, "get_reminders_list", return_value="Meetings")
@patch("subprocess.run")
def test_returns_false_when_remindctl_times_out(mock_run, _mock_list):
    """add_reminders returns False when remindctl add raises TimeoutExpired."""
    def side_effect(cmd, **kwargs):
        if "--help" in cmd:
            return MagicMock(returncode=0)
        raise subprocess.TimeoutExpired(cmd, 10)
    mock_run.side_effect = side_effect

    result = meeting.add_reminders(SUMMARY_WITH_ACTION, "Standup")
    assert result is False


@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
@patch.object(meeting, "get_reminders_list", return_value="Meetings")
@patch("subprocess.run")
@patch.object(meeting, "log")
def test_logs_warning_on_remindctl_failure(mock_log, mock_run, _mock_list):
    """add_reminders logs a warning including stderr when remindctl add fails."""
    def side_effect(cmd, **kwargs):
        if "--help" in cmd:
            return MagicMock(returncode=0)
        return MagicMock(returncode=1, stderr="permission denied\n")
    mock_run.side_effect = side_effect

    meeting.add_reminders(SUMMARY_WITH_ACTION, "Standup")

    log_messages = [c[0][0] for c in mock_log.call_args_list]
    # Should have a per-item warning with stderr
    assert any("remindctl add failed" in m and "permission denied" in m for m in log_messages), \
        f"Expected per-item failure log, got: {log_messages}"
    # Should have a summary warning
    assert any("1/1 reminder(s) failed" in m for m in log_messages), \
        f"Expected summary failure log, got: {log_messages}"


@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
@patch.object(meeting, "get_reminders_list", return_value="Meetings")
@patch("subprocess.run")
@patch.object(meeting, "log")
def test_logs_warning_on_exception(mock_log, mock_run, _mock_list):
    """add_reminders logs a warning when remindctl add raises an exception."""
    def side_effect(cmd, **kwargs):
        if "--help" in cmd:
            return MagicMock(returncode=0)
        raise subprocess.TimeoutExpired(cmd, 10)
    mock_run.side_effect = side_effect

    meeting.add_reminders(SUMMARY_WITH_ACTION, "Standup")

    log_messages = [c[0][0] for c in mock_log.call_args_list]
    assert any("remindctl add error" in m for m in log_messages), \
        f"Expected exception log, got: {log_messages}"


@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
@patch.object(meeting, "get_reminders_list", return_value="Meetings")
@patch("subprocess.run")
def test_returns_false_when_partial_failure(mock_run, _mock_list):
    """Returns False when some items succeed and some fail."""
    call_count = [0]
    def side_effect(cmd, **kwargs):
        if "--help" in cmd:
            return MagicMock(returncode=0)
        call_count[0] += 1
        if call_count[0] == 1:
            return MagicMock(returncode=0)  # first add succeeds
        return MagicMock(returncode=1, stderr="error")  # second fails
    mock_run.side_effect = side_effect

    result = meeting.add_reminders(SUMMARY_TWO_ALICE_ITEMS, "Sprint planning")
    assert result is False


# --- Early-return path tests ---

@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
def test_returns_true_when_no_summary():
    """No summary means nothing to do — return True (not a failure)."""
    result = meeting.add_reminders("", "Standup")
    assert result is True


@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
@patch("subprocess.run", side_effect=FileNotFoundError("remindctl"))
@patch.object(meeting, "log")
def test_returns_false_when_no_remindctl(mock_log, mock_run):
    """remindctl not installed — return False and log warning."""
    result = meeting.add_reminders(SUMMARY_WITH_ACTION, "Standup")
    assert result is False
    log_messages = [c[0][0] for c in mock_log.call_args_list]
    assert any("remindctl not available" in m for m in log_messages), \
        f"Expected remindctl-not-available warning, got: {log_messages}"


@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
@patch.object(meeting, "get_reminders_list", return_value=None)
@patch("subprocess.run", return_value=MagicMock(returncode=0))
@patch.object(meeting, "log")
def test_returns_false_when_no_list_configured(mock_log, mock_run, _mock_list):
    """No reminders list configured — return False and log warning."""
    result = meeting.add_reminders(SUMMARY_WITH_ACTION, "Standup")
    assert result is False
    log_messages = [c[0][0] for c in mock_log.call_args_list]
    assert any("No reminders list" in m for m in log_messages), \
        f"Expected no-list warning, got: {log_messages}"


@patch.object(meeting, "IDENTITY_NAME", "Alice Smith")
@patch.object(meeting, "get_reminders_list", return_value="Meetings")
@patch("subprocess.run", return_value=MagicMock(returncode=0))
def test_returns_true_when_no_items_for_me(mock_run, _mock_list):
    """Summary has action items but none for me — return True."""
    summary = """\
## Summary
Planning.

## Action Items
- Bob will review the PR
"""
    result = meeting.add_reminders(summary, "Standup")
    assert result is True
