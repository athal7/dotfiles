---
description: Audit the agent system against workflow specs and measured data
subtask: true
---

# Spec Compliance Audit

Measure the agent system against the workflow specs in `openspec/specs/`. The specs are the source of truth — when they change, this audit automatically covers the new requirements.

$ARGUMENTS

**Scoping:** When arguments name a specific spec or topic, audit only that. A bare `/audit` runs all specs.

---

## Step 1 — Read the specs

Read every `spec.md` in `openspec/specs/*/`. List each requirement and scenario. These are what you're measuring against.

If no specs exist, fall back to the legacy audit (skill load rates, delegation effectiveness, capability layer health).

## Step 2 — Set the measurement window

```bash
WINDOW_DAYS=30
DB=~/.local/share/opencode/opencode.db
```

## Step 3 — Gather evidence per spec

For each spec, gather evidence from the session DB and config. Organize findings by spec, not by data source.

### Evidence sources

**Session DB queries** — adapt these to the specific requirements you're measuring:

```bash
# Workflow command usage
sqlite3 -readonly "$DB" <<SQL
SELECT json_extract(p.data,'$.state.input.command') AS command, COUNT(*) AS uses
FROM part p
WHERE json_extract(p.data,'$.type') = 'tool'
  AND json_extract(p.data,'$.tool') = 'command'
  AND p.time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY command ORDER BY uses DESC;
SQL

# Skill load rates by agent
sqlite3 -readonly "$DB" <<SQL
SELECT s.agent, json_extract(p.data,'$.state.input.name') AS skill,
       COUNT(*) AS loads, COUNT(DISTINCT p.session_id) AS sessions
FROM part p JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data,'$.tool')='skill'
  AND json_extract(p.data,'$.state.status')='completed'
  AND p.time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY s.agent, skill ORDER BY s.agent, loads DESC;
SQL

# Delegation rate (lead edits = topology violation)
sqlite3 -readonly "$DB" <<SQL
WITH base AS (
  SELECT id FROM session
  WHERE time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
    AND parent_id IS NULL
),
edits AS (SELECT session_id, COUNT(*) AS n FROM part WHERE json_extract(data,'$.tool') IN ('edit','write') GROUP BY session_id),
tasks AS (SELECT session_id, COUNT(*) AS n FROM part WHERE json_extract(data,'$.tool')='task' GROUP BY session_id)
SELECT
  COUNT(*) FILTER (WHERE COALESCE(e.n,0) > 0) AS sessions_with_edits,
  SUM(CASE WHEN COALESCE(e.n,0)>0 AND COALESCE(t.n,0)=0 THEN 1 ELSE 0 END) AS violations,
  ROUND(100.0 * SUM(CASE WHEN COALESCE(e.n,0)>0 AND COALESCE(t.n,0)=0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*) FILTER (WHERE COALESCE(e.n,0)>0),0), 1) AS pct_violations
FROM base b
LEFT JOIN edits e ON e.session_id=b.id
LEFT JOIN tasks t ON t.session_id=b.id;
SQL

# Permission denials (friction vs enforcement)
sqlite3 -readonly "$DB" <<SQL
SELECT json_extract(data, '$.tool') AS tool,
       SUBSTR(json_extract(data, '$.state.input.command'), 1, 80) AS command,
       COUNT(*) AS denials
FROM part
WHERE json_extract(data, '$.type') = 'tool'
  AND json_extract(data, '$.state.error') LIKE '%permission%'
  AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY tool, command ORDER BY denials DESC LIMIT 20;
SQL

# Interrupt rate by agent
sqlite3 -readonly "$DB" <<SQL
WITH interrupts AS (
  SELECT m.id, json_extract(m.data, '$.agent') AS agent
  FROM message m
  WHERE json_extract(m.data, '$.role') = 'assistant'
    AND json_extract(m.data, '$.finish') IS NULL
    AND json_extract(m.data, '$.time.created') > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
    AND EXISTS (
      SELECT 1 FROM part p
      WHERE p.message_id = m.id AND json_extract(p.data, '$.type') = 'step-start'
        AND NOT EXISTS (SELECT 1 FROM part p2 WHERE p2.message_id = m.id AND json_extract(p2.data, '$.type') = 'step-finish')
    )
),
totals AS (
  SELECT json_extract(m.data, '$.agent') AS agent, COUNT(*) AS total
  FROM message m WHERE json_extract(m.data, '$.role') = 'assistant'
    AND json_extract(m.data, '$.time.created') > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
  GROUP BY agent
)
SELECT COALESCE(i.agent, '(unknown)') AS agent, COUNT(*) AS interrupts,
       t.total AS msgs, ROUND(100.0 * COUNT(*) / NULLIF(t.total, 0), 1) AS pct
FROM interrupts i LEFT JOIN totals t ON COALESCE(i.agent,'') = COALESCE(t.agent,'')
GROUP BY i.agent ORDER BY pct DESC;
SQL
```

**Config checks:**

```bash
# Rendered agent permissions
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl | jq '.agent | to_entries[] | {key, permissions: .value.permission}'

# Skill injection mappings
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl | jq '.plugin[0][1]'
```

**Manual spot-checks** — for requirements that can't be automated, sample 3-5 recent sessions and inspect:
- Were review passes run in order? (code-review R1)
- Were findings verified against the diff? (code-review R2)
- Did triage happen before code fixes? (merge-request R1)
- Was full content shown before remote writes? (remote-operations R3)

## Step 4 — Report

For each spec, report:

| Requirement | Status | Evidence |
|---|---|---|
| R1: ... | ✅ Compliant / ⚠️ Partial / ❌ Non-compliant | What you found |

Flag requirements that can't be measured and explain why.

## Step 5 — Recommendations

For each non-compliant requirement, recommend one action. Reference prior-attempts history at `openspec/changes/agent-rearchitecture/prior-attempts.md` to avoid repeating approaches that have failed.

| Symptom | Proven approach | Don't repeat |
|---|---|---|
| Behavior skipped despite instructions | Structural enforcement (permissions, tool removal) | Advisory prompt changes |
| Skill never loads | Embed in command template or agent prompt | More skill injection |
| Agent edits directly | Verify permission deny is in config | Identity framing |

---

## File locations

| Target | Source |
|---|---|
| `openspec/specs/*/spec.md` | Desired state — audit measures against these |
| `~/.local/share/opencode/opencode.db` | Session data for compliance measurement |
| `~/.config/opencode/opencode.json` | `dot_config/opencode/opencode.json.tmpl` |
| `~/.config/opencode/prompts/*.md` | `dot_config/opencode/prompts/*.md` |
| `~/.config/opencode/commands/*.md` | `dot_config/opencode/commands/*.md` |
| `~/.agents/skills/*` | `skills/*` |

Run `/audit` quarterly or after structural changes.
