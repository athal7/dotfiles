---
description: implement a change [issue|description], plan/build/review/ship
agent: lead
---

Workflow: implement.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Workspace setup — branch/worktree if needed per repo conventions; link `openspec/` to the durable store
- Plan — dispatch the `explore`/`scout` subagents (`task` tool, `subagent_type: explore` / `subagent_type: scout`) to gather, dispatch the `plan` subagent (`task` tool, `subagent_type: plan`), create proposal, present for approval
- Build — implement tasks via openspec-apply-change, present changeset for approval
- Review — dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`, static), dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) if UI touched, route findings, present for approval
- Ship — commit, push, watch CI, merge delta specs into the durable store

## Workspace setup

Check the repo's AGENTS.md for branch conventions. If the repo uses feature branches and you're on `main`: load the `opencode` skill and use dispatch.md to create a worktree session for this work — the implementation should happen in an isolated worktree, not on main. If the repo commits directly to main (e.g., dotfiles), skip the worktree step.

**Spec-store link — run this BEFORE the Plan phase reads `openspec/specs/`.** `/implement` often runs in ephemeral worktrees, but `openspec/` (accumulated `specs/` and per-change `changes/`) is durable per-repo memory that must survive teardown and be shared across all worktrees of the repo. Link the worktree's `openspec/` to a durable per-repo store at `~/.local/share/kb/openspec/<repo-slug>/`. Run from the worktree root:

```bash
# Derive a STABLE repo slug from the git common dir — NEVER the worktree basename
# (worktree dirs are branch-suffixed/unstable and would scatter the store).
# --path-format=absolute is MANDATORY: the relative form returns a bare ".git",
# and `dirname` of that breaks.
slug="$(basename "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")")"
store="$HOME/.local/share/kb/openspec/$slug"
mkdir -p "$store/specs" "$store/changes"

if [ -L openspec ] && [ "$(readlink openspec)" = "$store" ]; then
  : # already linked to the store → no-op (dangling-link guard: store recreated above)
elif [ ! -e openspec ] && [ ! -L openspec ]; then
  ln -s "$store" openspec                                   # absent (and not a broken/other symlink) → create the link
else
  # Real dir, or a symlink to some OTHER target. The one-time migration already
  # linked every repo that had a real openspec/; fresh worktrees never carry one
  # (openspec/ is gitignored). So this is unexpected — REFUSE, touch nothing.
  echo "FLAG: $PWD/openspec is an unexpected real/other path (not a symlink to $store)."
  echo "Run the one-time link/migration manually to reconcile, then re-run. Left it untouched."
  exit 1
fi
```

This is idempotent (safe every Workspace-setup) and non-destructive — it never `rm`s a real directory. Only two cases occur in steady state: `openspec` is already the store symlink (no-op) or absent (created). Anything else (a real `openspec/` dir, or a symlink to a different target) is unexpected and is REFUSED rather than seeded or relinked — the one-time migration already linked every repo that had real specs, and `openspec/` is gitignored so fresh worktrees never carry one. The symlink grounds Plan's `openspec/specs/` read in the durable accumulated specs with no extra "read the kb" instruction — the symlink IS the discovery mechanism. If the FLAG fires, surface it to the user and reconcile before proceeding.

## Plan

Gather context, then get a design recommendation:

1. Dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to gather internal context: relevant source files, git history, the referenced issue/PR/ticket, and any `openspec/specs/` requirements that constrain this change.
2. When the change involves unfamiliar libraries, dependencies, or external APIs, dispatch the `scout` subagent (`task` tool, `subagent_type: scout`) for external research (docs, dependency source, version constraints, changelogs) — alongside or before the `plan` subagent.
3. Dispatch the `plan` subagent (`task` tool, `subagent_type: plan`) with the user's request, the gathered context, any scout findings, and relevant spec constraints, asking "what should change and why?" Plan returns a structured recommendation with reasoning and tradeoffs.

Create an OpenSpec proposal to persist the plan: dispatch the `build` subagent (`task` tool, `subagent_type: build`) with `openspec-propose` to create proposal + design + tasks. The proposal is the plan artifact — it captures what changes, why, and the task breakdown. This step is mandatory, not conditional on change size.

**`openspec/` is git-ignored, but it is NOT throwaway.** Durability comes from the kb symlink (set up in Workspace-setup), not from git — the `specs/` (accumulated requirements) and `changes/` (proposals + design rationale) are durable per-repo memory that persists across worktrees. Don't try to `git add` `openspec/` (it's ignored on purpose), and don't treat a missing `openspec/` as a blocker — the link step creates it. Just don't mistake "git-ignored" for "disposable."

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

Load `commit` skill for staging, test verification, and commit message format. Then load `push` skill for branch naming, merge request creation, and CI watching. All remote actions require explicit approval.

**CI failure → diagnose and route:** code fix → dispatch the `build` subagent (`task` tool, `subagent_type: build`). Approach problem → re-dispatch the `plan` subagent (`task` tool, `subagent_type: plan`). Flaky test → re-run. Do not treat CI failure as terminal.

**Merge delta specs into the durable store (after a successful commit + push).** The change's delta specs under `openspec/changes/<name>/specs/` must be folded into the durable `openspec/specs/` (through the symlink) so the accumulated requirements compound. Do this as a **reviewed, non-lossy LLM merge**: read BOTH sides — the existing durable requirement and the delta — and integrate them, preserving existing scenarios and flagging any conflicts or supersession to the human for resolution. This reviewed merge is SEPARATE from archiving and is NOT performed by `openspec archive` — do it FIRST.

**Archive the completed change (standard step, after the reviewed merge above).** From the repo root run `openspec archive <name> --skip-specs -y`. `--skip-specs` avoids OpenSpec's lossy replace-only spec auto-fold (the unimplemented-merge data-loss bug as of openspec 1.4.1) — the durable `specs/` are updated only by the reviewed merge above, never by archive. `-y` runs it non-interactively so it won't hang. Because `openspec/` is a symlink into the durable store, archive writes through it and date-stamps the change as `changes/archive/YYYY-MM-DD-<name>/`, which is exactly what daily enrichment reads.

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

- **v1 is detection-only.** Surface conflicts to the human (the existing Plan read of `specs/` carries them forward as a plan-level finding); never run automated reconciliation, and never let the lossy auto-fold overwrite the durable specs. CI watch is best-effort and does NOT gate the merge.

$ARGUMENTS
