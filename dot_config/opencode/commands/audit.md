---
description: Audit the agent system — load rates, capability layer health, frontmatter, content, primitive fit
subtask: true
---

# Agent System Audit

Five-phase audit of the agent skills + capabilities + commands system in this dotfiles repo. Run quarterly or after a structural change. Each phase produces evidence; the synthesis at the end recommends specific actions.

$ARGUMENTS

---

## Phase 1 — Data gathering

Pull actual usage from the OpenCode session DB and compare against intent.

### 1a. Window selection

Default 30 days. If the user named a different window, use it.

```bash
WINDOW_DAYS=30
DB=~/.local/share/opencode/opencode.db
```

### 1b. Sessions by project

Skill loads need to be normalized by project — a "low" load rate over all sessions can be high within the relevant project.

```bash
sqlite3 -readonly "$DB" <<SQL
SELECT p.name, p.worktree, COUNT(*) AS sessions
FROM session s LEFT JOIN project p ON p.id = s.project_id
WHERE s.time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY s.project_id ORDER BY sessions DESC;
SQL
```

### 1c. Skill load rates per project

For each project that matters, look at load count and distinct sessions:

```bash
PROJECT_ID="<id from 1b>"
sqlite3 -readonly "$DB" <<SQL
SELECT json_extract(p.data,'\$.state.input.name') AS skill,
       COUNT(*) AS loads,
       COUNT(DISTINCT p.session_id) AS sessions
FROM part p JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data,'\$.tool')='skill'
  AND json_extract(p.data,'\$.state.status')='completed'
  AND s.project_id='$PROJECT_ID'
  AND p.time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY skill ORDER BY loads DESC;
SQL
```

### 1d. Subagent invocations

```bash
sqlite3 -readonly "$DB" <<SQL
SELECT json_extract(data,'\$.state.input.subagent_type') AS agent,
       COUNT(*) AS invocations
FROM part WHERE json_extract(data,'\$.tool')='task'
  AND json_extract(data,'\$.state.status')='completed'
  AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY agent ORDER BY invocations DESC;
SQL
```

### 1e. Workflow co-occurrence

For each pair of skills that should fire together (commit + tdd, plan + architecture, etc.), check the gap. Example:

```bash
sqlite3 -readonly "$DB" <<SQL
WITH project AS (SELECT id FROM session WHERE project_id='$PROJECT_ID' AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)),
     loaded AS (SELECT session_id, json_extract(data,'\$.state.input.name') AS skill
                FROM part WHERE json_extract(data,'\$.tool')='skill'
                  AND json_extract(data,'\$.state.status')='completed'
                  AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000))
SELECT
  SUM(CASE WHEN c.session_id IS NOT NULL AND t.session_id IS NULL THEN 1 ELSE 0 END) AS commit_no_tdd,
  SUM(CASE WHEN c.session_id IS NOT NULL AND t.session_id IS NOT NULL THEN 1 ELSE 0 END) AS commit_and_tdd
FROM project pr
LEFT JOIN (SELECT DISTINCT session_id FROM loaded WHERE skill='commit') c ON c.session_id=pr.id
LEFT JOIN (SELECT DISTINCT session_id FROM loaded WHERE skill='tdd') t ON t.session_id=pr.id;
SQL
```

When tdd is no longer a skill, replace the t.session_id check with a manual sample of "did the session involve tests" — see Phase 5.

### 1f. Delegation effectiveness

The "always delegate the work itself" rule from AGENTS.md is binary: any session where the primary agent edited files without dispatching at least one `task` call is a violation. These three queries surface the violation rate, the volume bucket where it concentrates, and the projects where the habit is weakest.

**Headline metric — sessions with edits but zero `task` calls:**

```bash
sqlite3 -readonly "$DB" <<SQL
WITH base AS (
  SELECT id FROM session
  WHERE time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
    AND parent_id IS NULL
),
edits AS (SELECT session_id, COUNT(*) AS n FROM part WHERE json_extract(data,'\$.tool') IN ('edit','write') GROUP BY session_id),
tasks AS (SELECT session_id, COUNT(*) AS n FROM part WHERE json_extract(data,'\$.tool')='task' GROUP BY session_id)
SELECT
  COUNT(*) FILTER (WHERE COALESCE(e.n,0) > 0) AS sessions_with_edits,
  SUM(CASE WHEN COALESCE(e.n,0)>0 AND COALESCE(t.n,0)=0 THEN 1 ELSE 0 END) AS violations,
  ROUND(100.0 * SUM(CASE WHEN COALESCE(e.n,0)>0 AND COALESCE(t.n,0)=0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*) FILTER (WHERE COALESCE(e.n,0)>0),0), 1) AS pct_violations
FROM base b
LEFT JOIN edits e ON e.session_id=b.id
LEFT JOIN tasks t ON t.session_id=b.id;
SQL
```

**Delegation rate by edit-volume bucket** — shows where the habit is weakest. Under "always delegate" every "no_delegation" cell is a violation; the buckets just tell you whether the rule is breaking on small jobs, large jobs, or everywhere.

```bash
sqlite3 -readonly "$DB" <<SQL
WITH base AS (
  SELECT id FROM session
  WHERE time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
    AND parent_id IS NULL
),
edits AS (SELECT session_id, COUNT(*) AS n FROM part WHERE json_extract(data,'\$.tool') IN ('edit','write') GROUP BY session_id),
tasks AS (SELECT session_id, COUNT(*) AS n FROM part WHERE json_extract(data,'\$.tool')='task' GROUP BY session_id)
SELECT
  CASE
    WHEN COALESCE(e.n,0)=0 THEN '0 edits'
    WHEN e.n BETWEEN 1 AND 2 THEN '1-2 edits'
    WHEN e.n BETWEEN 3 AND 9 THEN '3-9 edits'
    WHEN e.n BETWEEN 10 AND 29 THEN '10-29 edits'
    ELSE '30+ edits'
  END AS bucket,
  COUNT(*) AS sessions,
  SUM(CASE WHEN COALESCE(t.n,0)>0 THEN 1 ELSE 0 END) AS delegated,
  SUM(CASE WHEN COALESCE(t.n,0)=0 THEN 1 ELSE 0 END) AS no_delegation,
  ROUND(100.0 * SUM(CASE WHEN COALESCE(t.n,0)>0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_delegated
FROM base b
LEFT JOIN edits e ON e.session_id=b.id
LEFT JOIN tasks t ON t.session_id=b.id
GROUP BY bucket
ORDER BY bucket;
SQL
```

**Per-project delegation rate** for sessions with at least one edit — surfaces which repos have become habit black holes:

```bash
sqlite3 -readonly "$DB" <<SQL
WITH base AS (
  SELECT s.id, p.name AS project
  FROM session s LEFT JOIN project p ON p.id = s.project_id
  WHERE s.time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
    AND s.parent_id IS NULL
),
edits AS (SELECT session_id, COUNT(*) AS n FROM part WHERE json_extract(data,'\$.tool') IN ('edit','write') GROUP BY session_id),
tasks AS (SELECT session_id, COUNT(*) AS n FROM part WHERE json_extract(data,'\$.tool')='task' GROUP BY session_id)
SELECT
  COALESCE(NULLIF(b.project,''), '(no project)') AS project,
  COUNT(*) AS sessions_with_edits,
  SUM(CASE WHEN COALESCE(t.n,0)>0 THEN 1 ELSE 0 END) AS delegated,
  ROUND(100.0 * SUM(CASE WHEN COALESCE(t.n,0)>0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_delegated
FROM base b
JOIN edits e ON e.session_id=b.id AND e.n > 0
LEFT JOIN tasks t ON t.session_id=b.id
GROUP BY project
HAVING sessions_with_edits >= 3
ORDER BY pct_delegated ASC;
SQL
```

Sort ascending so the worst-offending projects float to the top.

---

## Phase 2 — Capability layer health

Validate the manifest and frontmatter consistency.

### 2a. Find dangling capabilities

For every `requires:` entry across all skills, confirm a provider exists (skill `provides`, `cli://` mapping, or `mcp://`).

```bash
# Collect all requires
for f in skills/*/SKILL.md; do
  python3 -c "
import yaml
content = open('$f').read()
if not content.startswith('---'): exit()
parts = content.split('---', 2)
fm = yaml.safe_load(parts[1])
md = fm.get('metadata', {}) or {}
for r in md.get('requires', []) or []:
    print(r)
"
done | sort -u > /tmp/required.txt

# Collect all provides + manifest entries
for f in skills/*/SKILL.md; do
  python3 -c "
import yaml
content = open('$f').read()
parts = content.split('---', 2)
fm = yaml.safe_load(parts[1])
md = fm.get('metadata', {}) or {}
for p in md.get('provides', []) or []:
    print(p)
"
done > /tmp/provided.txt
python3 -c "
import yaml
m = yaml.safe_load(open('skills/capabilities.yaml'))
for k in m: print(k)
" >> /tmp/provided.txt

# Anything required but not provided
comm -23 <(sort -u /tmp/required.txt) <(sort -u /tmp/provided.txt)
```

### 2b. Find orphan providers

Skills that `provides` something nothing else `requires`. Often legitimate (workflow-only skills shouldn't `provides`) but worth flagging.

```bash
comm -23 <(sort -u /tmp/provided.txt) <(sort -u /tmp/required.txt)
```

### 2c. External skills installed?

```bash
# Confirm packages.yaml's skills: list is actually deployed
yq -r '.packages.skills[].skill' .chezmoidata/packages.yaml | while read skill; do
  if [ -d "$HOME/.agents/skills/$skill" ]; then
    echo "OK $skill"
  else
    echo "MISSING $skill"
  fi
done
```

### 2d. Opencode permissions audit

Inspect `dot_config/opencode/opencode.json.tmpl` and the rendered config:

```bash
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl | jq '.agent.plan.permission.bash'
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl | jq '.permission.bash'
```

Flag both directions of permission drift:

**Too permissive** (allow that should be ask, ask that should be deny):

- A write/mutate command (`create`, `update`, `delete`, `push`, `apply`, `commit`, `merge`, `destroy`, `complete`, `add`, `edit`, `reply`, `append`) glob-matched to `allow` in the build-mode bash dict. Extract and scan:

```bash
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl \
  | jq -r '.permission.bash | to_entries[] | select(.value=="allow") | .key' \
  | grep -E '(create|update|delete|push|apply|commit|merge|destroy|complete|add|edit|reply|append)'
```

- A pattern in plan mode that's `allow` but routes to a binary that can mutate via certain flags or subcommands (e.g. allowing `foo*` when only `foo view*` is read-only). Apply judgment to the plan allow list.
- Read globs broader than necessary (`*` instead of `subcmd*`).

**Too restrictive** (ask that should be allow, missing — causes friction):

- Commands declared `allow_reads` in `packages.yaml` that aren't in the rendered plan dict:

```bash
# Extract declared allow_reads
yq -r '.packages[][] | select(type == "!!map") | .permissions.allow_reads // [] | .[]' \
  .chezmoidata/packages.yaml 2>/dev/null | sort -u > /tmp/declared_reads.txt

# Extract plan-mode allows
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl \
  | jq -r '.agent.plan.permission.bash | to_entries[] | select(.value=="allow") | .key' \
  | sort -u > /tmp/plan_allows.txt

# Missing from plan
comm -23 /tmp/declared_reads.txt /tmp/plan_allows.txt
```

- Tools in `mise`, `github_releases`, or npm sections of `packages.yaml` with no `permissions:` block (fall through to `*: ask`):

```bash
yq -r '.packages | (.mise // []) + (.github_releases // []) + (.npm // []) | .[] | select(type == "!!map") | select(.permissions == null) | .name // .repo' \
  .chezmoidata/packages.yaml
```

- Remember opencode evaluates pipeline segments independently — `linear issue view X | head -N` prompts on `head` even if `linear issue view*` is allowed. Check that common output-filter commands (`head`, `tail`, `grep`, `wc`, `sort`, `uniq`, `comm`) are in the plan allow list.

For each finding: tighten to `ask`, broaden to `allow`, add missing `permissions:` block in `packages.yaml`, or remove as redundant with `*`.

---

### 2e. Walk the integration-skill provider preference

For each local integration skill (`provides:` with a tool-shaped capability like `chat`, `source-control`), check if an upstream skill now exists. The watchlist in `skills/AGENTS.md` is the starting point.

---

## Phase 3 — Frontmatter audit

```bash
# agentskills validates spec compliance
agentskills validate skills/  # may be agentskills validate <each-dir>
```

Plus this repo's conventions:

- **Workflow skills** without `provides:` are correctly omitted (per `skills/AGENTS.md`'s no-provides convention) — but a workflow skill *that other skills `require`* must declare `provides`.
- **Integration skills** must declare `provides:` naming the domain capability (`chat`, not `slack`).
- **Description must be a concrete trigger**, not a topic. "Strict TDD loop" is a topic; "Load before any source-code edit. Applies to new features, bug fixes, refactors, and review-driven fixes" is a trigger.
- **No machine-specific config** in skill bodies (template names, project keys, channel names, internal URLs) — public-repo rule.

---

## Phase 4 — Content audit

The original instruction-hierarchy/redundancy/context-budget checks. These still matter alongside the data work above.

### Instruction hierarchy

```
Base system prompt (opencode upstream)  → built-in
  + AGENTS.md (global)                  → always loaded
  + instructions: files                 → always loaded (e.g. tdd.md)
  + opencode.json                       → agent config (models, permissions)
  + skills/*/SKILL.md                   → on-demand via skill tool
  + commands/*.md                       → on /command invocation
```

### Where to put things

| Content type | Location | When loaded |
|---|---|---|
| Universal rules, tone, scope discipline | `dot_config/opencode/AGENTS.md.tmpl` | Always |
| Standing rules (continuous trigger) | `dot_config/opencode/<name>.md` + `instructions:` | Always |
| Agent config (model, permissions, temperature) | `dot_config/opencode/opencode.json.tmpl` | Always |
| Specific-moment workflow (concrete trigger) | `skills/<name>/SKILL.md` | On `skill` tool call |
| User-triggered workflow | `dot_config/opencode/commands/<name>.md` | On `/command` |

### Context budget

```bash
wc -l ~/.config/opencode/AGENTS.md ~/.config/opencode/*.md
```

AGENTS.md + every `instructions:` file gets loaded every session. Aim to keep the always-loaded total tight (<400 lines). If it grows, ask whether something should become a skill (concrete-moment trigger) or be deleted.

### Redundancy

- AGENTS.md and `instructions:` files shouldn't repeat each other.
- Skills shouldn't duplicate AGENTS.md.
- Skill content shouldn't restate `--help` for its capability.

---

## Phase 5 — Findings synthesis

Walk the data with the principles from `skills/AGENTS.md`. For each finding, recommend a concrete action.

### What loaded as expected

Skills with high project-normalized load rate that hit their right moments. Leave these alone.

### What didn't load when it should have

Sessions where a skill *should* have fired (per its description) but didn't. Three causes:

1. **Description doesn't match the moment.** Fix the description.
2. **Right primitive is wrong.** Continuous trigger → instructions file. Mode-restricted → agent permissions. (See `skills/AGENTS.md` "When something shouldn't be a skill".)
3. **Skill doesn't earn its keep.** Delete or merge with a related skill.

### What's drifted

- Capabilities required but not provided.
- External skills declared in `packages.yaml` but not installed.
- Source skills modified but not deployed (`chezmoi apply` would fix).
- Local integration skills where an upstream skill now exists (consult the watchlist in `skills/AGENTS.md`).
- Sessions with edits but no `task` calls — direct violation of the "always delegate" rule. Phase 1f's per-project rate surfaces the habit hotspots.

### Recommendations

For each issue, pick one:

| Symptom | Action |
|---|---|
| Rule ignored despite being in AGENTS.md | Move up, simplify, or remove |
| Skill never loads, moment clearly happens | Description tweak, or relocate to instructions |
| Skill orchestrates other skills | Split per skill-shape rules |
| Skill loads but the work doesn't get better | Measure quality, then redesign or delete |
| Local integration when upstream skill exists | Switch to external skill via `gh skill install` |
| AGENTS.md > 400 lines | Move continuous-trigger content to `instructions:` |
| Capability dangling | Wire to a provider, or remove the requirement |
| Sessions with edits but zero `task` calls | Violation of "always delegate". Tighten AGENTS.md delegation language; if the rate doesn't drop after the next quarter, escalate to a hook that warns on the first non-delegated edit. |

Pre-existing changes from prior audits should be re-checked: the principle "measure before refactoring" applies to every audit, not just the first.

---

## Cadence

Run `/audit` quarterly. Also run after:

- Major skill additions or removals
- A new agent type appearing (e.g. opencode adds a built-in agent)
- A noticeable shift in project mix (different repo dominating sessions)
- A felt sense that "something isn't firing" — measure first
- AGENTS.md delegation rules change — re-run Phase 1f to verify the violation rate drops

## File locations (chezmoi)

| Target | Source |
|---|---|
| `~/.config/opencode/AGENTS.md` | `dot_config/opencode/AGENTS.md.tmpl` |
| `~/.config/opencode/opencode.json` | `dot_config/opencode/opencode.json.tmpl` |
| `~/.config/opencode/tdd.md` (and other instructions: files) | `dot_config/opencode/<name>.md` |
| `~/.agents/skills/*` | `skills/*` (via `run_onchange_after_sync-and-validate-skills.sh.tmpl`) |
| `~/.config/opencode/commands/*` | `dot_config/opencode/commands/*` |

After changes: apply via your `machine-config` capability.
