---
name: homebrew-release
description: Load when a merged release must update a Homebrew tap and local installation
license: MIT
---

Use this only for the named release.

## Discover and verify

- Discover the source pull request, tap, formula, release workflow, tap workflow, workflow inputs, and version manifest from repository configuration.
- Read the semantic-release configuration and both workflows before any write.
- Verify the pull request is open, not draft, reviewed, mergeable, conflict-free, and green.
- Verify the intended head commit and squash target.
- Show the complete merge payload before merging.

## Release gate

- Verify the semantic-release run belongs to the merged commit.
- Verify every required job passed.
- Verify the expected version, tag, published release, assets, and release notes.
- Stop on a missing run, wrong commit, missing tag, failed job, or unexpected draft release.

## Tap update

- Read the tap workflow declaration.
- Verify its repository, default branch, dispatch inputs, and expected tag or version.
- Discover the formula from configuration. Do not guess an input or repository.
- Show the complete dispatch payload before sending it.
- Verify the new run, formula version, source URL, checksum, and branch commit.

## Local install

- Read installed and available versions first.
- Run only the required `brew update`, `brew install`, or `brew upgrade` command.
- Do not use `--force` or perform unrelated upgrades.
- Verify the installed formula version with `brew info`, `brew list`, and its version command.

A failed gate is not success. Save the run URL, ref, SHA, and failing step. Do not retry a remote write until the existing state is checked for idempotency.
