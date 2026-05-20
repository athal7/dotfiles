"""Tests for kb.linear module."""
import json
from unittest.mock import patch, MagicMock
import pytest


class TestGetLinearToken:
    def test_returns_token_from_keychain(self):
        mock_result = MagicMock(stdout="lin_api_abc123\n")
        with patch("subprocess.run", return_value=mock_result) as mock_run:
            from kb.linear import get_linear_token
            token = get_linear_token()
        assert token == "lin_api_abc123"
        mock_run.assert_called_once_with(
            ["security", "find-generic-password", "-s", "chezmoi", "-a", "linear_api_key", "-w"],
            capture_output=True, text=True, timeout=5)

    def test_returns_empty_on_file_not_found(self):
        with patch("subprocess.run", side_effect=FileNotFoundError):
            from kb.linear import get_linear_token
            assert get_linear_token() == ""

    def test_returns_empty_on_timeout(self):
        import subprocess
        with patch("subprocess.run", side_effect=subprocess.TimeoutExpired("cmd", 5)):
            from kb.linear import get_linear_token
            assert get_linear_token() == ""


class TestLinearGraphql:
    def test_returns_data_on_success(self):
        response_body = json.dumps({"data": {"projects": []}}).encode()
        mock_resp = MagicMock()
        mock_resp.read.return_value = response_body

        with patch("urllib.request.urlopen", return_value=mock_resp) as mock_open:
            from kb.linear import linear_graphql
            result = linear_graphql("{ projects { nodes { name } } }", "lin_api_test")

        assert result == {"projects": []}
        # Verify auth header does NOT use "Bearer" prefix
        call_args = mock_open.call_args
        req = call_args[0][0]
        assert req.get_header("Authorization") == "lin_api_test"
        assert req.get_header("Content-type") == "application/json"

    def test_returns_none_on_graphql_error(self):
        response_body = json.dumps({"errors": [{"message": "bad query"}]}).encode()
        mock_resp = MagicMock()
        mock_resp.read.return_value = response_body

        with patch("urllib.request.urlopen", return_value=mock_resp):
            from kb.linear import linear_graphql
            result = linear_graphql("{ bad }", "token")
        assert result is None

    def test_returns_none_on_network_error(self):
        with patch("urllib.request.urlopen", side_effect=Exception("timeout")):
            from kb.linear import linear_graphql
            result = linear_graphql("{ q }", "token")
        assert result is None


class TestFetchAllProjects:
    def test_single_page(self):
        page = {
            "projects": {
                "pageInfo": {"hasNextPage": False, "endCursor": None},
                "nodes": [
                    {"name": "Alpha", "url": "https://linear.app/myorg/project/alpha", "state": "started"},
                    {"name": "Beta", "url": "https://linear.app/myorg/project/beta", "state": "planned"},
                ],
            }
        }
        with patch("kb.linear.linear_graphql", return_value=page):
            from kb.linear import fetch_all_projects
            result = fetch_all_projects("token")
        assert len(result) == 2
        assert result[0]["name"] == "Alpha"
        assert result[1]["url"] == "https://linear.app/myorg/project/beta"

    def test_pagination(self):
        page1 = {
            "projects": {
                "pageInfo": {"hasNextPage": True, "endCursor": "cursor1"},
                "nodes": [{"name": "A", "url": "https://linear.app/a", "state": "started"}],
            }
        }
        page2 = {
            "projects": {
                "pageInfo": {"hasNextPage": False, "endCursor": None},
                "nodes": [{"name": "B", "url": "https://linear.app/b", "state": "completed"}],
            }
        }
        call_count = 0

        def mock_graphql(query, token, log_prefix="kb-enrich"):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                assert 'after:' not in query
                return page1
            else:
                assert 'after: "cursor1"' in query
                return page2

        with patch("kb.linear.linear_graphql", side_effect=mock_graphql):
            from kb.linear import fetch_all_projects
            result = fetch_all_projects("token")
        assert len(result) == 2
        assert result[0]["name"] == "A"
        assert result[1]["name"] == "B"

    def test_returns_empty_on_api_failure(self):
        with patch("kb.linear.linear_graphql", return_value=None):
            from kb.linear import fetch_all_projects
            result = fetch_all_projects("token")
        assert result == []

    def test_includes_labels_in_results(self):
        page = {
            "projects": {
                "pageInfo": {"hasNextPage": False, "endCursor": None},
                "nodes": [
                    {
                        "name": "Alpha",
                        "url": "https://linear.app/myorg/project/alpha",
                        "state": "started",
                        "labels": {"nodes": [{"name": "prod-a"}, {"name": "design"}]},
                    },
                    {
                        "name": "Beta",
                        "url": "https://linear.app/myorg/project/beta",
                        "state": "planned",
                        "labels": {"nodes": []},
                    },
                ],
            }
        }

        def mock_graphql(query, token, log_prefix="kb-enrich"):
            # The query should request labels
            assert "labels" in query
            return page

        with patch("kb.linear.linear_graphql", side_effect=mock_graphql):
            from kb.linear import fetch_all_projects
            result = fetch_all_projects("token")
        assert result[0]["labels"] == ["prod-a", "design"]
        assert result[1]["labels"] == []
