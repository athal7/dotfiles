## 🧪 Review — QA: n/a
Findings: 5 build · 1 human · 2 plan

**Changeset:** https://github.com/athal7/dotfiles/pull/30/files   (local: `git diff 8c2bb19..8792045`)

Self-authored PR #30 (`athal7/dotfiles`), base `main` (`8c2bb19`) → head `8792045`. Non-UI change → QA: n/a (no screenshots). 12 files, +450/−85.

---

### AC1 — Findings are verified before inclusion in the report

- **Changeset:** [reviewer.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-85f2f3a17acb0bab5b59e75a773720ad0a36f013144c57b8cb5615c6973658d6) (local: `git diff 8c2bb19..8792045 -- dot_config/opencode/prompts/reviewer.md`)
- **Findings:** None.
- **QA:** n/a

### AC2 — Review output is a single AC-organized report

- **Changeset:** [review-publish/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-684b8d5ed4ecad9fbfff5b769f3a302ef48bbcf121d7cc7e29b07a5291135c9a) (local: `git diff 8c2bb19..8792045 -- skills/review-publish/SKILL.md`)
- **Findings:**
  - `skills/review-publish/SKILL.md:208,:211` (and `:252,:255`) **[build]** — Template examples lead with `QA: PASS ✅` while a per-AC line says `QA FAIL ❌`; the overall-verdict aggregation rule is unstated (also surfaces in `design.md:189/192,229/232`). → Make the examples internally consistent and add a sentence to "Report forms": the top-line verdict is FAIL if any AC's QA failed, n/a if QA didn't run, else PASS.
- **QA:** n/a

### AC3 — Findings with no acceptance criterion appear in a dedicated scope/cross-cutting section

- **Changeset:** [review-publish/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-684b8d5ed4ecad9fbfff5b769f3a302ef48bbcf121d7cc7e29b07a5291135c9a) (local: `git diff 8c2bb19..8792045 -- skills/review-publish/SKILL.md`)
- **Findings:** None.
- **QA:** n/a

### AC4 — Your own merge request surfaces the review report in its description

- **Changeset:** [mr.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-841315e989233ba9f0decaf7aceae23b5866845dd01a0116ff6c7353f98225ef) · [implement.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-a558d34f183b4487ac1f3dc868c51a1271829c9e6a67c69fb77ab9651a449a00) · [review.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-20cdf94d3298c20cba022691c72c663556758d74be759a4f6d42dc136f3a5e53) · [review-publish/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-684b8d5ed4ecad9fbfff5b769f3a302ef48bbcf121d7cc7e29b07a5291135c9a) (local: `git diff 8c2bb19..8792045 -- dot_config/opencode/commands/mr.md dot_config/opencode/commands/implement.md dot_config/opencode/commands/review.md`)
- **Findings:**
  - `dot_config/opencode/commands/mr.md:39` **[plan]** — The "regenerate the review report" step has no source of findings: `/mr` dispatches only explore+build, never reviewer/qa. It can only re-pin diffs/permalinks and refresh provenance over standing findings. → Reword to scope it to what `/mr` can do (or add a reviewer re-dispatch), and state the precondition that the marked block and the `qa-<ts>` dir already exist.
  - `dot_config/opencode/commands/implement.md:129` + `dot_config/opencode/commands/mr.md:39` + `dot_config/opencode/commands/review.md:33` **[build]** — These reference "Template-A"/"Template-B", but the loaded skill heads those sections "Your-own-request AC block layout" / "Someone-else summary body" (`skills/review-publish/SKILL.md:204,:249`); the labels exist only in `design.md`. → Add the parenthetical labels to the skill headers, or drop the labels from the commands.
- **QA:** n/a

### AC5 — Reviewing someone else's merge request delivers inline line-anchored comments in a single review submission

- **Changeset:** [review-publish/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-684b8d5ed4ecad9fbfff5b769f3a302ef48bbcf121d7cc7e29b07a5291135c9a) · [gh/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-10bdf1f85e44338633edb2b48a85ec6d3146e55a813520356105333a307f3767) (local: `git diff 8c2bb19..8792045 -- skills/review-publish/SKILL.md skills/gh/SKILL.md`)
- **Findings:** None.
- **QA:** n/a

### AC6 — The hosted report references the changeset, never copies diff text

- **Changeset:** [gh/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-10bdf1f85e44338633edb2b48a85ec6d3146e55a813520356105333a307f3767) (local: `git diff 8c2bb19..8792045 -- skills/gh/SKILL.md`)
- **Findings:**
  - `skills/gh/SKILL.md:350-352` **[build]** (clarity, low) — The render recipe's "hosted:" comment uses "hosted" to mean diff-*source* (a hosted PR), easy to misread as the hosted output *form*, and it sits adjacent to the never-embed-hunks rule. → Reword to "when the changeset under review is a hosted PR, source its diff via `gh pr diff`" plus "(still rendered into the local `.html`, never the hosted `.md`)".
- **QA:** n/a

### AC7 — The review report is produced in two forms

- **Changeset:** [review-publish/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-684b8d5ed4ecad9fbfff5b769f3a302ef48bbcf121d7cc7e29b07a5291135c9a) (local: `git diff 8c2bb19..8792045 -- skills/review-publish/SKILL.md`)
- **Findings:**
  - `skills/review-publish/SKILL.md:135-141` **[build]** — The "Badge composition" example `🧪 QA PASS ✅ · 3 findings — <link>` (a holdover from `qa-publish`) contradicts the real delivered badge `🧪 Review — QA: PASS ✅ · N build · N human · N plan` shown at `:208,:252`. → Update the example to the real format, or fold the section into the templates.
- **QA:** n/a

### AC8 — The local HTML form embeds the rendered changeset

- **Changeset:** [review-publish/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-684b8d5ed4ecad9fbfff5b769f3a302ef48bbcf121d7cc7e29b07a5291135c9a) · [gh/SKILL.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-10bdf1f85e44338633edb2b48a85ec6d3146e55a813520356105333a307f3767) (local: `git diff 8c2bb19..8792045 -- skills/review-publish/SKILL.md skills/gh/SKILL.md`)
- **Findings:** None. (Related coupling nit in Scope & cross-cutting below.)
- **QA:** n/a

### AC9 — Findings prefer fitness functions over manual sweeps

- **Changeset:** [reviewer.md](https://github.com/athal7/dotfiles/pull/30/files/8792045763a1958bc2da3db77d3c64a2dfe3b3d4#diff-85f2f3a17acb0bab5b59e75a773720ad0a36f013144c57b8cb5615c6973658d6) (local: `git diff 8c2bb19..8792045 -- dot_config/opencode/prompts/reviewer.md`)
- **Findings:** None.
- **QA:** n/a

---

### Scope & cross-cutting

- `skills/review-publish/SKILL.md:102` + the template permalink shape `…/blob/<headSHA>/<path>#L120-L156` (the `:194-213` region) **[build]** (low) — Coupling leaks in a workflow-skill body: a platform name ("GitHub-ish diff palette") and a host-specific URL shape that belongs in the source-control integration skill. → "GitHub-ish" → "a familiar code-host diff palette"; replace the literal `/blob/...#L...` with a generic placeholder and let the integration skill own the URL shape.
- `skills/review-publish/SKILL.md:27-30` + `dot_config/opencode/commands/implement.md:129` **[plan]** (low) — These create lead-authored no-QA `qa-<ts>` dirs holding only `review-report.{html,md}`, but `demo.md:23` assumes every `qa-*` dir holds `report.html` + screenshots. `/cleanup` prunes wholesale and `/demo` has a live fallback, so impact is benign — but `design.md:320-321`'s "unaffected" claim is incomplete. → Have lead not create a `qa-<ts>` dir for non-UI no-QA changes, or add a line to `demo.md` noting some `qa-*` dirs hold only `review-report.*`; at minimum correct the design claim.
- `README.md:14` + `dot_config/opencode/prompts/lead.md:20` **[human]** (style, low) — Run-on sentences; the README bullet is missing a terminal period. → Split into two sentences and add the period.

### Could not verify

- `chezmoi apply` — deploy of `review-publish` and absence of `qa-publish`/`review-helper` not run by the reviewer.
- External GitHub behaviors — the `#diff-<sha256>` anchor scheme and bare-permalink unfurl inside `<details>` are not statically verifiable.
- Skill-injection runtime — not exercised.
