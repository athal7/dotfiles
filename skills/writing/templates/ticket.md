# Ticket / Issue Writing

A ticket is a scoped unit of work. It should be completable by one person in one sprint (or less). If it can't be, break it down.

## Structure

### Title
One line. Verb + noun. Describe the change, not the symptom.

- Bad: "Login broken"
- Good: "Fix session expiry not logging out users on mobile"
- Bad: "Improve performance"
- Good: "Reduce initial page load to under 2s on 3G"

### Problem
What is broken or missing, and why does it matter? Write for someone who doesn't have your context. Include:
- What currently happens
- What should happen instead
- Who is affected and how often
- Any known constraints or root cause hypotheses

### Outcome
How will we know this is done? Write a verifiable statement. Avoid "it works" — say what specifically works.

- Bad: "Users can log in"
- Good: "Users on mobile can complete login without being redirected to the home screen after session expiry; existing desktop behavior is unchanged"

If you can write a test for it, write the test description here.

### Context *(optional)*
Background the implementer needs but might not have:
- Prior attempts and why they failed
- Related issues or PRs
- External dependencies or constraints
- Links to design, spec, or conversation

Keep this short. If it's long, the ticket is too big.

### Acceptance Criteria *(optional but recommended)*
Checklist of specific, testable conditions. Use when the outcome statement alone isn't sufficient.

```
- [ ] User sees error message within 500ms of network failure
- [ ] Error message text matches copy in Figma (link)
- [ ] Existing happy-path tests still pass
- [ ] No console errors in browser devtools
```

### Labels / metadata
- **Priority**: Only mark Urgent if it's truly blocking revenue or users. High = this week. Medium = this sprint. Low = someday.
- **Estimate**: If you can't estimate it, it's not scoped enough.
- **Labels**: Use labels for cross-cutting concerns (e.g. `bug`, `ux`, `security`, `tech-debt`), not for project membership.
- **Parent**: Link to a parent epic/initiative if applicable.

---

## Fill-in template

```markdown
## Problem
[What is broken or missing? Who is affected?]

## Outcome
[How will we know this is done? What specifically works?]

## Context
[Background, constraints, prior attempts, links]

## Acceptance Criteria
- [ ] [Condition 1]
- [ ] [Condition 2]
```

---

## Common mistakes

**Too vague**: "Improve the dashboard" — impossible to estimate, no done condition.

**Too large**: If acceptance criteria has more than ~5 items, consider splitting.

**Solution-first**: "Add a Redis cache to the auth service" — describe the problem, let the implementer own the approach unless there's a strong reason to prescribe.

**Missing outcome**: "Investigate slow queries" is a task, not a ticket. Add "and document findings in [doc] with a recommended fix" to make it completable.

**Duplicating tracker fields in the description**: Don't repeat the assignee, labels, or priority in the body. Those live in the tracker metadata.
