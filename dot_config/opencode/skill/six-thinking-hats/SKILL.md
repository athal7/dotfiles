---
name: six-thinking-hats
description: Apply Six Thinking Hats to examine a decision from six distinct perspectives — positivity, creativity, emotions, data, downside, and process control
---

# Six Thinking Hats

**Category:** Decision Making
**Source:** Edward de Bono

Use this when you need to look at a decision from multiple angles to avoid overlooking important aspects. Works for individual thinking or group discussion.

## The Six Hats

| Hat | Focus | Questions to ask |
|-----|-------|-----------------|
| **Yellow** | Positivity | What are the benefits? What opportunities does this open? |
| **Green** | Creativity | What creative options exist? What ideas haven't been considered? |
| **Red** | Emotions | How do I/others feel about this? What does intuition say? |
| **White** | Data | What does the data show? What are the facts and trends? |
| **Black** | Downside | What are worst-case scenarios? What might not work? |
| **Blue** | Process | Is the discussion making progress? Should we shift perspective? |

## How to Apply

1. **State the decision** clearly upfront.
2. **Work through each hat** — either sequentially or assign hats to different team members.
3. **Yellow first** to start with benefits and opportunity framing.
4. **Black hat** to stress-test against downsides.
5. **White hat** to ground in data and evidence.
6. **Red hat** to surface emotional/intuitive signals.
7. **Green hat** to generate creative alternatives.
8. **Blue hat** (facilitator role) to manage progress and pivot when stuck.

## Agent Workflow

When asked to analyze a decision using Six Thinking Hats:

1. Present the decision being analyzed.
2. Go through each hat in sequence, producing 2–4 observations per hat.
3. Synthesize: what perspective was most revealing? What's the recommended path forward?
4. Flag any hat where the analysis is weak due to missing information.

## Example Application (Software Architecture)

**Decision:** Migrate from monolith to microservices.

- **Yellow:** Enables independent scaling, faster team autonomy, polyglot flexibility.
- **Green:** Could we try strangler fig pattern instead? Or event-driven modular monolith?
- **Red:** Team is anxious about operational complexity. Leadership excited about industry trend.
- **White:** Current p99 latency is 800ms. Team has zero k8s experience. 3 incidents/month from deployment coupling.
- **Black:** Distributed systems failures, network overhead, data consistency nightmares, 6-month productivity loss.
- **Blue:** We've spent 20 min on Yellow/Green — let's spend equal time on Black before deciding.

## Related Tools

- **Inversion** — pairs well with Black hat thinking
- **Decision Matrix** — use after Six Thinking Hats to score options
- **Productive Thinking Model** — for deeper creative solution generation (Green hat)
