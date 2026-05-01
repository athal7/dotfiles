import type { Plugin } from "@opencode-ai/plugin"
import { execSync } from "child_process"
import { createHash } from "crypto"
import {
  mkdirSync,
  readFileSync,
  writeFileSync,
  existsSync,
  unlinkSync,
  rmdirSync,
} from "fs"
import { homedir } from "os"
import { dirname, join } from "path"

/**
 * Gates plugin — config-driven approval gate workflow.
 *
 * State (per repo, per branch, in ~/.local/state/opencode/gates/<repo-hash>/<branch>.json):
 *   { <gate_id>_approved: boolean, ... }    // all booleans, default false
 *
 * <repo-hash> = first 12 hex chars of sha256(absolute repo toplevel path).
 * State lives outside the repo so it never appears in diffs and is shared
 * across sessions/agents but isolated per-repo.
 *
 * Defaults ship with three gates: plan / commit / push.
 *
 * Optional override file: ~/.config/opencode/gates.json
 *   {
 *     "gates": {
 *       "commit": { "embed_hint": "..." }   // shallow-merge over default fields
 *     },
 *     "disabled": ["push"]                  // remove gates from the active set
 *   }
 *
 * No config file → use defaults (byte-identical to pre-refactor behavior).
 * Invalid config or unknown gate id → throw at startup.
 *
 * The user is the only one who can grant approval: they're the only one
 * who can pick the answer in the question tool's UI.
 */

const APPROVED_PREFIX = "Approved"
const CONFIG_PATH = join(
  process.env.XDG_CONFIG_HOME || join(homedir(), ".config"),
  "opencode",
  "gates.json",
)

// ----- Bash tokenizer --------------------------------------------------------

/**
 * Split a bash command string into one argv array per compound segment.
 * Segments are separated by top-level `;`, `&&`, `||`, `|`, `&`.
 * Quoted regions (`'...'`, `"..."`) and backslash escapes are respected so
 * operators inside quotes don't split.
 *
 * This is a deliberately small subset of bash — enough to recognize argv
 * boundaries for prefix matching. Things we don't try to handle:
 *   - command substitution `$(...)` `` `...` `` — treated as opaque text
 *   - parameter expansion `${...}` — treated as opaque text
 *   - here-docs / here-strings — the heredoc body is part of the command
 *     string and gets tokenized like any other text; it won't usually
 *     start with our prefix tokens, so it's safe in practice
 *
 * Best-effort: malformed input (unterminated quote, trailing backslash) is
 * tokenized as far as possible and the partial result is returned.
 */
function tokenizeCompound(command: string): string[][] {
  const segments: string[][] = []
  let current: string[] = []
  let token = ""
  let inSingle = false
  let inDouble = false

  const flushToken = () => {
    if (token.length > 0) {
      current.push(token)
      token = ""
    }
  }
  const flushSegment = () => {
    flushToken()
    if (current.length > 0) {
      segments.push(current)
      current = []
    }
  }

  for (let i = 0; i < command.length; i++) {
    const ch = command[i]

    if (inSingle) {
      if (ch === "'") inSingle = false
      else token += ch
      continue
    }
    if (inDouble) {
      if (ch === '"') inDouble = false
      else if (ch === "\\" && i + 1 < command.length) {
        // In double quotes, backslash only escapes a few chars; keep it simple
        const next = command[i + 1]
        if (next === '"' || next === "\\" || next === "$" || next === "`") {
          token += next
          i++
        } else {
          token += ch
        }
      } else token += ch
      continue
    }

    if (ch === "'") {
      inSingle = true
      continue
    }
    if (ch === '"') {
      inDouble = true
      continue
    }
    if (ch === "\\" && i + 1 < command.length) {
      token += command[i + 1]
      i++
      continue
    }

    // Operators (top-level, outside quotes)
    if (ch === ";") {
      flushSegment()
      continue
    }
    if (ch === "|") {
      // `||` and `|` both end a segment for our purposes
      flushSegment()
      if (command[i + 1] === "|") i++
      continue
    }
    if (ch === "&") {
      // `&&` and `&` both end a segment
      flushSegment()
      if (command[i + 1] === "&") i++
      continue
    }

    // Whitespace as token separator
    if (ch === " " || ch === "\t" || ch === "\n" || ch === "\r") {
      flushToken()
      continue
    }

    token += ch
  }

  flushSegment()
  return segments
}

/**
 * Returns true if any compound segment of `command` has argv starting with
 * `prefix` exactly (token-by-token).
 */
function cliMatches(command: string, prefix: readonly string[]): boolean {
  if (prefix.length === 0) return false
  for (const argv of tokenizeCompound(command)) {
    if (argv.length < prefix.length) continue
    let ok = true
    for (let i = 0; i < prefix.length; i++) {
      if (argv[i] !== prefix[i]) {
        ok = false
        break
      }
    }
    if (ok) return true
  }
  return false
}

// ----- Gate definitions ------------------------------------------------------

type CliTrigger = { kind: "cli"; argv_prefix: string[] }
type ToolTrigger = { kind: "tool"; tools: string[] }
type Trigger = CliTrigger | ToolTrigger

type GateDef = {
  id: string
  header: string
  what: string
  question: string
  yes: string
  no: string
  embed_hint: string
  trigger: Trigger
  // Side effects on this gate's approval transitions:
  on_approve_set: string[] // gates to mark approved
  on_approve_unset: string[] // gates to unmark
  // Side effect when the gate's triggering action is attempted:
  on_attempt: "unset_self" | "clear_state" | "none"
}

const DEFAULT_GATES: GateDef[] = [
  {
    id: "plan",
    header: "Plan approval gate",
    what: "Edits to source files",
    question: "Approve the plan above?",
    yes: "Approved — proceed with edits",
    no: "Not yet — plan needs more work",
    embed_hint:
      "Present the full plan in chat FIRST (the question UI does not render multi-line content). Then call the question tool with a short cue like 'Approve the plan above?'. The substance is in the chat scrollback. Ask the user to greenlight the plan — do not ask them to confirm work you should have done yourself.",
    trigger: { kind: "tool", tools: ["edit", "write", "apply_patch"] },
    on_approve_set: ["plan"],
    on_approve_unset: [],
    on_attempt: "none",
  },
  {
    id: "commit",
    header: "Pre-commit review gate",
    what: "Committing",
    question: "Approve this commit?",
    yes: "Approved — commit",
    no: "Not yet — needs more work",
    embed_hint:
      "Self-review the diff yourself FIRST (your `review` capability) — that is your responsibility, not the user's. Then present the drafted commit message and a brief summary in chat (the question UI does not render multi-line content). Then call the question tool with the short cue 'Approve this commit?'. The user already sees the diff in the side panel; ask them to greenlight shipping it — do not ask them whether self-review has been completed.",
    trigger: { kind: "cli", argv_prefix: ["git", "commit"] },
    on_approve_set: ["commit"],
    on_approve_unset: ["plan"],
    on_attempt: "unset_self",
  },
  {
    id: "push",
    header: "Pre-push approval gate",
    what: "Pushing",
    question: "Approve this push?",
    yes: "Approved — push",
    no: "Not yet — hold off",
    embed_hint:
      "Present the branch name and unpushed commit subjects in chat FIRST (the question UI does not render multi-line content). Then call the question tool with the short cue 'Approve this push?'. Ask the user to greenlight the push — do not ask them to confirm checks you should have run yourself.",
    trigger: { kind: "cli", argv_prefix: ["git", "push"] },
    on_approve_set: ["push"],
    on_approve_unset: [],
    on_attempt: "clear_state",
  },
]

// ----- Config loading --------------------------------------------------------

type RawOverride = Partial<
  Pick<
    GateDef,
    "header" | "what" | "question" | "yes" | "no" | "embed_hint"
  >
>

type RawConfig = {
  gates?: Record<string, RawOverride>
  disabled?: string[]
}

function loadGates(): GateDef[] {
  if (!existsSync(CONFIG_PATH)) return DEFAULT_GATES

  let raw: RawConfig
  try {
    raw = JSON.parse(readFileSync(CONFIG_PATH, "utf8"))
  } catch (e) {
    throw new Error(
      `[gates] failed to parse ${CONFIG_PATH}: ${(e as Error).message}`,
    )
  }

  const knownIds = new Set(DEFAULT_GATES.map((g) => g.id))

  const overrides = raw.gates ?? {}
  for (const id of Object.keys(overrides)) {
    if (!knownIds.has(id)) {
      throw new Error(
        `[gates] unknown gate id in override: '${id}'. Known: ${[...knownIds].join(", ")}`,
      )
    }
  }

  const disabled = new Set(raw.disabled ?? [])
  for (const id of disabled) {
    if (!knownIds.has(id)) {
      throw new Error(
        `[gates] unknown gate id in disabled list: '${id}'. Known: ${[...knownIds].join(", ")}`,
      )
    }
  }

  return DEFAULT_GATES.filter((g) => !disabled.has(g.id)).map((g) => ({
    ...g,
    ...(overrides[g.id] ?? {}),
  }))
}

// ----- State management ------------------------------------------------------

type GateState = Record<string, boolean>

type RepoContext = {
  toplevel: string
  branch: string
}

function getRepoContext(cwd: string): RepoContext | null {
  try {
    const toplevel = execSync("git rev-parse --show-toplevel", {
      cwd,
      encoding: "utf8",
      timeout: 2000,
    }).trim()
    if (!toplevel) return null

    const branch = execSync("git rev-parse --abbrev-ref HEAD", {
      cwd,
      encoding: "utf8",
      timeout: 2000,
    }).trim()
    if (!branch || branch === "HEAD") return null

    return { toplevel, branch }
  } catch {
    return null
  }
}

function stateDir(): string {
  const xdg = process.env.XDG_STATE_HOME
  const base = xdg && xdg.length > 0 ? xdg : join(homedir(), ".local", "state")
  return join(base, "opencode", "gates")
}

function statePath(repo: RepoContext): string {
  const repoHash = createHash("sha256")
    .update(repo.toplevel)
    .digest("hex")
    .slice(0, 12)
  const sanitizedBranch = repo.branch.replace(/\//g, "__")
  return join(stateDir(), repoHash, `${sanitizedBranch}.json`)
}

function defaultState(gates: GateDef[]): GateState {
  return Object.fromEntries(gates.map((g) => [`${g.id}_approved`, false]))
}

function readState(repo: RepoContext, gates: GateDef[]): GateState {
  const base = defaultState(gates)
  const path = statePath(repo)
  if (!existsSync(path)) return base
  try {
    return { ...base, ...JSON.parse(readFileSync(path, "utf8")) }
  } catch {
    return base
  }
}

function writeState(repo: RepoContext, state: GateState): void {
  const path = statePath(repo)
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, JSON.stringify(state, null, 2))
}

/**
 * Delete the state file for this repo+branch. If the repo's gates dir is
 * empty afterward, remove it too.
 */
function deleteState(repo: RepoContext): void {
  const path = statePath(repo)
  if (existsSync(path)) {
    try {
      unlinkSync(path)
    } catch {
      return
    }
  }
  try {
    rmdirSync(dirname(path))
  } catch {
    // dir not empty (other branches have state) — leave it
  }
}

// ----- Approval detection ----------------------------------------------------

/**
 * Inspect a question tool call. If its first question has the given header
 * AND the user picked an option whose label starts with "Approved", return true.
 */
function isApproval(args: any, metadata: any, expectedHeader: string): boolean {
  try {
    const questions = args?.questions
    if (!Array.isArray(questions)) return false
    const matchHeader = questions.some(
      (q: any) =>
        typeof q?.header === "string" && q.header.includes(expectedHeader),
    )
    if (!matchHeader) return false

    const answers = metadata?.answers
    if (!Array.isArray(answers)) return false
    const flat = answers.flat()
    return flat.some(
      (a: any) => typeof a === "string" && a.startsWith(APPROVED_PREFIX),
    )
  } catch {
    return false
  }
}

// ----- Block message ---------------------------------------------------------

function buildBlockMessage(gate: GateDef, branch: string): string {
  return (
    `[gates] ${gate.what} blocked on branch '${branch}': ${gate.id} gate not approved.\n\n` +
    `${gate.embed_hint}\n\n` +
    `Required question shape:\n\n` +
    `  question({\n` +
    `    questions: [{\n` +
    `      header: "${gate.header}",\n` +
    `      question: "${gate.question}",\n` +
    `      options: [\n` +
    `        { label: "${gate.yes}", description: "..." },\n` +
    `        { label: "${gate.no}", description: "..." }\n` +
    `      ]\n` +
    `    }]\n` +
    `  })\n\n` +
    `The header MUST start with "${gate.header}" and the approval label MUST start with "Approved" — otherwise the gate will not unlock. When the user picks the "${gate.yes}" option, the gate is satisfied and the blocked action will succeed on the next attempt.`
  )
}

// ----- Plugin ---------------------------------------------------------------

export const GatesPlugin: Plugin = async (ctx) => {
  const cwd = ctx.directory || ctx.worktree || process.cwd()
  const gates = loadGates()

  // Helper: find the gate (if any) whose trigger matches a tool invocation.
  function matchTrigger(
    tool: string,
    bashCommand: string | undefined,
  ): GateDef | null {
    for (const gate of gates) {
      const t = gate.trigger
      if (t.kind === "tool" && t.tools.includes(tool)) return gate
      if (
        t.kind === "cli" &&
        tool === "bash" &&
        typeof bashCommand === "string" &&
        cliMatches(bashCommand, t.argv_prefix)
      ) {
        return gate
      }
    }
    return null
  }

  return {
    "tool.execute.before": async (input, output) => {
      const repo = getRepoContext(cwd)
      if (!repo) return // detached HEAD or not a git repo — no-op

      const bashCommand =
        input.tool === "bash" ? output?.args?.command : undefined
      const gate = matchTrigger(input.tool, bashCommand)
      if (!gate) return

      const state = readState(repo, gates)
      if (state[`${gate.id}_approved`]) return
      throw new Error(buildBlockMessage(gate, repo.branch))
    },

    "tool.execute.after": async (input, output) => {
      const repo = getRepoContext(cwd)
      if (!repo) return

      // Approval transitions: question tool answered with "Approved"
      if (input.tool === "question") {
        const args = (input as any).args
        const metadata = output?.metadata
        const state = readState(repo, gates)

        for (const gate of gates) {
          if (!isApproval(args, metadata, gate.header)) continue
          const next = { ...state }
          for (const id of gate.on_approve_set) next[`${id}_approved`] = true
          for (const id of gate.on_approve_unset) next[`${id}_approved`] = false
          writeState(repo, next)
          return
        }
        return
      }

      // Consumption transitions: any triggering action consumes its approval.
      // Even if the command failed (e.g. nothing to commit, hook failure), the
      // approval was for THIS specific intent — a retry needs a new approval
      // because the agent may have changed something in between.
      if (input.tool === "bash") {
        const args = (input as any).args
        const command = args?.command
        if (typeof command !== "string") return

        const gate = matchTrigger("bash", command)
        if (!gate) return

        if (gate.on_attempt === "clear_state") {
          deleteState(repo)
        } else if (gate.on_attempt === "unset_self") {
          const state = readState(repo, gates)
          writeState(repo, { ...state, [`${gate.id}_approved`]: false })
        }
      }
    },
  }
}
