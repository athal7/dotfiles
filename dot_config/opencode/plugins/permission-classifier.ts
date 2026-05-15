import { readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

type Classification = "read" | "write" | "unknown"

function loadToolAlwaysAllow(): Record<string, Set<string>> {
  try {
    const p = join(homedir(), ".config", "opencode", "permission-reads.json")
    const raw = readFileSync(p, "utf8")
    const parsed = JSON.parse(raw)
    if (parsed?.tools && typeof parsed.tools === "object") {
      const result: Record<string, Set<string>> = {}
      for (const [tool, entry] of Object.entries(parsed.tools)) {
        const suffixes = (entry as Record<string, unknown>)?.always_allow
        if (Array.isArray(suffixes)) {
          result[tool] = new Set(suffixes as string[])
        }
      }
      return result
    }
  } catch {
    // absent during first deploy or tests
  }
  return {}
}

const TOOL_ALWAYS_ALLOW: Record<string, Set<string>> = loadToolAlwaysAllow()

const DEFAULT_READ_VERBS = new Set([
  "list", "view", "show", "status", "log", "diff", "blame", "search", "find",
  "describe", "inspect", "info", "get", "check", "verify", "read", "history", "summary",
  "version", "help", "ls", "cat", "head", "tail", "count", "exists", "validate", "render",
  "data", "managed", "ps", "jobs", "paths", "actions", "health", "sources", "watch",
  "whoami", "stats", "routes", "audit", "lint", "test", "spec",
])

const DEFAULT_WRITE_VERBS = new Set([
  "create", "edit", "delete", "update", "push", "commit", "reset", "restore",
  "set", "add", "remove", "install", "uninstall", "enable", "disable", "login", "logout",
  "apply", "revert", "deploy", "drop", "pop", "clear", "review", "comment", "send", "post",
  "publish", "archive", "sync", "pull", "fetch", "init", "clone", "merge", "close", "reopen",
  "write", "mv", "cp", "rm", "mkdir", "rmdir", "touch", "kill", "pkill", "start", "stop",
  "restart", "reload", "unload", "bootstrap", "bootout", "kickstart", "upgrade", "build",
  "compile", "generate", "scaffold", "migrate", "seed", "setup", "teardown", "ingest",
  "process", "confirm", "record", "complete", "done", "approve", "reject", "squash",
  "restack", "submit", "upload", "import", "export", "purge", "destroy", "rollback",
  "undo", "rerun", "cancel", "repair", "fix", "run",
])

function validateAlwaysAllow(toolAlwaysAllow: Record<string, Set<string>>): void {
  for (const [tool, entries] of Object.entries(toolAlwaysAllow)) {
    for (const entry of entries) {
      const parts = entry.split(/\s+/)
      if (parts.length === 1 && DEFAULT_READ_VERBS.has(entry)) {
        console.warn(
          `[permission-classifier] Redundant always_allow entry: ${tool}.${entry} — ` +
          `single-token verb is already in DEFAULT_READ_VERBS`,
        )
      }
    }
  }
}

validateAlwaysAllow(TOOL_ALWAYS_ALLOW)

function tokens(segment: string): string[] {
  return segment.trim().split(/\s+/).filter(Boolean)
}

function nonFlagTokens(argv: string[]): string[] {
  return argv.filter(t => !t.startsWith("-"))
}

function httpMethodClass(method: string): Classification {
  if (method === "GET" || method === "HEAD") return "read"
  if (method === "POST" || method === "PUT" || method === "PATCH" || method === "DELETE") return "write"
  return "unknown"
}

function extractHttpMethod(argv: string[]): string | undefined {
  for (let i = 0; i < argv.length - 1; i++) {
    if (argv[i] === "-X" || argv[i] === "--request" || argv[i] === "--method") {
      return argv[i + 1].toUpperCase()
    }
  }
  return undefined
}

function hasImplicitBody(argv: string[]): boolean {
  return argv.some(t => t === "-d" || t === "--data" || t === "--data-binary" || t === "--data-raw")
}

function matchesToolAlwaysAllow(argv: string[]): boolean {
  if (argv.length < 2) return false
  const tool = argv[0]
  const entries = TOOL_ALWAYS_ALLOW[tool]
  if (!entries) return false

  const nf = nonFlagTokens(argv.slice(1))
  if (nf.length === 0) return false

  for (let len = nf.length; len >= 1; len--) {
    const suffix = nf.slice(0, len).join(" ")
    if (entries.has(suffix)) return true
  }
  return false
}

function classifyGit(argv: string[]): Classification {
  let start = 1
  while (start < argv.length && argv[start] === "-C") start += 2

  const nf = nonFlagTokens(argv.slice(start))
  const sub = nf[0]
  if (!sub) return "unknown"

  const rest = nf.slice(1)
  if (sub === "stash" || sub === "worktree") {
    return rest[0] === "list" ? "read" : "write"
  }
  if (sub === "branch") {
    if (rest.some(t => ["-d", "-D", "-m", "-c", "-C", "-M"].includes(t))) return "write"
    if (rest.length > 0) return "write"
    return "read"
  }
  if (sub === "tag") {
    return rest.length > 0 ? "write" : "read"
  }
  if (sub === "config") {
    return rest.some(t => t === "--get" || t === "--list" || t === "--show-origin") ? "read" : "write"
  }

  return "unknown"
}

function classifyGh(argv: string[], rawCommand?: string): Classification {
  if (argv[1] === "api") {
    const src = rawCommand ? rawCommand.split(/\s+/) : argv

    if (src.some(t => t.includes("graphql"))) {
      const haystack = rawCommand ?? src.join(" ")
      return /\bmutation\b/.test(haystack) ? "write" : "read"
    }

    const method = extractHttpMethod(src)
    if (method) return httpMethodClass(method)
    return "read"
  }

  return "unknown"
}

function classifyCurl(argv: string[], rawCommand?: string): Classification {
  const src = rawCommand ? rawCommand.split(/\s+/) : argv

  if (src.some(t => t.includes("graphql"))) {
    const haystack = rawCommand ?? src.join(" ")
    return /\bmutation\b/.test(haystack) ? "write" : "read"
  }

  const method = extractHttpMethod(src)
  if (method) return httpMethodClass(method)
  if (hasImplicitBody(src)) return "write"
  return "read"
}

function classifyDefault(argv: string[]): Classification {
  const nf = nonFlagTokens(argv)
  for (let i = nf.length - 1; i >= 1; i--) {
    const tok = nf[i]
    if (DEFAULT_READ_VERBS.has(tok)) return "read"
    if (DEFAULT_WRITE_VERBS.has(tok)) return "write"
  }
  return "unknown"
}

function classifySegment(segment: string, rawCommand?: string): Classification {
  const argv = tokens(segment)
  if (argv.length === 0) return "unknown"

  switch (argv[0]) {
    case "git":  {
      const gitResult = classifyGit(argv)
      if (gitResult !== "unknown") return gitResult
      break
    }
    case "gh": {
      const ghResult = classifyGh(argv, rawCommand)
      if (ghResult !== "unknown") return ghResult
      break
    }
    case "curl": return classifyCurl(argv, rawCommand)
  }

  if (matchesToolAlwaysAllow(argv)) return "read"
  return classifyDefault(argv)
}

function severity(c: Classification): number {
  return c === "write" ? 2 : c === "unknown" ? 1 : 0
}

function classifyPattern(pattern: string, rawCommand?: string): Classification {
  const segments = pattern.split(/&&|\|\||[;|]/)
  let max: Classification = "read"
  for (const seg of segments) {
    const c = classifySegment(seg.trim(), rawCommand)
    if (severity(c) > severity(max)) max = c
  }
  return max
}

function classifyPatterns(patterns: string[], rawCommand?: string): Classification {
  let max: Classification = "read"
  for (const p of patterns) {
    const c = classifyPattern(p, rawCommand)
    if (severity(c) > severity(max)) max = c
  }
  return max
}

export default (async () => {
  return {
    "permission.ask": async (input, output) => {
      if (input.permission !== "bash") return

      const rawCommand = typeof input.metadata?.command === "string"
        ? input.metadata.command
        : undefined

      const result = classifyPatterns(input.patterns, rawCommand)
      if (result === "read") output.status = "allow"
    },
  }
}) satisfies Plugin
