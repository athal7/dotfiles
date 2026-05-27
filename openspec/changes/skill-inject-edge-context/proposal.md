## Why

The skill-inject plugin appends a footer recommending related skills when a skill loads (e.g., loading `linear` shows "load `xh` skill"). But the footer only carries the target skill's description — it doesn't explain WHY the skills are related or HOW to use the injected skill in context. This creates multi-hop indirection (agent must load the recommended skill, find the relevant info, then connect it back), which the skill design guidance says loses ~90% of behavior per hop. Observed failure: agents loading API skills don't connect them to xh sessions for auth — they try raw Authorization headers, fail, and go credential hunting.

## What Changes

- The skill-inject plugin config format extends from `string[]` to `(string | {skill: string, context: string})[]`
- Plain strings keep current behavior (description-based footer)
- Objects add a per-edge context hint rendered in the injection footer
- The `buildInjection` function renders context hints inline instead of the description when present
- The skills AGENTS.md guidance on API skill auth (`$VARIABLE` format) is updated to acknowledge the xh session model and the edge-context mechanism
- API skill injection configs (linear, elasticsearch, confluence, pagerduty, slack, figma) get context hints for xh

## Capabilities

### New Capabilities

- `injection-edge-context`: Per-relationship context hints in the skill-inject plugin, replacing description-only injection footers

### Modified Capabilities

None (no existing spec-level behavior changes)

## Impact

- `dot_config/opencode/plugins/skill-inject.ts` — plugin implementation
- `dot_config/opencode/opencode.json.tmpl` — injection config entries
- `skills/AGENTS.md` — guidance update for API skill auth pattern
- All existing injection mappings continue working (backward compatible — plain strings unchanged)
