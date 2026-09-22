---
name: omp-approval-feedback
description: Fires when the user says the immediately preceding OMP CLI approval should have been allowed without prompting.
license: MIT
---

Update the OMP Bash approval policy for the immediately preceding approved command.

1. Identify the exact command that OMP asked the user to approve in the current interaction.
2. Edit `dot_omp/private_agent/private_config.yml`.
3. Add a narrow entry under `bash.patterns` with `approval: allow` and a `match` pattern for that command class.
4. Place the new entry before the first broader `approval: prompt` entry that would match it.
5. Preserve existing prompt rules for broader or unrelated commands. Do not add a catch-all allow rule.
6. Do not rerun the command. The command may write, delete, deploy, or make a remote change.

If the exact approved command is not available, do not guess the match pattern. Report that the current interaction does not contain enough detail.
