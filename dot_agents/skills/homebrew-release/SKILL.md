---
name: homebrew-release
description: Load when releasing a pull request whose semantic-release output must update one of the user's Homebrew taps and local installation.
license: MIT
---

Use this workflow only for the named pull request. Do not merge an unrelated request.
Use read-only repository and Homebrew operations for discovery and verification. Run remote and local writes only after the required read-only checks pass.

## 1. Preflight the pull request

Discover the source repository, pull request number, target Homebrew tap spec, formula name, tap repository, release workflow, tap workflow, workflow inputs, and version manifest. Read the semantic-release configuration and the tap workflow before acting.

Run read-only checks:

- Read the pull request's state, draft status, mergeability, review decision, branches, commits, and checks.
- Confirm the request is open, not draft, has the required review state, is mergeable, conflict-free, and has every required check passing.
- Confirm the head commit and intended squash target. Do not bypass branch protection, required reviews, or failed checks.

Show the full merge payload, pull request, target branch, squash operation, and commit subject. Then merge the pull request.

After the merge, verify its state, merge time, and merge commit.

## 2. Verify semantic-release

Find the semantic-release run for the merged commit and wait for its terminal result.

The release gate requires all of these:

- The run is for the merged commit, not an older push or a retry for another ref.
- Every required job completed successfully. A green individual job does not prove the workflow succeeded.
- The expected semantic version was calculated from the merged commits.
- The expected tag points to the merged release commit.
- The GitHub Release exists, is published, and has the expected tag, version, and required assets or notes.

Read the tag and release. Compare them with the repository manifest and semantic-release output. If no run starts, the run fails, the tag is absent, or the release is draft/prerelease unexpectedly, stop and capture the run URL and failing log step. Do not trigger the tap workflow.

## 3. Trigger and verify the Homebrew tap

Inspect the tap workflow's `workflow_dispatch` declaration. Confirm its repository, default branch, required inputs, input types, and whether it expects a release tag, version, source repository, or formula name. Discover the target Homebrew tap as `<tap>` from the project configuration, then run `brew tap-info --json=v2 <tap>` and inspect the tap checkout's `git remote -v` to verify its GitHub repository. Discover `<formula>` from the same configuration and workflow. Do not assume a tap spec is the GitHub owner/repository or guess an input name or ref.

Prepare the exact command. For example:

Dispatch the declared tap workflow using the verified repository, branch, and input name/value.

Use only the inputs that the workflow declares. If the workflow has no manual trigger, stop and report that prerequisite.

Record every input value, then dispatch the verified workflow.

Identify the newly created run by workflow, dispatch event, ref, and creation time, then wait for its terminal result. Verify the target formula in the discovered tap repository: the formula version and URL match the release, the checksum is present and correct when required, and the commit is on the expected branch. A successful dispatch without the expected formula commit is failure.

## 4. Update the local Homebrew installation

Run read-only checks first: `brew tap`, `brew list --formula --versions <formula>`, and `brew info <tap>/<formula>`. Confirm the local tap points to the updated formula and record installed and available versions.

Record the exact local commands. Use `brew update`, then `brew upgrade <tap>/<formula>` when installed and outdated. Use `brew install <tap>/<formula>` only when it is not installed and installation is intended. Do not use `--force` or unrelated upgrades.

Verify with `brew info <tap>/<formula>`, `brew list --formula --versions <formula>`, and the package's documented `--version` or equivalent smoke command. Confirm the installed version equals the published formula version. Report the command output and any expected caveat for auto-updating software.

## Failure handling

A timeout, cancelled run, failed required check, missing release, wrong tag, wrong formula, or version mismatch is not success. Stop at the failed gate. Save URLs, run IDs, refs, SHAs, and the first failing log step. Do not merge again or dispatch again until the existing state is inspected for idempotency. Retry only with the same verified inputs after the cause is fixed. If a tap commit is wrong, do not repair it silently: stop, preserve evidence, and request the repository owner's correction path.
