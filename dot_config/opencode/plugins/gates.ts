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
 * Gates plugin — three-gate workflow enforcement.
 *
 * State (per repo, per branch, in ~/.local/state/opencode/gates/<repo-hash>/<branch>.json):
 *   { plan_approved, commit_approved, push_approved }   // all booleans, default false
 *
 * <repo-hash> = first 12 hex chars of sha256(absolute repo toplevel path).
 * State lives outside the repo so it never appears in diffs and is shared
 * across sessions/agents but isolated per-repo.
 *
 * Blocks:
 *   - edit / write / apply_patch          blocked when !plan_approved
 *   - bash matching `git commit`          blocked when !commit_approved
 *   - bash matching `git push`            blocked when !push_approved
 *
 * Transitions:
 *   - question with header "Plan approval gate"      + Approved   → plan_approved = true
 *   - question with header "Pre-commit review gate"  + Approved   → commit_approved = true, plan_approved = false
 *   - question with header "Pre-push approval gate"  + Approved   → push_approved = true
 *   - any `git commit` attempt                                     → commit_approved = false
 *   - any `git push`   attempt                                     → state file removed (full reset)
 *
 * The user is the only one who can grant approval: they're the only one
 * who can pick the answer in the question tool's UI.
 */

const HEADER_PLAN = "Plan approval gate"
const HEADER_COMMIT = "Pre-commit review gate"
const HEADER_PUSH = "Pre-push approval gate"
const APPROVED_PREFIX = "Approved"

type GateState = {
  plan_approved: boolean
  commit_approved: boolean
  push_approved: boolean
}

const DEFAULT_STATE: GateState = {
  plan_approved: false,
  commit_approved: false,
  push_approved: false,
}

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
  // XDG_STATE_HOME, falling back to ~/.local/state
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

function readState(repo: RepoContext): GateState {
  const path = statePath(repo)
  if (!existsSync(path)) return { ...DEFAULT_STATE }
  try {
    return { ...DEFAULT_STATE, ...JSON.parse(readFileSync(path, "utf8")) }
  } catch {
    return { ...DEFAULT_STATE }
  }
}

function writeState(repo: RepoContext, state: GateState): void {
  const path = statePath(repo)
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, JSON.stringify(state, null, 2))
}

/**
 * Delete the state file for this repo+branch. If the repo's gates dir is
 * empty afterward, remove it too. Used after a successful push to mark
 * this unit of work as complete.
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
  // Try to remove the now-possibly-empty repo dir; rmdir fails non-fatally
  // if the dir still has other branch files.
  try {
    rmdirSync(dirname(path))
  } catch {
    // dir not empty (other branches have state) — leave it
  }
}

function isGitCommit(command: string): boolean {
  return /(^|[\s;&|])git\s+commit(\s|$)/.test(command)
}

function isGitPush(command: string): boolean {
  return /(^|[\s;&|])git\s+push(\s|$)/.test(command)
}

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

/**
 * Build the throw message that instructs the agent to call the question tool
 * with the right shape for the given gate.
 */
function buildBlockMessage(
  gate: "plan" | "commit" | "push",
  branch: string,
): string {
  const cfg = {
    plan: {
      header: HEADER_PLAN,
      what: "Edits to source files",
      question: "Approve the plan above?",
      yes: "Approved — proceed with edits",
      no: "Not yet — plan needs more work",
      embedHint:
        "Present the full plan in chat FIRST (the question UI does not render multi-line content). Then call the question tool with a short cue like 'Approve the plan above?'. The substance is in the chat scrollback. Ask the user to greenlight the plan — do not ask them to confirm work you should have done yourself.",
    },
    commit: {
      header: HEADER_COMMIT,
      what: "Committing",
      question: "Approve this commit?",
      yes: "Approved — commit",
      no: "Not yet — needs more work",
      embedHint:
        "Self-review the diff yourself FIRST (your `review` capability) — that is your responsibility, not the user's. Then present the drafted commit message and a brief summary in chat (the question UI does not render multi-line content). Then call the question tool with the short cue 'Approve this commit?'. The user already sees the diff in the side panel; ask them to greenlight shipping it — do not ask them whether self-review has been completed.",
    },
    push: {
      header: HEADER_PUSH,
      what: "Pushing",
      question: "Approve this push?",
      yes: "Approved — push",
      no: "Not yet — hold off",
      embedHint:
        "Present the branch name and unpushed commit subjects in chat FIRST (the question UI does not render multi-line content). Then call the question tool with the short cue 'Approve this push?'. Ask the user to greenlight the push — do not ask them to confirm checks you should have run yourself.",
    },
  }[gate]

  return (
    `[gates] ${cfg.what} blocked on branch '${branch}': ${gate} gate not approved.\n\n` +
    `${cfg.embedHint}\n\n` +
    `Required question shape:\n\n` +
    `  question({\n` +
    `    questions: [{\n` +
    `      header: "${cfg.header}",\n` +
    `      question: "${cfg.question}",\n` +
    `      options: [\n` +
    `        { label: "${cfg.yes}", description: "..." },\n` +
    `        { label: "${cfg.no}", description: "..." }\n` +
    `      ]\n` +
    `    }]\n` +
    `  })\n\n` +
    `The header MUST start with "${cfg.header}" and the approval label MUST start with "Approved" — otherwise the gate will not unlock. When the user picks the "${cfg.yes}" option, the gate is satisfied and the blocked action will succeed on the next attempt.`
  )
}

export const GatesPlugin: Plugin = async (ctx) => {
  const cwd = ctx.directory || ctx.worktree || process.cwd()

  return {
    "tool.execute.before": async (input, output) => {
      const repo = getRepoContext(cwd)
      if (!repo) return // detached HEAD or not a git repo — no-op

      // Plan gate: block file edits
      if (
        input.tool === "edit" ||
        input.tool === "write" ||
        input.tool === "apply_patch"
      ) {
        const state = readState(repo)
        if (state.plan_approved) return
        throw new Error(buildBlockMessage("plan", repo.branch))
      }

      // Commit & push gates: bash command pattern matching
      if (input.tool === "bash") {
        const command = output?.args?.command
        if (typeof command !== "string") return

        if (isGitCommit(command)) {
          const state = readState(repo)
          if (state.commit_approved) return
          throw new Error(buildBlockMessage("commit", repo.branch))
        }

        if (isGitPush(command)) {
          const state = readState(repo)
          if (state.push_approved) return
          throw new Error(buildBlockMessage("push", repo.branch))
        }
      }
    },

    "tool.execute.after": async (input, output) => {
      const repo = getRepoContext(cwd)
      if (!repo) return

      // Approval transitions: question tool answered with "Approved"
      if (input.tool === "question") {
        const args = (input as any).args
        const metadata = output?.metadata
        const state = readState(repo)

        if (isApproval(args, metadata, HEADER_PLAN)) {
          writeState(repo, { ...state, plan_approved: true })
          return
        }
        if (isApproval(args, metadata, HEADER_COMMIT)) {
          writeState(repo, {
            ...state,
            commit_approved: true,
            plan_approved: false,
          })
          return
        }
        if (isApproval(args, metadata, HEADER_PUSH)) {
          writeState(repo, { ...state, push_approved: true })
          return
        }
        return
      }

      // Consumption transitions: any commit/push attempt consumes its approval.
      // Even if the command failed (e.g. nothing to commit, hook failure), the
      // approval was for THIS specific diff/push intent — a retry needs a new
      // approval because the agent may have changed something in between.
      if (input.tool === "bash") {
        const args = (input as any).args
        const command = args?.command
        if (typeof command !== "string") return

        if (isGitCommit(command)) {
          const state = readState(repo)
          writeState(repo, { ...state, commit_approved: false })
          return
        }
        if (isGitPush(command)) {
          // Push is the natural end of a unit of work. Clean up state
          // entirely — next change cycle on this branch starts fresh.
          deleteState(repo)
          return
        }
      }
    },
  }
}
