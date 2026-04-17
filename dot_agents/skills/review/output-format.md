
## Output Format

**Be terse.** Developers can read code — don't explain what the diff does.

### Reviewing your own uncommitted work

No audience to triage for — apply every finding, no categorization.

```markdown
## Verdict: [APPROVE | CHANGES REQUESTED]

[One sentence why, if not obvious]

## Findings

- **file.rb:10** - [issue]. [concrete fix]
- **file.rb:25** - [issue]. [concrete fix]

## Pre-existing Issues

> These bugs exist in the codebase but were not introduced by this diff. They do not affect the verdict.

- **file.rb:55** - [issue]. [1 sentence explanation]
```

**Behavior:** If the verdict is CHANGES REQUESTED, apply every item in Findings, re-run the review, and iterate until the verdict is APPROVE. Do not wait for user input between iterations. Present only the final verdict.

### Reviewing someone else's code

Triage for the author — Blockers are required, Suggestions are optional, Nits are tiny.

```markdown
## Verdict: [APPROVE | CHANGES REQUESTED | COMMENT]

[One sentence why, if not obvious]

## Blockers

- **file.rb:10** - [2-5 word issue]. [1 sentence context if needed]
  ```suggestion
  # concrete replacement code
  ```

## Suggestions (non-blocking)

- **file.rb:25** - [2-5 word suggestion]
  ```suggestion
  # concrete replacement code
  ```

## Nits

- **file.rb:30** - [tiny thing]

## Pre-existing Issues

> These bugs exist in the codebase but were not introduced by this diff. They do not affect the verdict.

- **file.rb:55** - [issue title]. [1 sentence explanation]
```

**Rules:**
- Skip sections with no items (don't say "None")
- Max 1-2 sentences per item. No filler.
- **Always include a `suggestion` code block** with the concrete fix, unless the fix requires architectural changes that can't be expressed as a snippet
- Use "I" statements, frame as questions not directives
- Pre-existing Issues never influence the verdict — they are informational only
- **When submitting:** inline comments only — no top-level body. Verdict, TL;DR, Requirements Check, and all summaries stay in the session; never submit them to the code review platform.

---

**For merge requests, extend the session output as follows:**

```markdown
[Merge request URL as clickable link]

## TL;DR

[One sentence summary of what this merge request does]

## Verdict: [APPROVE | CHANGES REQUESTED | COMMENT]

[One sentence why, if not obvious]

## Requirements Check

> Only include this section if issue context was found.

- [Acceptance criterion 1]: [met / not met — one sentence]
- [Acceptance criterion 2]: [met / not met — one sentence]

## Unresolved Prior Feedback

> Only include this section if prior reviews exist and any threads are still unresolved.

- **file.rb:10** (@reviewer, [date]) - [original comment summary]. [Status: author hasn't responded / author replied but issue remains]

## Blockers
...

## Pre-existing Issues

> These bugs exist in the codebase but were not introduced by this merge request. They do not affect the verdict.

- **file.rb:55** - [issue title]. [1 sentence explanation]
```
