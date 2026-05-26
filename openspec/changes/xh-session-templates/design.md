## Context

The agent currently must synthesize auth behavior across a 3-skill injection chain: API skill (auth line) → xh skill (session protocol) → secrets skill (env var resolution). Measured indirection loss (~4% per hop) means agents rarely use `--session` and instead either pass auth headers manually every time or forget auth entirely.

xh sessions are JSON files at `~/.config/xh/sessions/<hostname>/<session-name>.json`. They persist headers (and optionally basic auth) across requests to the same host. The session name is an arbitrary string passed via `--session=<name>`.

All API credentials are already in macOS Keychain (service "chezmoi"), accessible via chezmoi's `output` template function.

## Goals / Non-Goals

**Goals:**
- Pre-seed xh session files at `chezmoi apply` time so auth is invisible to the agent
- Use a single constant session name (`agent`) across all services
- Bake the xh command pattern (`--ignore-stdin --session=agent`) into the skill so the agent copies it without thinking
- Remove auth concerns from API skills entirely

**Non-Goals:**
- Managing multiple session names per host (one `agent` session per host is sufficient)
- Supporting services not already in the skill set
- Changing the Keychain/direnv secret infrastructure (that stays for non-xh use cases like `gws`)

## Decisions

### 1. Use a chezmoi run_onchange script, not static templated files

**Decision:** A single `run_onchange_after` script generates all session files.

**Why not static source files:** xh sessions are keyed by hostname in the directory path. For static-host services (slack.com, api.linear.app, etc.) static templates would work. But Confluence and Elasticsearch have user-specific hostnames stored in Keychain — chezmoi can't template a dynamic directory name from source-state alone. A script handles both cases uniformly.

**Why `run_onchange`:** The script re-runs whenever the secrets list in `local.yaml` changes or when a token value changes (via hash of secrets). This keeps sessions fresh without running on every apply.

**Alternatives considered:**
- Static `.tmpl` files for fixed hosts + script for dynamic hosts → split approach, harder to reason about
- `.chezmoiexternal.toml` → wrong tool, designed for downloading external resources

### 2. Constant session name: `agent`

**Decision:** Every session file is named `agent.json`, used via `--session=agent`.

**Rationale:** The agent never needs to choose a session name. One name, always. xh resolves the correct file by matching the request URL's hostname to the session directory.

### 3. Session-to-service mapping lives in `local.yaml`

**Decision:** Extend the existing `secrets` section in `local.yaml` with session metadata.

```yaml
secrets:
  slack_user_token:
    session:
      host: slack.com
      header: "authorization"
      format: "Bearer {value}"
  linear_api_key:
    session:
      host: api.linear.app
      header: "authorization"
      format: "{value}"
  pagerduty_api_token:
    session:
      host: api.pagerduty.com
      headers:
        - name: "authorization"
          format: "Token token={value}"
        - name: "accept"
          value: "application/vnd.pagerduty+json;version=2"
  figma_access_token:
    session:
      host: api.figma.com
      header: "x-figma-token"
      format: "{value}"
  confluence_api_token:
    session:
      host_from: confluence_base_url  # dynamic: extract host from this secret's value
      auth_type: basic
      username_from: confluence_email  # basic auth user from this secret
  es_api_key:
    session:
      host_from: es_url  # dynamic: extract host from this secret's value
      header: "authorization"
      format: "ApiKey {value}"
```

**Rationale:** The mapping is declarative, lives next to the secrets it references, and is visible in one place. The script reads this data and generates the correct JSON structure for each service.

**Alternatives considered:**
- Hardcode mapping in the script → works but couples script to service list, invisible
- Separate config file → unnecessary indirection when `local.yaml` already has the secrets

### 4. Remove Auth lines from API skills, add session reference to xh skill

**Decision:**
- API skills: remove `Auth:` lines entirely. No auth information in the skill body.
- xh skill: update the syntax template to include `--session=agent` as part of the standard pattern. Simplify the Sessions section to state sessions are pre-configured.
- Skill injection: remove `"xh": ["secrets"]` — xh no longer needs secrets.

### 5. Write session files as private (mode 0600)

**Decision:** The script creates session files with restrictive permissions since they contain bearer tokens.

## Risks / Trade-offs

- **[Stale tokens]** → If a Keychain value is updated, `chezmoi apply` must be re-run to refresh session files. Mitigation: this is the existing model for `.envrc` — users already know to apply after credential changes.
- **[chezmoi apply in non-TTY]** → The script uses `security find-generic-password` which works in non-TTY contexts. No risk here.
- **[xh version drift]** → Session file format includes `"xh": "<version>"` in `__meta__`. If xh changes its session format, generated files might not load. Mitigation: omit the version or use current installed version; xh has been stable on this format.
- **[Missing Keychain entries]** → If a secret isn't in Keychain yet, the script should skip that service gracefully (no session file) rather than writing a file with an empty token.
