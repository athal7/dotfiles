import type { Plugin } from "@opencode-ai/plugin"
import { readFile, readdir } from "fs/promises"
import { existsSync } from "fs"
import { join } from "path"

/**
 * Compaction hook that preserves context across session compaction.
 *
 * Injects:
 * - Active OpenSpec change context (proposal + design) if one exists
 * - Fallback: .opencode/context-log.md for repos not using OpenSpec
 * - Continuation rules for key behavioral compliance
 *
 * Resolves paths against the current worktree/directory rather than
 * process.cwd(), since the opencode server is launched from $HOME
 * (via LaunchAgent) and a relative path would never match.
 */
export const ContextCompactionPlugin: Plugin = async (ctx) => {
  const projectRoot = ctx.worktree ?? ctx.directory ?? process.cwd()

  return {
    "experimental.session.compacting": async (_input, output) => {
      // Prefer OpenSpec change context over context-log
      const changesDir = join(projectRoot, "openspec", "changes")
      let injectedContext = false

      if (existsSync(changesDir)) {
        try {
          const changes = await readdir(changesDir)
          for (const change of changes) {
            const proposalPath = join(changesDir, change, "proposal.md")
            const designPath = join(changesDir, change, "design.md")
            const tasksPath = join(changesDir, change, "tasks.md")

            // Only inject changes that have a proposal (active changes)
            if (!existsSync(proposalPath)) continue

            const parts: string[] = [`### Change: ${change}\n`]

            for (const [label, path] of [
              ["Proposal", proposalPath],
              ["Design", designPath],
              ["Tasks", tasksPath],
            ] as const) {
              if (existsSync(path)) {
                try {
                  const content = await readFile(path, "utf-8")
                  parts.push(`**${label}:**\n${content.trim()}\n`)
                } catch {
                  // Skip unreadable files
                }
              }
            }

            if (parts.length > 1) {
              output.context.push(`
## Active Change: ${change}

The following change artifacts were maintained during this session (source: ${changesDir}/${change}/):

${parts.join("\n")}
`)
              injectedContext = true
            }
          }
        } catch {
          // Changes dir exists but couldn't be read — fall through
        }
      }

      // Fallback: context-log for repos not using OpenSpec
      if (!injectedContext) {
        const contextLogPath = join(projectRoot, ".opencode", "context-log.md")
        if (existsSync(contextLogPath)) {
          try {
            const log = await readFile(contextLogPath, "utf-8")
            output.context.push(`
## Context Log

The following log was maintained during this session (source: ${contextLogPath}):

${log}
`)
          } catch {
            // Skip silently
          }
        }
      }

      output.context.push(`
## Continuation Rules

After compaction, ensure these behaviors are maintained:

1. **Check in after each todo** - Stop and report what was done, wait for approval before next
2. **Commit timing** - Commit after each green test, don't batch commits
3. **Never skip todos** - Complete all items unless user explicitly says to skip
4. **Tone** - Use Humble Inquiry, prefix agent-authored prose with \`[ai]\`, stay concise — see Tone section in your global AGENTS.md
5. **Issue context** - If the user references an issue/ticket/PR by ID, fetch it before any other action
6. **Follow the workflow** - If a workflow command was active (/implement, /review, /mr), continue following its methodology
7. **Check specs** - If the repo has openspec/specs/, re-read relevant specs to verify your work aligns with requirements
`)
    },
  }
}
