# Evaluation Report: Maintainability Sensors for Coding Agents

This report evaluates and synthesizes the core concepts, findings, and architectural implications from the Martin Fowler article [Maintainability Sensors for Coding Agents](https://martinfowler.com/articles/sensors-for-coding-agents.html) by Birgitta Böckeler. It provides a detailed critique of each sensor category, reflects on the implications for modern AI-assisted engineering harnesses, and outlines concrete recommendations for applying these techniques.

---

## 1. Executive Summary

As coding agents (like Claude Code, Cursor, OpenCode, and Pi) become standard execution partners in software development, the bottleneck of software engineering shifts from **writing code** to **reviewing and maintaining code**. Codebases generated or modified by AI agents are prone to "inadvertent technical debt"—subtle architectural drift, semantic duplication, poorly abstracted repetition, and weak test assertions that look correct superficially (and pass basic coverage metrics) but erode the long-term maintainability (or internal quality) of the application.

Birgitta Böckeler's article introduces a foundational paradigm to address this: **Harness Engineering with Guides and Sensors**.
* **Guides** (e.g., `AGENTS.md`, markdown instruction sheets) are passive instructions that define rules and boundaries. However, they suffer from context window dilution and agent amnesia (failing to follow or recall rules during execution).
* **Sensors** are active, computational or inferential feedback loops that continuously monitor the codebase state, report health metrics, and provide explicit, actionable guidance to the agent for self-correction.

This evaluation concludes that a hybrid, multi-layered sensor suite—combining **deterministic computational sensors** (linters, type checkers, dependency boundary cruisers, mutation testing) with **probabilistic inferential sensors** (LLM-driven semantic design and modularity reviews)—dramatically improves the correctness and architectural integrity of agent outputs, lowers human cognitive load during PR reviews, and enforces durable engineering fitness functions.

---

## 2. Sensor Category Breakdown & Analysis

### 2.1 Static Code Analysis: Basic Linting
* **Core Idea:** Target maintainability risk at the individual file and function level using tools like ESLint or Ruff.
* **The AI Failure Modes:** Coding agents are notorious for creating overly long files, single monstrous functions, high cyclomatic complexity, or passing excessive numbers of arguments.
* **The Innovation (Guidance for Self-Correction):**
  * Default linter outputs are designed for humans and are often ignored or poorly interpreted by AI.
  * Overriding linter output messages with **custom self-correction formatters** allows us to inject prompt instructions directly into the tool's stdout (e.g., telling the agent exactly how to handle or suppress an `any` warning with a documented reason).
  * Rather than binary suppress-or-comply, allowing agents to slightly adjust numeric thresholds (like maximum function length) forces them to make a deliberate judgment call, which is highly visible in code reviews.
* **Evaluation & Critique:**
  * Highly effective. Basic static analysis is the lowest-hanging, highest-ROI computational sensor.
  * *Caveat:* Strict enforcement can lead to unexpected trade-offs. For example, limiting function size in React often leads to "prop-drilling" or extremely deep component trees with bloated property interfaces, simply shifting complexity elsewhere.

### 2.2 Static Code Analysis: Dependency Rules
* **Core Idea:** Use structural rules (like `dependency-cruiser` in JS/TS or `import-linter` in Python) to enforce layered architectural boundaries across directories.
* **The AI Failure Mode:** Agents easily lose sight of the folder structure and architectural layers (e.g., importing a service/orchestrator layer into a low-level HTTP/API client layer).
* **The Innovation (Layering Enforcement):**
  * Codifying folder conventions directly into configuration files so that a violation fails the sensor step, providing the agent with an immediate error message summarizing the layering system.
* **Evaluation & Critique:**
  * Exceptional value. It replaces easily-forgotten written instructions in markdown files with deterministic build-time failures. It dramatically lowers the steep configuration and regex cost of such tools by utilizing AI to author the dependency rules in the first place.

### 2.3 Static Code Analysis: Coupling Data
* **Core Idea:** Measure code coupling (incoming/outgoing references, fan-in/fan-out, cycles) deterministically using compiler trees.
* **Evaluation & Critique:**
  * **Low utility on its own.** Raw coupling numbers (like "Module X has 15 inbound imports") are highly noisy and context-dependent. Legitimate design patterns like Central Factories, Shared Contract Schemas (e.g., Zod schemas), or Dependency Injection hubs appear to static tools as dangerous "god modules" or highly coupled hotspots.
  * Asking an agent to evaluate design quality *solely* on raw coupling metrics yields lackluster, overly academic, and pedantic refactoring recommendations that often worsen actual readability.
  * **High utility for Risk Triage:** Rather than using this data for automated refactoring, it is extremely valuable for identifying the **blast radius** of an agent's change (e.g., "This changed file has 25 callers, trigger deeper human review").

### 2.4 Static Code Analysis: AI Modularity Review
* **Core Idea:** Use a highly-prompted LLM (an inferential sensor, such as Vlad Khononov's "Modularity Skills") to semantically review the entire codebase.
* **The AI Failure Modes:** Repetitive boilerplate code (e.g., copying and pasting identical routing/error-handling blocks), inconsistent backend call patterns, and scattered responsibilities (e.g., putting mockauth rules in a wiring factory).
* **The Innovation (Semantic Garbage Collection):**
  * Combining LLM semantic understanding with codebase context.
  * Running the analysis recursively or multiple times (since LLM outputs are probabilistic and may find different hotspots in separate passes).
* **Evaluation & Critique:**
  * Extremely powerful. Where deterministic tools see valid imports, the inferential modularity sensor sees semantic code duplication and structural rot.
  * It correctly identifies and discounts "acceptable hubs" (like factories or contracts) that raw coupling metrics mislabel as code smells.
  * It serves as a necessary safety valve for "inadvertent technical debt" that passes static compilers and lint checks but degrades system architecture.

### 2.5 The Test Suite as a Regression Sensor & Mutation Testing
* **Core Idea:** Use test suites as safety nets, measuring test efficacy with **Mutation Testing** (e.g., Stryker) rather than just code coverage.
* **The AI Failure Modes:** Agents are highly capable of writing tests to achieve 100% code coverage. However, these tests are often shallow or lack rigorous assertions. They may execute lines (e.g., calling a data mapper) via a large, generic end-to-end integration test without actually asserting that the output is correct.
* **The Innovation (Active Mutation Verification):**
  * Mutation testing modifies lines of code (e.g., changing `>` to `>=` or removing a mapper line) and runs the test suite. If the tests still pass, the mutant "survived," exposing an assertion gap.
* **Evaluation & Critique:**
  * Critical for AI-authored codebases. As testing moves toward "approved scenarios" and integration tests, mutation testing is the only objective metric that exposes the "coverage illusion."
  * *Caveat:* Mutation testing is computationally extremely expensive. It cannot be run on every keystroke or file save. It must be run incrementally or on a slower cadence (e.g., in CI or scheduled jobs).

---

## 3. Harness & Tooling Evaluation (The "Sidecar" Pattern)

The article describes a **Sensors Sidecar** CLI tool. This represents a major shift in how agent environments are architected:

```
[ Coding Agent ] <===> [ Sensors Sidecar CLI ] <===> [ Target Codebase ]
                              ||
                      [ config.json ]
                              ||
                      [ Custom Parsers ] <===> (Linter, Test, Stryker, etc.)
```

### 3.1 Strengths of the Sidecar Approach
1. **Unifies Tool Feedback:** Consolidates stdout/stderr and JSON reports from heterogeneous tools (Jest, ESLint, Semgrep, Stryker) into a single, standardized, token-efficient payload.
2. **Context Preservation:** By converting verbose tool outputs into a highly structured JSON or Markdown summary, the sidecar minimizes the token cost and context window bloat for coding agents.
3. **Trend Tracking:** Persists historical snapshots (e.g., "coverage is worse than snapshot") to inform the agent of regressions or improvements over time.
4. **Scouting & Global Guidance:** Integrates a "Scouting Rule" at the top of every sensor run, reminding the agent to clean up neighboring lines or follow specific design rules *in the context of the current run*.

### 3.2 Key Weaknesses & Gaps
1. **Agent Integration is Unreliable:** When agents are prompted via a guide (like `AGENTS.md`) to run the sensor check command, they frequently ignore it, run tests directly, or bypass the sensors entirely.
2. **Lack of Native Sandbox Integration:** The sidecar must be manually installed and configured in the sandbox, increasing setup friction.
3. **Fragile Parser Overhead:** Every new sensor requires a custom CLI parser to parse its output. While AI makes writing these parsers easy, it increases the maintenance surface of the sidecar itself. (The shift to a standard "Sensor JSON Schema" where individual sensor wrapper scripts output a uniform JSON structure is a strong remedy).

---

## 4. Synthesis: Balancing Guides vs. Sensors

A critical insight from Fowler's article is the dynamic equilibrium between **Guides** and **Sensors**:

| Aspect | Guides (`AGENTS.md`, prompts, instruction files) | Sensors (Lint rules, dependency-cruiser, AI reviews) |
| :--- | :--- | :--- |
| **Nature** | Passive, descriptive, text-based. | Active, prescriptive, execution-based. |
| **Cost** | Low CPU, high token cost (dilutes context window). | High CPU/run cost, zero or minimal token cost. |
| **Reliability** | Low (agents forget, hallucinate, or overlook instructions). | High (deterministic binary fail/pass, semantic reviews). |
| **Maintenance** | Hard to keep in sync with code; accumulates rot. | Enforced by execution; fails immediately if out of date. |

### The Recommendation:
**Keep guides lean.** Do not bloat `AGENTS.md` with exhaustive rules. Whenever a rule can be codified deterministically (e.g., "no importing models into views" or "functions must be under 50 lines"), **delete the text from the guide and codify it as a sensor.** This frees up valuable agent context window tokens, reduces model noise, and ensures self-enforcement.

---

## 5. Concrete Recommendations for Our Repository & Agent Harness

To implement the insights from the maintainability sensors article, we should adopt the following tactical measures in our dotfiles and coding agent prompts:

### Recommendation 1: Shift from Written Rules to Deterministic Sensors
* **Action:** Review the current instructions in `skills/code-quality/SKILL.md`. Identify rules that are purely mechanical (such as **Dead code**, **Orphaned code**, **Layering violations**, and **Propagation**).
* **Implementation:** Instead of relying on the agent's memory during a review to check if a function is dead or has other callers, we should recommend/write shell or Python scripts that automatically scan the git diff for these smells (e.g., running `grep` or `ast` trees to find orphaned methods) and surface them dynamically.

### Recommendation 2: Introduce "Custom Guidance" in Standard Tool Outputs
* **Action:** In our project linters, formatters, and git hooks, wrap or override standard error output to include contextual instructions for the agent.
* **Example:** For our pre-commit scripts or git config hooks in `dot_config/git/`, we can append a custom message when a linter fails:
  ```
  ❌ Linter Error: Explicit 'any' detected in server/clients/api.ts.
  💡 Guidance: We want things to be typed to avoid errors on key concepts.
  If you choose not to introduce a type, you must suppress it with:
  // eslint-disable-next-line @typescript-eslint/no-explicit-any -- (give your reasons)
  ```

### Recommendation 3: Enforce Sensors via Git Hooks and CI Harness
* **Action:** Rather than instructing the agent in `AGENTS.md` to "Run verification scripts before commit," enforce this deterministically.
* **Implementation:** Use a robust `pre-commit` framework (configured via `.pre-commit-config.yaml`) that automatically triggers the static check sensors when the agent attempts to commit or push. The agent is forced to self-correct because the git transaction fails until the sensors pass.

### Recommendation 4: Create Self-Updating "Baseline Snapshots"
* **Action:** For non-binary metrics (like test coverage, files length, or mutation scores), implement a local snapshot mechanism (such as saving a state JSON in `~/.local/share/`).
* **Implementation:** During execution, a pre-commit sensor compares the current metrics to the baseline. If they degrade, the agent is prompted with an error; if they improve, the snapshot is updated. This prevents the "boiling frog" syndrome of gradual codebase erosion.

### Recommendation 5: Leverage "Modularity and Coupling" as Blast Radius Triage
* **Action:** Create a lightweight custom tool in `/home/jules/self_created_tools` that lists the incoming and outgoing reference counts of modified files in a Git branch.
* **Implementation:** Use this tool during code-reviews or PR-level evaluations to flag high-risk edits (e.g., "You modified `utils.ts` which has 42 dependants. Triggering high-rigor regression verification.").
