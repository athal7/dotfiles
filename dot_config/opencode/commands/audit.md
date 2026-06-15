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
# Top-level bash policy (default-allow + guardrails; inherited by lead/plan)
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl | jq '.permission'

# Rendered agent permissions (agent-level overrides; bash for build)
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl | jq '.agent | to_entries[] | {key, permissions: .value.permission}'

# Skill injection mappings
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl | jq '.plugin[0][1]'

# Per-agent model + effort variant — verify expected models; cross-check vs empty-turn query (catch access-gated models)
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl | jq '.agent | to_entries[] | {agent: .key, model: .value.model, variant: .value.variant}'
```

**Cost & context health** — the system's spend profile. Lead is typically the largest cost (always-on primary carrying full context); build is the largest *editing* agent. Watch for context bloat, speed regressions, and silently-broken models:

```bash
# Per-agent cost & avg context — which agent dominates spend?
sqlite3 -readonly "$DB" <<SQL
SELECT json_extract(data,'$.agent') AS agent,
       ROUND(SUM(json_extract(data,'$.cost')),0) AS cost_usd,
       COUNT(*) AS msgs,
       ROUND(AVG(json_extract(data,'$.tokens.cache.read'))) AS avg_ctx_tok
FROM message
WHERE json_extract(data,'$.role')='assistant'
  AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY agent ORDER BY cost_usd DESC;
SQL

# Cost decomposition for top agents — is spend cache/context-bound vs output?
sqlite3 -readonly "$DB" <<SQL
SELECT json_extract(data,'$.agent') AS agent,
       ROUND(SUM(json_extract(data,'$.tokens.cache.write'))/1e6,1) AS cache_w_Mtok,
       ROUND(SUM(json_extract(data,'$.tokens.cache.read'))/1e6,1) AS cache_r_Mtok,
       ROUND(SUM(json_extract(data,'$.tokens.output'))/1e6,1) AS out_Mtok
FROM message
WHERE json_extract(data,'$.role')='assistant'
  AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY agent ORDER BY cache_r_Mtok DESC LIMIT 5;
SQL

# Lead daily cost & context trend — are prune + delegation keeping context lean?
sqlite3 -readonly "$DB" <<SQL
SELECT date(time_created/1000,'unixepoch','localtime') AS day,
       ROUND(SUM(json_extract(data,'$.cost')),0) AS lead_cost,
       ROUND(AVG(json_extract(data,'$.tokens.cache.read'))) AS avg_ctx_tok
FROM message
WHERE json_extract(data,'$.role')='assistant' AND json_extract(data,'$.agent')='lead'
  AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY day ORDER BY day DESC;
SQL

# Per-agent/model latency & output — speed regressions (build is tuned for speed)
sqlite3 -readonly "$DB" <<SQL
SELECT json_extract(data,'$.agent') AS agent, json_extract(data,'$.modelID') AS model,
       COUNT(*) AS msgs,
       ROUND(AVG((json_extract(data,'$.time.completed')-json_extract(data,'$.time.created'))/1000.0),1) AS avg_lat_s,
       ROUND(AVG(json_extract(data,'$.tokens.output'))) AS avg_out_tok
FROM message
WHERE json_extract(data,'$.role')='assistant'
  AND json_extract(data,'$.time.completed') IS NOT NULL
  AND json_extract(data,'$.tokens.output') > 0
  AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY agent, model HAVING msgs > 50 ORDER BY agent, model;
SQL

# Empty-turn RATE per agent+model — a model that's ~100% empty is broken or access-gated
# (e.g. retention-gated). Normal tool-heavy agents have a moderate baseline; watch for >30%.
sqlite3 -readonly "$DB" <<SQL
SELECT json_extract(data,'$.agent') AS agent, json_extract(data,'$.modelID') AS model,
       SUM(CASE WHEN COALESCE(json_extract(data,'$.cost'),0)=0
                  AND COALESCE(json_extract(data,'$.tokens.output'),0)=0
                THEN 1 ELSE 0 END) AS empty_turns,
       COUNT(*) AS total_turns,
       ROUND(100.0*SUM(CASE WHEN COALESCE(json_extract(data,'$.cost'),0)=0
                  AND COALESCE(json_extract(data,'$.tokens.output'),0)=0
                THEN 1 ELSE 0 END)/COUNT(*),1) AS empty_pct
FROM message
WHERE json_extract(data,'$.role')='assistant'
  AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY agent, model HAVING total_turns > 20 AND empty_pct > 30 ORDER BY empty_pct DESC;
SQL
```

**Semantic-dedup effectiveness** — does the `dedup` injection actually drive `plan`/`reviewer` to run `ck`? Measures the `semantic-dedup-skill` spec. Guidance-not-enforcement, so low invocation despite injection is the signal to escalate (see recommendation row):

```bash
# (a) Did plan/reviewer sessions invoke ck? (bash parts whose command runs ck --sem)
sqlite3 -readonly "$DB" <<SQL
SELECT s.agent,
       COUNT(*) AS ck_calls,
       COUNT(DISTINCT p.session_id) AS sessions_with_ck
FROM part p JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data,'$.type') = 'tool'
  AND json_extract(p.data,'$.tool') = 'bash'
  AND json_extract(p.data,'$.state.input.command') LIKE '%ck %--sem%'
  AND s.agent IN ('plan','reviewer')
  AND p.time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY s.agent ORDER BY s.agent;
SQL

# (b) Skill-load rate for dedup + its gateway skills, by agent.
# The "Skill load rates by agent" query above already covers this — filter its
# output to skill IN ('dedup','architecture','code-quality') and agent IN
# ('plan','reviewer'). Compare gateway loads (architecture/code-quality) vs.
# dedup loads: dedup loads should track gateway loads if the footer is followed.

# (c) Review-flagged-dup proxy — reviewer findings naming an existing symbol +
# file:line as a duplicate. No structured marker yet, so spot-check: list recent
# reviewer sessions that ran ck and inspect whether a dup was flagged.
sqlite3 -readonly "$DB" <<SQL
SELECT DISTINCT p.session_id,
       date(p.time_created/1000,'unixepoch','localtime') AS day
FROM part p JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data,'$.tool') = 'bash'
  AND json_extract(p.data,'$.state.input.command') LIKE '%ck %--sem%'
  AND s.agent = 'reviewer'
  AND p.time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
ORDER BY day DESC;
SQL
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
| Primary/lead cost dominated by cache (>80%) | Delegate token-heavy reads to subagents; `compaction.prune` | Effort tuning alone (output is only ~10% of lead cost) |
| Optimizing without per-agent cost data | Measure per-agent cost first (cost-health queries above) | Assuming which agent is expensive |
| Agent emits empty/zero-cost turns | Verify the model is available, not access/retention-gated | Leaving a silently-broken model configured |
| `plan`/`reviewer` rarely run `ck` despite the dedup injection | Embed the dedup pointer directly in the agent prompt, or move to a structural results hook that injects matches | More advisory skill injection |

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
