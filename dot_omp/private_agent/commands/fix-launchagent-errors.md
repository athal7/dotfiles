---
description: Triage and self-heal LaunchAgent errors found by the log watcher
---

Triage the supplied LaunchAgent error-log lines and fix genuine source defects in the dotfiles repository.

$ARGUMENTS

The argument names each service and its new log lines as `[service] <line>`.

1. Read the source behind every flagged service. Classify each line as a genuine defect or transient/upstream noise; never decide from error keywords alone.
2. For a genuine defect, change the managed source that owns the behavior. Leave commit and deploy decisions to the lead unless explicitly requested.
3. For transient noise, add the narrowest applicable `service|grep -E pattern` entry to `EXCLUDE_PATTERNS` in `dot_local/bin/executable_check-error-logs`. Never suppress an entire service or a real error category.
4. Verify source changes render correctly with the chezmoi worktree. Where feasible, rerun the affected script or kickstart the LaunchAgent and confirm the error no longer recurs.
5. Report each service, classification, source change or suppression, and verification result.
