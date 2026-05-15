/**
 * Tests for the permission-classifier plugin.
 *
 * Functions under test are extracted copies of their production counterparts so
 * private helpers can be called directly without importing the plugin module.
 *
 * Sections:
 *   1. classifyCurl — GraphQL detection
 *   2. classifyGh   — GraphQL / api method detection
 *   3. matchesToolRead — per-tool always_allow suffix lookup
 *   4. classifyDefault — walk-backward verb detection
 */
import { describe, expect, it } from "bun:test"

type Classification = "read" | "write" | "unknown"

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
  return argv.some(
    t => t === "-d" || t === "--data" || t === "--data-binary" || t === "--data-raw",
  )
}

// ---------------------------------------------------------------------------
// FIXED implementations (the target state)
// ---------------------------------------------------------------------------

function classifyCurl(argv: string[], rawCommand?: string): Classification {
  const src = rawCommand ? rawCommand.split(/\s+/) : argv

  // GraphQL: mutation keyword is required for any mutation operation.
  // Its absence means the body is a query (read). Check any token for the
  // graphql marker so -X POST ordering doesn't obscure the URL.
  if (src.some(t => t.includes("graphql"))) {
    const haystack = rawCommand ?? src.join(" ")
    return /\bmutation\b/.test(haystack) ? "write" : "read"
  }

  const method = extractHttpMethod(src)
  if (method) return httpMethodClass(method)
  if (hasImplicitBody(src)) return "write"
  return "read"
}

function classifyGh(argv: string[], rawCommand?: string): Classification {
  if (argv[1] === "api") {
    const src = rawCommand ? rawCommand.split(/\s+/) : argv

    // GraphQL endpoint: mutation keyword required for mutations. Check any
    // token for the graphql marker so flag ordering doesn't obscure the URL.
    if (src.some(t => t.includes("graphql"))) {
      const haystack = rawCommand ?? src.join(" ")
      return /\bmutation\b/.test(haystack) ? "write" : "read"
    }

    // Non-GraphQL: inspect HTTP method flag
    const method = extractHttpMethod(src)
    if (method) return httpMethodClass(method)
    return "read" // gh api defaults to GET
  }

  return "unknown"
}

// ---------------------------------------------------------------------------
// classifyCurl — GraphQL tests
// ---------------------------------------------------------------------------

describe("classifyCurl GraphQL", () => {
  it("classifies a GraphQL query as read when URL contains graphql and no mutation keyword", () => {
    // Arrange
    const argv = ["curl", "-X", "POST", "https://api.example.com/graphql", "-d", '{"query":"{ user { name } }"}']
    const raw = 'curl -X POST https://api.example.com/graphql -d \'{"query":"{ user { name } }"}\''

    // Act
    const result = classifyCurl(argv, raw)

    // Assert
    expect(result).toBe("read")
  })

  it("classifies a GraphQL mutation as write when mutation keyword present", () => {
    // Arrange
    const argv = ["curl", "-X", "POST", "https://api.example.com/graphql", "-d", '{"query":"mutation { createUser(name:\\"foo\\") { id } }"}']
    const raw = 'curl -X POST https://api.example.com/graphql -d \'{"query":"mutation { createUser(name:\\"foo\\") { id } }"}\''

    // Act
    const result = classifyCurl(argv, raw)

    // Assert
    expect(result).toBe("write")
  })

  it("classifies a GraphQL query as read when POST body present but no mutation keyword", () => {
    // Arrange: -d flag is present, which would incorrectly classify as write in the old code
    const argv = ["curl", "https://api.example.com/graphql", "-d", '{"query":"{ viewer { login } }"}']
    const raw = 'curl https://api.example.com/graphql -d \'{"query":"{ viewer { login } }"}\''

    // Act
    const result = classifyCurl(argv, raw)

    // Assert — the core regression: POST body should NOT override GraphQL query semantics
    expect(result).toBe("read")
  })

  it("does not match 'mutations' (plural) as a mutation operation", () => {
    // Arrange: 'mutations' is a field name, not a mutation operation keyword
    const argv = ["curl", "https://api.example.com/graphql", "-d", '{"query":"{ mutations { count } }"}']
    const raw = 'curl https://api.example.com/graphql -d \'{"query":"{ mutations { count } }"}\''

    // Act
    const result = classifyCurl(argv, raw)

    // Assert: \bmutation\b does not match "mutations"
    expect(result).toBe("read")
  })

  it("falls through to method/body checks for non-GraphQL URLs", () => {
    // Arrange: POST to a REST endpoint with body — should still be write
    const argv = ["curl", "https://api.example.com/users", "-d", '{"name":"foo"}']
    const raw = 'curl https://api.example.com/users -d \'{"name":"foo"}\''

    // Act
    const result = classifyCurl(argv, raw)

    // Assert
    expect(result).toBe("write")
  })
})

// ---------------------------------------------------------------------------
// classifyGh — GraphQL tests
// ---------------------------------------------------------------------------

describe("classifyGh GraphQL", () => {
  it("classifies a gh api graphql query as read when no mutation keyword", () => {
    // Arrange
    const argv = ["gh", "api", "graphql", "-f", 'query={ viewer { login } }']
    const raw = "gh api graphql -f 'query={ viewer { login } }'"

    // Act
    const result = classifyGh(argv, raw)

    // Assert — was "unknown" before the fix
    expect(result).toBe("read")
  })

  it("classifies a gh api graphql mutation as write", () => {
    // Arrange
    const argv = ["gh", "api", "graphql", "-f", 'query=mutation { createIssue(input:{}) { issue { id } } }']
    const raw = "gh api graphql -f 'query=mutation { createIssue(input:{}) { issue { id } } }'"

    // Act
    const result = classifyGh(argv, raw)

    // Assert
    expect(result).toBe("write")
  })

  it("classifies a gh api graphql query (full URL form) as read when no mutation keyword", () => {
    // Arrange: some scripts use the full GitHub GraphQL URL
    const argv = ["gh", "api", "--method", "POST", "https://api.github.com/graphql"]
    const raw = "gh api --method POST https://api.github.com/graphql"

    // Act
    const result = classifyGh(argv, raw)

    // Assert: graphql URL with no mutation keyword → read
    expect(result).toBe("read")
  })

  it("classifies non-graphql gh api with explicit GET method as read", () => {
    // Arrange
    const argv = ["gh", "api", "-X", "GET", "/repos/foo/bar"]
    const raw = "gh api -X GET /repos/foo/bar"

    // Act
    const result = classifyGh(argv, raw)

    // Assert
    expect(result).toBe("read")
  })

  it("classifies non-graphql gh api with no method flag as read (GET default)", () => {
    // Arrange
    const argv = ["gh", "api", "/repos/foo/bar"]

    // Act
    const result = classifyGh(argv)

    // Assert
    expect(result).toBe("read")
  })
})

// ---------------------------------------------------------------------------
// matchesToolAlwaysAllow — per-tool always_allow suffix lookup
// ---------------------------------------------------------------------------

function nonFlagTokens(argv: string[]): string[] {
  return argv.filter(t => !t.startsWith("-"))
}

/**
 * Extracted copy of matchesToolAlwaysAllow from permission-classifier.ts.
 * Accepts an explicit toolAlwaysAllow map so tests are self-contained.
 */
function matchesToolAlwaysAllow(argv: string[], toolAlwaysAllow: Record<string, Set<string>>): boolean {
  if (argv.length < 2) return false
  const tool = argv[0]
  const entries = toolAlwaysAllow[tool]
  if (!entries) return false

  const nf = nonFlagTokens(argv.slice(1))
  if (nf.length === 0) return false

  for (let len = nf.length; len >= 1; len--) {
    const suffix = nf.slice(0, len).join(" ")
    if (entries.has(suffix)) return true
  }
  return false
}

describe("matchesToolAlwaysAllow — single-token suffix", () => {
  const toolAlwaysAllow = {
    git: new Set(["rev-parse", "merge-base", "reflog"]),
    chezmoi: new Set(["execute-template", "source-path"]),
  }

  it("returns true for a known single-token suffix", () => {
    // Arrange
    const argv = ["git", "rev-parse", "HEAD"]

    // Act / Assert
    expect(matchesToolAlwaysAllow(argv, toolAlwaysAllow)).toBe(true)
  })

  it("returns false for a suffix not in the tool's always_allow set", () => {
    // Arrange: "push" is not always-allowed for git
    const argv = ["git", "push", "origin", "main"]

    // Act / Assert
    expect(matchesToolAlwaysAllow(argv, toolAlwaysAllow)).toBe(false)
  })

  it("returns false for a tool with no entry in toolAlwaysAllow", () => {
    // Arrange: "rg" has no per-tool entry (covered by static defaults)
    const argv = ["rg", "some-pattern"]

    // Act / Assert
    expect(matchesToolAlwaysAllow(argv, toolAlwaysAllow)).toBe(false)
  })

  it("returns false when argv has only the tool name and no subcommand", () => {
    // Arrange
    const argv = ["git"]

    // Act / Assert
    expect(matchesToolAlwaysAllow(argv, toolAlwaysAllow)).toBe(false)
  })

  it("ignores flag tokens when matching the suffix", () => {
    // Arrange: flags before the subcommand should not affect suffix matching
    const argv = ["chezmoi", "--verbose", "execute-template"]

    // Act / Assert
    expect(matchesToolAlwaysAllow(argv, toolAlwaysAllow)).toBe(true)
  })
})

describe("matchesToolAlwaysAllow — multi-token suffix", () => {
  const toolAlwaysAllow = {
    gh: new Set(["checks", "pr checks"]),
    gws: new Set(["drive files export"]),
  }

  it("matches a two-token suffix (gh pr checks)", () => {
    // Arrange
    const argv = ["gh", "pr", "checks", "123"]

    // Act / Assert
    expect(matchesToolAlwaysAllow(argv, toolAlwaysAllow)).toBe(true)
  })

  it("matches a single-token suffix when multi-token is also in the set", () => {
    // Arrange: "gh checks" alone — matches the single-token entry "checks"
    const argv = ["gh", "checks"]

    // Act / Assert
    expect(matchesToolAlwaysAllow(argv, toolAlwaysAllow)).toBe(true)
  })

  it("does not match an unknown two-token suffix even when the first token is known", () => {
    // Arrange: "gws docs documents create" — create is not always-allowed
    const argv = ["gws", "docs", "documents", "create"]

    // Act / Assert
    expect(matchesToolAlwaysAllow(argv, toolAlwaysAllow)).toBe(false)
  })
})

// ---------------------------------------------------------------------------
// classifyDefault — walk-backward verb detection
// ---------------------------------------------------------------------------

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

function classifyDefault(argv: string[]): Classification {
  const nf = argv.filter(t => !t.startsWith("-"))
  for (let i = nf.length - 1; i >= 1; i--) {
    const tok = nf[i]
    if (DEFAULT_READ_VERBS.has(tok)) return "read"
    if (DEFAULT_WRITE_VERBS.has(tok)) return "write"
  }
  return "unknown"
}

describe("classifyDefault — walk-backward verb detection", () => {
  it("classifies a nested CLI with positional args after the verb as read", () => {
    // Arrange: "get" is the verb; "DOC_ID" and "outfile.txt" are positional args after it
    const argv = ["gws", "docs", "documents", "get", "DOC_ID", "outfile.txt"]

    // Act
    const result = classifyDefault(argv)

    // Assert: old last-token approach would return "unknown" (outfile.txt); walk-backward finds "get"
    expect(result).toBe("read")
  })

  it("classifies aws s3 ls as read (verb before bucket arg)", () => {
    // Arrange
    const argv = ["aws", "s3", "ls", "s3://my-bucket"]

    // Act
    const result = classifyDefault(argv)

    // Assert
    expect(result).toBe("read")
  })

  it("classifies kubectl get pods -n foo as read (verb before resource and flag args)", () => {
    // Arrange
    const argv = ["kubectl", "get", "pods", "-n", "foo"]

    // Act
    const result = classifyDefault(argv)

    // Assert
    expect(result).toBe("read")
  })

  it("classifies a command with only unrecognized tokens as unknown", () => {
    // Arrange: no token in argv is in either verb set
    const argv = ["sometool", "subcommand", "identifier123"]

    // Act
    const result = classifyDefault(argv)

    // Assert
    expect(result).toBe("unknown")
  })

  it("does not use argv[0] (the tool name) as a verb candidate", () => {
    // Arrange: tool name "get" should not be recognized as the read verb
    // Only tokens after argv[0] are considered
    const argv = ["get", "something-else"]

    // Act
    const result = classifyDefault(argv)

    // Assert: "something-else" is unknown, and "get" at index 0 is excluded
    expect(result).toBe("unknown")
  })
})
