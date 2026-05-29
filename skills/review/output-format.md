
## Output Format

**Be terse.** You can read your own code — don't explain what the diff does.

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

**Rules:**
- Skip sections with no items (don't say "None")
- Max 1-2 sentences per item. No filler.
- Pre-existing Issues never influence the verdict — they are informational only
