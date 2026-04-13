---
name: chezmoi
description: Apply dotfiles and machine configuration via chezmoi — handles the mid-session server restart that causes apparent hangs when editing opencode config or skills
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides:
    - machine-config
---

Unified skill for machine configuration management. Use the reference files below for each area.

- **[apply.md](apply.md)** — run chezmoi apply safely, handling the mid-session server restart
