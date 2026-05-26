## Purpose

Define the permission model for agent interactions with external services —
which operations are allowed autonomously and which require human approval.
This is a cross-cutting concern that applies to all workflows.

## Requirements

### Requirement: Read operations are allowed without approval
The system SHALL allow the agent to read from external services without
requiring human approval. Reading is necessary for context gathering and
does not produce side effects.

#### Scenario: Fetching issue context
- **WHEN** the agent needs to read an issue, PR, or document from an external service
- **THEN** the agent fetches it without waiting for human approval

#### Scenario: Querying search or logs
- **WHEN** the agent needs to search issues, query logs, or list resources
- **THEN** the agent performs the query without waiting for human approval

### Requirement: Write operations require human approval
The system SHALL require explicit human approval before performing any
write operation on an external service. Writes produce side effects that
cannot be easily undone.

#### Scenario: Posting comments or replies
- **WHEN** the agent is about to post a comment, review, or thread reply
- **THEN** the agent presents the full proposed content and waits for human approval

#### Scenario: Pushing code
- **WHEN** the agent is about to push commits to a remote repository
- **THEN** the agent presents the commits to push and waits for human approval

#### Scenario: Creating or updating resources
- **WHEN** the agent is about to create or update an issue, PR, wiki page, or other remote resource
- **THEN** the agent presents the proposed action and waits for human approval

#### Scenario: Sending messages
- **WHEN** the agent is about to send a chat message, email, or notification
- **THEN** the agent presents the full message content and waits for human approval

### Requirement: Approval includes full proposed content
The system SHALL show the human the complete content of any proposed write
operation, not just a summary or description of intent.

#### Scenario: Review comment approval
- **WHEN** the agent asks for approval to post review comments
- **THEN** the approval request includes the exact text of every comment to be posted

#### Scenario: Issue update approval
- **WHEN** the agent asks for approval to update an issue
- **THEN** the approval request includes the exact field changes being made
