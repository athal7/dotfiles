Approved but not pushed. Order matters — store steps run *after* the push, since archiving early finalizes durable state for code that may still change.

1. **Commit and push.** Load `commit`, then `push`. For PR repos this opens the draft request; otherwise it's the whole ship step.

   **Tracker auto-transition:** When a PR is linked to an issue (issue key in branch name, title, or body), the tracker-GitHub integration auto-transitions issue status and posts PR linkage. Don't manually update the issue or add comments — races with the integration.

   **List state names before guessing:** State names vary per org/team (e.g., 'Code Review' vs 'In Review' have distinct meanings). Query the tracker's actual available states instead of assuming similarity.
2. **Watch CI and automated review** per the `push` skill. A long-pending approval is not the finish line — the steps below still run in the same pass. CI failure routes like any Review finding: code fix → `build` (or direct), approach problem → update the proposal, flaky → re-run. Never terminal.
3. **Merge delta specs into the durable store — before archiving.** Read both sides, integrate, preserve existing scenarios, flag conflicts or supersession to the human. Detection only; never auto-reconcile. `openspec archive` does not do this.
4. **Archive:** `openspec archive <name> --skip-specs -y` from the repo root. `--skip-specs` avoids the lossy replace-only auto-fold; `-y` stops it hanging.
5. **Stamp correlation metadata** so daily enrichment can skip re-reading expensive transcripts:

   ```sh
   archived="$(ls -d openspec/changes/archive/*-<name>/ 2>/dev/null | tail -n1)"
   if [ -z "$archived" ] || [ ! -d "$archived" ]; then
     echo "FLAG: archived change dir for <name> not found; skipped kb-meta stamp."
   else
     cat > "$archived/kb-meta.yaml" <<EOF
   worktree: $(git rev-parse --show-toplevel)
   branch: $(git rev-parse --abbrev-ref HEAD)
   date: $(basename "$archived" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
   change: <name>
   EOF
   fi
   ```

   Guard the empty glob — unquoted it resolves to `/kb-meta.yaml` at the filesystem root. **Verify it landed**; missing means every future enrichment run re-reads this change's raw transcripts. `worktree` is the join key.
6. **Publish the QA report** when QA ran — load `qa-report-publish`.

Ends with: pushed, specs merged, change archived.
