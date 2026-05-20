"""Tests for kb.github module."""
import json
import subprocess
from unittest.mock import patch, MagicMock
import pytest


class TestFetchOrgRepos:
    def test_returns_repos_on_success(self):
        repos = [
            {"name": "myrepo", "url": "https://github.com/myorg/myrepo", "description": "A repo"},
            {"name": "other", "url": "https://github.com/myorg/other", "description": ""},
        ]
        mock_result = MagicMock(returncode=0, stdout=json.dumps(repos), stderr="")
        with patch("subprocess.run", return_value=mock_result) as mock_run:
            from kb.github import fetch_org_repos
            result = fetch_org_repos("myorg")
        assert len(result) == 2
        assert result[0]["name"] == "myrepo"
        assert result[1]["url"] == "https://github.com/myorg/other"
        mock_run.assert_called_once_with(
            ["gh", "repo", "list", "myorg", "--limit", "200", "--json", "name,url,description"],
            capture_output=True, text=True, timeout=30)

    def test_returns_empty_on_nonzero_exit(self):
        mock_result = MagicMock(returncode=1, stdout="", stderr="auth required")
        with patch("subprocess.run", return_value=mock_result):
            from kb.github import fetch_org_repos
            result = fetch_org_repos("myorg")
        assert result == []

    def test_returns_empty_on_file_not_found(self):
        with patch("subprocess.run", side_effect=FileNotFoundError):
            from kb.github import fetch_org_repos
            result = fetch_org_repos("myorg")
        assert result == []

    def test_returns_empty_on_timeout(self):
        with patch("subprocess.run", side_effect=subprocess.TimeoutExpired("gh", 30)):
            from kb.github import fetch_org_repos
            result = fetch_org_repos("myorg")
        assert result == []

    def test_returns_empty_on_invalid_json(self):
        mock_result = MagicMock(returncode=0, stdout="not json", stderr="")
        with patch("subprocess.run", return_value=mock_result):
            from kb.github import fetch_org_repos
            result = fetch_org_repos("myorg")
        assert result == []
