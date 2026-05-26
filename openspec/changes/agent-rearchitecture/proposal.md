## Why

The agent system has gone through 12 iterations of workflow enforcement
over 5 months, each addressing the previous failure mode but introducing
a new one. Measured across 1,965 sessions: review compliance reached 80%
in the current era (up from 0% in January) but advisory approaches
consistently fail. The system needs a structured approach grounded in
desired-state specs, a capability gap analysis, and research into what
tools exist to fill the gaps — rather than another incremental fix.

## What Changes

- Map the harness capabilities required by the four workflow specs
- Identify gaps between current capabilities and required capabilities
- Research existing tools and platform features that can fill gaps
- Design the implementation approach based on what's structurally possible
- Implement the changes that bring the system closer to spec compliance

## Capabilities

### Modified Capabilities
- `agent-workflow`: Implementation changes to improve compliance with existing spec requirements (human gates, phase sequencing, structural enforcement)
- `code-review`: Implementation changes for multi-pass analysis compliance and goal alignment
- `merge-request`: Add conflict resolution support, improve thread tracking persistence
- `remote-operations`: Verify and tighten write-approval enforcement

## Impact

- Agent prompts (lead.md, build.md, plan.md)
- opencode.json.tmpl (permissions, plugins, commands, agent definitions)
- Skills (review, commit, push, respond-to-review)
- Plugins (context-compaction.ts, skill-inject.ts, potentially new)
- Possibly new tools or platform features adopted
