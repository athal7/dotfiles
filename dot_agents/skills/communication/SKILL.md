---
name: communication
description: Load when composing human-facing prose through an integration — chat messages, review comments, merge request descriptions, emails, doc bodies, ticket descriptions. Carries the AI-authorship attribution rule.
license: MIT
---
Load `knowledge-base` before collecting project, product, person, or decision context.


Tailor to the recipient — role, technical depth, your relationship with them. Some want two lines; some need the context.

Surface assumptions as questions, not conclusions: "I'm reading this as X — does that match?" beats "this is X." Informal, contractions fine, no corporate hedging. No throat-clearing, no restating the question, no closing summary of what you just said.

## AI-authorship marker

Posting composed prose through an integration on the user's behalf → append, as the last line:

```
*Co-authored with <model id>*
```

Skip it when: relaying the user's words verbatim · titles · commit messages and merge request descriptions (the `Co-Authored-By` trailer already signals it) · Slack (its own send attribution covers it).
