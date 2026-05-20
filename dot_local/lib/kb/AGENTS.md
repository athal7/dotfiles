# kb package

Python package at `~/.local/lib/kb/`. Entry point: `python3 -m kb {meeting,enrich}`. Requires `PYTHONPATH=~/.local/lib`.

## LM Studio / qwen3

- Use `/no_think` tags at start and end of user messages to suppress chain-of-thought output that pollutes JSON/markdown extraction.
- `lms_call` catches `urllib.error.HTTPError` separately to log the response body — LM Studio 400s have useful error details that the generic exception message hides.
- When the LLM omits the `# Name` header during profile reconciliation, the regex fixup `re.sub(r"^#\s+.*$", ...)` silently no-ops. Always check for header absence and prepend if missing, don't just regex-replace.

## Runtime data files

Internal names (product names, org names, Linear labels, GitHub repos) live in `~/meetings/knowledge/*.json` — loaded at runtime, never committed. When adding a new data-driven mapping, follow this pattern rather than hardcoding names in Python.

- `names.json` — people display name → canonical name
- `projects.json` — project name → canonical name (empty string = suppress)
- `product-labels.json` — Linear label → product profile slug
- `github-repos.json` — GitHub repo name → project profile slug (`_org` key = which org to fetch)

## Products vs projects

Products are ongoing — they get Linear label metadata. Projects are bounded work — they get direct Linear/GitHub URLs. Don't alias specific projects into product-level profiles.

## Slack API

- `conversations.history` intermittently returns `{"ok": true, "messages": []}` for channels with messages. No error, no rate limit. Works on retry. The script handles this gracefully but may produce 0 updates on unlucky runs.
- KB people profiles with `<@UXXXXXXX>` Slack IDs drive DM scanning — no external user cache or config needed.
