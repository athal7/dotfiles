# Architecture Decision Record (ADR)

An ADR documents a significant architectural decision: what was decided, why, and what alternatives were considered. Its value is future context — six months from now, someone will ask "why is it like this?" The ADR is the answer.

## When to write an ADR

Write an ADR when:
- The decision is hard to reverse (or expensive to reverse)
- Multiple reasonable approaches exist and you chose one
- Future engineers are likely to question the choice
- The decision crosses system boundaries or affects other teams

Skip the ADR for: style/convention choices, trivial implementation details, decisions that are easily changed.

## ADR as a thinking tool

Writing an ADR before implementing forces you to articulate why. If you can't write a convincing "decision" section, you may not have decided yet.

---

## Structure

### Status
`Proposed` | `Accepted` | `Deprecated` | `Superseded by ADR-XXX`

### Context
What situation or problem led to this decision? What forces are at play?

Include:
- The constraints you're working within (performance, team size, existing stack, timeline)
- The trigger: what made this decision necessary now?
- Any background a future reader would need

Keep it factual. This is not the place to argue for your preferred option.

### Decision
State the decision plainly in one sentence. Then explain why.

- "We will use PostgreSQL as the primary data store."
- "We will implement the queue using Redis Streams rather than a managed queue service."

The "why" should reference the context directly — which forces drove you to this option over others?

### Decision matrix
Use a table to compare options across the criteria that actually matter for this decision. Pick 3-5 criteria — more than that and the table becomes noise.

```markdown
| Criterion          | Option A (chosen) | Option B       | Option C       |
|--------------------|:-----------------:|:--------------:|:--------------:|
| Ops familiarity    | ✅ High           | ⚠️ Medium      | ❌ Low         |
| Horizontal scale   | ✅ Native         | ✅ Native      | ⚠️ Manual      |
| Full-text search   | ❌ Needs plugin   | ✅ Built-in    | ✅ Built-in    |
| Migration tooling  | ✅ Mature         | ⚠️ Limited     | ❌ None        |
| Cost (hosted)      | ⚠️ Medium         | ❌ High        | ✅ Low         |
```

Choose criteria based on what the team actually debated — don't invent criteria to make the chosen option look better. If two options tie on a criterion, say so.

### Alternatives considered
For each alternative in the matrix, add a brief narrative paragraph explaining why it was viable and what specifically ruled it out. The table shows *what*; the prose explains *why*.

If you only considered one option, either the decision isn't significant enough for an ADR, or you haven't thought carefully enough.

### Consequences
What becomes easier? What becomes harder? What new constraints does this decision create?

Be honest about the tradeoffs. ADRs that only list upsides aren't useful.

```
Good:
- Positive: Enables horizontal scaling without application changes
- Positive: Ops team already familiar with the tooling
- Negative: Requires managing schema migrations carefully
- Negative: No full-text search without additional tooling
```

### Links *(optional)*
- Related ADRs
- Design doc, RFC, or discussion thread where this was debated
- Relevant external resources

---

## Fill-in template

```markdown
# ADR-NNN: [Short title of the decision]

**Status**: Proposed

## Context
[What situation led to this decision? What constraints are you working within?]

## Decision
[One sentence: what are we doing?]

[Why: which forces or requirements drove you to this option?]

## Decision matrix

| Criterion     | [Option A — chosen] | [Option B]  | [Option C]  |
|---------------|:-------------------:|:-----------:|:-----------:|
| [Criterion 1] | ✅                  | ⚠️          | ❌          |
| [Criterion 2] | ✅                  | ✅          | ⚠️          |
| [Criterion 3] | ⚠️                  | ❌          | ✅          |

## Alternatives considered

### [Option A — chosen]
[Why viable. Why it won.]

### [Option B]
[Why viable. What specifically ruled it out.]

### [Option C]
[Why viable. What specifically ruled it out.]

## Consequences
- Positive: [What becomes easier]
- Positive: [What becomes easier]
- Negative: [What becomes harder or what new constraints exist]
- Negative: [What becomes harder or what new constraints exist]
```

---

## Common mistakes

**Decision buried in the consequences**: State the decision explicitly at the top of the Decision section. Don't make the reader infer it.

**No real alternatives**: "We considered doing nothing" is not a genuine alternative unless it was. Include the options you actually debated.

**Written after the fact with hindsight bias**: The best ADRs are written at decision time, not during a post-mortem. Alternatives look less attractive in retrospect.

**Too much implementation detail**: An ADR is about *why*, not *how*. "We'll use Postgres" is an ADR. "Here's the schema" belongs in a design doc or ticket.

**Updating an accepted ADR**: Don't edit an accepted ADR to make it say something different. Mark it `Deprecated` or `Superseded by ADR-XXX` and write a new one. The historical record matters.

---

## Numbering and location

Store ADRs in `docs/decisions/` or `docs/adr/`. Name them `NNN-short-title.md` (e.g. `0012-use-postgres-for-primary-store.md`). Keep a running index in `docs/decisions/README.md` or similar.

Link ADRs from the relevant project or epic in your issue tracker.
