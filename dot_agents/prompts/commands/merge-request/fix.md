Batch the whole cycle: fix every actionable thread first — directly if you have `edit`/`write` tools in this session, otherwise dispatch `build` (delegation is also fine with those tools, when it earns its keep) — then **one** commit and push, then resolve every fixed thread together. Load `incremental-implementation` for the direct-fix path; no code comments, whether direct or dispatched.

**QA before that push** if any fix touches views, templates, CSS, or frontend — once, covering every UI-touching fix (load `qa-verification` for the method and report contract; on omp, construct the task() dispatch from it directly). Route findings the same way: direct fix or `build`. Skip entirely when no fix touches UI.

**Resolve silently, in one pass** — no comment, just mark resolved.

**Batch the non-fix replies** — declines, deferrals, questions, added context. Draft them together, present every reply's full text as one approval, then post consecutively.

**Look for a fitness function.** Repetition is invisible inside a single changeset, so don't wait to see an issue twice. Ask whether the feedback expresses a *convention* the repo should hold everywhere — a naming rule, an architectural boundary, a banned pattern. The strongest signal is feedback pointing at guidance already written down that keeps getting missed: a soft nudge nobody follows is a prime candidate to replace with a lint rule, test, or CI gate rather than restate.

Ends with: fixes pushed, threads resolved.
