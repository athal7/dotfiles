---
name: communication
description: Load when composing human-facing prose through an integration — chat messages, review comments, merge request descriptions, emails, doc bodies, ticket descriptions. Carries the AI-authorship attribution rule.
license: MIT
---
Use Mnemopi recall for relevant agent-learned context. For authoritative collected facts, citations, or source verification, use OMP’s `vault://` interface; never substitute memory, CQ, or direct backing-file access for the vault.

## Concision

- For external communications—including initial issue/proposal bodies and replies—lead with the main point and keep the default short. For longer messages, use Minto Pyramid framing: conclusion first, grouped reasons next, supporting evidence last. For complex proposals, use an issue tree to group non-overlapping concerns, cover necessary scope, and prioritize high-impact branches; omit speculative branches and low-value detail. Keep the problem, recommendation, essential tradeoffs/evidence, and decision needed; cut repetition and tangents. Expand only for accuracy or when requested.

## Voice

- Sound like a direct, relaxed colleague, not a formal announcement template. Prefer plain language, contractions, and short paragraphs; use warmth sparingly and naturally.
- Lead with the outcome or the specific question. Keep Slack updates especially brief; include only the context needed to understand the change or respond.
- Make status, uncertainty, risk, and the requested next step explicit when they matter. Do not imply a change is complete, approved, or live before verifying it.
- Use one canonical link when it gives readers the details; avoid reproducing a guide or PR in the message.
- Follow established channel conventions exactly (including terse reaction-plus-link review requests). Check whether a request is already assigned or posted before asking again.
- Match the user's conversational register, not typing errors: preserve technical capitalization and names, and do not imitate typos or force lowercase into polished prose.

## Rollout announcements

- For rollout-completion announcements, lead with what is now live. Once the rollout is complete and verified, send one brief, conversational update with a single canonical guide link; keep operational detail in the guide.
- Do not repost or duplicate an announcement already sent. If people need advance notice or approval before activation, send that separately before rollout; a post-rollout update does not replace it.

## AI-authorship marker

When posting a message through an integration on the user's behalf, include this as the last line of the message body when it applies:

```
*Co-authored with <model id>*
```

Skip it when: relaying the user's words verbatim · titles · commit messages and merge request descriptions (the `Co-Authored-By` trailer already signals it) · Slack (its own send attribution covers it).
