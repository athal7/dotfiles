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

**Cost & context health** — the system's spend profile. Lead is typically the largest cost (always-on primary carrying full context); build is the largest *editing* agent. Watch for context bloat, speed regressions, and silently-broken models.

**Token-efficiency baseline (DCP + snip):** the headline metric for the token-efficiency plugins is the `lead` `avg_ctx_tok` from the queries below — the per-turn average context, which is robust across windows. `cache_r_Mtok` is a window-SUM (it scales with how much work happened that month, so a quiet month shows a fake "reduction"); treat it as **directional / decomposition support only**, not the target metric. The recorded pre-adoption baseline (before DCP/snip were wired) is **`lead` 30-day: avg_ctx_tok ≈ 159,707 (cache_r ≈ 4,582 Mtok); all-time: avg_ctx_tok ≈ 158,979 (cache_r ≈ 4,917 Mtok)**. Target: **≥15% reduction in `lead` `avg_ctx_tok`** vs that baseline (a ratcheting floor — it only moves down); use `cache_r_Mtok` only to sanity-check the direction, not to grade the target. No new SQL: reuse the per-agent `avg_ctx_tok`, the `cache_r_Mtok` decomposition, and the `lead` daily trend below. If the reduction is not measured, follow the Step-5 wiring-verification row before adding another plugin.

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

**Local-model adoption (Claude displacement):** the headline metric is **local turn-share** — the % of assistant turns served by a non-Anthropic provider (`lmstudio`/`ollama`/`mlx`/etc.), which **ratchets UP** as work is displaced off Claude (the opposite direction from the DCP floor). Because every local/non-Anthropic provider records `cost = 0` in the DB, dollar savings cannot be read directly — it is **ESTIMATED** (an agent's local turns × that agent's historical avg Anthropic $/turn) and treated as **directional only**, exactly like `cache_r_Mtok`. Key the metric on `providerID`, NOT on agent name: the `title` agent's turns are not stored under `agent='title'`, so an agent-name filter would miss them. **Baseline (recorded 2026-06-18):** local turn-share = 0.1%; as of commit `fa89b03` the `title` agent runs on `lmstudio/qwen3-30b-a3b-instruct-2507` (first deliberate production displacement; prior local turns were ad-hoc experiments). **Target:** local turn-share expands run-over-run WITHOUT a rise in local empty-turn rate or interactive-latency regressions (an empty or timed-out local turn is *fake* displacement, not savings — cross-check the empty-turn and latency queries above, scanning rows where `providerID != 'anthropic'`). Expansion path: `title` (done) → kb-summarization pipeline (next) → low-stakes `explore`/`scout` (gated). Never move `build`/`reviewer`/`plan`/`lead`.

```bash
# (a) Local vs Anthropic turn-share by provider/model/agent — WHERE is work displaced?
sqlite3 -readonly "$DB" <<SQL
SELECT CASE WHEN json_extract(data,'$.providerID')='anthropic' THEN 'anthropic' ELSE 'local' END AS class,
       json_extract(data,'$.providerID') AS provider,
       json_extract(data,'$.modelID') AS model,
       json_extract(data,'$.agent') AS agent,
       COUNT(*) AS turns
FROM message
WHERE json_extract(data,'$.role')='assistant'
  AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY class, provider, model, agent ORDER BY turns DESC;
SQL

# (b) Headline: overall local turn-share (the ratcheting-UP number)
sqlite3 -readonly "$DB" <<SQL
SELECT ROUND(100.0*SUM(CASE WHEN json_extract(data,'$.providerID')!='anthropic' THEN 1 ELSE 0 END)/COUNT(*),1) AS local_turn_pct,
       SUM(CASE WHEN json_extract(data,'$.providerID')!='anthropic' THEN 1 ELSE 0 END) AS local_turns,
       COUNT(*) AS total_turns
FROM message
WHERE json_extract(data,'$.role')='assistant'
  AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000);
SQL

# (c) Estimated Claude $ avoided (DIRECTIONAL — local cost=0, so estimate from each
# agent's historical Anthropic $/turn). Agents that run ONLY on local have no
# Anthropic baseline -> est shows 0/null; for title (not attributed to agent='title')
# use the haiku $/turn as the reference manually.
sqlite3 -readonly "$DB" <<SQL
WITH anthro AS (
  SELECT json_extract(data,'$.agent') AS agent, AVG(json_extract(data,'$.cost')) AS avg_cost
  FROM message
  WHERE json_extract(data,'$.role')='assistant' AND json_extract(data,'$.providerID')='anthropic'
    AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
  GROUP BY agent
),
local AS (
  SELECT json_extract(data,'$.agent') AS agent, COUNT(*) AS local_turns
  FROM message
  WHERE json_extract(data,'$.role')='assistant' AND json_extract(data,'$.providerID')!='anthropic'
    AND time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
  GROUP BY agent
)
SELECT l.agent, l.local_turns, ROUND(a.avg_cost,4) AS anthro_avg_cost,
       ROUND(l.local_turns*COALESCE(a.avg_cost,0),2) AS est_usd_avoided
FROM local l LEFT JOIN anthro a ON a.agent=l.agent
ORDER BY est_usd_avoided DESC;
SQL
```

**Semantic-search adoption** — measures the `semantic-code-search` spec. Are agents actually invoking the resident `ck` MCP server? The headline metric is `explore`'s advisory `ck_semantic_search` rate (prompt-driven, not enforced) plus the dedup use by `plan`/`reviewer` (injection-context-driven) and `build` (prompt-driven, via the build.md before-writing dedup directive). MCP tool-call parts are stored with opencode's `<server>_<tool>` underscore namespacing, so the ck tools are `ck_semantic_search` and `ck_reindex` (confirmed against the live DB `part.data.tool`). Low invocation despite the prompt/injection being wired is the signal to escalate (see recommendation row):

```bash
# (a) semantic_search adoption by agent — % of explore/plan/reviewer/build sessions invoking it.
# Denominator = all sessions per agent in-window; numerator = those with >=1 ck_semantic_search.
sqlite3 -readonly "$DB" <<SQL
WITH sem AS (
  SELECT DISTINCT session_id FROM part
  WHERE json_extract(data,'$.type') = 'tool'
    AND json_extract(data,'$.tool') = 'ck_semantic_search'
)
SELECT s.agent,
       COUNT(*) AS total_sessions,
       SUM(CASE WHEN sem.session_id IS NOT NULL THEN 1 ELSE 0 END) AS sessions_with_semantic,
       ROUND(100.0*SUM(CASE WHEN sem.session_id IS NOT NULL THEN 1 ELSE 0 END)/COUNT(*),1) AS semantic_pct
FROM session s LEFT JOIN sem ON sem.session_id = s.id
WHERE s.agent IN ('explore','plan','reviewer','build')
  AND s.time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY s.agent ORDER BY s.agent;
SQL

# (b) reindex counts by agent — is the reindex-before-first-query guidance followed?
sqlite3 -readonly "$DB" <<SQL
SELECT s.agent,
       COUNT(*) AS reindex_calls,
       COUNT(DISTINCT p.session_id) AS sessions_with_reindex
FROM part p JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data,'$.type') = 'tool'
  AND json_extract(p.data,'$.tool') = 'ck_reindex'
  AND p.time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
GROUP BY s.agent ORDER BY s.agent;
SQL

# (c) ck injection-context delivery — confirm the dedup reason-to-use is wired
# under both gateways the dedup-using agents load (architecture→plan,
# code-quality→reviewer). Verifies the dedup-as-context delivery, not a skill.
chezmoi execute-template < dot_config/opencode/opencode.json.tmpl \
  | jq '.plugin[0][1] | {architecture, "code-quality"}'

# (d) Review-flagged-dup proxy — reviewer findings naming an existing symbol +
# file:line as a duplicate. No structured marker yet, so spot-check: list recent
# reviewer sessions that ran ck_semantic_search and inspect whether a dup was flagged.
sqlite3 -readonly "$DB" <<SQL
SELECT DISTINCT p.session_id,
       date(p.time_created/1000,'unixepoch','localtime') AS day
FROM part p JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data,'$.tool') = 'ck_semantic_search'
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
| Primary/lead cost dominated by cache (>80%) | Delegate token-heavy reads to subagents; `compaction.prune`; token-efficiency plugins (DCP + snip) | Effort tuning alone (output is only ~10% of lead cost) |
| No measurable `lead` ctx/cache-read reduction after the DCP/snip plugins | Verify plugin wiring (rendered config shows the plugins loaded, `dcp.jsonc` present with `autoUpdate` false, pruning/trimming firing) before adding another plugin | Stacking more plugins on top of a silently-unloaded one |
| Optimizing without per-agent cost data | Measure per-agent cost first (cost-health queries above) | Assuming which agent is expensive |
| Agent emits empty/zero-cost turns | Verify the model is available, not access/retention-gated | Leaving a silently-broken model configured |
| `explore`/`build` rarely run `ck_semantic_search` despite the explore prompt / build.md dedup directive | Staged escalation: strengthen the prompt/directive first, then a structural results-injection hook that runs the search and injects matches | More advisory prompt text alone |
| `plan`/`reviewer` rarely run `ck_semantic_search` despite the dedup injection context | Staged escalation: strengthen the injection `context`, then a structural results hook that injects matches | More advisory skill injection |
| Local-model turn-share flat / not expanding vs prior audit | Take the next bounded crawl→walk step (title done → kb-summarization: bulk text, no tools, latency-tolerant, privacy-positive) | Moving agentic/high-stakes roles (build/reviewer/plan/lead) to local — quality regression + qwen3 tool-call XML-leak risk |
| Local model shows high empty-turn rate or latency blowup | Raise its LM Studio load-context, or revert that role to Claude — empty/timed-out turns are fake savings | Counting broken local turns as displacement |

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
