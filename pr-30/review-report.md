## 🧪 Review — QA: n/a
Findings: 4 build · 3 human · 2 plan

**Changeset:** [PR #30 — files changed](https://github.com/athal7/dotfiles/pull/30/files)

### AC1 — Single AC-organized report replacing inline comments
- **Changeset:** [commands/review.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-20cdf94d3298c20cba022691c72c663556758d74be759a4f6d42dc136f3a5e53) · [commands/implement.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-a558d34f183b4487ac1f3dc868c51a1271829c9e6a67c69fb77ab9651a449a00) · [prompts/lead.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-8295cf75dd25f7d767207b8ba915c632d5608a69d321543e0c26207c2efca983) · [README.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-b335630551682c19a781afebcf4d07bf978fb1f8ac04c6bf87428ed5106870f5)
- **Findings:** None. Satisfied — all surfaces agree; no stale qa-publish/Walk/inline-comment wording in any config/command/skill body.

### AC2 — Two forms in qa session dir, both led by verdict + Findings
- **Changeset:** [skills/README.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-4d647326e823e7202ff18d96504599a2f17893ead7e40499f82899106dbad2c7)
- **Findings:** `[plan] openspec/changes/unified-review-report/specs/code-review/spec.md:51` — the "Dual output" scenario says both forms are led by the `## 🧪 Review` verdict line, but the HTML form is led by `<h1>🧪 Review…</h1>` + `<p class="summary">`, not a Markdown `##`. The skill is right; the spec text is imprecise. → Fix: "…each led by the 🧪 Review verdict line (`## 🧪 Review` in the Markdown form, `<h1>` in the HTML form) and the `Findings:` count line."

### AC3 — Hosted MD references changeset, never copies diff text
- **Changeset:** [skills/gh/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-10bdf1f85e44338633edb2b48a85ec6d3146e55a813520356105333a307f3767) · [skills/review-publish/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-684b8d5ed4ecad9fbfff5b769f3a302ef48bbcf121d7cc7e29b07a5291135c9a) (mechanics; see AC4)
- **Findings:** None. Satisfied — deep-links per file via `#diff-<sha256(path)>` pinned to head SHA; local fallback cites diff command + file:line. The recipe uses `printf '%s'` not echo, and `shasum -a 256 | cut -d' ' -f1` — correct.

### AC4 — Local HTML embeds rendered changeset (self-contained)
- **Changeset:** [skills/gh/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-10bdf1f85e44338633edb2b48a85ec6d3146e55a813520356105333a307f3767) · [skills/review-publish/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-684b8d5ed4ecad9fbfff5b769f3a302ef48bbcf121d7cc7e29b07a5291135c9a)
- **Findings:**
  - `[build] skills/gh/SKILL.md` (render_diff_html awk) — the `^(\+\+\+|---)` header-skip rule runs on every line, not just the pre-hunk header block, so a REMOVED line whose content begins with `--` renders as `---…` and is dropped, and an ADDED line beginning with `++` (`+++…`) is dropped. This repo is markdown/YAML-heavy (frontmatter `---`, horizontal rules, YAML separators) so removing such a line vanishes from the rendered diff. HTML-escaping order is correct; the line-classification is the bug. → Fix: classify structurally — skip everything before the first `@@`, then only tag within hunks (the corrected awk used to render the HTML form of this report).
  - `[human] skills/gh/SKILL.md` (hosted-sourcing comment) — feeding from the `diff --git` line means `diff --git`, `index`, and mode lines fall through to the `ctx` branch and render as context in every file block. Cosmetic; the structural fix eliminates it.
  - `[human] skills/gh/SKILL.md` — local sourcing uses `git diff "$base..$head"`, but a pre-commit context has no committed head. Generation runs post-push per `implement.md:129` so commits exist — acceptable; flagged so the `base..head` template isn't copied into a pre-commit context.

### AC5 — Findings prefer fitness functions
- **Changeset:** [prompts/reviewer.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-85f2f3a17acb0bab5b59e75a773720ad0a36f013144c57b8cb5615c6973658d6)
- **Findings:** None. Satisfied — reviewer.md's new "Prefer the fitness function over the hand-run sweep" section matches firm-ish design intent.

### AC6 — Rename qa-publish → review-publish; link is the sole MR write
- **Changeset:** [opencode.json.tmpl](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-6b53085d6a3c037ddffe171a34af38f42da0dcc214ca23dd549eeb56b46c82ec) · [skills/qa-publish/SKILL.md (deleted)](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-1d416265227d3fc8afa2c5e12beab6fde69d85157e71935ebafee3072393e625)
- **Findings:** `[human] skills/review-publish/SKILL.md:159`, `commands/implement.md:129` — the description markers are still `<!-- qa:start -->`/`<!-- qa:end -->`. Consistent across both files, but semantically stale now the badge is a Review badge. Likely intentional to avoid breaking existing MR descriptions; flagged as a deliberate-vs-oversight call.

### AC7 — Store contract preserved
- **Changeset:** [prompts/qa.md](https://github.com/athal7/dotfiles/pull/30/files/5bd92759bd9d1116859c19ef17c0d1365a67c717#diff-ddc859062c06ace472876e4d83bd2098cbd8339da60f11121843c168ff62fe52)
- **Findings:** None. Satisfied — qa.md preserves report.html, NNN-*.png, the store path, qa-* naming, and the `## 🧪 QA` heading; review-report.* siblings are distinct-prefixed and don't collide.

### Scope & cross-cutting
- `[build] commands/implement.md:129` — ship-time publish omits the no-QA path its own trigger admits. Trigger is "QA ran OR noteworthy surviving findings," but the assembly text says "reviewer findings fused with qa evidence" and never tells lead to create the `qa-<ts>` dir itself or that the report is findings-only when QA didn't run. `review.md:31` handles this; implement.md is asymmetric. → Fix: "…assemble the report in BOTH forms (reviewer findings, fused with qa evidence WHEN QA ran); … when QA did not run, create the `qa-<ts>` session dir yourself and write both forms with verdict `n/a` — the findings half is always present."
- `[build] skills/review-publish/SKILL.md:25-27` — the no-QA "create the session dir" instruction lacks the concrete path/naming, so the created dir may not be prune-eligible / demo-readable. → Fix: name `~/.local/share/qa/<project>/qa-<ts>/` explicitly (a stable store constant, not a tool name — fine in a workflow body).
- `[build] prompts/reviewer.md` (Re-review paragraph) — says lead regenerates only `review-report.md`; review-publish + review.md say BOTH forms. → Fix: "…lead REGENERATES the unified report (both forms; the hosted `review-report.md` is overwritten wholesale, so the link is unchanged)."
- `[plan] fitness-function suggestion` — the cross-file consistency gaps above are what a guard could catch: a lightweight CI check asserting `commands/*.md`, `prompts/{lead,qa,reviewer}.md`, and `review-publish/SKILL.md` all reference the same artifact names (`review-report.html`/`review-report.md`) and the `qa-<ts>` path. Plan-level suggestion, not a blocker.

### Could not verify
- The render_diff_html awk was not executed by the reviewer (static read); the `---`/`+++` swallowing is confirmed by regex semantics. (The HTML form of this report was rendered with the corrected awk.)
- `design.md:93`'s illustrative URL drops the `/$HEAD_SHA` segment its own prose requires — design doc, not code under review; noted in passing.
