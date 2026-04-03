---
name: ishikawa-diagram
description: Use the Ishikawa (fishbone/cause-and-effect) diagram to identify root causes of a problem by mapping contributing factors
---

# Ishikawa Diagram

**Category:** Problem Solving
**Also called:** Fishbone diagram, Cause-and-effect diagram
**Source:** Kaoru Ishikawa

Use this when you need to identify root causes of a complex problem rather than treating symptoms. Especially effective for recurring or multi-factor issues.

## The Four Steps

### 1. Define the problem
State the problem clearly and specifically. This is the "head" of the fish. A vague problem produces vague causes.

### 2. Identify contributing factors or categories
List the major factor categories that could contribute to the problem. Plot them as "bones" off the main spine.

**Generic categories to start with (the 6 M's):**
- People (Man)
- Equipment (Machine)
- Methods
- Measurement
- Materials
- Environment

Adapt these to your domain — for software, consider: Code, Process, Infrastructure, People, Data, External.

### 3. Find possible root causes per factor
For each factor, ask **"Why is this happening?"** and list specific causes as sub-branches. Use Five Whys to go deeper. One problem can have multiple root causes.

### 4. Analyze the diagram
Look across all branches. Identify the most likely or most impactful root causes. Decide what to investigate or fix first.

## Agent Workflow

When asked to apply an Ishikawa diagram:

1. **State the problem** at the top.
2. **List factor categories** (propose 4–6 relevant to the domain).
3. **Under each factor**, enumerate 2–4 specific possible root causes.
4. **Render as structured list** (since ASCII fishbones are hard to read):
   ```
   Problem: [X]
   ├── Factor A
   │   ├── Cause A1
   │   └── Cause A2
   ├── Factor B
   │   ├── Cause B1
   │   └── Cause B2
   ```
5. **Analyze**: identify the top 2–3 most likely root causes and recommend next investigative steps.

## Example

**Problem:** Declining new user sign-ups

```
├── Landing Page
│   ├── Poor conversion copy
│   └── Slow page load time
├── Marketing
│   ├── Targeting wrong audience
│   └── Budget reduced last quarter
├── Competition
│   ├── Competitor launched free tier
│   └── Better onboarding experience
├── Product
│   ├── Sign-up flow has too many steps
│   └── No social sign-in option
```

**Analysis:** Start by checking conversion rate data — if traffic is steady but conversion dropped, focus on Landing Page and Product branches first.

## Related Tools

- **First Principles** — for deeper "why" questioning within each branch
- **Issue Trees** — alternative structured problem decomposition
- **Five Whys** — technique to use within each branch
