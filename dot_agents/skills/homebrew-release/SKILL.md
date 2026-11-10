---
name: homebrew-release
description: Load when a merged release must update a Homebrew tap and local installation
license: MIT
---

Scope is the merged release plus the formulas the tap tracks for it. A tap that updates several formulas from one dispatch or workflow is the repository's normal flow, not a widened scope: run it as declared instead of narrowing it to a single formula. Do not extend to formulas that flow does not touch.

## Discover and verify

- Discover the tap, the formulas it tracks, the release workflow, tap workflow, workflow inputs, and version manifest from repository configuration.
- Read the semantic-release configuration and both workflows before any write.

## Release gate

- Verify the semantic-release run belongs to the merged commit.
- Verify every required job passed.
- Verify the expected version, tag, published release, assets, and release notes.
- Stop on a missing run, wrong commit, missing tag, failed job, or unexpected draft release.

## Tap update

- Read the tap workflow declaration.
- Verify its repository, default branch, dispatch inputs, and expected tag or version.
- Discover which formulas the flow updates from configuration. A workflow that updates every tracked formula, or takes no formula selection at all, is normal; do not invent a selection input or guess a repository.
- Verify the new run, then for each formula the run updated verify its version, source URL, checksum, and branch commit. Treat an updated formula the flow declares as expected, and a formula the flow declares but skipped as a failure.

## Local install

- Read installed and available versions first.
- Run only the required `brew update`, `brew install`, or `brew upgrade` command, addressing each formula this release updated.
- Do not use `--force` or upgrade formulas outside this release.
- Verify the installed formula version with `brew info`, `brew list`, and its version command.

A failed gate is not success. Save the run URL, ref, SHA, and failing step. Do not retry a remote write until the existing state is checked for idempotency.
