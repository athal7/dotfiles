"""Tests for Linear enrichment in kb.enrich."""
import json, re
from pathlib import Path
from unittest.mock import patch, MagicMock
import pytest


@pytest.fixture
def kb_tree(tmp_path):
    """Create a minimal KB directory with project and product profiles."""
    kb = tmp_path / "knowledge"
    projects_dir = kb / "projects"
    projects_dir.mkdir(parents=True)

    # Project profiles
    (projects_dir / "alpha-service.md").write_text("# Alpha Service\n\n## Status\n- Active\n")
    (projects_dir / "beta-api.md").write_text(
        "# Beta API\n- **Linear**: https://linear.app/myorg/project/beta-api\n\n## Status\n- Done\n")
    (projects_dir / "gamma-tool.md").write_text(
        "# Gamma Tool\n- **Linear**: https://linear.app/myorg/project/old-gamma\n\n## Status\n- WIP\n")

    # Product profiles (these get labels, not URLs)
    (projects_dir / "myproduct.md").write_text("# MyProduct\n\n## Status\n- Active product\n")
    (projects_dir / "data-feed.md").write_text("# Data Feed\n\n## Status\n- Active product\n")
    (projects_dir / "platform.md").write_text("# Platform\n\n## Status\n- Active product\n")

    # projects.json for name normalization
    project_map = {
        "Alpha Service": "Alpha Service",
        "alpha-service": "Alpha Service",
        "Beta API": "Beta API",
        "Gamma Tool": "Gamma Tool",
        "Ignored Thing": "",  # suppressed
    }
    (kb / "projects.json").write_text(json.dumps(project_map))

    # product-labels.json — maps Linear label names to profile slugs
    product_labels = {
        "prod-a": "myproduct",
        "prod-a-deploy": "myproduct",
        "prod-b": "data-feed",
        "cross-cutting": "platform",
    }
    (kb / "product-labels.json").write_text(json.dumps(product_labels))

    return kb


class TestProcessLinearProjects:
    """Tests for project URL enrichment — Linear projects matched to KB profiles by name."""

    def test_adds_linear_url_to_profile_without_one(self, kb_tree):
        linear_projects = [
            {"name": "Alpha Service", "url": "https://linear.app/myorg/project/alpha-svc", "state": "started", "labels": []},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        content = (kb_tree / "projects" / "alpha-service.md").read_text()
        assert "- **Linear**: https://linear.app/myorg/project/alpha-svc" in content
        lines = content.split("\n")
        assert lines[0] == "# Alpha Service"
        assert lines[1] == "- **Linear**: https://linear.app/myorg/project/alpha-svc"

    def test_skips_profile_with_same_url(self, kb_tree):
        linear_projects = [
            {"name": "Beta API", "url": "https://linear.app/myorg/project/beta-api", "state": "started", "labels": []},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        content = (kb_tree / "projects" / "beta-api.md").read_text()
        assert content == "# Beta API\n- **Linear**: https://linear.app/myorg/project/beta-api\n\n## Status\n- Done\n"

    def test_updates_existing_linear_field(self, kb_tree):
        linear_projects = [
            {"name": "Gamma Tool", "url": "https://linear.app/myorg/project/new-gamma", "state": "started", "labels": []},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        content = (kb_tree / "projects" / "gamma-tool.md").read_text()
        assert "- **Linear**: https://linear.app/myorg/project/new-gamma" in content
        assert "old-gamma" not in content

    def test_skips_unmatched_project(self, kb_tree):
        linear_projects = [
            {"name": "Unknown Project", "url": "https://linear.app/myorg/project/unknown", "state": "started", "labels": []},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        profiles = list((kb_tree / "projects").glob("*.md"))
        names = {p.name for p in profiles}
        assert "unknown-project.md" not in names

    def test_skips_suppressed_project(self, kb_tree):
        (kb_tree / "projects" / "ignored-thing.md").write_text("# Ignored Thing\n")
        linear_projects = [
            {"name": "Ignored Thing", "url": "https://linear.app/myorg/project/ignored", "state": "started", "labels": []},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        content = (kb_tree / "projects" / "ignored-thing.md").read_text()
        assert "Linear" not in content

    def test_dry_run_does_not_write(self, kb_tree):
        linear_projects = [
            {"name": "Alpha Service", "url": "https://linear.app/myorg/project/alpha-svc", "state": "started", "labels": []},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=True)
            process_linear(args)

        content = (kb_tree / "projects" / "alpha-service.md").read_text()
        assert "Linear" not in content

    def test_no_token_returns_early(self, kb_tree):
        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value=""):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

    def test_matches_by_slugified_linear_name_fallback(self, kb_tree):
        (kb_tree / "projects" / "delta-widget.md").write_text("# Delta Widget\n")
        linear_projects = [
            {"name": "Delta Widget", "url": "https://linear.app/myorg/project/delta", "state": "started", "labels": []},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        content = (kb_tree / "projects" / "delta-widget.md").read_text()
        assert "- **Linear**: https://linear.app/myorg/project/delta" in content


class TestProcessLinearProducts:
    """Tests for product label enrichment — labels aggregated across projects into product profiles."""

    def test_adds_labels_to_product_profile(self, kb_tree):
        """MyProduct profile gets label:prod-a from projects with that label."""
        linear_projects = [
            {"name": "Product UX Rework", "url": "https://linear.app/myorg/project/prod-ux", "state": "started", "labels": ["prod-a"]},
            {"name": "Product Perf", "url": "https://linear.app/myorg/project/prod-perf", "state": "started", "labels": ["prod-a", "prod-a-deploy"]},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        content = (kb_tree / "projects" / "myproduct.md").read_text()
        assert "- **Linear**: label:prod-a, label:prod-a-deploy" in content

    def test_product_labels_sorted_alphabetically(self, kb_tree):
        """Multiple labels for a product appear sorted."""
        linear_projects = [
            {"name": "P1", "url": "https://linear.app/myorg/project/p1", "state": "started", "labels": ["prod-a-deploy"]},
            {"name": "P2", "url": "https://linear.app/myorg/project/p2", "state": "started", "labels": ["prod-a"]},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        content = (kb_tree / "projects" / "myproduct.md").read_text()
        # prod-a before prod-a-deploy alphabetically
        assert "label:prod-a, label:prod-a-deploy" in content

    def test_product_label_already_present_skips(self, kb_tree):
        """If the product profile already has the correct label line, don't rewrite."""
        (kb_tree / "projects" / "myproduct.md").write_text(
            "# MyProduct\n- **Linear**: label:prod-a, label:prod-a-deploy\n\n## Status\n- Active product\n")
        linear_projects = [
            {"name": "P1", "url": "https://linear.app/myorg/project/p1", "state": "started", "labels": ["prod-a", "prod-a-deploy"]},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        content = (kb_tree / "projects" / "myproduct.md").read_text()
        assert content == "# MyProduct\n- **Linear**: label:prod-a, label:prod-a-deploy\n\n## Status\n- Active product\n"

    def test_product_labels_update_existing_linear_field(self, kb_tree):
        """If a product profile has an old Linear field, it gets replaced with labels."""
        (kb_tree / "projects" / "myproduct.md").write_text(
            "# MyProduct\n- **Linear**: label:prod-a\n\n## Status\n- Active product\n")
        linear_projects = [
            {"name": "P1", "url": "https://linear.app/myorg/project/p1", "state": "started", "labels": ["prod-a", "prod-a-deploy"]},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        content = (kb_tree / "projects" / "myproduct.md").read_text()
        assert "- **Linear**: label:prod-a, label:prod-a-deploy" in content
        # Old single label line should be gone
        assert content.count("**Linear**") == 1

    def test_multiple_products_from_same_project_set(self, kb_tree):
        """Projects with different labels enrich different product profiles."""
        linear_projects = [
            {"name": "P1", "url": "https://linear.app/myorg/project/p1", "state": "started", "labels": ["prod-a"]},
            {"name": "P2", "url": "https://linear.app/myorg/project/p2", "state": "started", "labels": ["prod-b"]},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        myproduct_content = (kb_tree / "projects" / "myproduct.md").read_text()
        assert "label:prod-a" in myproduct_content

        feed_content = (kb_tree / "projects" / "data-feed.md").read_text()
        assert "label:prod-b" in feed_content

    def test_dry_run_does_not_write_product_labels(self, kb_tree):
        linear_projects = [
            {"name": "P1", "url": "https://linear.app/myorg/project/p1", "state": "started", "labels": ["prod-a"]},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=True)
            process_linear(args)

        content = (kb_tree / "projects" / "myproduct.md").read_text()
        assert "Linear" not in content

    def test_unknown_label_ignored(self, kb_tree):
        """Labels not in product-labels.json mapping are silently skipped."""
        linear_projects = [
            {"name": "P1", "url": "https://linear.app/myorg/project/p1", "state": "started", "labels": ["unknown-label"]},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        # No product profiles should have been touched
        myproduct_content = (kb_tree / "projects" / "myproduct.md").read_text()
        assert "Linear" not in myproduct_content

    def test_missing_labels_file_treated_as_empty(self, kb_tree):
        """If product-labels.json is missing, label enrichment silently does nothing."""
        (kb_tree / "product-labels.json").unlink()
        linear_projects = [
            {"name": "P1", "url": "https://linear.app/myorg/project/p1", "state": "started", "labels": ["prod-a"]},
        ]

        with patch("kb.enrich.KB_DIR", kb_tree), \
             patch("kb.profiles.KB_DIR", kb_tree), \
             patch("kb.linear.get_linear_token", return_value="lin_api_test"), \
             patch("kb.linear.fetch_all_projects", return_value=linear_projects):
            from kb.enrich import process_linear
            args = MagicMock(dry_run=False)
            process_linear(args)

        myproduct_content = (kb_tree / "projects" / "myproduct.md").read_text()
        assert "Linear" not in myproduct_content


class TestArgparseLinearFlag:
    def test_linear_flag_recognized(self):
        from kb.enrich import main
        # Should not raise — just verify the flag is accepted
        # We mock process_linear to avoid actually running
        with patch("kb.enrich.process_linear") as mock_pl, \
             patch("kb.enrich.process_slack"):
            main(["--linear"])
        mock_pl.assert_called_once()

    def test_no_flags_runs_linear(self):
        """Running with no flags should run all sources including linear."""
        from kb.enrich import main
        with patch("kb.enrich.process_linear") as mock_pl, \
             patch("kb.enrich.process_slack") as mock_ps:
            main([])
        mock_pl.assert_called_once()
        mock_ps.assert_called_once()

    def test_slack_only_skips_linear(self):
        from kb.enrich import main
        with patch("kb.enrich.process_linear") as mock_pl, \
             patch("kb.enrich.process_slack") as mock_ps:
            main(["--slack"])
        mock_pl.assert_not_called()
        mock_ps.assert_called_once()

    def test_linear_only_skips_slack(self):
        from kb.enrich import main
        with patch("kb.enrich.process_linear") as mock_pl, \
             patch("kb.enrich.process_slack") as mock_ps:
            main(["--linear"])
        mock_pl.assert_called_once()
        mock_ps.assert_not_called()
