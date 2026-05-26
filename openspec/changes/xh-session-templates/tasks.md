## 1. Data Layer

- [x] 1.1 Add `session` metadata to each secret in `.chezmoidata/local.yaml` (host, header, format for each service)
- [x] 1.2 Add `local.yaml.example` entries for the new session fields

## 2. Session Generation Script

- [x] 2.1 Create `run_onchange_after_xh-sessions.sh.tmpl` chezmoi script that reads session config from data, fetches tokens from Keychain, and writes `agent.json` files to `~/.config/xh/sessions/<host>/`
- [x] 2.2 Handle static hosts (slack.com, api.linear.app, api.pagerduty.com, api.figma.com)
- [x] 2.3 Handle dynamic hosts (confluence via `host_from`, elasticsearch via `host_from`) — extract hostname from URL secret value
- [x] 2.4 Handle basic auth (confluence) — write `auth` field instead of `headers` array
- [x] 2.5 Handle multi-header services (pagerduty — auth + accept header)
- [x] 2.6 Skip services with missing Keychain entries gracefully
- [x] 2.7 Set file permissions to 0600

## 3. Skill Updates

- [x] 3.1 Update `skills/xh/SKILL.md` — bake `--session=agent` into the syntax template, simplify Sessions section to "pre-configured, no auth needed"
- [x] 3.2 Remove `Auth:` line from `skills/slack/SKILL.md`
- [x] 3.3 Remove `Auth:` line from `skills/linear/SKILL.md`
- [x] 3.4 Remove `Auth:` line from `skills/pagerduty/SKILL.md` (and the `Accept` header line)
- [x] 3.5 Remove `Auth:` line from `skills/figma/SKILL.md`
- [x] 3.6 Remove `Auth:` and secrets line from `skills/confluence/SKILL.md`
- [x] 3.7 Remove `Auth:` line from `skills/elasticsearch/SKILL.md`

## 4. Injection Config

- [x] 4.1 Remove `"secrets"` from `"xh"` injection list in `dot_config/opencode/opencode.json.tmpl`

## 5. Verify

- [x] 5.1 Run `chezmoi apply` and confirm session files are generated at the correct paths with correct content
- [x] 5.2 Test `xh --ignore-stdin --session=agent GET https://slack.com/api/auth.test` returns valid auth
- [x] 5.3 Run `agentskills validate` on modified skills
