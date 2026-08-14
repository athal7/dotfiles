---
name: code-quality
description: Load when reviewing a diff and grading finding severity, or when deciding whether a pre-existing problem is in scope for the change in front of you. Supplies the severity rubric and the mechanical sweeps a review must not skip.
license: MIT
---

Name the pattern (Feature Envy, Premature Abstraction, Scattered Enforcement, …), propose a concrete refactoring move, and grade it with the rubric below. The catalog itself you already know; the rubric and the sweeps are what this skill exists for.

## Severity — "make the change easy, then make the easy change"

| Diff's relationship to a pre-existing problem | Grade |
|---|---|
| Doesn't worsen it — reads, passes through, no new callsite | **Skip.** Never flag ambient patterns the work doesn't touch. |
| Adds another callsite to an already-scattered pattern | **Blocker.** Stop and extract. |
| Would be simpler if the problem were fixed first | **Suggestion.** Name it as a prerequisite, propose a separate issue. |

Check version-control history before grading — confirm the issue is from this diff, not pre-existing.

## Mechanical sweeps — run these, they're what review misses

- **Propagation** — the diff renames, removes, or semantically changes a column, attribute, enum, scope, association, route, or method → search the *entire* codebase (source, views, JS, JSON, YAML, fixtures, exports, serializers, mailers, jobs, seeds, admin and marketing pages). Any surviving reference is a **blocker**.
- **Dead code** — every new function, method, scope, constant, or route: search for callers. Zero callers = dead.
- **Orphaned code** — every call the diff *removes*: does the target still have other callers? Last one removed = dead.
- **Caching correctness** — reads from memoization/Redis/framework cache: can the value be stale relative to what the operation needs, especially after writes?
- **Test validity** — a stub on a method outside the execution path means the test asserts nothing.
- **Test tier** — a test belongs at the lowest tier that can validate the behavior. Unit-testable logic reachable only through e2e is a finding; so is logic needing real interaction that's only mocked.

## Explaining for understanding — "understanding is the new bottleneck"

Don't just verify or approve. Write code reviews and change explainers to help humans understand and build shared mental models so they can actively participate.

- **Background first** — Teach the context of what was already there before explaining what changed. Build domain/system context.
- **Intuition before details** — State the high-level goal and conceptual model first. Use metaphors or conceptual maps before diving into lines of code.
- **Literate diff** — Walk through modified files in a logical narrative order, not alphabetical. Present the changes as a story/prose with embedded snippets.
- **Micro-worlds** — Suggest or write small helper tools, debuggers, or playgrounds (e.g. interactive dashboards, step-by-step command centers) to let the human play with the system. Agents can write code to help humans understand code.
- **Comprehension check** — Append a 3-5 question conceptual quiz at the end of major explainers to act as a speed regulator, verifying the developer actually retains the key insights before shipping.

## Prefer a fitness function to a repeated comment

When a finding is an instance of a standing convention — a naming rule, a layering boundary, a banned pattern, or guidance already written in an `AGENTS.md` that keeps getting missed — recommend encoding it as a lint rule, test, or CI gate. A rule enforced by tooling is verified continuously; a rule enforced by review commentary has to be re-cited from memory every time.

The mechanical sweeps above are the prime candidates: they're exhaustive, automatable scans. Run the manual sweep for the instance in front of you, but treat an unguarded one as a missing check.
