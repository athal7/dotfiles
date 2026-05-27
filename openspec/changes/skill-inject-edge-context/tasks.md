## 1. Plugin implementation

- [x] 1.1 Update `buildInjection` to accept `(string | {skill: string, context: string})[]` and render context hints with ` — <context>` format instead of `(<description>)` for object entries
- [x] 1.2 Update config type from `Record<string, string[]>` to `Record<string, (string | {skill: string, context: string})[]>` in the plugin
- [x] 1.3 Update `inject_list` tool to display context hints for object entries

## 2. Config updates

- [x] 2.1 Add xh context hints to API skill injection entries (linear, elasticsearch, confluence, pagerduty, slack, figma) in `opencode.json.tmpl`

## 3. Guidance update

- [x] 3.1 Update `skills/AGENTS.md` auth guidance to acknowledge xh session model and edge-context mechanism

## 4. Cleanup

- [x] 4.1 Remove the "Requests" section from `skills/linear/SKILL.md` (the xh command example that violates "API skills describe shape, not code" guidance — the edge context hint replaces its purpose)
