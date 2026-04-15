---
name: thinking-tools
description: Use when facing a decision, unclear or recurring problem, system behavior question, communication challenge, or when generating novel solutions — loads structured thinking frameworks
license: MIT
metadata:
  author: athal7
  version: "1.0"
  provides:
    - thinking
---

# Thinking Tools

Given a situation, identify the right framework category, read the relevant file, and apply it.

## Categories

| Category | When to use | File |
|----------|-------------|------|
| **Problem framing & root cause** | Problem is unclear, recurring, or needs reframing | `frameworks/problem.md` |
| **Decision making** | Choosing between options, calibrating effort, prioritizing | `frameworks/decisions.md` |
| **Systems thinking** | Understanding why a system behaves the way it does | `frameworks/systems.md` |
| **Communication** | Writing clearly, giving feedback, resolving conflict | `frameworks/communication.md` |
| **Creative problem solving** | Generating novel solutions, exhausted obvious approaches | `frameworks/creative.md` |

## How to Route

Read the user's situation and pick the best-fit category. If a problem spans two categories (e.g. a decision *about* a system), read both files.

If the user names a specific framework (e.g. "use inversion" or "cynefin"), go straight to the relevant file — don't re-route.

## Reading a framework file

Use the Read tool on the relevant file path:
- `~/.agents/skills/thinking-tools/frameworks/problem.md`
- `~/.agents/skills/thinking-tools/frameworks/decisions.md`
- `~/.agents/skills/thinking-tools/frameworks/systems.md`
- `~/.agents/skills/thinking-tools/frameworks/communication.md`
- `~/.agents/skills/thinking-tools/frameworks/creative.md`

Each file contains multiple frameworks. Pick the most relevant one and apply it. If two frameworks complement each other (noted in "Related Tools"), apply both.
