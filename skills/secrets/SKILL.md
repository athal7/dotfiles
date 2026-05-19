---
name: secrets
description: Fetch credentials and API keys. Use when a skill needs an API token, password, or other secret.
license: MIT
---

All secrets are stored in the macOS Keychain under service `chezmoi`. The account name matches the secret name declared in `$(chezmoi source-path)/.chezmoidata/local.yaml` under the `secrets` key — these are lowercase (e.g. `slack_user_token`), not the uppercase env var convention a skill body might use (e.g. `$SLACK_USER_TOKEN`).

This works non-interactively from any agent context (including remote sessions) — no Touch ID, no biometric prompts.

## Fetch a secret

```bash
MY_TOKEN=$(security find-generic-password -s "chezmoi" -a "<secret-name>" -w)
```

If the command fails with `The specified item could not be found in the keychain`, the secret hasn't been populated yet. Tell the user: "The Keychain entry for `<secret-name>` is missing. Please add it via `security add-generic-password -U -s chezmoi -a <secret-name> -w <value>` and let me know when done."

## Adding a new secret

1. Add an entry to `$(chezmoi source-path)/.chezmoidata/local.yaml` under `secrets` (the entry can be empty: `my_secret: {}`).
2. Add the value to Keychain:
   ```bash
   security add-generic-password -U -s "chezmoi" -a "<name>" -w "<value>"
   ```
3. Verify the fetch works:
   ```bash
   security find-generic-password -s "chezmoi" -a "<name>" -w
   ```
