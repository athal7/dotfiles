"""Tests for profile frontmatter handling."""
from kb.profiles import _strip_frontmatter, _add_frontmatter


def test_strip_frontmatter_present():
    content = "---\ntype: person\nlast_updated: 2026-05-21\n---\n# Jane\n## Current\n- Working\n"
    fm, body = _strip_frontmatter(content)
    assert fm == {"type": "person", "last_updated": "2026-05-21"}
    assert body.startswith("# Jane")
    assert "---" not in body


def test_strip_frontmatter_absent():
    content = "# Jane\n## Current\n- Working\n"
    fm, body = _strip_frontmatter(content)
    assert fm == {}
    assert body == content


def test_add_frontmatter():
    body = "# Jane\n## Current\n- Working\n"
    result = _add_frontmatter(body, {"type": "person", "last_updated": "2026-05-21"})
    assert result.startswith("---\ntype: person")
    assert "# Jane" in result


def test_add_frontmatter_empty():
    body = "# Jane\n## Current\n- Working\n"
    result = _add_frontmatter(body, {})
    assert result == body  # no frontmatter added


def test_roundtrip():
    fm_in = {"type": "person", "last_updated": "2026-05-21"}
    body_in = "# Jane\n## Current\n- Working\n"
    combined = _add_frontmatter(body_in, fm_in)
    fm_out, body_out = _strip_frontmatter(combined)
    assert fm_out == fm_in
    assert body_out == body_in
