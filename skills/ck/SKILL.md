---
name: ck
description: Semantic code search via the resident ck MCP server — find code by meaning for concept discovery, understanding unfamiliar code, and catching existing implementations before adding a duplicate
license: MIT
---

`ck` is a local semantic code-search engine running as a single shared resident MCP server (one daemon for all sessions/worktrees), reached over the configured MCP transport. Warm `semantic_search` queries return in ~250ms — fast enough to use freely during discovery, planning, and review.

The shared daemon re-embeds each repo path lazily on the **first** query for that path, which can take minutes for a large repo (then ~200ms warm). If a first query is slow or times out, fail open (skip and continue) and retry later once the path has warmed.

## What it's for

- **Concept discovery** — "is there something that does X", "where is the logic for Y".
- **Understanding unfamiliar code** — locate the relevant region by meaning, then read.
- **Finding existing implementations** — before adding a function, search for an equivalent and reuse it. Duplication is often *semantic*, not *lexical*: `format_currency` vs. an existing `scope_price_label` share no tokens, so grep and LSP `workspaceSymbol` (name-based) miss them. Semantic search catches them.

## grep vs. semantic — decision rule

- **Exact tokens, filenames, known symbols** → grep/glob. Faster and precise.
- **Conceptual / "does anything do X"** → `semantic_search`, then narrow with grep.

## Invoking semantic_search

Call the `ck_semantic_search` MCP tool:

- `query` — natural-language description of the behavior (not a symbol name).
- `path` — directory to search (e.g. the repo root or a subtree like `app/`).
- `top_k` — cap results (3–5 for a focused dedup check).
- `threshold` — optional minimum score filter.
- `include_patterns` / `exclude_patterns` — required array args; pass `[]` for both when unscoped.

Results name the `file` and line for each match, with a snippet. For dedup, name the existing symbol and its `file:line` and recommend reuse.

## Freshness: reindex once per session

The resident server reads the on-disk index and does **not** auto-reindex. Before your first `semantic_search` in a session, call the `ck_reindex` MCP tool (`path` = the search root) once to pick up recent changes. An out-of-band `ck --index` from bash does **not** reach the resident process — reindex must go through the MCP tool. The staleness window is small in practice because discovery and dedup target established code, not the lines you just edited.

## Graceful degradation (fail open)

If the `ck` MCP server is unavailable, or a `semantic_search`/`reindex` call errors or exceeds its time budget, **skip the step and continue**. Semantic search is a best-effort backstop, never a gate — exploration, planning, and review proceed normally without it.
