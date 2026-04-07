# Project Update Writing

A project update communicates current status to stakeholders who are not in the day-to-day. It should give them enough information to feel confident (or appropriately concerned) without requiring follow-up questions.

## When to write a project update
- Weekly or bi-weekly cadence for active projects
- At milestone completion or milestone miss
- When health status changes (especially deteriorating)
- When a significant decision was made that stakeholders should know about

---

## Structure

### Health status
State it first, plainly. Don't bury the lede.

- **On track**: Proceeding as planned, no significant risks.
- **At risk**: A specific risk or blocker that *may* impact delivery. Name it.
- **Off track**: Something has changed. Delivery is likely to slip or scope must change. State what and why.

If the project is at risk or off track, write the problem statement *before* the progress summary, not after.

### Progress since last update
What moved forward? Focus on outcomes, not activity.

- Bad: "Worked on the auth integration all week"
- Good: "Auth integration merged; users can now sign in via Okta in staging"
- Bad: "Had several meetings about the API design"
- Good: "Agreed on API contract with platform team; design doc linked below"

Completed work: 2-4 bullet points max. What shipped or was completed.
In progress: What's actively being worked on right now. One line each.

### Blockers
Any issue preventing progress or requiring a decision from outside the team. For each blocker:
- What is blocked
- Who needs to act
- What the impact is if unresolved (timeline, scope)

Don't list concerns here — only true blockers that need action from someone not in your team.

### Decisions made *(optional)*
Key decisions made since the last update that stakeholders should know about. Especially anything that changed scope, approach, or timeline.

### What's next
Top 2-3 things happening before the next update. Gives readers a preview and creates accountability.

### Timeline / milestone status *(for milestone updates)*
If this update accompanies a milestone: state whether the milestone was hit, what it contained, and updated delivery projection.

---

## Health status decision guide

Ask yourself:
1. Are we on schedule to hit the next milestone?
2. Are there any blockers outside our team's control?
3. Has scope changed unexpectedly?

| Situation | Health |
|-----------|--------|
| On schedule, no blockers | On track |
| Might slip but we have a plan | At risk |
| Will slip, or need scope cut | Off track |
| Already slipped | Off track (with explanation) |

Don't round up. "At risk" that stays "on track" for two updates destroys credibility.

---

## Fill-in template

```markdown
**Health: [On track / At risk / Off track]**
[If at risk or off track: one sentence on why, before anything else.]

## Progress
- [Completed item 1]
- [Completed item 2]
- In progress: [Active work item]

## Blockers
- [Blocker] — needs [person/team] to [action] by [date] or [impact]

## Decisions
- [Decision made and brief rationale]

## What's next
- [Next thing 1]
- [Next thing 2]
```

---

## Tone guidance

**Write for a busy stakeholder, not a teammate.** They don't know the acronyms, the internal tool names, or the drama. Define abbreviations. Link to tickets rather than citing identifiers by name.

**Don't hide bad news.** A late update that's honest is better than an on-time update that softens the truth. Stakeholders forgive slips; they don't forgive surprises.

**Avoid activity theater.** "The team worked hard this week" and "We had 3 planning sessions" are not progress. Ship-centric language only.

**Be specific about dates.** "Soon" and "next sprint" are meaningless. "By March 14" is not.
