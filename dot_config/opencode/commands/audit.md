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

**Token-efficiency baseline (DCP):** the headline metric for the token-efficiency plugin is the `lead` `avg_ctx_tok` from the queries below — the per-turn average context, which is robust across windows. `cache_r_Mtok` is a window-SUM (it scales with how much work happened that month, so a quiet month shows a fake "reduction"); treat it as **directional / decomposition support only**, not the target metric. Target: **≥15% reduction in `lead` `avg_ctx_tok`** vs a re-derived, work-intensity-controlled **floor read from `~/.config/opencode/dcp-baseline.json`** (source: `dot_config/opencode/dcp-baseline.json`) — NOT a hard-coded scalar. The floor is a ratcheting one (it only moves DOWN, and only on a guard-passing lower median; a higher/non-representative window is flagged, never adopted). Use `cache_r_Mtok` only to sanity-check direction, not to grade the target.

**Grade R3 by SEGMENTING at the DCP-introduction date — never average across the boundary.** DCP was wired on **2026-06-16** (git commit `8d3f374`), so a single 30-day window straddles that date and yields a window-straddling artifact (the prior misleading −2.7%). The reduction MUST be computed as **post-introduction `avg_ctx_tok` vs pre-introduction `avg_ctx_tok`** (same formula on each segment), using the conservative "fully live" cutoff **2026-06-17** as the primary post boundary (the 06-16 commit day is partial and used only as a sensitivity point). The introduction-date split is the **bootstrap** method while the post-DCP segment is young (currently ~6 days / ~3.4k turns — **revisit at ≥30 post-DCP days, n≈15–20k turns**); the work-intensity-guarded median floor (below) becomes the **ongoing** mechanism once ≥30 post-DCP days accumulate.

**DCP firing is instrumented (fail-open).** Read DCP's own persisted sidecar state (`~/.local/share/opencode/storage/plugin/dcp/<sessionId>.json`, written on every prune/compress) joined to the DB for `lead` attribution to prove prune/`compress` actually fires on `lead` turns and quantify per-turn tokens removed (a directional **median** of per-event `blocksById.compressedTokens`, not a window-sum). The sidecar dir is rolling/partial, so ALSO report the DB `compress`-part count as a complete **lower bound**. If neither is present for the window, report "firing signal absent" and continue (do not error). This distinguishes **firing-but-under-pruning** from **silently-no-op** — see the Step-5 row.

Reuse the per-agent `avg_ctx_tok`, the `cache_r_Mtok` decomposition, and the `lead` daily trend below for the baseline; add only the minimal `lead`-session-id selector SQL + the read-only `jq` aggregation over the sidecar store for the firing signal. The new snippets below keep each command to a single-statement `sqlite3 -readonly` call or a single `jq` pipeline fed by command substitutions (no heredoc, no bare `VAR=` lines, no shell read-loop, inline literal paths, `\$` escaped); the firing aggregate slurps the sidecar glob inside one `jq` pass to ~5 scalars — never reading sidecar bodies into context.

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

# Per-agent/model latency & output — speed regressions (build is tuned for speed).
# Turns with latency >= 30 min (1,800,000 ms) are excluded: they represent suspended
# sessions (laptop closed mid-turn), not slow model responses, and would otherwise
# dominate the average (e.g. 14 frozen turns accounted for 93.5% of raw general-agent
# latency in one window).
sqlite3 -readonly "$DB" <<SQL
SELECT json_extract(data,'$.agent') AS agent, json_extract(data,'$.modelID') AS model,
       COUNT(*) AS msgs,
       ROUND(AVG((json_extract(data,'$.time.completed')-json_extract(data,'$.time.created'))/1000.0),1) AS avg_lat_s,
       ROUND(AVG(json_extract(data,'$.tokens.output'))) AS avg_out_tok
FROM message
WHERE json_extract(data,'$.role')='assistant'
  AND json_extract(data,'$.time.completed') IS NOT NULL
  AND json_extract(data,'$.tokens.output') > 0
  AND (json_extract(data,'$.time.completed')-json_extract(data,'$.time.created')) < 1800000
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

**DCP firing signal + segmented R3 grade + re-derived floor.** These snippets surface (1) the firing aggregate, (2) the DB compress lower bound, (3) the segmented pre/post reduction, (4) the candidate floor under the work-intensity guard, and (5) the committed-floor R3 grade. The two *refusal guards* (boundary-straddle refusal, ratchet refusal) come FIRST — they constrain the grades that follow.

```bash
# GUARD 1 (refusal, comes first) — a single window that STRADDLES the DCP-introduction
# date (2026-06-16) is REFUSED for grading R3: it averages pre-DCP and post-DCP turns into
# one window-straddling artifact (the misleading -2.7%). This prints the straddling number
# AND the verdict that it must NOT be used — the segmented split below is mandatory.
sqlite3 -readonly ~/.local/share/opencode/opencode.db "SELECT 'STRADDLING WINDOW (DO NOT GRADE R3 ON THIS)' AS guard, ROUND(AVG(json_extract(data,'\$.tokens.cache.read'))) AS straddling_avg_ctx_tok, COUNT(*) AS turns, 'REFUSED: spans 2026-06-16 DCP intro; use the segmented pre/post grade below' AS verdict FROM message WHERE json_extract(data,'\$.role')='assistant' AND json_extract(data,'\$.agent')='lead' AND time_created >= strftime('%s','now','-30 days')*1000"

# GUARD 2 (refusal, comes first) — the re-baseline action REFUSES to (a) raise the floor or
# (b) commit on a guard-failing / non-representative window. It compares the candidate floor
# (computed below) to the committed floor and emits ALLOW only when strictly lower AND the
# window is representative AND >=30 post-DCP days. Otherwise REFUSE. Defaults to REFUSE.
# (Run after the candidate-floor snippet; substitute the two numbers it printed.)
echo "RE-BASELINE GUARD: commit a new floor ONLY IF candidate_floor < committed_floor AND representative (days_kept>=5) AND post_dcp_days>=30 AND human-ratified. Down-only ratchet; higher or non-representative or <30d => REFUSE (no write to dcp-baseline.json)."

# (1) Firing aggregate over the lead sidecars on disk (rolling/partial store). A single jq pass
# reads the sidecar glob and keeps only files whose basename (sessionId) is in the lead-id set
# from the DB, aggregating to ~5 scalars (no bodies into context). No shell read-loop. Fail-open:
# absent/empty dir => glob yields nothing => aggregate over [] ("firing signal absent"); stdin is
# redirected from /dev/null so a no-file run never blocks on a TTY.
jq -n --argjson ids "$(sqlite3 -readonly ~/.local/share/opencode/opencode.db "SELECT json_group_array(id) FROM (SELECT id FROM session WHERE agent='lead' UNION SELECT session_id AS id FROM message WHERE json_extract(data,'\$.agent')='lead')")" '($ids|map({(.):true})|add // {}) as $set | [inputs | select($set[input_filename|sub(".*/";"")|sub("\\.json$";"")] // false)] as $rows | ($rows|map(.stats.totalPruneTokens // 0)) as $tot | ($rows|map(.prune.messages.blocksById // {}|to_entries|map(.value.compressedTokens // 0))|add // []) as $blk | ($rows|map(.prune.tools // {}|to_entries|map(.value))|add // []) as $strat | ($blk|sort) as $s | {lead_sidecars_on_disk: ($rows|length), firing_sessions: ($rows|map(select((.stats.totalPruneTokens // 0)>0))|length), total_reclaimed_tok: ($tot|add), compression_blocks: ($blk|length), median_compressed_tok_per_event: (if ($s|length)==0 then 0 else $s[(($s|length)/2|floor)] end), strategy_prune_tok: ($strat|add)}' $(ls ~/.local/share/opencode/storage/plugin/dcp/*.json 2>/dev/null) </dev/null

# (2) DB compress-part count = COMPLETE lower bound on lead firing count (sidecars are partial).
# If this is 0 AND the sidecar aggregate above is empty => report "firing signal absent" (fail-open).
sqlite3 -readonly ~/.local/share/opencode/opencode.db "SELECT COUNT(*) AS compress_parts_lead_lower_bound FROM part p JOIN (SELECT id FROM session WHERE agent='lead' UNION SELECT session_id AS id FROM message WHERE json_extract(data,'\$.agent')='lead') L ON L.id=p.session_id WHERE json_extract(p.data,'\$.type')='tool' AND json_extract(p.data,'\$.tool')='compress'"

# (3) SEGMENTED reduction grade — post-introduction vs pre-introduction avg_ctx_tok, SAME formula
# on each segment, NEVER across the 2026-06-16 boundary. pre = 30d pre-DCP window; post = >=2026-06-17
# (conservative); the 06-16 sensitivity row includes the partial commit day.
sqlite3 -readonly ~/.local/share/opencode/opencode.db "SELECT 'pre_dcp' AS seg, ROUND(AVG(json_extract(data,'\$.tokens.cache.read'))) AS avg_ctx_tok, COUNT(*) AS turns FROM message WHERE json_extract(data,'\$.role')='assistant' AND json_extract(data,'\$.agent')='lead' AND time_created >= strftime('%s','2026-05-17','localtime')*1000 AND time_created < strftime('%s','2026-06-16','localtime')*1000 UNION ALL SELECT 'post_dcp_0617', ROUND(AVG(json_extract(data,'\$.tokens.cache.read'))), COUNT(*) FROM message WHERE json_extract(data,'\$.role')='assistant' AND json_extract(data,'\$.agent')='lead' AND time_created >= strftime('%s','2026-06-17','localtime')*1000 UNION ALL SELECT 'post_dcp_0616_sens', ROUND(AVG(json_extract(data,'\$.tokens.cache.read'))), COUNT(*) FROM message WHERE json_extract(data,'\$.role')='assistant' AND json_extract(data,'\$.agent')='lead' AND time_created >= strftime('%s','2026-06-16','localtime')*1000"

# (4) CANDIDATE floor = work-intensity-guarded MEDIAN of the post-DCP lead per-day avg_ctx_tok
# series. Guard: keep only days whose lead-turns/day is within +/-50% of the trailing-90-day
# lead-turns/day median; take the median of avg_ctx_tok over survivors. If too few days survive
# the window is NON-REPRESENTATIVE => flagged, NOT adopted (feeds GUARD 2). Displayed every run,
# committed only on an explicit, human-ratified re-baseline once >=30 post-DCP days exist.
jq -n --argjson m "$(sqlite3 -readonly ~/.local/share/opencode/opencode.db "WITH d AS (SELECT date(time_created/1000,'unixepoch','localtime') AS day, COUNT(*) AS n FROM message WHERE json_extract(data,'\$.role')='assistant' AND json_extract(data,'\$.agent')='lead' AND time_created >= strftime('%s','now','-90 days')*1000 GROUP BY day) SELECT AVG(n) FROM (SELECT n FROM d ORDER BY n LIMIT 2 - (SELECT COUNT(*) FROM d)%2 OFFSET (SELECT (COUNT(*)-1)/2 FROM d))")" --slurpfile rows <(sqlite3 -readonly -json ~/.local/share/opencode/opencode.db "SELECT date(time_created/1000,'unixepoch','localtime') AS day, COUNT(*) AS lead_turns, ROUND(AVG(json_extract(data,'\$.tokens.cache.read'))) AS avg_ctx_tok FROM message WHERE json_extract(data,'\$.role')='assistant' AND json_extract(data,'\$.agent')='lead' AND time_created >= strftime('%s','2026-06-17','localtime')*1000 GROUP BY day ORDER BY day") '($rows[0]) as $all | [$all[] | select(.lead_turns >= ($m*0.5) and .lead_turns <= ($m*1.5))] as $kept | ($kept | map(.avg_ctx_tok) | sort) as $s | {turns_per_day_median_90d: $m, band: [($m*0.5),($m*1.5)], days_total: ($all|length), days_kept: ($kept|length), candidate_floor_avg_ctx_tok: (if ($s|length)==0 then null elif (($s|length)%2)==1 then $s[(($s|length)/2|floor)] else (($s[($s|length)/2-1]+$s[($s|length)/2])/2) end), representative: (($kept|length) >= 5), note: "candidate only; representative requires >=5 guard-surviving days (median defensibility); revisit at >=30 post-DCP days; human ratification required to ratchet"}'

# (5) Committed-floor R3 grade — read the floor from the data file (NOT a hard-coded scalar) and
# grade the post-DCP segment against it. >=15% reduction => MEETS R3 (pending human ratification of
# the first re-baselined floor; do NOT auto-close R3).
jq -n --slurpfile f ~/.config/opencode/dcp-baseline.json --argjson post "$(sqlite3 -readonly ~/.local/share/opencode/opencode.db "SELECT ROUND(AVG(json_extract(data,'\$.tokens.cache.read'))) FROM message WHERE json_extract(data,'\$.role')='assistant' AND json_extract(data,'\$.agent')='lead' AND time_created >= strftime('%s','2026-06-17','localtime')*1000")" '($f[0].floor_avg_ctx_tok) as $floor | {committed_floor: $floor, post_dcp_avg_ctx_tok: $post, reduction_pct: (((($floor-$post)/$floor)*100)|.*10|round/10), target_pct: 15, r3_meets: ((($floor-$post)/$floor) >= 0.15), gate: "human ratification required before closing R3"}'
```

**Local-model adoption (Claude displacement):** the headline metric is **local turn-share** — the % of assistant turns served by a non-Anthropic provider (`lmstudio`/`ollama`/`mlx`/etc.), which **ratchets UP** as work is displaced off Claude (the opposite direction from the DCP floor). Because every local/non-Anthropic provider records `cost = 0` in the DB, dollar savings cannot be read directly — it is **ESTIMATED** (an agent's local turns × that agent's historical avg Anthropic $/turn) and treated as **directional only**, exactly like `cache_r_Mtok`. Key the metric on `providerID`, NOT on agent name: the `title` agent's turns are not stored under `agent='title'`, so an agent-name filter would miss them. **Baseline (recorded 2026-06-18):** local turn-share = 0.1%; as of commit `fa89b03` the `title` agent runs on `lmstudio/qwen3-30b-a3b-instruct-2507` (first deliberate production displacement; prior local turns were ad-hoc experiments). **Target:** local turn-share expands run-over-run WITHOUT a rise in local empty-turn rate or interactive-latency regressions (an empty or timed-out local turn is *fake* displacement, not savings — cross-check the empty-turn and latency queries above, scanning rows where `providerID != 'anthropic'`). Expansion path: `title` (done) → kb-summarization pipeline (next) → low-stakes `explore`/`scout` (gated). Never move `build`/`plan`/`lead`.

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

# NOTE — local_turn_pct EXCLUDES session auto-titling (the local model's primary job).
# Session titling fires as an internal OpenCode runtime call per top-level session and
# never writes a message row, so near-0% local_turn_pct is EXPECTED and does not mean
# the local model is idle. The providerID query above = "local model used as a session
# agent"; query (d) below = "local model used for titling" (the dominant workload).

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

# (d) Local-model titling throughput — the primary local-utilization signal.
# Counts top-level sessions (parent_id IS NULL; subagent sessions excluded) with a
# real (non-default) title vs total. A high titled_pct confirms LM Studio is up and
# serving requests even when message-table local_turn_pct rounds to ~0. A sudden DROP
# in titled_pct (many sessions getting default titles) means the LM Studio server is
# down — the failure mode the 2026-06-26 autoStartOnLaunch fix addressed.
sqlite3 -readonly "$DB" <<SQL
SELECT
  SUM(CASE WHEN title NOT IN ('New Session','New session','Untitled','') AND title IS NOT NULL THEN 1 ELSE 0 END) AS titled_sessions,
  COUNT(*) AS total_sessions,
  ROUND(100.0*SUM(CASE WHEN title NOT IN ('New Session','New session','Untitled','') AND title IS NOT NULL THEN 1 ELSE 0 END)/COUNT(*),1) AS titled_pct
FROM session
WHERE time_created > (strftime('%s','now','-${WINDOW_DAYS} days')*1000)
  AND parent_id IS NULL;
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
| Primary/lead cost dominated by cache (>80%) | Delegate token-heavy reads to subagents; `compaction.prune`; token-efficiency plugin (DCP) | Effort tuning alone (output is only ~10% of lead cost) |
| No measurable `lead` ctx/cache-read reduction after the DCP plugin | FIRST read the DCP firing signal (sidecar aggregate + DB `compress` lower bound) and grade reduction SEGMENTED at the 2026-06-16 intro date (never a straddling window): **firing-but-under-pruning** (sidecar shows prunes, post-vs-pre still <15%) → separate tuning proposal (NOT this change); **silently-no-op** (no sidecar prunes, no `compress` parts) → verify plugin wiring (rendered config loaded, `dcp.jsonc` present with `autoUpdate` false) before adding another plugin; **window-straddling artifact** (firing confirmed + segmented split clears 15%) → re-baseline the floor in `dcp-baseline.json` (down-only, guard-passing, human-ratified) | Stacking more plugins on top of a silently-unloaded one; grading R3 on a single window that straddles the DCP-intro date |
| Optimizing without per-agent cost data | Measure per-agent cost first (cost-health queries above) | Assuming which agent is expensive |
| Agent emits empty/zero-cost turns | Verify the model is available, not access/retention-gated | Leaving a silently-broken model configured |
| Local-model turn-share flat / not expanding vs prior audit | Take the next bounded crawl→walk step (title done → kb-summarization: bulk text, no tools, latency-tolerant, privacy-positive) | Moving agentic/high-stakes roles (build/plan/lead) to local — quality regression + qwen3 tool-call XML-leak risk |
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
