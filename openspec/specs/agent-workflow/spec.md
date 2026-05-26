## Purpose

Define the repeatable, iterative workflow the agent follows when
implementing changes — from planning through shipping. The workflow is
agile: phases feed back and feed forward rather than executing in strict
linear sequence.

## Requirements

### Requirement: Human approval gates
The system SHALL require explicit human approval at two defined points:
plan approval and changeset approval. No gate SHALL be skippable
regardless of perceived change triviality.

#### Scenario: Plan approval before build
- **WHEN** the agent completes a plan with gathered context and analysis
- **THEN** the agent presents the plan and waits for human approval or steering before proceeding to build

#### Scenario: Changeset approval before shipping
- **WHEN** the agent completes build work with tests and verification
- **THEN** the agent presents the changeset and QA artifact and waits for human approval or steering before committing

### Requirement: Planning phase gathers context and applies frameworks
The system SHALL gather relevant local context (codebase, specs, history)
and remote context (issues, docs, prior decisions) during planning, and
SHALL apply appropriate analytical frameworks to produce a plan artifact.

#### Scenario: Local context gathering
- **WHEN** the agent begins planning a change
- **THEN** the agent reads relevant source files, specs, and git history before proposing a plan

#### Scenario: Remote context gathering
- **WHEN** the change references an issue, PR, or external requirement
- **THEN** the agent fetches that context before proposing a plan

#### Scenario: Analytical framework application
- **WHEN** the change involves a design decision or tradeoff
- **THEN** the agent applies a structured thinking framework rather than jumping to a solution

### Requirement: Build phase follows strict TDD
The system SHALL follow strict TDD (red/green/refactor) during all build
work, SHALL validate that plan goals are met, and SHALL validate
cross-functional requirements.

#### Scenario: TDD discipline
- **WHEN** the agent implements any code change
- **THEN** the agent writes a failing test first, implements minimum code to pass, then refactors under green tests

#### Scenario: Goal validation
- **WHEN** the agent completes build work
- **THEN** the changeset demonstrably addresses the goals stated in the approved plan

### Requirement: Review feeds findings back to appropriate phase
The system SHALL examine the changeset for correctness, quality, and goal
alignment, and SHALL route findings to the appropriate phase rather than
always restarting from the beginning.

#### Scenario: Build-level finding
- **WHEN** review finds a localized code issue (bug, style, missing test)
- **THEN** the finding routes back to build for a targeted fix

#### Scenario: Plan-level finding
- **WHEN** review finds a fundamental approach problem
- **THEN** the finding routes back to plan for reconsideration

#### Scenario: Human-judgment finding
- **WHEN** review finds an issue that requires human judgment
- **THEN** the finding is presented to the human for decision

### Requirement: Ship phase handles CI feedback
The system SHALL commit, push, and monitor CI. CI failures SHALL feed
back to build or plan as appropriate rather than being treated as terminal.

#### Scenario: CI failure feedback
- **WHEN** CI fails after push
- **THEN** the agent diagnoses the failure and routes it back to build (for code fixes) or plan (for approach issues)

### Requirement: Self-steering with intent
The agent SHALL check its own work against the higher-level intent
throughout the workflow. "Am I solving the right problem?" SHALL take
precedence over procedural checklist completion.

#### Scenario: Drift detection
- **WHEN** the agent is mid-task and the work is diverging from the stated goal
- **THEN** the agent pauses, names the drift, and either self-corrects or escalates to the human

### Requirement: Structural enforcement over advisory guidance
Desired behaviors SHALL be enforced by system structure (permissions,
agent boundaries, lifecycle hooks) rather than solely by instructions
that the agent can rationalize away.

#### Scenario: Attention budget management
- **WHEN** the agent needs guidance for a specific workflow phase
- **THEN** the system delivers the right guidance at the right moment rather than loading all guidance at once

### Requirement: Dependencies are maintained and used as intended
The system SHALL build on actively maintained tools and SHALL use them
as intended. Bespoke solutions SHALL be a last resort.

#### Scenario: Tool adoption
- **WHEN** the system adopts an external tool or framework
- **THEN** it follows the tool's intended usage patterns rather than building workarounds
