/**
 * Tests for the inject plugin.
 *
 * Functions under test are extracted copies of their production counterparts so
 * they can be called directly without importing the plugin module (which has
 * runtime deps on `@opencode-ai/plugin` and Bun.YAML filesystem APIs).
 *
 * Sections:
 *   1. readDescription      — YAML frontmatter description extraction
 *   2. buildInjection       — injection block assembly from skill names
 *   3. inject_list format   — output format for the listing tool
 */
import { describe, expect, it } from "bun:test"

// ---------------------------------------------------------------------------
// Extracted: readDescription
// Mirrors the production cache-lookup logic but without filesystem access.
// In production this reads SKILL.md and parses frontmatter; here we test the
// parsing logic directly.
// ---------------------------------------------------------------------------

function parseDescription(content: string): string | null {
  const match = content.match(/^---\n([\s\S]*?)\n---/)
  if (!match) return null
  try {
    const fm = Bun.YAML.parse(match[1]) as Record<string, unknown>
    return typeof fm.description === "string" ? fm.description : null
  } catch {
    return null
  }
}

// ---------------------------------------------------------------------------
// Extracted: buildInjection
// Takes injection entries and a description resolver (injected for testability).
// A string entry triggers a description lookup; an object entry carries its own
// context verbatim with an em-dash separator (no lookup).
// ---------------------------------------------------------------------------

type InjectionEntry = string | { skill: string; context: string }

function buildInjection(
  entries: InjectionEntry[],
  descriptionOf: (name: string) => string | null,
): string {
  if (entries.length === 0) return ""
  const lines: string[] = []
  for (const entry of entries) {
    if (typeof entry === "string") {
      const desc = descriptionOf(entry)
      if (desc) {
        lines.push(`- load \`${entry}\` skill (${desc})`)
      } else {
        lines.push(`- load \`${entry}\` skill`)
      }
    } else {
      lines.push(`- load \`${entry.skill}\` skill — ${entry.context}`)
    }
  }
  return "\n---\n**Skills:**\n" + lines.join("\n")
}

// ---------------------------------------------------------------------------
// Extracted: formatInjectList
// Formats the config for the inject_list tool output. String targets render as
// a bare backtick-quoted name; object targets render as `skill` (context).
// ---------------------------------------------------------------------------

function formatInjectList(config: Record<string, InjectionEntry[]>): string {
  const entries = Object.entries(config)
  if (entries.length === 0) return "(no injection mappings configured)"
  return entries
    .map(
      ([skill, targets]) =>
        `- ${skill}: ${targets.map((t) => (typeof t === "string" ? `\`${t}\`` : `\`${t.skill}\` (${t.context})`)).join(", ")}`,
    )
    .join("\n")
}

// ---------------------------------------------------------------------------
// 1. readDescription — YAML frontmatter description extraction
// ---------------------------------------------------------------------------

describe("parseDescription — happy path", () => {
  it("extracts the description string from valid frontmatter", () => {
    const content = `---
name: review
description: Load before every commit, push, or merge-request finalization
---
# Body`
    expect(parseDescription(content)).toBe(
      "Load before every commit, push, or merge-request finalization",
    )
  })
})

describe("parseDescription — missing or invalid", () => {
  it("returns null when no frontmatter delimiters exist", () => {
    expect(parseDescription("# Just markdown")).toBeNull()
  })

  it("returns null when frontmatter has no description field", () => {
    const content = `---
name: review
---
# Body`
    expect(parseDescription(content)).toBeNull()
  })

  it("returns null when description is not a string", () => {
    const content = `---
description:
  - a list
---
# Body`
    expect(parseDescription(content)).toBeNull()
  })

  it("returns null on malformed YAML", () => {
    const content = `---
description: [unclosed
---
# Body`
    expect(() => parseDescription(content)).not.toThrow()
    expect(parseDescription(content)).toBeNull()
  })
})

// ---------------------------------------------------------------------------
// 2. buildInjection — injection block assembly
// ---------------------------------------------------------------------------

describe("buildInjection — empty input", () => {
  it("returns empty string for empty skills array", () => {
    expect(buildInjection([], () => null)).toBe("")
  })
})

describe("buildInjection — with descriptions", () => {
  it("includes description in parentheses when available", () => {
    const desc = (name: string) => (name === "gh" ? "GitHub CLI" : null)
    const result = buildInjection(["gh"], desc)
    expect(result).toContain("- load `gh` skill (GitHub CLI)")
  })

  it("omits description when resolver returns null", () => {
    const result = buildInjection(["unknown"], () => null)
    expect(result).toContain("- load `unknown` skill")
    expect(result).not.toContain("(")
  })
})

describe("buildInjection — multiple skills", () => {
  it("emits one line per skill in order", () => {
    const descs: Record<string, string> = {
      qa: "QA verification",
      gh: "GitHub CLI",
    }
    const result = buildInjection(["qa", "gh", "linear"], (n) => descs[n] ?? null)

    expect(result).toContain("- load `qa` skill (QA verification)")
    expect(result).toContain("- load `gh` skill (GitHub CLI)")
    expect(result).toContain("- load `linear` skill")
    // Verify order: qa before gh before linear
    const qaIdx = result.indexOf("`qa`")
    const ghIdx = result.indexOf("`gh`")
    const linearIdx = result.indexOf("`linear`")
    expect(qaIdx).toBeLessThan(ghIdx)
    expect(ghIdx).toBeLessThan(linearIdx)
  })
})

describe("buildInjection — object entry", () => {
  it("emits an em-dash context line without a description lookup", () => {
    let lookups = 0
    const result = buildInjection(
      [{ skill: "xh", context: "All requests use xh --ignore-stdin --session=agent for auth" }],
      () => {
        lookups++
        return "should not be used"
      },
    )
    expect(result).toContain(
      "- load `xh` skill — All requests use xh --ignore-stdin --session=agent for auth",
    )
    // Object entries carry their own context; no description resolver call.
    expect(lookups).toBe(0)
  })
})

describe("buildInjection — mixed string and object entries", () => {
  it("emits both line styles in order", () => {
    const result = buildInjection(
      ["communication", { skill: "xh", context: "use --session=agent for auth" }],
      (n) => (n === "communication" ? "Communication style" : null),
    )
    expect(result).toContain("- load `communication` skill (Communication style)")
    expect(result).toContain("- load `xh` skill — use --session=agent for auth")
    // Verify order: the string entry precedes the object entry.
    const commIdx = result.indexOf("`communication`")
    const xhIdx = result.indexOf("`xh`")
    expect(commIdx).toBeLessThan(xhIdx)
  })
})

describe("buildInjection — format validation", () => {
  it("starts with newline-separator-header sequence", () => {
    const result = buildInjection(["gh"], () => "GitHub CLI")
    expect(result.startsWith("\n---\n**Skills:**\n")).toBe(true)
  })

  it("does not end with a trailing newline", () => {
    const result = buildInjection(["gh"], () => "GitHub CLI")
    expect(result.endsWith("\n")).toBe(false)
  })
})

describe("buildInjection — object-entry context formatting", () => {
  // These assert how a `{ skill, context }` entry renders, given a hand-built
  // target array. They do NOT verify the real `architecture`/`code-quality`
  // config maps `dedup` under both keys — that wiring is checked separately by
  // the `chezmoi execute-template | jq` config assertion, not this unit suite.
  it("renders a context suffix for an object entry among plain string entries", () => {
    const targets: InjectionEntry[] = [
      "gh",
      "linear",
      "code-quality",
      { skill: "dedup", context: "semantic-search for an existing equivalent before adding a function; prefer reuse" },
    ]
    const result = buildInjection(targets, () => null)
    expect(result).toContain(
      "- load `dedup` skill — semantic-search for an existing equivalent before adding a function; prefer reuse",
    )
  })

  it("renders a context suffix for a sole object entry", () => {
    const targets: InjectionEntry[] = [
      { skill: "dedup", context: "semantic-search diff-added functions, flag semantic dups, scope queries tight" },
    ]
    const result = buildInjection(targets, () => null)
    expect(result).toContain(
      "- load `dedup` skill — semantic-search diff-added functions, flag semantic dups, scope queries tight",
    )
  })
})

// ---------------------------------------------------------------------------
// 3. inject_list format
// ---------------------------------------------------------------------------

describe("formatInjectList — output format", () => {
  it("formats config entries as backtick-quoted comma-separated lists", () => {
    const config = {
      review: ["qa", "gh", "code-quality"],
      push: ["commit", "gh"],
    }
    const result = formatInjectList(config)
    expect(result).toContain("- review: `qa`, `gh`, `code-quality`")
    expect(result).toContain("- push: `commit`, `gh`")
  })

  it("returns placeholder when config is empty", () => {
    expect(formatInjectList({})).toBe("(no injection mappings configured)")
  })

  it("handles a single-skill mapping", () => {
    const result = formatInjectList({ review: ["qa"] })
    expect(result).toBe("- review: `qa`")
  })

  it("renders an object entry as `skill` (context)", () => {
    const result = formatInjectList({
      confluence: [{ skill: "xh", context: "use --session=agent for auth" }, "communication"],
    })
    expect(result).toBe("- confluence: `xh` (use --session=agent for auth), `communication`")
  })
})
