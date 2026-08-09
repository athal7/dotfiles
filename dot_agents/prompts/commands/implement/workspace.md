Branch conventions live in the repo's AGENTS.md. Worktree isolation belongs to the session tooling — never create one here.

| State | Do |
|---|---|
| Already in a worktree or on a feature branch | Proceed in place |
| On `main`, feature-branch repo | Create `<type>/<short-description>` off `origin/main`, incorporating the issue id. Don't ask |
| Repo commits straight to main | Work in place |

Then run `openspec-worktree-link` **before Plan reads any specs**. It links `openspec/specs` and `openspec/changes/archive` into the durable per-repo store, is idempotent, and refuses rather than clobbering — if it flags, fix that first.

Ends with: a branch and a linked spec store.
