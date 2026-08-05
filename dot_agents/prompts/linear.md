# Linear

Tool surface isn't a published fixed list — check your actual tools. Naming is consistent: `save_<object>` creates *and* updates, `list_<object>`/`get_<object>` reads.

Resolve team/project/parent with a read tool before any write — don't guess an ID. Before calling `save_<object>`, decide whether the task means create or update; the same tool does both.

**Listing comments includes archived issues** — don't skip an issue just because it looks closed.

**New issues default to the current user as assignee** — resolve the authenticated account via a viewer/self lookup, unless the task names someone else or asks for it unassigned.

Resolve team/project/user IDs to human-readable names before returning them. Cite the issue identifier (`ENG-123`) or URL.
