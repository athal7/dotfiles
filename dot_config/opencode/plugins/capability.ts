import { readFileSync, readdirSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"
import type { Plugin } from "@opencode-ai/plugin"
import { tool } from "@opencode-ai/plugin"

// ---------------------------------------------------------------------------
// Skill provides auto-discovery
// ---------------------------------------------------------------------------

let cachedProviders: Record<string, string[]> | null = null

function loadSkillProviders(): Record<string, string[]> {
  if (cachedProviders) return cachedProviders
  const result: Record<string, string[]> = {}
  const skillsDir = join(homedir(), ".agents", "skills")
  try {
    for (const entry of readdirSync(skillsDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue
      try {
        const content = readFileSync(join(skillsDir, entry.name, "SKILL.md"), "utf8")
        const match = content.match(/^---\n([\s\S]*?)\n---/)
        if (!match) continue
        const fm = Bun.YAML.parse(match[1]) as Record<string, unknown>
        const metadata = fm.metadata as Record<string, unknown> | undefined
        const provides = metadata?.provides ?? fm.provides
        if (Array.isArray(provides)) {
          for (const cap of provides) {
            const capName = String(cap)
            if (!result[capName]) result[capName] = []
            result[capName].push(entry.name)
          }
        }
      } catch { /* skip unreadable skills */ }
    }
  } catch { /* skills dir unreadable */ }
  cachedProviders = result
  return result
}

// ---------------------------------------------------------------------------
// Tool: capability_list
// ---------------------------------------------------------------------------

const capabilityList = tool({
  description: "List all registered capabilities with their providing skills.",
  args: {},
  async execute(_args) {
    try {
      const providers = loadSkillProviders()
      const lines = Object.entries(providers).map(([name, skills]) =>
        skills.length === 1
          ? `- ${name}: \`${skills[0]}\` skill`
          : `- ${name}: ${skills.map((s) => `\`${s}\` skill`).join(", ")}`,
      )
      return lines.length > 0 ? lines.join("\n") : "(no capabilities registered)"
    } catch (err) {
      return `Error listing capabilities: ${err instanceof Error ? err.message : String(err)}`
    }
  },
})

// ---------------------------------------------------------------------------
// Tool: capability_describe
// ---------------------------------------------------------------------------

const capabilityDescribe = tool({
  description: "Describe a capability — which skill provides it and how to load it.",
  args: {
    name: tool.schema.string().describe("Capability name to describe"),
  },
  async execute({ name }) {
    try {
      const providers = loadSkillProviders()
      const skills = providers[name]
      if (!skills || skills.length === 0) {
        return `No provider found for \`${name}\`. Ask the user which provider to use.`
      }
      if (skills.length === 1) {
        return `The \`${name}\` capability is provided by the \`${skills[0]}\` skill. Load it for details.`
      }
      const list = skills.map((s) => `\`${s}\``).join(", ")
      return `The \`${name}\` capability has multiple providers: ${list}. Load the appropriate one based on context.`
    } catch (err) {
      return `Error describing capability: ${err instanceof Error ? err.message : String(err)}`
    }
  },
})

// ---------------------------------------------------------------------------
// Skill hook helpers
// ---------------------------------------------------------------------------

// Map of callID → args (for skill tool tracking)
const pendingSkillArgs = new Map<string, Record<string, unknown>>()

function parseSkillFrontmatter(content: string): { requires?: string[] } {
  // SKILL.md files use YAML frontmatter delimited by ---
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

function readSkillFile(skillName: string): string | null {
  const p = join(homedir(), ".agents", "skills", skillName, "SKILL.md")
  try {
    return readFileSync(p, "utf8")
  } catch {
    return null
  }
}

// ---------------------------------------------------------------------------
// Capability injection builder
// ---------------------------------------------------------------------------

function readSkillDescription(skillName: string): string | null {
  const content = readSkillFile(skillName)
  if (!content) return null
  const match = content.match(/^---\n([\s\S]*?)\n---/)
  if (!match) return null
  try {
    const fm = Bun.YAML.parse(match[1]) as Record<string, unknown>
    return typeof fm.description === "string" ? fm.description : null
  } catch {
    return null
  }
}

// Built-in fallback descriptions when no skill is installed for these common capabilities.
// Installing a skill (xh, gq) overrides these automatically via `provides`.
const BUILTIN_CAPABILITY_DEFAULTS: Record<string, string> = {
  rest: "curl (default — install `xh` skill for cleaner syntax)",
  graphql: "curl -X POST with JSON body (default — install `gq` skill for introspection)",
}

function buildInjection(requires: string[]): string {
  if (requires.length === 0) return ""
  const providers = loadSkillProviders()
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
// Plugin export
// ---------------------------------------------------------------------------

export default (async () => {
  return {
    // -----------------------------------------------------------------------
    // Tools
    // -----------------------------------------------------------------------
    tool: {
      capability_list: capabilityList,
      capability_describe: capabilityDescribe,
    },

    // -----------------------------------------------------------------------
    // Hooks
    // -----------------------------------------------------------------------

    // Stash skill args before execution
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "skill") return
      // output.args holds the args that will be passed to the skill tool
      // We need the current args — they come via the output object at this hook point
      const args = output.args as Record<string, unknown> | null
      if (args && input.callID) {
        pendingSkillArgs.set(input.callID, args)
      }
    },

    // Inject resolved capabilities after skill execution
    "tool.execute.after": async (input, output) => {
      if (input.tool !== "skill") return
      const args = pendingSkillArgs.get(input.callID)
      pendingSkillArgs.delete(input.callID)

      if (!args) return
      // The skill tool receives `name` as its argument
      const skillName = typeof args.name === "string" ? args.name : null
      if (!skillName) return

      const content = readSkillFile(skillName)
      if (!content) return

      const { requires } = parseSkillFrontmatter(content)
      if (!requires || requires.length === 0) return

      const injection = buildInjection(requires)
      if (injection) {
        output.output = (output.output ?? "") + injection
      }
    },
  }
}) satisfies Plugin
