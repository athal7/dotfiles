---
name: concept-map
description: Build a concept map to visualize relationships between entities in a system or domain — useful for onboarding, design, and knowledge gaps
---

# Concept Map

**Category:** Systems Thinking
**Source:** Joseph Novak and Alberto Caňas

Use this when you need to understand or communicate how parts of a system relate to each other. Especially useful for: onboarding to a new codebase or domain, designing system architecture, finding knowledge gaps, or aligning teams on how something works.

## Steps

### 1. Define a focus question
A good concept map needs a specific angle. Examples:
- "How does authentication work in this system?"
- "What are the relationships between teams, services, and data stores?"
- "How does the deployment pipeline work?"

### 2. Identify key entities (15–25)
List the important nouns in your domain — people, systems, processes, data types, concepts. Keep it to entities that actually change or interact.

### 3. Sort from general to specific
Arrange your list from most general (high-level concepts) to most specific (concrete instances). This helps build a useful hierarchy in the map.

### 4. Connect entities with labeled relationships
Draw links between entities with a verb or phrase that describes the relationship:
- "depends on"
- "sends events to"
- "is owned by"
- "stores data in"
- "triggers"
- "validates"

The goal: any two connected entities should form a readable sentence: `[Entity A] [relationship] [Entity B]`.

### 5. Look for gaps
Where are connections missing that should exist? What entities are isolated? These are knowledge gaps or design problems.

## Agent Workflow

When asked to map a concept or system:

1. Confirm the focus question.
2. Identify 10–20 key entities from the description or codebase.
3. Render as a structured relationship list:
   ```
   User → [creates] → Order
   Order → [contains] → LineItems
   Order → [triggers] → PaymentService
   PaymentService → [writes to] → PaymentsDB
   PaymentsDB → [read by] → ReportingService
   ```
4. Highlight any entity with no connections (orphaned) or with many connections (high-coupling risk).
5. Answer the focus question using the map.

## Example

**Focus question:** How does a feature request become deployed code?

```
Product Manager → [writes] → Feature Spec
Feature Spec → [reviewed by] → Engineering Lead
Engineering Lead → [creates] → GitHub Issue
GitHub Issue → [assigned to] → Developer
Developer → [opens] → Pull Request
Pull Request → [triggers] → CI Pipeline
CI Pipeline → [runs] → Tests
CI Pipeline → [runs] → Linter
Pull Request → [reviewed by] → Reviewer
Reviewer → [approves] → Merge
Merge → [triggers] → Deploy Pipeline
Deploy Pipeline → [deploys to] → Staging
Staging → [promoted to] → Production
```

**Gap identified:** No connection between Deploy Pipeline and monitoring/alerting — is there automatic validation post-deploy?

## Tips

- Don't try to be exhaustive. A map with 50 nodes is unreadable. Prioritize the entities most relevant to the focus question.
- Cross-links (connections between branches) are valuable — they often reveal non-obvious dependencies.
- Treat gaps as hypotheses, not failures. "We don't know" is useful information.

## Related Tools

- **Connection Circles** — for mapping causal/feedback relationships specifically (not just any relationship)
- **Issue Trees** — for decomposing problems rather than mapping systems
- **Iceberg Model** — when the map reveals systemic behavior you want to explain
