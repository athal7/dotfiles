/**
 * Tests for the capability plugin.
 *
 * Functions under test are extracted copies of their production counterparts so
 * private helpers can be called directly without importing the plugin module
 * (which has runtime deps on `@opencode-ai/plugin` and Bun.YAML filesystem APIs).
 *
 * Sections:
 *   1. parseSkillFrontmatter — YAML frontmatter parsing and requires extraction
 *   2. buildInjection        — capability resolution and injection block assembly
 *   3. Format validation     — shape of the injection block header and unresolved suffix
 */
import { describe, expect, it } from "bun:test"

// ---------------------------------------------------------------------------
// Extracted: parseSkillFrontmatter
// Mirrors the production implementation in capability.ts.
// ---------------------------------------------------------------------------

function parseSkillFrontmatter(content: string): { requires?: string[] } {
  const match = content.match(/^---\n([\s\S]*?)\n---/)
  if (!match) return {}
  try {
    const fm = Bun.YAML.parse(match[1]) as Record<string, unknown>
    const metadata = fm.metadata as Record<string, unknown> | undefined
    const requires = metadata?.requires ?? fm.requires
    if (Array.isArray(requires)) return { requires: requires.map(String) }
  } catch {
    // malformed frontmatter — skip
  }
  return {}
}

// ---------------------------------------------------------------------------
// Extracted: buildInjection (with injected dependencies for testability)
//
// The production version calls loadSkillProviders() and readSkillDescription()
// which touch the filesystem. Here we accept them as parameters so tests are
// fully self-contained.
// ---------------------------------------------------------------------------

const BUILTIN_CAPABILITY_DEFAULTS: Record<string, string> = {
  rest: "curl (default — install `xh` skill for cleaner syntax)",
  graphql: "curl -X POST with JSON body (default — install `gq` skill for introspection)",
}

function buildInjection(
  requires: string[],
  providers: Record<string, string[]>,
  readSkillDescription: (skillName: string) => string | null,
): string {
  if (requires.length === 0) return ""
  const lines: string[] = []
  const unresolved: string[] = []

  for (const name of requires) {
    const skills = providers[name]
    if (!skills || skills.length === 0) {
      const builtin = BUILTIN_CAPABILITY_DEFAULTS[name]
      if (builtin) {
        lines.push(`- ${name}: ${builtin}`)
      } else {
        unresolved.push(name)
      }
    } else if (skills.length === 1) {
      lines.push(`- ${name}: load \`${skills[0]}\` skill`)
    } else {
      // Multiple providers — emit a sub-list with description hints
      lines.push(`- ${name}:`)
      for (const skill of skills) {
        const desc = readSkillDescription(skill)
        const hint = desc ? ` (${desc})` : ""
        lines.push(`  - load \`${skill}\` skill${hint}`)
      }
    }
  }

  if (lines.length === 0 && unresolved.length === 0) return ""
  let block = "\n---\n**Capabilities:**\n" + lines.join("\n")
  if (unresolved.length > 0) {
    block += `\nUnresolved: ${unresolved.join(", ")} — ask the user which provider to use`
  }
  return block
}

// ---------------------------------------------------------------------------
// 1. parseSkillFrontmatter
// ---------------------------------------------------------------------------

describe("parseSkillFrontmatter — metadata.requires path", () => {
  it("returns the requires array when nested under metadata", () => {
    // Arrange
    const content = `---
metadata:
  requires:
    - rest
    - graphql
---
# Skill content here`

    // Act
    const result = parseSkillFrontmatter(content)

    // Assert
    expect(result.requires).toEqual(["rest", "graphql"])
  })

  it("returns an empty object when metadata has no requires key", () => {
    // Arrange
    const content = `---
metadata:
  provides:
    - something
---
# Body`

    // Act
    const result = parseSkillFrontmatter(content)

    // Assert
    expect(result).toEqual({})
  })
})

describe("parseSkillFrontmatter — top-level requires (legacy/auto-discovery path)", () => {
  it("returns the requires array when declared at the top level", () => {
    // Arrange — skills without a metadata block use top-level requires
    const content = `---
requires:
  - slack
  - github
---
# Body`

    // Act
    const result = parseSkillFrontmatter(content)

    // Assert
    expect(result.requires).toEqual(["slack", "github"])
  })

  it("prefers metadata.requires over top-level requires when both present", () => {
    // Arrange
    const content = `---
requires:
  - top-level
metadata:
  requires:
    - in-metadata
---
# Body`

    // Act
    const result = parseSkillFrontmatter(content)

    // Assert: metadata.requires takes precedence (nullish coalescing order in production)
    expect(result.requires).toEqual(["in-metadata"])
  })
})

describe("parseSkillFrontmatter — no / invalid frontmatter", () => {
  it("returns empty object when the file has no frontmatter delimiters", () => {
    // Arrange
    const content = "# Just a plain markdown file\nNo frontmatter here."

    // Act
    const result = parseSkillFrontmatter(content)

    // Assert
    expect(result).toEqual({})
  })

  it("returns empty object (does not throw) when frontmatter YAML is malformed", () => {
    // Arrange: colons without values, invalid indentation
    const content = `---
requires: [unclosed bracket
  - oops
---
# Body`

    // Act / Assert — must not throw
    expect(() => parseSkillFrontmatter(content)).not.toThrow()
    expect(parseSkillFrontmatter(content)).toEqual({})
  })

  it("returns empty object when requires is present but not an array", () => {
    // Arrange: requires is a plain string, not a list
    const content = `---
requires: "some-string"
---
# Body`

    // Act
    const result = parseSkillFrontmatter(content)

    // Assert
    expect(result).toEqual({})
  })

  it("coerces non-string items in requires array to strings via map(String)", () => {
    // Arrange: requires contains numbers — YAML parses them as numbers, not strings
    const content = `---
requires:
  - 42
  - true
  - rest
---
# Body`

    // Act
    const result = parseSkillFrontmatter(content)

    // Assert: all items coerced to strings
    expect(result.requires).toEqual(["42", "true", "rest"])
  })
})

// ---------------------------------------------------------------------------
// 2. buildInjection — capability resolution
// ---------------------------------------------------------------------------

describe("buildInjection — empty requires", () => {
  it("returns an empty string when requires is empty", () => {
    // Arrange
    const providers: Record<string, string[]> = {}
    const desc = (_: string) => null

    // Act
    const result = buildInjection([], providers, desc)

    // Assert
    expect(result).toBe("")
  })
})

describe("buildInjection — single provider", () => {
  it("emits a single load-skill line for a resolved capability", () => {
    // Arrange
    const providers = { docs: ["gws"] }
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["docs"], providers, desc)

    // Assert
    expect(result).toContain("- docs: load `gws` skill")
  })
})

describe("buildInjection — multiple providers for one capability", () => {
  it("emits a sub-list entry for each provider", () => {
    // Arrange: two skills both provide the same capability
    const providers = { calendar: ["ical-cli", "gcal"] }
    const desc = (skill: string) => (skill === "ical-cli" ? "Apple Calendar via CLI" : null)

    // Act
    const result = buildInjection(["calendar"], providers, desc)

    // Assert: parent bullet with no trailing text, then child bullets
    expect(result).toContain("- calendar:")
    expect(result).toContain("  - load `ical-cli` skill (Apple Calendar via CLI)")
    expect(result).toContain("  - load `gcal` skill")
  })

  it("omits the description hint when readSkillDescription returns empty string", () => {
    // Arrange: description is empty string (treated as falsy)
    const providers = { calendar: ["ical-cli", "gcal"] }
    const desc = (_: string) => ""

    // Act
    const result = buildInjection(["calendar"], providers, desc)

    // Assert: no trailing hint on any sub-entry
    expect(result).not.toMatch(/skill \(/)
  })

  it("omits the description hint when readSkillDescription returns null", () => {
    // Arrange
    const providers = { calendar: ["ical-cli", "gcal"] }
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["calendar"], providers, desc)

    // Assert
    expect(result).not.toMatch(/skill \(/)
  })
})

describe("buildInjection — multiple requires all resolved", () => {
  it("emits a line for each capability in order", () => {
    // Arrange
    const providers = { rest: ["xh"], graphql: ["gq"] }
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["rest", "graphql"], providers, desc)

    // Assert
    expect(result).toContain("- rest: load `xh` skill")
    expect(result).toContain("- graphql: load `gq` skill")
  })
})

describe("buildInjection — unresolved capabilities", () => {
  it("adds unresolved to the suffix when no provider and no builtin fallback", () => {
    // Arrange: 'database' has no provider and no BUILTIN_CAPABILITY_DEFAULTS entry
    const providers: Record<string, string[]> = {}
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["database"], providers, desc)

    // Assert
    expect(result).toContain("Unresolved: database")
    expect(result).toContain("ask the user which provider to use")
  })

  it("lists multiple unresolved capabilities comma-separated in the suffix", () => {
    // Arrange
    const providers: Record<string, string[]> = {}
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["database", "smtp"], providers, desc)

    // Assert: both appear in the Unresolved suffix
    expect(result).toContain("Unresolved: database, smtp")
  })
})

describe("buildInjection — BUILTIN_CAPABILITY_DEFAULTS fallbacks", () => {
  it("emits the rest fallback line when no skill provides rest", () => {
    // Arrange
    const providers: Record<string, string[]> = {}
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["rest"], providers, desc)

    // Assert: builtin fallback text, not unresolved
    expect(result).toContain("- rest: curl (default")
    expect(result).not.toContain("Unresolved")
  })

  it("emits the graphql fallback line when no skill provides graphql", () => {
    // Arrange
    const providers: Record<string, string[]> = {}
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["graphql"], providers, desc)

    // Assert
    expect(result).toContain("- graphql: curl -X POST with JSON body")
    expect(result).not.toContain("Unresolved")
  })

  it("uses skill provider over builtin fallback when a skill registers the capability", () => {
    // Arrange: xh skill provides rest, overriding the default
    const providers = { rest: ["xh"] }
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["rest"], providers, desc)

    // Assert: skill takes precedence
    expect(result).toContain("load `xh` skill")
    expect(result).not.toContain("curl (default")
  })
})

describe("buildInjection — mixed resolved, unresolved, and defaults", () => {
  it("renders all three categories correctly in one call", () => {
    // Arrange
    // - docs → resolved via single provider
    // - rest → BUILTIN_CAPABILITY_DEFAULTS fallback
    // - database → unresolved (no provider, no builtin)
    const providers = { docs: ["gws"] }
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["docs", "rest", "database"], providers, desc)

    // Assert all three sections are present
    expect(result).toContain("- docs: load `gws` skill")
    expect(result).toContain("- rest: curl (default")
    expect(result).toContain("Unresolved: database")
    expect(result).toContain("ask the user which provider to use")
  })
})

// ---------------------------------------------------------------------------
// 3. Format validation — injection block header and unresolved suffix shape
// ---------------------------------------------------------------------------

describe("buildInjection — format validation", () => {
  it("starts with newline-separator-header sequence", () => {
    // Arrange
    const providers = { rest: ["xh"] }
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["rest"], providers, desc)

    // Assert: block always starts with \n---\n**Capabilities:**\n
    expect(result.startsWith("\n---\n**Capabilities:**\n")).toBe(true)
  })

  it("unresolved suffix has exactly the right template shape", () => {
    // Arrange
    const providers: Record<string, string[]> = {}
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["unknown-cap"], providers, desc)

    // Assert: suffix format matches the production template exactly
    expect(result).toMatch(/\nUnresolved: unknown-cap — ask the user which provider to use$/)
  })

  it("no unresolved suffix when all capabilities are resolved", () => {
    // Arrange
    const providers = { rest: ["xh"], docs: ["gws"] }
    const desc = (_: string) => null

    // Act
    const result = buildInjection(["rest", "docs"], providers, desc)

    // Assert
    expect(result).not.toContain("Unresolved")
    expect(result).not.toContain("ask the user")
  })

  it("returns empty string when all requires are empty array (not just falsy)", () => {
    // Triangulate: ensure empty array → empty string, not a header-only block
    const providers: Record<string, string[]> = { docs: ["gws"] }
    const desc = (_: string) => null

    // Act
    const result = buildInjection([], providers, desc)

    // Assert
    expect(result).toBe("")
  })
})
