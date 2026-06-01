## ADDED Requirements

### Requirement: Primary local model is an MLX MoE tuned for Apple Silicon
The system SHALL use an MLX-format Mixture-of-Experts model as the primary local LLM, selected to fit within 48 GB unified memory alongside a large context window and to decode quickly on Apple M4 Pro.

#### Scenario: Primary model loads in MLX runtime
- **WHEN** the user loads the primary local model in LM Studio
- **THEN** it loads using the MLX runtime with full GPU offload
- **AND** inference runs without falling back to CPU

#### Scenario: Model fits with headroom
- **WHEN** the primary model is loaded with its configured context window
- **THEN** total memory use leaves headroom within 48 GB for the OS and active applications

### Requirement: Local model load config uses an adequate context window
The system SHALL configure local models with a context window large enough for real coding and agentic prompts (at least 16K tokens), so that long prompts do not error.

#### Scenario: Long prompt succeeds
- **WHEN** a prompt of ~17K tokens is sent to a model configured with a 32K context window
- **THEN** the model processes it without an `n_ctx` overflow error

#### Scenario: Default context window
- **WHEN** the primary model is loaded with default settings
- **THEN** its context window is at least 16K tokens

### Requirement: The lms CLI is provisioned reproducibly via dotfiles
The dotfiles SHALL make the LM Studio `lms` CLI available on PATH on a fresh machine with no manual steps beyond `chezmoi apply`.

#### Scenario: lms on PATH after apply
- **WHEN** `chezmoi apply` runs and LM Studio is installed
- **THEN** `~/.lmstudio/bin` is on PATH and `lms` is invocable from a new shell

#### Scenario: Bootstrap is safe when the app is absent
- **WHEN** the bootstrap script runs and `~/.lmstudio/bin/lms` does not exist
- **THEN** the script exits successfully without error

### Requirement: Models can be downloaded and verified via CLI
The system SHALL support downloading the primary model and verifying generation throughput from the command line.

#### Scenario: Download via lms
- **WHEN** the user runs the documented `lms get` command for the primary model
- **THEN** the MLX model is downloaded under `~/.lmstudio/models`

#### Scenario: Throughput smoke test
- **WHEN** the primary model is loaded and a generation is run
- **THEN** decode tokens-per-second is recorded as the M4 Pro baseline
