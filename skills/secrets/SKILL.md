---
name: secrets
description: Fetch credentials and API keys. Use when a skill needs an API token, password, or other secret. Covers both personal (macOS Keychain) and work (1Password) secrets.
license: MIT
metadata:
  provides:
    - secrets
---

Secrets are split across two providers based on whether they are personal or work-related:

- **Personal secrets** — macOS Keychain, service `chezmoi`
- **Work secrets** — 1Password CLI (`op`)

The mapping of secret names to provider, vault, item, and field is in `~/.local/share/chezmoi/.chezmoidata/local.yaml` under the `secrets` key. Read it to know which provider and lookup details to use for a given secret.

## Fetching a secret

**From Keychain:**
```bash
security find-generic-password -s "chezmoi" -a "<account>" -w
```

**From 1Password:**
```bash
op item get <item-id> --fields label=<field> --account <account>
```

If `op` returns an authorization error, the session has expired — re-authenticate via the 1Password desktop app or `op signin`.

## Adding a new secret

Add an entry to `~/.local/share/chezmoi/.chezmoidata/local.yaml`:

```yaml
secrets:
  my_token:
    provider: keychain   # or: op
    account: my_token    # keychain account name
    # for op:
    # account: your-1password-account
    # vault: your-vault
    # item: item-id
    # field: field-label
```

For Keychain, also add the value:
```bash
security add-generic-password -s "chezmoi" -a "my_token" -w "value"
```
