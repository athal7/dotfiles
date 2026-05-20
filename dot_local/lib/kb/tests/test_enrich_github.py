"""Tests for GitHub enrichment in kb.enrich."""
import json
from pathlib import Path
from unittest.mock import patch, MagicMock
import pytest


@pytest.fixture
def kb_tree(tmp_path):
    """Create a minimal KB directory with project profiles and github-repos.json."""
    kb = tmp_path / "knowledge"
    projects_dir = kb / "projects"
    projects_dir.mkdir(parents=True)

    # Project profiles
    (projects_dir / "alpha-service.md").write_text("# Alpha Service\n\n## Status\n- Active\n")
    (projects_dir / "beta-api.md").write_text(
        "# Beta API\n- **Linear**: https://linear.app/myorg/project/beta-api\n\n## Status\n- Done\n")
    (projects_dir / "gamma-tool.md").write_text(
        "# Gamma Tool\n- **GitHub**: https://github.com/myorg/gamma\n\n## Status\n- WIP\n")

    # github-repos.json mapping
    repo_map = {
        "_org": "myorg",
        "myrepo-alpha": "alpha-service",
        "myrepo-beta": "beta-api",
        "myrepo-gamma": "gamma-tool",
        "myrepo-gamma2": "gamma-tool",
    }
    (kb / "github-repos.json").write_text(json.dumps(repo_map))

    return kb


def _gh_repos():
    """Standard set of GitHub repos returned by the mock."""
    return [
        {"name": "myrepo-alpha", "url": "https://github.com/myorg/myrepo-alpha", "description": "Alpha"},
        {"name": "myrepo-beta", "url": "https://github.com/myorg/myrepo-beta", "description": "Beta"},
        {"name": "myrepo-gamma", "url": "https://github.com/myorg/gamma", "description": "Gamma"},
        {"name": "myrepo-gamma2", "url": "https://github.com/myorg/myrepo-gamma2", "description": "Gamma second"},
        {"name": "unmapped-repo", "url": "https://github.com/myorg/unmapped-repo", "description": "Not mapped"},
    ]


class TestProcessGitHub:
    def test_adds_github_url_to_profile_without_one(self, kb_tree):
        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.github.fetch_org_repos", return_value=_gh_repos()):
            from kb.enrich import process_github
            args = MagicMock(dry_run=False)
            process_github(args)

        content = (kb_tree / "projects" / "alpha-service.md").read_text()
        assert "- **GitHub**: https://github.com/myorg/myrepo-alpha" in content
        lines = content.split("\n")
        assert lines[0] == "# Alpha Service"
        assert lines[1] == "- **GitHub**: https://github.com/myorg/myrepo-alpha"

    def test_inserts_github_after_linear_field(self, kb_tree):
        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.github.fetch_org_repos", return_value=_gh_repos()):
            from kb.enrich import process_github
            args = MagicMock(dry_run=False)
            process_github(args)

        content = (kb_tree / "projects" / "beta-api.md").read_text()
        assert "- **GitHub**: https://github.com/myorg/myrepo-beta" in content
        lines = content.split("\n")
        # Linear first, GitHub second
        assert "- **Linear**:" in lines[1]
        assert "- **GitHub**:" in lines[2]

    def test_appends_second_repo_url_to_existing_field(self, kb_tree):
        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.github.fetch_org_repos", return_value=_gh_repos()):
            from kb.enrich import process_github
            args = MagicMock(dry_run=False)
            process_github(args)

        content = (kb_tree / "projects" / "gamma-tool.md").read_text()
        # Original URL was https://github.com/myorg/gamma, second repo adds myrepo-gamma2
        assert "https://github.com/myorg/gamma" in content
        assert "https://github.com/myorg/myrepo-gamma2" in content
        # Both in a single GitHub field line
        github_lines = [l for l in content.split("\n") if "**GitHub**" in l]
        assert len(github_lines) == 1
        assert "https://github.com/myorg/gamma" in github_lines[0]
        assert "https://github.com/myorg/myrepo-gamma2" in github_lines[0]

    def test_skips_when_url_already_present(self, kb_tree):
        # gamma-tool already has https://github.com/myorg/gamma and myrepo-gamma maps to it
        # The returned url for myrepo-gamma is the same as the existing one
        original = (kb_tree / "projects" / "gamma-tool.md").read_text()

        repos_only_gamma = [
            {"name": "myrepo-gamma", "url": "https://github.com/myorg/gamma", "description": "Gamma"},
        ]
        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.github.fetch_org_repos", return_value=repos_only_gamma):
            from kb.enrich import process_github
            args = MagicMock(dry_run=False)
            process_github(args)

        content = (kb_tree / "projects" / "gamma-tool.md").read_text()
        assert content == original

    def test_skips_unmapped_repos(self, kb_tree):
        repos = [
            {"name": "unmapped-repo", "url": "https://github.com/myorg/unmapped-repo", "description": ""},
        ]
        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.github.fetch_org_repos", return_value=repos):
            from kb.enrich import process_github
            args = MagicMock(dry_run=False)
            process_github(args)

        # No profile should mention this URL
        for p in (kb_tree / "projects").glob("*.md"):
            assert "unmapped-repo" not in p.read_text()

    def test_dry_run_does_not_write(self, kb_tree):
        original = (kb_tree / "projects" / "alpha-service.md").read_text()

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.github.fetch_org_repos", return_value=_gh_repos()):
            from kb.enrich import process_github
            args = MagicMock(dry_run=True)
            process_github(args)

        content = (kb_tree / "projects" / "alpha-service.md").read_text()
        assert content == original
        assert "GitHub" not in content

    def test_missing_repos_file_skips_gracefully(self, kb_tree):
        (kb_tree / "github-repos.json").unlink()

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.github.fetch_org_repos", return_value=_gh_repos()) as mock_fetch:
            from kb.enrich import process_github
            args = MagicMock(dry_run=False)
            process_github(args)

        mock_fetch.assert_not_called()

    def test_missing_org_key_skips_gracefully(self, kb_tree):
        (kb_tree / "github-repos.json").write_text(json.dumps({"myrepo": "alpha-service"}))

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.github.fetch_org_repos", return_value=_gh_repos()) as mock_fetch:
            from kb.enrich import process_github
            args = MagicMock(dry_run=False)
            process_github(args)

        mock_fetch.assert_not_called()

    def test_invalid_repos_json_skips_gracefully(self, kb_tree):
        (kb_tree / "github-repos.json").write_text("not valid json {{{")

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.github.fetch_org_repos", return_value=_gh_repos()) as mock_fetch:
            from kb.enrich import process_github
            args = MagicMock(dry_run=False)
            process_github(args)

        mock_fetch.assert_not_called()


class TestArgparseGitHubFlag:
    def test_github_flag_recognized(self):
        from kb.enrich import main
        with patch("kb.enrich.process_github") as mock_gh, \
             patch("kb.enrich.process_linear"), \
             patch("kb.enrich.process_slack"):
            main(["--github"])
        mock_gh.assert_called_once()

    def test_no_flags_runs_github(self):
        from kb.enrich import main
        with patch("kb.enrich.process_github") as mock_gh, \
             patch("kb.enrich.process_linear") as mock_pl, \
             patch("kb.enrich.process_slack") as mock_ps:
            main([])
        mock_gh.assert_called_once()
        mock_pl.assert_called_once()
        mock_ps.assert_called_once()

    def test_slack_only_skips_github(self):
        from kb.enrich import main
        with patch("kb.enrich.process_github") as mock_gh, \
             patch("kb.enrich.process_linear") as mock_pl, \
             patch("kb.enrich.process_slack") as mock_ps:
            main(["--slack"])
        mock_gh.assert_not_called()
        mock_ps.assert_called_once()

    def test_github_only_skips_slack_and_linear(self):
        from kb.enrich import main
        with patch("kb.enrich.process_github") as mock_gh, \
             patch("kb.enrich.process_linear") as mock_pl, \
             patch("kb.enrich.process_slack") as mock_ps:
            main(["--github"])
        mock_gh.assert_called_once()
        mock_pl.assert_not_called()
        mock_ps.assert_not_called()
