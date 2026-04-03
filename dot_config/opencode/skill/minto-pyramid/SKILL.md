---
name: minto-pyramid
description: Structure written communication using the Minto Pyramid — lead with the conclusion, support with key arguments, then provide details
---

# Minto Pyramid

**Category:** Communication
**Also called:** BLUF (Bottom Line Up Front)
**Source:** Barbara Minto

Use this when writing anything that needs to be read by busy people: proposals, reports, incident postmortems, engineering design docs, status updates, or Slack messages that require a decision.

## The Structure

```
[Conclusion / Recommendation]   ← lead with this
         ↓
[Key Argument 1]  [Key Argument 2]  [Key Argument 3]   ← why
         ↓                ↓                ↓
[Supporting    ] [Supporting    ] [Supporting    ]      ← evidence/detail
 data/evidence    data/evidence    data/evidence
```

Counter-intuitive but effective: **the busier the audience, the more they need the conclusion first.**

## The Three Layers

### 1. Conclusion (BLUF)
State the main recommendation, decision, or message upfront. One or two sentences.

> "We should migrate to Postgres. The current SQLite setup is blocking scale and two engineers have already scoped a 3-week migration path."

### 2. Key Arguments
The 2–4 main reasons that justify the conclusion. Written as summaries, not full explanations.

> "SQLite doesn't support concurrent writes — we're hitting this at current load."
> "Postgres gives us better tooling for debugging and observability."
> "Migration is low-risk: the data model maps 1:1 and we have a rollback plan."

### 3. Supporting Detail
Evidence, data, and specifics for each key argument. Readers who need convincing or full context read this. Others can stop at the key arguments.

> "Current SQLite write conflicts: 47 errors in the last 7 days. Peak concurrent write load: 12 connections. SQLite's documented limit: 1."

## Agent Workflow

When helping write a document, proposal, or message:

1. Ask: What is the one-sentence conclusion or recommendation?
2. Ask: What are the 2–4 strongest reasons to support it?
3. Ask: What data or evidence backs each reason?
4. Assemble in pyramid order: conclusion → arguments → details.
5. Check: Can someone who reads only the first paragraph make an informed decision?

## Example: Engineering Proposal

**Without Minto Pyramid:**
> "We've been looking at our database setup. SQLite was chosen originally for simplicity. However, we've been seeing some concurrency issues lately, which has caused some errors. After some research, we found that Postgres would be a better fit. We've also looked at the migration path and it seems feasible..."

**With Minto Pyramid:**
> **Recommendation:** Migrate from SQLite to Postgres in Q3. It's blocking our scaling and the migration is low-risk.
>
> **Why:**
> 1. SQLite write locks are causing 47 errors/week at current load — will get worse.
> 2. Postgres gives us row-level locking, better observability, and connection pooling.
> 3. Migration is 3 weeks of work with a complete rollback plan already scoped.
>
> **Details:** [link to full technical assessment]

## Tips

- Don't bury the recommendation in the conclusion paragraph. Put it in sentence one.
- Each key argument should be able to stand alone as a justification.
- In async text communication (Slack, email), readers often stop after the first paragraph. Make that paragraph complete.

## Related Tools

- **Situation-Behavior-Impact** — for feedback communication specifically
- **Issue Trees** — for structuring the supporting detail section of complex documents
