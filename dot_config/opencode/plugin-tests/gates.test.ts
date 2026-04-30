import { describe, test, expect, beforeEach, afterEach } from "bun:test"
import { execSync } from "child_process"
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "fs"
import { tmpdir } from "os"
import { join } from "path"
import { createHash } from "crypto"
import { GatesPlugin } from "../plugins/gates"

/**
 * Tests for the gates plugin.
 *
 * Strategy:
 *   - Each test creates a tmp git repo on a real branch
 *   - XDG_STATE_HOME points at a tmp dir so writes are isolated
 *   - Hooks are invoked directly with fake input/output objects matching
 *     the OpenCode plugin SDK shapes
 *
 * Run from repo root:
 *   bun test dot_config/opencode/plugin-tests/
 */

type Hooks = Awaited<ReturnType<typeof GatesPlugin>>

let repoDir: string
let stateDir: string
let originalXdgState: string | undefined
let hooks: Hooks

function repoStatePath(toplevel: string, branch: string): string {
  const repoHash = createHash("sha256")
    .update(toplevel)
    .digest("hex")
    .slice(0, 12)
  const sanitized = branch.replace(/\//g, "__")
  return join(stateDir, "opencode", "gates", repoHash, `${sanitized}.json`)
}

async function setup(branchName = "main"): Promise<void> {
  repoDir = mkdtempSync(join(tmpdir(), "gates-test-repo-"))
  stateDir = mkdtempSync(join(tmpdir(), "gates-test-state-"))
  originalXdgState = process.env.XDG_STATE_HOME
  process.env.XDG_STATE_HOME = stateDir

  execSync("git init -q", { cwd: repoDir })
  execSync("git config user.email test@example.com", { cwd: repoDir })
  execSync("git config user.name Test", { cwd: repoDir })
  execSync("git config commit.gpgsign false", { cwd: repoDir })
  execSync(`git checkout -q -b ${branchName}`, { cwd: repoDir })
  // Need at least one commit so HEAD is valid
  writeFileSync(join(repoDir, ".keep"), "")
  execSync("git add .keep && git commit -q -m initial", { cwd: repoDir })

  hooks = await GatesPlugin({
    directory: repoDir,
    worktree: repoDir,
  } as any)
}

function teardown(): void {
  if (repoDir && existsSync(repoDir)) rmSync(repoDir, { recursive: true, force: true })
  if (stateDir && existsSync(stateDir)) rmSync(stateDir, { recursive: true, force: true })
  if (originalXdgState === undefined) delete process.env.XDG_STATE_HOME
  else process.env.XDG_STATE_HOME = originalXdgState
}

// ---------- Mini helpers for invoking hooks ----------

async function callBefore(tool: string, args: any): Promise<{ thrown: Error | null }> {
  const input = { tool, sessionID: "s", callID: "c" }
  const output = { args }
  try {
    await hooks["tool.execute.before"]!(input as any, output as any)
    return { thrown: null }
  } catch (err) {
    return { thrown: err as Error }
  }
}

async function callAfter(tool: string, args: any, metadata: any = {}): Promise<void> {
  const input = { tool, sessionID: "s", callID: "c", args }
  const output = { title: "", output: "", metadata }
  await hooks["tool.execute.after"]!(input as any, output as any)
}

function approvalQuestion(header: string, label: string) {
  return {
    args: { questions: [{ header, question: "?", options: [{ label, description: "" }] }] },
    metadata: { answers: [[label]] },
  }
}

// ---------- Tests ----------

describe("plan gate", () => {
  beforeEach(() => setup())
  afterEach(teardown)

  test("blocks edit when plan_approved is false", async () => {
    const result = await callBefore("edit", { filePath: "/x.ts", oldString: "a", newString: "b" })
    expect(result.thrown).not.toBeNull()
    expect(result.thrown!.message).toContain("plan gate not approved")
  })

  test("blocks write when plan_approved is false", async () => {
    const result = await callBefore("write", { filePath: "/x.ts", content: "" })
    expect(result.thrown).not.toBeNull()
    expect(result.thrown!.message).toContain("plan gate not approved")
  })

  test("blocks apply_patch when plan_approved is false", async () => {
    const result = await callBefore("apply_patch", { input: "" })
    expect(result.thrown).not.toBeNull()
    expect(result.thrown!.message).toContain("plan gate not approved")
  })

  test("approval question with Approved label sets plan_approved=true", async () => {
    const q = approvalQuestion("Plan approval gate", "Approved — go")
    await callAfter("question", q.args, q.metadata)

    const stateFile = repoStatePath(execSync("git rev-parse --show-toplevel", { cwd: repoDir, encoding: "utf8" }).trim(), "main")
    expect(existsSync(stateFile)).toBe(true)
    const state = JSON.parse(readFileSync(stateFile, "utf8"))
    expect(state.plan_approved).toBe(true)
  })

  test("approval question with non-Approved label does NOT set plan_approved", async () => {
    const q = approvalQuestion("Plan approval gate", "Not yet — needs work")
    await callAfter("question", q.args, q.metadata)

    const stateFile = repoStatePath(execSync("git rev-parse --show-toplevel", { cwd: repoDir, encoding: "utf8" }).trim(), "main")
    expect(existsSync(stateFile)).toBe(false)
  })

  test("edit succeeds after plan_approved=true", async () => {
    const q = approvalQuestion("Plan approval gate", "Approved — go")
    await callAfter("question", q.args, q.metadata)

    const result = await callBefore("edit", { filePath: "/x.ts", oldString: "a", newString: "b" })
    expect(result.thrown).toBeNull()
  })
})

describe("commit gate", () => {
  beforeEach(() => setup())
  afterEach(teardown)

  test("blocks `git commit` when commit_approved is false", async () => {
    const result = await callBefore("bash", { command: "git commit -m 'x'" })
    expect(result.thrown).not.toBeNull()
    expect(result.thrown!.message).toContain("commit gate not approved")
  })

  test("does NOT block `git add`", async () => {
    const result = await callBefore("bash", { command: "git add ." })
    expect(result.thrown).toBeNull()
  })

  test("does NOT block `git commit-tree` (regex precision)", async () => {
    const result = await callBefore("bash", { command: "git commit-tree abc123" })
    expect(result.thrown).toBeNull()
  })

  test("commit approval flips commit_approved=true and resets plan_approved=false", async () => {
    // First approve plan
    const planQ = approvalQuestion("Plan approval gate", "Approved — go")
    await callAfter("question", planQ.args, planQ.metadata)

    // Then approve commit
    const commitQ = approvalQuestion("Pre-commit review gate", "Approved — commit")
    await callAfter("question", commitQ.args, commitQ.metadata)

    const stateFile = repoStatePath(execSync("git rev-parse --show-toplevel", { cwd: repoDir, encoding: "utf8" }).trim(), "main")
    const state = JSON.parse(readFileSync(stateFile, "utf8"))
    expect(state.commit_approved).toBe(true)
    expect(state.plan_approved).toBe(false)
  })

  test("git commit attempt consumes commit_approved (sets it to false)", async () => {
    const commitQ = approvalQuestion("Pre-commit review gate", "Approved — commit")
    await callAfter("question", commitQ.args, commitQ.metadata)

    // Simulate a successful commit attempt
    await callAfter("bash", { command: "git commit -m 'x'" }, { exit: 0 })

    const stateFile = repoStatePath(execSync("git rev-parse --show-toplevel", { cwd: repoDir, encoding: "utf8" }).trim(), "main")
    const state = JSON.parse(readFileSync(stateFile, "utf8"))
    expect(state.commit_approved).toBe(false)
  })

  test("commit attempt consumes approval EVEN ON FAILURE", async () => {
    const commitQ = approvalQuestion("Pre-commit review gate", "Approved — commit")
    await callAfter("question", commitQ.args, commitQ.metadata)

    await callAfter("bash", { command: "git commit -m 'x'" }, { exit: 1 })

    const stateFile = repoStatePath(execSync("git rev-parse --show-toplevel", { cwd: repoDir, encoding: "utf8" }).trim(), "main")
    const state = JSON.parse(readFileSync(stateFile, "utf8"))
    expect(state.commit_approved).toBe(false)
  })
})

describe("push gate", () => {
  beforeEach(() => setup())
  afterEach(teardown)

  test("blocks `git push` when push_approved is false", async () => {
    const result = await callBefore("bash", { command: "git push" })
    expect(result.thrown).not.toBeNull()
    expect(result.thrown!.message).toContain("push gate not approved")
  })

  test("push approval flips push_approved=true", async () => {
    const pushQ = approvalQuestion("Pre-push approval gate", "Approved — push")
    await callAfter("question", pushQ.args, pushQ.metadata)

    const stateFile = repoStatePath(execSync("git rev-parse --show-toplevel", { cwd: repoDir, encoding: "utf8" }).trim(), "main")
    const state = JSON.parse(readFileSync(stateFile, "utf8"))
    expect(state.push_approved).toBe(true)
  })

  test("git push attempt deletes the entire state file", async () => {
    const pushQ = approvalQuestion("Pre-push approval gate", "Approved — push")
    await callAfter("question", pushQ.args, pushQ.metadata)

    const toplevel = execSync("git rev-parse --show-toplevel", { cwd: repoDir, encoding: "utf8" }).trim()
    const stateFile = repoStatePath(toplevel, "main")
    expect(existsSync(stateFile)).toBe(true)

    await callAfter("bash", { command: "git push origin main" }, { exit: 0 })
    expect(existsSync(stateFile)).toBe(false)
  })
})

describe("branch handling", () => {
  test("sanitizes slashes in branch name", async () => {
    await setup("feat/my-feature")
    try {
      const planQ = approvalQuestion("Plan approval gate", "Approved")
      await callAfter("question", planQ.args, planQ.metadata)

      const toplevel = execSync("git rev-parse --show-toplevel", { cwd: repoDir, encoding: "utf8" }).trim()
      const stateFile = repoStatePath(toplevel, "feat/my-feature")
      // path uses double underscore, not slash
      expect(stateFile).toContain("feat__my-feature.json")
      expect(existsSync(stateFile)).toBe(true)
    } finally {
      teardown()
    }
  })

  test("isolates state per branch", async () => {
    await setup("main")
    try {
      // Approve on main
      const planQ = approvalQuestion("Plan approval gate", "Approved")
      await callAfter("question", planQ.args, planQ.metadata)

      // Switch branch in same repo
      execSync("git checkout -q -b other", { cwd: repoDir })

      // Plan should still be blocked on the new branch
      const result = await callBefore("edit", { filePath: "/x.ts", oldString: "a", newString: "b" })
      expect(result.thrown).not.toBeNull()
    } finally {
      teardown()
    }
  })
})

describe("non-git contexts", () => {
  let originalDir: string
  let nonGitDir: string

  beforeEach(async () => {
    nonGitDir = mkdtempSync(join(tmpdir(), "gates-test-nongit-"))
    stateDir = mkdtempSync(join(tmpdir(), "gates-test-state-"))
    originalXdgState = process.env.XDG_STATE_HOME
    process.env.XDG_STATE_HOME = stateDir

    hooks = await GatesPlugin({ directory: nonGitDir, worktree: nonGitDir } as any)
  })

  afterEach(() => {
    if (existsSync(nonGitDir)) rmSync(nonGitDir, { recursive: true, force: true })
    if (existsSync(stateDir)) rmSync(stateDir, { recursive: true, force: true })
    if (originalXdgState === undefined) delete process.env.XDG_STATE_HOME
    else process.env.XDG_STATE_HOME = originalXdgState
  })

  test("plugin is no-op when not in a git repo", async () => {
    const result = await callBefore("edit", { filePath: "/x.ts", oldString: "a", newString: "b" })
    expect(result.thrown).toBeNull()
  })

  test("plugin is no-op for git commit when not in a git repo", async () => {
    const result = await callBefore("bash", { command: "git commit -m 'x'" })
    expect(result.thrown).toBeNull()
  })
})
