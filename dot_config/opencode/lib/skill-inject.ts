import { readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"
import type { Plugin } from "@opencode-ai/plugin"
import { tool } from "@opencode-ai/plugin"

// ---------------------------------------------------------------------------
// Description cache — reads SKILL.md frontmatter once per skill name
// ---------------------------------------------------------------------------

const descriptionCache = new Map<string, string | null>()

function readDescription(skillName: string): string | null {
  if (descriptionCache.has(skillName)) return descriptionCache.get(skillName)!
  let result: string | null = null
  try {
    const content = readFileSync(
      join(homedir(), ".agents", "skills", skillName, "SKILL.md"),
      "utf8",
    )
    const match = content.match(/^---\n([\s\S]*?)\n---/)
    if (match) {
      const fm = Bun.YAML.parse(match[1]) as Record<string, unknown>
      if (typeof fm.description === "string") result = fm.description
    }
  } catch {
    // skill not found or unreadable
  }
  descriptionCache.set(skillName, result)
  return result
}

// ---------------------------------------------------------------------------
// Injection block builder
// ---------------------------------------------------------------------------

type InjectionEntry = string | { skill: string; context: string }

function buildInjection(entries: InjectionEntry[]): string {
  if (entries.length === 0) return ""
  const lines: string[] = []
  for (const entry of entries) {
    if (typeof entry === "string") {
      const desc = readDescription(entry)
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
// Plugin export
// ---------------------------------------------------------------------------

export default (async (_input, options) => {
  const config = (options ?? {}) as Record<string, InjectionEntry[]>

  const pendingSkillArgs = new Map<string, Record<string, unknown>>()

  const injectList = tool({
    description: "List all configured injection mappings.",
    args: {},
    async execute() {
      const entries = Object.entries(config)
      if (entries.length === 0) return "(no injection mappings configured)"
      return entries
        .map(
          ([skill, targets]) =>
            `- ${skill}: ${targets.map((t) => typeof t === "string" ? `\`${t}\`` : `\`${t.skill}\` (${t.context})`).join(", ")}`,
        )
        .join("\n")
    },
  })

  return {
    tool: {
      inject_list: injectList,
    },

    "tool.execute.before": async (input, output) => {
      if (input.tool !== "skill") return
      const args = output.args as Record<string, unknown> | null
      if (args && input.callID) {
        pendingSkillArgs.set(input.callID, args)
      }
    },

    "tool.execute.after": async (input, output) => {
      if (input.tool !== "skill") return
      const args = pendingSkillArgs.get(input.callID)
      pendingSkillArgs.delete(input.callID)

      if (!args) return
      const skillName = typeof args.name === "string" ? args.name : null
      if (!skillName) return

      const targets = config[skillName]
      if (!targets || targets.length === 0) return

      const injection = buildInjection(targets)
      if (injection) {
        output.output = (output.output ?? "") + injection
      }
    },
  }
}) satisfies Plugin
