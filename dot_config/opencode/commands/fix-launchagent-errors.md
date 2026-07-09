---
description: Triage and self-heal LaunchAgent error-log failures found by the check-error-logs watcher
subtask: true
---

Triage the LaunchAgent error-log lines below and fix them at the source in the dotfiles repo. The `check-error-logs` watcher dispatched this session because it found new errors in `~/Library/Logs/*.error.log`.

$ARGUMENTS

The argument carries the flagged service name(s) and the new error log lines the watcher matched. Each detail line is tagged with its service as `[service] <line>` — the service name is the `.error.log` basename without the suffix.

## Skills

- **opencode** — for stale-worktree / session DB failures, follow `repair.md` (especially "Fix B"). For dispatch mechanics, see `SKILL.md`.
- **chezmoi** — this repo manages `~`; load the chezmoi skill for the deploy workflow.

## Steps

1. **Triage each flagged error.** Classify every error line as one of:
   - **(a) Genuine defect** — a real bug fixable in the dotfiles repo (bad script logic, broken path, missing dependency, malformed config).
   - **(b) Transient / upstream noise** — an upstream warning, an expected-transient condition, or anything not caused by this repo's code that should simply stop tripping the watcher.

   Read the relevant source (the script or config behind the failing service) before deciding. Do not dismiss by keyword alone — `failed`/`error` in a log line may be benign or may be a real defect.

2. **Genuine defects — fix at source.** Edit the source file in this repo (e.g. `dot_local/bin/...`, `dot_config/...`, `.chezmoidata/...`). Leave the commit and deploy to the lead unless told otherwise.

3. **Stale worktree / session-picker errors.** For errors like `Failed to init file picker: Invalid path .../worktree/.../<session-name>` (or a blank session list), apply the opencode skill `repair.md` **"Fix B"** procedure:
   - Recreate the missing git worktree as a real `git worktree add` (not `mkdir`), OR reconcile the sqlite DB by **UPDATE**-ing `project.sandboxes` — **never DELETE project rows** (deleting breaks the `session` FK constraint).
   - Keep `project.sandboxes` and `global.dat` `workspaceOrder` consistent — fixing only one leaves the UI blank.
   - The opencode DB is at `~/.local/share/opencode/opencode.db`.

4. **Transient / upstream noise — suppress at the watcher.** When an error is not a code defect and should simply stop tripping the watcher (an upstream warning, an expected-transient condition), do **not** write a code fix. Instead add an entry to the `EXCLUDE_PATTERNS` list in `dot_local/bin/executable_check-error-logs`:
   - Format: one `service|pattern` entry per line, where `service` is the `.error.log` basename without the suffix and `pattern` is a `grep -E` extended regex matched against the log line.
   - Matching lines are stripped before error-keyword scanning, so the watcher stops re-dispatching on them. Prefer a narrow pattern that targets the specific noisy line — never suppress a whole service's real errors.
   - In your report, explain why the line is noise and not a defect, so the suppression is auditable.

5. **Verify.** Render-only confirms the source change; the lead deploys. Where feasible, confirm the failing service no longer errors (e.g. re-run the script or `launchctl kickstart` the agent).

6. **Report** — per flagged error: the classification (defect / stale-worktree / noise), the action taken (file changed or DB reconciled or EXCLUDE_PATTERNS entry added), and the verification result.
