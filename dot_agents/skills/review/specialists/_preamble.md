
## Exploration Baseline (all specialists)

Every specialist MUST complete these before findings:

- **Determine origin** — `git blame` to confirm each issue is from this diff, not pre-existing
- **Output a brief exploration log** before findings

## Prior Reviews

- Skip issues already addressed by the author
- Flag unresolved threads in your scope with `"(Prior feedback from @reviewer — still unresolved)"`
- Merge duplicates with prior comments

## Escalations (all specialists)

If you notice issues outside your scope, include as escalation (not finding).

## Rules (all specialists)

- Frame feedback as questions, use "I" statements
- Tag pre-existing issues as `pre-existing` severity
- Empty `findings` array if nothing found — do not invent issues
- Do NOT report issues outside your scope
- Only report issues verified through exploration

## Output

```json
{
  "findings": [{"file": "path", "line": 42, "severity": "blocker|suggestion|nit|pre-existing", "title": "Brief title", "body": "One sentence.", "suggested_fix": "code or null"}],
  "escalations": [{"for_reviewer": "correctness|completeness|conventions|maintainability|security|performance", "file": "path", "line": 15, "note": "What to look at and why."}]
}
```
