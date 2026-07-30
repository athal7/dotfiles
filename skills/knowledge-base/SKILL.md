---
name: knowledge-base
description: "Look up people, projects, products, and decisions locally first: contact info (email, Slack ID, GitHub handle), titles and teams, project/product status, who works on what, and past decisions. Check before searching Slack, email, calendar, or GitHub — this is the first stop for any contact detail, project context, or decision-history question."
license: MIT
metadata:
  provides:
    - knowledge-base
---

The knowledge base is queried and managed programmatically using the `kb` CLI and the `kb-git-activity` CLI. Direct filesystem access (such as reading, writing, or grepping files in `~/.local/share/kb/`) is deprecated in favor of these CLI interfaces.

## Querying People

Use the `kb people` command group to search and lookup people registered in the knowledge base:

- **List all people**: `kb people list`
  - Returns a JSON array of all registered people with their canonical names, titles, teams, emails, Slack IDs, and aliases.
- **Show a person profile**: `kb people show <name>`
  - Look up a person by their name or any of their aliases, returning their parsed record as JSON.
  - Always check this first for contact information (emails, Slack IDs, GitHub handles) before searching external services.

## Managing Action Items

Use the `kb action-items` command group to list and update the status of action items:

- **List action items**: `kb action-items list`
  - Returns a JSON array of open or in-progress action items, including their line numbers, source groups, and text.
- **Mark an item as in-progress**: `kb action-items progress <line_no>`
- **Mark an item as completed**: `kb action-items complete <line_no>`
- **Reset an item to todo**: `kb action-items todo <line_no>`

## Journaling and Coding Activity

Use the `kb journal` command group and `kb-git-activity` CLI to log dev activity:

- **Append content to daily journal**: `kb journal append --date YYYY-MM-DD --section <section_name> --content <content>`
  - Appends content under a specific section of the daily journal for the given date (defaulting to today).
- **Automate git activity stats**: `kb-git-activity --dir <repos_directory> --date YYYY-MM-DD`
  - Derives daily coding statistics (commit counts, files changed, insertions, and deletions) from local git history and appends them to the daily journal under the "Git Activity" section.
