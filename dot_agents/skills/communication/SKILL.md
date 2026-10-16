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

## Draft-first workflow

When the user has not provided exact final wording for an external communication, create a local draft before using an integration write tool.

- Write the literal outbound body to `tmp/<slug>.md` under the active workspace.
- Use a collision-safe slug, such as `<YYYYMMDD-HHMM>-<topic>`, or confirm that an existing draft and sidecar are intentionally being replaced. Never silently overwrite an existing pair.
- Include the AI-authorship marker in the draft body when it applies. Add it before stopping so the reviewed file is complete.
- Keep destination, recipients, subject, thread, schedule, tool, and other metadata in the matching `<slug>.json` sidecar.
- Keep the `.md` file limited to the outbound body. Do not put YAML frontmatter or review notes in it.
- Store drafts under the active workspace. Do not create them outside it.
- Stop after creating the draft and give the user its path so they can edit it directly.
- If the user requests changes, update the draft file and stop again.
- When the user requests sending, read both the body file and matching sidecar immediately before constructing the integration call. Treat the `.md` contents as the authoritative body and the `.json` contents as authoritative metadata. Do not rewrite, paraphrase, or append to the body or silently replace the metadata.

If the user provides exact final wording and explicitly requests a send, a local draft is optional.

Do not use a remote Slack or Gmail draft as the editing surface when a local draft is requested. Remote draft creation is itself a remote write.

## AI-authorship marker

When a draft will be posted through an integration on the user's behalf, include this as the last line of the draft body when it applies:

```
*Co-authored with <model id>*
```

Do not add or change the marker after the user edits the draft.

Skip it when: relaying the user's words verbatim · titles · commit messages and merge request descriptions (the `Co-Authored-By` trailer already signals it) · Slack (its own send attribution covers it).
