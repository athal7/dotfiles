## Why

Agents aren't using xh sessions for API auth despite the xh skill documenting session handling. The current design requires the agent to synthesize behavior across three injected skills (API skill → xh → secrets) — a multi-hop chain that measured skill research shows drops to ~4% compliance per hop. By pre-seeding xh session files at `chezmoi apply` time, auth becomes invisible infrastructure rather than agent-synthesized behavior.

## What Changes

- Add chezmoi-templated xh session files (`agent.json`) for each API service, deployed to `~/.config/xh/sessions/<host>/agent.json`. These pull tokens from macOS Keychain at apply time.
- Simplify the xh skill: replace the session-seeding instructions with a single constant — always use `--session=agent`. Remove the secrets injection dependency.
- Remove `Auth:` lines from API skills (slack, linear, pagerduty, figma, confluence, elasticsearch). Auth is handled by the pre-seeded session, not by the agent.
- Remove `"xh": ["secrets"]` from the skill-inject plugin config. The xh skill no longer needs to teach the agent how to fetch and apply credentials.

## Capabilities

### New Capabilities
- `xh-session-templates`: Chezmoi-managed xh session files that pre-seed API auth for all integrated services, using a constant session name (`agent`) across all hosts.

### Modified Capabilities

## Impact

- **Files added:** `dot_config/xh/sessions/<host>/agent.json.tmpl` for each service (slack.com, api.linear.app, api.pagerduty.com, api.figma.com, plus dynamic-host services)
- **Files modified:** `skills/xh/SKILL.md`, `skills/slack/SKILL.md`, `skills/linear/SKILL.md`, `skills/pagerduty/SKILL.md`, `skills/figma/SKILL.md`, `skills/confluence/SKILL.md`, `skills/elasticsearch/SKILL.md`, `dot_config/opencode/opencode.json.tmpl`
- **Dynamic hosts:** Confluence and Elasticsearch have user-specific hostnames. These will need hostname values available as chezmoi data (derived from existing Keychain secrets or added to `local.yaml`).
- **No breaking changes** to existing workflows — sessions that already exist will be overwritten with chezmoi-managed versions containing the same credentials.
