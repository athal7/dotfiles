---
name: implement
description: The full implementation loop — issue, workspace, plan, build, review, ship. Load when starting or resuming work on a change, or when the user invokes the implement workflow.
license: MIT
---

Track the six phases as a checklist, one in progress at a time. Trivial change → trivial plan, but every change runs the phases.

| Phase | Ends with |
|---|---|
| 1 Issue | a tracked issue, In Progress |
| 2 Workspace | a branch and a linked spec store |
| 3 Plan | **approved proposal** |
| 4 Build | tasks green |
| 5 Review | **approved changeset + QA** |
| 6 Ship | pushed, specs merged, change archived |

## 1. Issue

Every change is tracked — no exemptions. The issue id anchors the branch name, the proposal, and the commit.

Resolve the tracker for the repo's org:

```sh
ORG=$(git remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#')
chezmoi data --format json | jq -r ".orgs[\"$ORG\"].issues // empty"
```

`linear` → Linear; anything else, including empty → GitHub Issues.

| Situation | Do |
|---|---|
| Request names an issue | Fetch it |
| No reference | Search the tracker by keyword for existing open or recently-closed work. Clear match → confirm before adopting |
| No match | Draft title + short what/why, show it in full, create it |
| Tracking disabled entirely | Flag it, ask whether to proceed untracked |

Set it **In Progress** before any code work.

## 2. Workspace

Branch conventions live in the repo's AGENTS.md. Worktree isolation belongs to the session tooling — never create one here.

| State | Do |
|---|---|
| Already in a worktree or on a feature branch | Proceed in place |
| On `main`, feature-branch repo | Create `<type>/<short-description>` off `origin/main`, incorporating the issue id. Don't ask |
| Repo commits straight to main | Work in place |

Then run `openspec-worktree-link` **before Plan reads any specs**. It links `openspec/specs` and `openspec/changes/archive` into the durable per-repo store, is idempotent, and refuses rather than clobbering — if it flags, fix that first.

## 3. Plan

1. Gather internal context — source, history, the issue, constraining specs.
2. `scout` for external research when unfamiliar libraries or APIs are involved.
3. `plan` with the request, the context, and the spec constraints: "what should change and why?"

**Persist it as an OpenSpec proposal** via `openspec-propose` — proposal, design, tasks. Mandatory regardless of size. If the plan's Domain model proposes new or changed terms, write them to `changes/<name>/specs/domain-model/spec.md`: one Requirement per term (`Term: <X>` / `Bounded context: <X>`) with a `#### Scenario:` giving its canonical meaning and boundary, valid under `openspec validate`.

`openspec/` is real but not throwaway. Only `specs` and `changes/archive` are gitignored symlinks into the store; in-flight `changes/<name>/` are deliberately tracked so they show up in review. Never `git add` those two symlinks, and never blanket-add in-flight change files into a code commit.

**Present the proposal. Wait.**

## 4. Build

`openspec-apply-change`, then dispatch `build` per task under strict test-first scope. Track progress via the task checkboxes.

## 5. Review

Changeset touches UI (views, templates, CSS, frontend) → dispatch `qa` for browser verification of the affected flows.

Static and blast-radius review is **not** inline — it happens automatically on the pushed merge request.

| Finding | Route |
|---|---|
| Bug, style, missing test | `build`, then re-verify |
| Wrong approach, missing requirement | `plan`, update the proposal |
| Tradeoff or scope question | Carry into the gate |

**Present the diff, the QA report, and any carried findings. Wait.** (`lumen diff --save-viewed` persists per-file viewed state locally.)

## 6. Ship

Approved but not pushed. Order matters — store steps run *after* the push, since archiving early finalizes durable state for code that may still change.

1. **Commit and push.** Load `commit`, then `push`. For PR repos this opens the draft request; otherwise it's the whole ship step.
2. **Watch CI and automated review** per the `push` skill. A long-pending approval is not the finish line — the steps below still run in the same pass. CI failure routes like any Review finding: code fix → `build`, approach problem → `plan`, flaky → re-run. Never terminal.
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
