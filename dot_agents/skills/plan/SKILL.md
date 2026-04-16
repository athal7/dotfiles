---
name: plan
description: Present a plan and wait for user approval before implementing — load when a change spans multiple files or involves design decisions
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides:
    - plan
---

## When to Use

Load this skill before implementing any change that spans multiple files or involves design decisions. Skip for typo fixes, single-line config changes, and trivial one-file edits.

## Steps

### 1. Research

Explore the codebase, read relevant files, check git history. Use available capabilities (issues, meetings, logs) to gather context. Only ask the user when information isn't discoverable.

### 2. Write the Plan

The plan must include:

1. What files will change and why
2. The approach and key decisions
3. Risks or open questions

### 3. Present and STOP

Present the plan to the user. **End your response. Do not implement.**

Wait for explicit approval: "yes", "approved", "lgtm", "go ahead", or equivalent.

### 4. After Implementation

Before committing:

1. Run the full test suite and fix any failures
2. Self-review the diff — read it as a reviewer would, looking for bugs, missing edge cases, and incomplete changes
3. Present a summary of what was implemented and any findings from self-review

**End your response. Do not commit.** Wait for explicit approval before committing.
