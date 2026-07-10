---
name: knowledge-base
description: "Look up people, projects, products, and decisions locally first: contact info (email, Slack ID, GitHub handle), titles and teams, project/product status, who works on what, and past decisions. Check before searching Slack, email, calendar, or GitHub — this is the first stop for any contact detail, project context, or decision-history question."
license: MIT
metadata:
  provides:
    - knowledge-base
---

The knowledge base at `~/.local/share/kb/` is a distilled, maintained view of people, projects, and decisions.

## Structure

- `people/<slug>.md` — person profiles
- `products/<slug>.md` — product profiles (umbrella products with real surface area / repos)
- `projects/<slug>.md` — project profiles (workstreams; each links to its parent product)
- `decisions/cross-cutting.md` — org/process decisions not tied to a product or project
- `decisions/archive.md` — historical decision log (not actively maintained)
- `journal/YYYY-MM-DD.md` — daily dev journal
- `names.json` — display name → canonical name (people)
- `projects.json` — variant name → canonical name (projects, empty string = suppress)
- `product-labels.json` — Linear label → product/project slug
- `github-repos.json` — repo name → product/project slug; also has an `_org` key (the GitHub org), so combine `_org` + repo name to build a `github.com/<org>/<repo>` URL (e.g. for PR links)
- `openspec/<repo-slug>/` — durable per-repo OpenSpec store: `specs/` (accumulated standing requirements) and `changes/archive/<date>-<name>/` (completed changes, each with a `design.md` rationale). In-flight change proposals and their `design.md` live in the worktree at `openspec/changes/<name>/` until archived — the store's `changes/` holds only `archive/`. Each archived change carries a `kb-meta.yaml` (worktree, branch, date, change) that lets enrichment correlate the producing sessions to the change. `/implement` links each worktree's `openspec/` into this store via narrow symlinks (`openspec/specs`, `openspec/changes/archive`); in-flight `changes/<name>/` are real files in the worktree until archived. The store is read during planning and by daily enrichment (which reads the dated `changes/archive/<date>-<name>/design.md` for that day's decisions).
- `apm-fix-ledger.jsonl` — append-only JSONL ledger of `/fix-prod-errors` dispatches and their disposition (`pending` / `filed`+`ticket_url` / `declined`+`reason` / `noise-confirmed`), keyed by `worktree` (== opencode session `directory`); last line per worktree wins. `/fix-prod-errors` writes the `pending` line; `/kb-enrich` surfaces pending drafts for approval and appends the resolving line. Runtime state, not chezmoi-managed.

## People profiles

Distilled reference cards, not meeting logs. Omit any section with no information.

    ---
    type: person
    email: jane@example.com
    slack: U123ABC
    github: janesmith
    title: Engineering Lead
    team: Platform
    aliases:
      - Jane
      - J. Smith
    projects:
      - "[[Shield]]"
      - "[[Auth Service]]"
    last_updated: 2026-06-02
    ---
    # Jane Smith
    ## Current
    - Leading infrastructure migration on [[Shield]]
    - Key contact for enterprise onboarding on [[Auth Service]]
    ## Style
    - Prefers short threads over long documents
    - Direct, action-oriented
    ## Personal
    - Based in Portland, two kids
    ## Key Decisions
    - Deprecate old UI in favor of portal automation (2026-01)
    - Move analytics to PostHog (2026-04)

Contact fields live in frontmatter properties (email, slack, github, title, team) and the body holds only the heading and sections. The `slack` property is a raw id (wrap it as `<@id>` when posting to chat); `github` is a raw handle. `aliases` lists the person's name variants so links and search resolve. `projects` is a quoted-`[[wikilink]]` list that mirrors the `[[Project]]` links in the Current section, so the person↔project relationship is queryable from frontmatter.

Rules: preserve the contact properties (never drop email/slack/github/title/team). Preserve the `projects` relationship list and keep it in sync with the `[[Project]]` wikilinks in Current (quote each entry so it parses). Drop stale Current items (>2 weeks, no recent mention). Max 5 Current, max 10 Key Decisions. Use `[[Project Name]]` wikilinks in Current.

When looking up a person: read their profile first. Contact info lives in the frontmatter properties — use the email or slack id directly. The slack property is a raw id; wrap it as `<@id>` when messaging.

## Product profiles

Products are the umbrella offerings with real surface area and one or more associated repos (like Scanner or Shield). Same shape as a project, but `type: product` and a `repos:` list of the repo names that make up the product.

    ---
    type: product
    status: active
    linear: label:scanner
    github: https://github.com/myorg/scanner
    repos:
      - scanner
      - scanner-cli
    aliases:
      - the scanner
      - scanner product
    people:
      - "[[Jane Smith]]"
    last_updated: 2026-06-01
    ---
    # Scanner
    ## Status
    - Public launch shipped; onboarding rethink in progress
    ## Key Decisions
    - "Probes" is the canonical term for scanner-focused messaging (2026-03)
    ## People
    - [[Jane Smith]] — engineering lead

Link fields and `status` work as on projects; `repos` lists the associated repo names so the product↔repo relationship is queryable from frontmatter. Projects point to their parent product via the `product:` property, so a product gathers the workstreams beneath it. Because a product spans many Linear projects rather than mapping to one, its `linear` field is a label filter (e.g. `label:<product>`), not a single project URL — and it may be omitted entirely if the product has no dedicated label. (Single-project workstreams that map to one Linear project still use a project URL — see Project profiles.)

## Project profiles

    ---
    type: project
    status: active
    product: "[[Scanner]]"
    linear: https://linear.app/myorg/project/shield
    github: https://github.com/myorg/shield
    aliases:
      - shield-service
      - the shield
    people:
      - "[[Jane Smith]]"
      - "[[Bob Chen]]"
    last_updated: 2026-06-01
    ---
    # Shield
    ## Status
    - Active development, migrating from monolith to microservices
    - Blocked on [[Auth Service]] dependency
    ## Key Decisions
    - Use Rust for core service (2026-03)
    - GCS for storage, not Vertex (2026-04)
    ## People
    - [[Jane Smith]] — engineering lead
    - [[Bob Chen]] — infrastructure

Link fields and `status` live in frontmatter properties. `product` is a quoted-`[[wikilink]]` to the parent product, so the project↔product relationship is queryable from frontmatter (and a product's workstreams can be gathered by querying for it). `linear` and `github` are full URLs (a label filter is acceptable for `linear` on umbrella projects); `aliases` lists the project's name variants so links and search resolve. `people` is a quoted-`[[wikilink]]` list that mirrors the `## People` section, so the project↔person relationship is queryable from frontmatter.

Rules: preserve the link and status properties (never drop linear/github/status). Preserve the `people` relationship list and keep it in sync with the `[[Person]]` wikilinks in the `## People` section (quote each entry so it parses). `status` is one of active, blocked, paused, or archived. Use `[[Person Name]]` wikilinks in People, `[[Project Name]]` in Status.

**What counts as a project:** a durable product, service, or named workstream (like the `Shield` example above) — not a single feature, ticket, infra task, or one-off activity. Fold features, bug-fixes, infra tasks, and completed one-liners into the parent project's **Status** as bullets rather than creating a new file. Time-bound or phase-style efforts (a release hotfix, a single campaign phase) belong in the issue tracker, not here. Before creating a new project file, check the existing alias mappings — the work is usually a variant of an existing project. Aim for a small set of substantive profiles, not many stubs.

**Linking to Linear:** resolve a project's `**Linear**:` field to a real project URL (`https://linear.app/<workspace>/project/<slug>`, where `<workspace>` is the team's Linear workspace slug — discover it from the existing Linear URLs already in the KB or from chezmoi data, don't hard-code it here). Match the project name against Linear's project list. For umbrella projects that span many Linear projects, a label filter (e.g. `label:<product>`) is acceptable instead of a single URL. Never invent a URL — if no confident match exists, leave the field off and note it.

## Decisions

Decisions are anchored to the thing they're about. Record each decision in the relevant product's or project's `## Key Decisions` section, dated `YYYY-MM` or `YYYY-MM-DD`:

    ## Key Decisions
    - Use Rust for core service (2026-03)
    - GCS for storage, not Vertex (2026-04)

When a later decision supersedes an earlier one, keep only the latest. Genuinely cross-cutting org or process decisions — ones that don't belong to any single product or project (onboarding, standup cadence, team logistics, tooling and convention choices) — go in `decisions/cross-cutting.md`. The historical decision log lives in `decisions/archive.md` and is not actively maintained; treat it as a read-only record of past context, not a place to add new decisions.

## Journal

Daily coding activity per project, with diff stats:

    # 2026-05-22
    ## Shield
    - Fix auth token refresh race condition
    - Add integration tests for session middleware
    - *5 sessions, 12 files changed, +340/-120 lines*
    ## dotfiles
    - Update knowledge base skill
    - *2 sessions, 3 files changed, +87/-40 lines*

Coding-stats source: opencode's local session store (`~/.local/share/opencode/storage/session`) is pruned to roughly the last few months, so it cannot supply older session counts or diff stats — derive journal stats from git instead. Beware that `git log --all` double-counts pre-squash and merged copies of the same work and includes bot commits (e.g. `reg_actions`, `argocd-image-updater`); filter to the human author and dedupe so the stats stay honest.

## Name resolution

`names.json` maps display name variants to canonical names: `{"Joe": "Joseph Martinez", "J. Martinez": "Joseph Martinez"}`. Check before creating a new profile — the person may exist under a different name.

`projects.json` maps project name variants to canonical names: `{"the shield": "Shield", "shield-service": "Shield"}`. Empty string value means suppress (noise, not a real project). Update both files when encountering new name variants.

Each profile's `aliases` frontmatter property mirrors the variants from these maps for that canonical name, so links to `[[variant]]` resolve and the variants surface in search. Keep the JSON maps and the per-file `aliases` in sync: when adding a variant to a map, add it to the matching profile's `aliases` too.

## Enriching profiles

When you encounter new contact info (email, chat handle, GitHub handle, title, team) from any source — calendar attendees, chat messages, email headers, commit authors — update the person's profile.

## Searching
- Find a person: `cat ~/.local/share/kb/people/<slug>.md`
- Find a product: `cat ~/.local/share/kb/products/<slug>.md`
- Find a project: `cat ~/.local/share/kb/projects/<slug>.md`
- Find a decision: check the relevant product/project `## Key Decisions` first, then `cat ~/.local/share/kb/decisions/cross-cutting.md`; older context is in `decisions/archive.md`
- Search across KB: `grep -r "search term" ~/.local/share/kb/`
- Search journal: `grep -r "search term" ~/.local/share/kb/journal/`
- Find OpenSpec requirements for a repo: `cat ~/.local/share/kb/openspec/<repo-slug>/specs/<capability>/spec.md`
- Find the rationale behind a change: active/in-flight changes live in the worktree at `cat <repo>/openspec/changes/<name>/design.md`; archived (dated) changes live in the store at `cat ~/.local/share/kb/openspec/<repo-slug>/changes/archive/<date>-<name>/design.md`
- Search across all durable specs/changes: `grep -r "search term" ~/.local/share/kb/openspec/`
