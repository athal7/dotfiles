## Purpose

Define the workflow for maintaining your own merge request — responding
to review feedback, resolving conflicts, rebasing, and iterating until
the MR is ready to merge.

## Requirements

### Requirement: Review threads are triaged before acting
The system SHALL read and categorize all open review threads before
making any code changes, to avoid partial or misdirected fixes.

#### Scenario: Thread triage
- **WHEN** the agent begins addressing review feedback
- **THEN** the agent reads all open threads, categorizes each as actionable (fix code), discussable (needs reply), or already resolved, and presents the triage to the human

### Requirement: Code fixes follow TDD
The system SHALL follow strict TDD when fixing code in response to
review feedback, the same as during initial implementation.

#### Scenario: Review-driven fix
- **WHEN** a review thread identifies a code issue to fix
- **THEN** the agent writes a test that reproduces the issue, confirms it fails, fixes the code, and confirms the test passes

### Requirement: Thread replies are accurate and complete
The system SHALL reply to review threads explaining what was done,
referencing the specific commit that addresses the feedback.

#### Scenario: Thread resolution
- **WHEN** the agent fixes an issue identified in a review thread
- **THEN** the agent replies to the thread citing the commit SHA and explaining the fix

#### Scenario: Threads not being addressed
- **WHEN** the agent decides not to address a review thread in the current iteration
- **THEN** the agent replies explaining why and gets human approval before posting

### Requirement: Conflict resolution preserves intent
The system SHALL resolve merge conflicts by understanding the intent of
both sides, not by mechanically accepting one side.

#### Scenario: Conflict resolution
- **WHEN** the merge request has conflicts with the target branch
- **THEN** the agent examines both sides of each conflict, understands the intent, resolves preserving both, and runs the test suite after resolution

### Requirement: Re-request review when ready
The system SHALL re-request review after addressing feedback, with a
summary of what changed.

#### Scenario: Re-request after fixes
- **WHEN** all actionable threads have been addressed and tests pass
- **THEN** the agent presents a summary of changes to the human and, upon approval, re-requests review with a comment summarizing what was addressed
