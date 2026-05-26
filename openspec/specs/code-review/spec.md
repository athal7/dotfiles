## Purpose

Define the workflow for reviewing someone else's code — reading a merge
request, analyzing it for issues, and posting actionable findings.

## Requirements

### Requirement: Review uses structured multi-pass analysis
The system SHALL analyze the changeset through multiple specialist passes
rather than a single unstructured read-through.

#### Scenario: Multi-pass review
- **WHEN** the agent reviews a merge request
- **THEN** the agent runs at minimum correctness, code quality, and reviewability passes, with security and performance passes when the change warrants them

### Requirement: Findings are verified before posting
The system SHALL verify each finding against the actual diff before
including it in review output. Findings that cannot be confirmed in the
diff SHALL be discarded.

#### Scenario: Finding verification
- **WHEN** the agent identifies a potential issue
- **THEN** the agent confirms the issue exists in the actual changed lines, attempts to disprove it, and only includes it if it survives verification

### Requirement: Review examines goal alignment
The system SHALL evaluate whether the changeset achieves its stated
purpose, not just whether the code is technically correct.

#### Scenario: Acceptance criteria check
- **WHEN** the merge request references an issue or has a stated goal
- **THEN** the review evaluates whether the implementation satisfies the stated requirements

### Requirement: QA verification for UI changes
The system SHALL perform functional QA verification when the changeset
touches user-facing views or flows.

#### Scenario: UI change detected
- **WHEN** the changeset modifies views, templates, CSS, or frontend code
- **THEN** the agent performs browser-based QA verification of affected flows
