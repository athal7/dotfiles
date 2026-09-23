# Agent Skills

[agentskills.io](https://agentskills.io)-compatible skills, deployed to `~/.agents/skills/` for OMP.

Edit skills here, never in `~/.agents/skills/`; chezmoi manages each authored skill directly without replacing the shared directory.

## Integration Skills

How to drive a specific tool or API.

| Skill | Covers |
|---|---|
| **aoe** | Agent of Empires: session creation, worktrees, dispatch |
| **chezmoi** | This repo's deploy workflow, LaunchAgents, template gotchas |
| **elasticsearch** | Production triage: logs, APM traces, errors |
| **reminders** | macOS Reminders via `remindctl` |
| **xh** | HTTPie-compatible HTTP client |

External skills come from `.chezmoidata/packages.yaml` `skills:` — [ical-cli](https://github.com/BRO3886/ical).

## Workflow Skills

| Skill | Covers |
|---|---|
| **implement** | End-to-end implementation workflow when requested. |
| **communication** | Draft human-facing prose for an integration. |
| **omp-approval-feedback** | Allow a just-approved OMP CLI command without a future prompt. |
| **shipit** | Commit and push completed changes, or deploy this dotfiles repository. |
| **homebrew-release** | Verify a release, update its Homebrew tap, and verify the local install. |
| **merge-request** | Maintain a pull request after review feedback or conflicts. |
| **qa-report-publish** | Publish local QA evidence in a pull request review. |
| **qa-verification** | Verify a running app in a browser and write local evidence. |

## Other primitives

- **System Prompt** lives at `dot_omp/private_agent/APPEND_SYSTEM.md`.
- **Prompts** live at `dot_agents/prompts/`, deployed to `~/.agents/prompts/` for scheduled agents.
- **Scripts** carry deterministic runtime automation.
