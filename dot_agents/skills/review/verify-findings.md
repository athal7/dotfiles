
## Merge and Verify Results

After all specialists and follow-up agents return:

1. Collect all `findings` from all agents (initial + follow-up)
2. Deduplicate — if two specialists flag the same line, keep the higher-severity one and note both concerns
3. **Verification pass** — for each finding, attempt to disprove it:

   | Claim type | How to disprove |
   |---|---|
   | "Unused variable/function" | `rg` for all usages including dynamic calls, string interpolation, metaprogramming; discard only if zero real usages found |
   | "Missing null check" | Read the full call chain upstream — is there a guard, `presence` validation, or DB constraint that guarantees non-null? Discard only if protection is confirmed |
   | "N+1 query" | Check `default_scope`, `after_find`, controller `includes`, and any concern that wraps the association; discard only if eager loading is confirmed for this access path |
   | "Unsanitized input" | Trace the full input path — does a framework layer (Rack, Rails strong params, ORM) sanitize it before use? Discard only if sanitization is confirmed end-to-end |
   | "Race condition" | Read the surrounding transaction, lock, or mutex scope; discard only if the critical section is provably atomic |
   | "Side effect fires on failure" | Read the callback/hook definition and check whether it is wrapped in `after_commit`, `after_save` with a condition, or guarded by the success of the preceding operation |
   | "Pre-existing" tag | Confirm with `git blame` — if the line was touched by this diff, reclassify to appropriate severity |

   **Default: keep, don't discard.** Discard a finding only if you can positively disprove the claim above. When in doubt, keep it as a `suggestion` with a note that further investigation is needed.

   **While verifying, read the surrounding code actively** — if you spot a new issue the specialists missed, add it. Look for cross-cutting concerns: security implications of correctness issues, correctness implications of performance changes.

4. Classify remaining findings:
   - `blocker` → **Blockers** section
   - `suggestion` → **Suggestions** section
   - `nit` → **Nits** section
   - `pre-existing` → **Pre-existing Issues** section (separate, never affects verdict)
5. Determine verdict based on blockers only (pre-existing findings never trigger CHANGES REQUESTED)
