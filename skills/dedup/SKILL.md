---
name: dedup
description: Load before adding a function (planning) or approving one (review) to check the codebase for an existing semantic equivalent. Catches renamed/differently-named duplicate functions that grep and LSP workspaceSymbol (name-based) cannot find.
license: MIT
---

Before introducing or approving a new function, semantic-search the target codebase for an existing equivalent and prefer reuse over a differently-named duplicate. Duplication is often *semantic*, not *lexical* — `format_currency` vs. an existing `scope_price_label` share no tokens, so name-based tools (grep, LSP `workspaceSymbol`) miss them. Semantic search (`ck`) catches them.

## When this fires

- **Planning** — before specifying a new function, search for an existing equivalent. If one exists, record it (with `file:line`) as the reuse target instead of designing a new, differently-named implementation. One broader search pass is acceptable here.
- **Review** — for each function the diff *adds*, search for an existing equivalent. If the new function duplicates existing behavior, flag it, name the existing symbol and its `file:line`, and recommend reuse.

## Running ck

Bare `ck` resolves to the mise shim (`~/.local/share/mise/shims/ck`), which fails under the Desktop GUI's minimal PATH ("No version is set for shim"). Resolve the real binary by glob and call it by absolute path:

```bash
CK=$(ls ~/.local/share/mise/installs/cargo-ck-search/*/bin/ck 2>/dev/null | head -1)
"$CK" --json --sem --limit 5 "<concept or function purpose>" <path>
```

- `--sem` = semantic search; `--limit N` caps results (it builds/updates the index automatically on first run).
- `--json` emits newline-delimited JSON — one JSON object per line (NDJSON), not a JSON array — each with `file`, `span.line_start`, `score`, `preview`. Banner lines go to stderr, so piping stdout to `jq` is clean. The `--jsonl --no-snippet` agent variant uses different field names (`path` not `file`, `language`) and drops `preview`. If you fall back to plain text output, strip ANSI escape codes before parsing.

### Worked example

```bash
CK=$(ls ~/.local/share/mise/installs/cargo-ck-search/*/bin/ck 2>/dev/null | head -1)
"$CK" --json --sem --limit 5 "format a price for display" app/
# → results include app/models/price.rb:42  scope_price_label  (score 0.71)
# Reuse scope_price_label instead of adding format_currency.
```

## Review: scope queries tight

`ck` has a cold-start cost (~160s to build the index the first time). To bound it during review, query **only** the diff-added function names/purposes with a small `--limit` (e.g. 3–5) — one focused query per added function. Do **not** semantic-search the entire diff.

## Graceful degradation (fail open)

If the `ck` binary cannot be resolved at the globbed path, or a query errors or exceeds its time budget, **skip the dedup step and continue** planning/review normally. There is no hard stop — dedup is a best-effort backstop, never a gate.
