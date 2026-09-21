# Agent Skills

[agentskills.io](https://agentskills.io)-compatible skills, deployed to `~/.agents/skills/` for OMP.

Edit skills here, never in `~/.agents/skills/`; chezmoi manages each authored skill directly without replacing the shared directory.

## Integration Skills

How to drive a specific tool or API.

| Skill | Covers |
|---|---|
| **aoe** | Agent of Empires: session creation, worktrees, dispatch |
| **chezmoi** | This repo's deploy workflow, LaunchAgents, template gotchas |
| **knowledge-base** | KB ingestion and local CQ projection maintenance. CQ is the normal index; KB is the fallback. |
| **elasticsearch** | Production triage: logs, APM traces, errors |
| **reminders** | macOS Reminders via `remindctl` |
| **xh** | HTTPie-compatible HTTP client |

External skills come from `.chezmoidata/packages.yaml` `skills:` — [ical-cli](https://github.com/BRO3886/ical).

## Other primitives

- **System Prompt** lives at `dot_omp/private_agent/APPEND_SYSTEM.md`.
- **Scripts** carry runtime automation.

## Commands

| Command | What |
|---|---|
| `/learn` | Capture discoveries into AGENTS.md or a skill |
| `/rename` | Retitle the session from what it turned out to be about |
| `/demo` | Build a demo deck from work since the last demo |
| `/audit` | Agent-system and cost/latency audit |
| `/daily-maintenance` | Production-error triage followed by knowledge-base enrichment (scheduled) |
| `/kb-enrich` | Knowledge-base enrichment |
| `/fix-prod-errors` | APM error triage and fix dispatch |
| `/fix-launchagent-errors` | LaunchAgent error self-heal (watcher-dispatched) |
