---
name: secrets
description: Fetch credentials and API keys. Use when a skill needs an API token, password, or other secret.
license: MIT
---

Secrets declared in `local.yaml` under the `secrets` key are exported as uppercase environment variables via `~/.envrc`. Direnv caches the keychain lookups and the opencode direnv plugin injects them into every bash call automatically.

## Use a secret

Read the uppercase env var directly. No setup, no fetch step.

```bash
# Examples
curl -H "Authorization: $LINEAR_API_KEY" ...
curl -H "X-Slack-Token: $SLACK_TOKEN" ...
```

The env var name is the secret name uppercased (e.g. `linear_api_key` → `LINEAR_API_KEY`). The full list of secret names lives in `$(chezmoi source-path)/.chezmoidata/local.yaml` under `secrets`.

## Fallback — direct keychain lookup

If the env var is empty (e.g. outside direnv context, or a secret just added to Keychain but not yet reloaded):

```bash
MY_TOKEN=$(security find-generic-password -s "chezmoi" -a "<secret-name>" -w)
```

## Adding a new secret

1. Add an entry to `$(chezmoi source-path)/.chezmoidata/local.yaml` under `secrets` (can be empty: `my_secret: {}`).
2. Run `chezmoi apply` — this regenerates `~/.envrc` with the new secret.
3. Add the value to Keychain:
   ```bash
   security add-generic-password -U -s "chezmoi" -a "<name>" -w "<value>"
   ```
4. Run `direnv reload` to pick up the new value immediately.

## Troubleshooting

- **Env var is empty** — run `direnv reload` or check that the Keychain entry exists: `security find-generic-password -s "chezmoi" -a "<name>" -w`
- **`The specified item could not be found in the keychain`** — the secret hasn't been added yet. Tell the user to run `security add-generic-password -U -s chezmoi -a <name> -w <value>`.
