#!/usr/bin/env bash
# Validate SKILL.md files against the Agent Skills spec:
# - name and description frontmatter are required
# - name must match the parent directory name
# - name must be lowercase alphanumeric + hyphens, no leading/trailing/consecutive hyphens
# - name must be 1-64 characters
# - description must be 1-1024 characters

set -euo pipefail

errors=0

for skill_file in "$@"; do
  dir=$(basename "$(dirname "$skill_file")")

  # Extract frontmatter values (between first --- pair)
  name=$(awk '/^---/{f=!f; next} f && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$skill_file")
  description=$(awk '/^---/{f=!f; next} f && /^description:/{sub(/^description:[[:space:]]*/, ""); print; exit}' "$skill_file")

  fail() {
    echo "SKILL ERROR: $skill_file — $1" >&2
    errors=$((errors + 1))
  }

  # name required
  if [ -z "$name" ]; then
    fail "missing 'name' in frontmatter"
    continue
  fi

  # name matches directory
  if [ "$name" != "$dir" ]; then
    fail "name '$name' does not match directory '$dir'"
  fi

  # name format: lowercase alphanumeric + hyphens, no leading/trailing/consecutive hyphens, 1-64 chars
  if ! echo "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    fail "name '$name' is invalid (must be lowercase alphanumeric with single hyphens)"
  fi

  if [ "${#name}" -gt 64 ]; then
    fail "name '$name' exceeds 64 characters"
  fi

  # description required
  if [ -z "$description" ]; then
    fail "missing 'description' in frontmatter"
    continue
  fi

  if [ "${#description}" -gt 1024 ]; then
    fail "description exceeds 1024 characters"
  fi
done

if [ "$errors" -gt 0 ]; then
  echo "$errors skill validation error(s) found" >&2
  exit 1
fi
