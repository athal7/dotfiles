---
description: implement a change [issue|description], plan/build/review/ship
agent: lead
---

Workflow: implement.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Workspace setup — branch/worktree if needed per repo conventions; set up `openspec/` (real dir + narrow store symlinks)
- Plan — dispatch the `explore`/`scout` subagents (`task` tool, `subagent_type: explore` / `subagent_type: scout`) to gather, dispatch the `plan` subagent (`task` tool, `subagent_type: plan`), create proposal, present for approval
- Build — implement tasks via openspec-apply-change, present changeset for approval
- Review — dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`, static), dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) if UI touched, route findings, present for approval
- Ship — commit, push, watch CI, merge delta specs into the durable store

## Workspace setup

Check the repo's AGENTS.md for branch conventions. If the repo uses feature branches and you're on `main`: load the `opencode` skill and use dispatch.md to create a worktree session for this work — the implementation should happen in an isolated worktree, not on main. If the repo commits directly to main (e.g., dotfiles), skip the worktree step.

**Spec-store link — run this BEFORE the Plan phase reads `openspec/specs/`.** `/implement` often runs in ephemeral worktrees, but the accumulated `specs/` and archived `changes/` are durable per-repo memory that must survive teardown and be shared across all worktrees of the repo. The layout is a REAL `openspec/` directory in the worktree with only two NARROW symlinks into a durable per-repo store at `~/.local/share/kb/openspec/<repo-slug>/`: `openspec/specs` → `$store/specs` and `openspec/changes/archive` → `$store/changes/archive`. In-flight change docs at `openspec/changes/<name>/` are REAL worktree files (so they surface in the opencode review UI for inline comments); only the specs and archive leaves point outside the worktree. Run from the worktree root:

```bash
# Derive a STABLE repo slug from the git common dir — NEVER the worktree basename
# (worktree dirs are branch-suffixed/unstable and would scatter the store).
# --path-format=absolute is MANDATORY: the relative form returns a bare ".git".
slug="$(basename "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")")"
store="$HOME/.local/share/kb/openspec/$slug"
mkdir -p "$store/specs" "$store/changes/archive"   # both symlink targets must exist

# Ensure a path is a symlink to $target: create if absent, no-op if correct,
# REFUSE (don't clobber) if it exists as anything else.
ensure_link() {  # $1=link path  $2=target
  if [ -L "$1" ]; then
    [ "$(readlink "$1")" = "$2" ] && return 0
    echo "FLAG: $PWD/$1 → $(readlink "$1") but expected $2. Left untouched."; return 1
  elif [ -e "$1" ]; then
    echo "FLAG: $PWD/$1 exists and is not a symlink (expected → $2). Left untouched."; return 1
  fi
  ln -s "$2" "$1"
}

if [ -L openspec ]; then
  # A symlink AT openspec is the OLD whole-dir layout (or a stray link). Never
  # auto-convert: in-flight changes in the store may belong to other worktrees.
  echo "FLAG: $PWD/openspec is a whole-directory symlink → $(readlink openspec)."
  echo "      Run the one-time OpenSpec migration to convert it to the real-dir +"
  echo "      narrow-symlink layout, then re-run Workspace setup. Left it untouched."
  exit 1
elif [ -d openspec ]; then
  # Real dir → already migrated (or partial). Make it idempotently correct.
  mkdir -p openspec/changes
  ensure_link openspec/specs          "$store/specs"          || exit 1
  ensure_link openspec/changes/archive "$store/changes/archive" || exit 1
elif [ ! -e openspec ]; then
  # Absent → create the new structure fresh.
  mkdir -p openspec/changes
  ln -s "$store/specs"          openspec/specs
  ln -s "$store/changes/archive" openspec/changes/archive
else
  echo "FLAG: $PWD/openspec is an unexpected path (a real file?). Left it untouched."
  exit 1
fi
```

This is idempotent (safe every Workspace-setup) and non-destructive — it never `rm`s a real directory or clobbers an existing path. It handles four states: **absent** → create the real dir plus the two narrow symlinks; **real dir** → repair idempotently (ensure the two leaf symlinks point at the store, leaving in-flight real change dirs alone); **old whole-dir symlink** (a symlink AT `openspec`) → REFUSE and exit, pending the one-time migration (auto-converting could corrupt other worktrees whose in-flight changes live in the shared store); **unexpected** (e.g. a real file) → refuse. The `openspec/specs` symlink grounds Plan's `openspec/specs/` read in the durable store, while in-flight `changes/<name>/` are real worktree files visible to review. If a FLAG fires, surface it to the user and reconcile before proceeding.

## Plan

Gather context, then get a design recommendation:

1. Dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to gather internal context: relevant source files, git history, the referenced issue/PR/ticket, and any `openspec/specs/` requirements that constrain this change.
2. When the change involves unfamiliar libraries, dependencies, or external APIs, dispatch the `scout` subagent (`task` tool, `subagent_type: scout`) for external research (docs, dependency source, version constraints, changelogs) — alongside or before the `plan` subagent.
3. Dispatch the `plan` subagent (`task` tool, `subagent_type: plan`) with the user's request, the gathered context, any scout findings, and relevant spec constraints, asking "what should change and why?" Plan returns a structured recommendation with reasoning and tradeoffs.

Create an OpenSpec proposal to persist the plan: dispatch the `build` subagent (`task` tool, `subagent_type: build`) with `openspec-propose` to create proposal + design + tasks. The proposal is the plan artifact — it captures what changes, why, and the task breakdown. This step is mandatory, not conditional on change size.

**`openspec/` is a real dir, but it is NOT throwaway.** Only `openspec/specs` and `openspec/changes/archive` are git-ignored (they're symlinks into the durable store); in-flight `openspec/changes/<name>/` are intentionally NOT ignored so they surface in the opencode review UI for inline comments. Durability comes from the kb store at `~/.local/share/kb/openspec/<repo-slug>/` (set up in Workspace-setup), not from git — the durable `specs/` (accumulated requirements) and archived `changes/` (proposals + design rationale) are per-repo memory that persists across worktrees. Don't `git add` the `specs`/`archive` symlinks (they're the durable store), and don't blanket-`git add` in-flight change files into a code commit (they belong in the store and are moved there at archive time). Don't treat a missing `openspec/` as a blocker — the setup step creates it.

**Present the proposal for approval. Wait before proceeding.**

## Build

Load `openspec-apply-change` and work through the tasks. For each task, dispatch the `build` subagent (`task` tool, `subagent_type: build`) with strict TDD scope. Track progress via task checkboxes.

**Present the changeset for approval. Wait before proceeding.**

## Review

Dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`) against the changeset. Reviewer owns the static review protocol (multi-pass analysis, verification) and returns findings classified by routing destination.

When the changeset touches UI (views, templates, CSS, frontend), also dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) for browser functional verification of the affected flows. Both reviewer and qa findings feed into the routing below.

**Route the returned findings:**
- **Build-level** (bug, style, missing test) → dispatch the `build` subagent (`task` tool, `subagent_type: build`) for a targeted fix, then re-dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`) on the fix
- **Plan-level** (wrong approach, missing requirement) → re-dispatch the `plan` subagent (`task` tool, `subagent_type: plan`), update the proposal
- **Human judgment** (tradeoff, scope question) → present to the user and wait

**Present the review for approval before proceeding.**

## Ship

Commit and push the code FIRST; the OpenSpec store steps (reviewed spec merge → archive → kb-meta stamp) run AFTER a successful push. The commit-skill guard already unstages in-flight `openspec/changes/<name>/` files, so the code commit stays clean without needing the change archived out of the worktree first. Archiving before push would prematurely finalize the durable store — moving the change to archive and folding its specs — for code that may not pass CI or get push approval; so archive runs after, not before, the push.

**Commit, push, watch CI (FIRST).** Load `commit` skill for staging, test verification, and commit message format — its in-flight-change `git reset` guard keeps `openspec/changes/<name>/` paths out of the code commit even though they're un-ignored and visible in review. Then load `push` skill for branch naming, merge request creation, and CI watching. All remote actions require explicit approval. **CI failure → diagnose and route:** code fix → dispatch the `build` subagent (`task` tool, `subagent_type: build`); approach problem → re-dispatch the `plan` subagent (`task` tool, `subagent_type: plan`); flaky test → re-run. Do not treat CI failure as terminal.

**Merge delta specs into the durable store (after a successful commit and push, before archiving).** The change's delta specs under `openspec/changes/<name>/specs/` must be folded into the durable `openspec/specs/` (through the symlink) so the accumulated requirements compound. Do this as a **reviewed, non-lossy LLM merge**: read BOTH sides — the existing durable requirement and the delta — and integrate them, preserving existing scenarios and flagging any conflicts or supersession to the human for resolution. This reviewed merge is SEPARATE from archiving and is NOT performed by `openspec archive` — do it FIRST, before archive.

**Archive the completed change (after the reviewed merge above).** From the repo root run `openspec archive <name> --skip-specs -y`. `--skip-specs` avoids OpenSpec's lossy replace-only spec auto-fold (the unimplemented-merge data-loss bug as of openspec 1.4.1) — the durable `specs/` are updated only by the reviewed merge above, never by archive. `-y` runs it non-interactively so it won't hang. Because `openspec/changes/archive` is a symlink into the store, archive moves the in-flight change through it into the store and removes it from the worktree, date-stamping it as `changes/archive/YYYY-MM-DD-<name>/`, which is exactly what daily enrichment reads.

**Stamp correlation metadata into the archived change (right after archive).** Write a small `kb-meta.yaml` into the archived change dir so daily enrichment can correlate opencode sessions to this change and SKIP re-reading their (token-expensive) transcripts — for those sessions it uses the change's `design.md`/specs instead. The archived dir lives in the durable store via the symlink at `openspec/changes/archive/<YYYY-MM-DD>-<name>/`; determine its exact name from the archive output or by globbing. Run from the repo root:

```bash
archived="$(ls -d openspec/changes/archive/*-<name>/ 2>/dev/null | tail -n1)"   # exact dated dir from the archive
if [ -z "$archived" ] || [ ! -d "$archived" ]; then
  # Empty glob would make "$archived/kb-meta.yaml" resolve to /kb-meta.yaml (fs root).
  # Skip the stamp loudly rather than write to the wrong place; don't fail Ship.
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

`worktree` is the absolute repo/worktree root — it equals the opencode session's `directory`, which is the join key `/kb-enrich` uses to exclude these sessions from transcript reads.

**Assemble and publish the unified review report.** Load the `review-publish` skill and follow it — assemble the AC-organized report in BOTH forms: `review-report.html` (local-only, embeds the rendered diffs + screenshots) and `review-report.md` (hosted, deep-links the diffs). WHEN QA ran, fuse the reviewer findings with the qa evidence; WHEN QA did not run, create the `qa-<ts>` session dir yourself and write both forms with verdict `n/a` (the findings half is always present). Open the `.html` locally, then after approval host the `.md` (it backs the `full report ↗` link and renders the screenshots) and upsert the **full Template-A collapsed-AC block** — visible verdict+counts+link line, `<sub>` provenance, per-AC `<details>`/`<details open>` sections with a head-pinned code reference + classified findings, Scope & cross-cutting, Could not verify — into the merge request **description** between the `<!-- qa:start -->` / `<!-- qa:end -->` markers. The merge request must exist first (the push above creates it), so this runs after push and after approval. **Publish when** QA ran in the Review phase **OR** noteworthy surviving human/plan findings remain; **skip** for a clean non-UI self-review.

- **v1 is detection-only.** Surface conflicts to the human (the existing Plan read of `specs/` carries them forward as a plan-level finding); never run automated reconciliation, and never let the lossy auto-fold overwrite the durable specs. CI watch is best-effort and does NOT gate the merge.

$ARGUMENTS
