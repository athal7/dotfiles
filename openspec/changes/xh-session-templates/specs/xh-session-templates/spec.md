## ADDED Requirements

### Requirement: Session files are generated at apply time
chezmoi SHALL generate xh session files at `~/.config/xh/sessions/<host>/agent.json` for every secret in `local.yaml` that has a `session` configuration block. Files SHALL be created with mode 0600. If a Keychain entry is missing for a secret, that service's session file SHALL be skipped without error.

#### Scenario: Static-host session generated
- **WHEN** `chezmoi apply` runs and `slack_user_token` has a `session` block with `host: slack.com`
- **THEN** `~/.config/xh/sessions/slack.com/agent.json` exists with the token from Keychain in the `headers` array

#### Scenario: Dynamic-host session generated
- **WHEN** `chezmoi apply` runs and `es_api_key` has a `session` block with `host_from: es_url`
- **THEN** the hostname is extracted from the `es_url` Keychain value and the session file is written to `~/.config/xh/sessions/<extracted-host>/agent.json`

#### Scenario: Missing Keychain entry skipped
- **WHEN** `chezmoi apply` runs and a secret has a `session` block but no Keychain entry exists
- **THEN** no session file is written for that service and no error is raised

### Requirement: Session files use the constant name `agent`
All generated session files SHALL be named `agent.json`. The xh `--session=agent` flag SHALL resolve to the correct file based on the request URL's hostname.

#### Scenario: Same session name resolves different auth per host
- **WHEN** the agent runs `xh --session=agent GET https://slack.com/api/...` and `xh --session=agent POST https://api.linear.app/graphql ...`
- **THEN** the Slack request uses the Slack bearer token and the Linear request uses the Linear API key

### Requirement: Session metadata is declared in local.yaml
The `secrets` section of `local.yaml` SHALL support a `session` key on each secret entry. The `session` block SHALL support: `host` (static hostname), `host_from` (secret name whose value contains the URL to extract hostname from), `header`/`headers` (header name(s) and format), `auth_type: basic` (for HTTP Basic auth with `username_from`).

#### Scenario: Single header with format string
- **WHEN** a secret has `session.header: "authorization"` and `session.format: "Bearer {value}"`
- **THEN** the generated session file contains a header entry `{"name": "authorization", "value": "Bearer <token>"}`

#### Scenario: Multiple headers
- **WHEN** a secret has `session.headers` as an array with multiple entries
- **THEN** the generated session file contains all specified headers

#### Scenario: Basic auth
- **WHEN** a secret has `session.auth_type: basic` and `session.username_from: confluence_email`
- **THEN** the generated session file uses the `auth` field with type `basic` instead of the `headers` array

### Requirement: xh skill documents the constant session pattern
The xh skill SHALL include `--session=agent` in its standard command syntax template. The Sessions section SHALL state that sessions are pre-configured and the agent does not need to provide auth headers.

#### Scenario: Agent uses xh without auth knowledge
- **WHEN** the agent loads the xh skill and an API skill
- **THEN** the xh skill syntax shows `--session=agent` and no auth header is needed

### Requirement: API skills do not contain auth information
API skills (slack, linear, pagerduty, figma, confluence, elasticsearch) SHALL NOT contain `Auth:` lines or auth header documentation. Auth is handled by pre-seeded sessions.

#### Scenario: Slack skill has no auth line
- **WHEN** the agent loads the slack skill
- **THEN** the skill contains base URL and endpoint documentation but no auth header or token reference

### Requirement: xh skill does not inject secrets
The skill-inject configuration SHALL NOT include `secrets` in the xh injection list. The xh skill operates independently of the secrets skill.

#### Scenario: Loading xh does not surface secrets
- **WHEN** the agent loads the xh skill
- **THEN** only the xh skill content is surfaced, not the secrets skill
