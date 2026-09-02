# Agent Skills

[agentskills.io](https://agentskills.io)-compatible skills, deployed to `~/.agents/skills/` for OMP.

Edit skills here, never in `~/.agents/skills/`; chezmoi manages each authored skill directly without replacing the shared directory.

See `AGENTS.md` for what earns a line and when something shouldn't be a skill at all.

## Skills

**Workflow** — a process, loaded at a specific moment.

| Skill | Fires when |
|---|---|
| **implement** | Optional end-to-end workflow when explicitly requested |
| **merge-request** | Optional own-request review workflow when explicitly requested |
| **commit** | About to stage and commit |
| **push** | About to push; owns the CI and automated-review watch |
| **architecture** | A multi-option design decision appears |
| **code-quality** | Grading review-finding severity; the mechanical sweeps |
| **communication** | Composing human-facing prose through an integration |
| **qa-report-publish** | Publishing an assembled QA report to a request |

**Integration** — how to drive a specific tool or API.

| Skill | Covers |
|---|---|
| **aoe** | Agent of Empires: session creation, worktrees, dispatch |
| **chezmoi** | This repo's deploy workflow, LaunchAgents, template gotchas |
| **knowledge-base** | KB ingestion and local CQ projection maintenance. CQ is the normal index; KB is the fallback. |
| **elasticsearch** | Production triage: logs, APM traces, errors |
| **pagerduty** | Incidents, on-call schedules, escalation policies |
| **reminders** | macOS Reminders via `remindctl` |
| **xh** | HTTPie-compatible HTTP client |

External skills come from `.chezmoidata/packages.yaml` `skills:` — [ical-cli](https://github.com/BRO3886/ical).

## Other primitives

Not everything is a skill:

- **Agent prompts** live in `dot_agents/prompts/` — role boundaries and workflow guidance. OMP's system prompt lives directly at `dot_omp/private_agent/APPEND_SYSTEM.md`.
- **Scripts** carry runtime automation.

## Commands

| Command | What |
|---|---|
| `/implement` | Optional shortcut to load the implement skill |
| `/mr` | Optional shortcut to load the merge-request skill |
| `/qa` | Functional QA on the running app; relays the verdict |
| `/learn` | Capture discoveries into AGENTS.md or a skill |
| `/rename` | Retitle the session from what it turned out to be about |
| `/demo` | Build a demo deck from work since the last demo |
| `/audit` | Agent-system and cost/latency audit (scheduled) |
| `/kb-enrich` | Knowledge-base enrichment (scheduled) |
| `/fix-prod-errors` | APM error triage and fix dispatch (scheduled) |
| `/fix-launchagent-errors` | LaunchAgent error self-heal (watcher-dispatched) |
