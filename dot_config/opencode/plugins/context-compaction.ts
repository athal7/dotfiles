import type { Plugin } from "@opencode-ai/plugin"
import { readFile } from "fs/promises"
import { existsSync } from "fs"
import { join } from "path"

/**
 * Compaction hook that preserves context across session compaction.
 *
 * Injects:
 * - Context log contents (if .opencode/context-log.md exists in project)
 * - Continuation rules for key behavioral compliance
 *
 * Resolves the context log path against the current worktree/directory
 * rather than process.cwd(), since the opencode server is launched from
 * $HOME (via LaunchAgent) and a relative path would never match.
 */
export const ContextCompactionPlugin: Plugin = async (ctx) => {
  // Prefer the active worktree (set per-session for git worktrees), fall back
  // to the plugin's directory.
  const projectRoot = ctx.worktree ?? ctx.directory ?? process.cwd()

  return {
    "experimental.session.compacting": async (_input, output) => {
      const contextLogPath = join(projectRoot, ".opencode", "context-log.md")

      if (existsSync(contextLogPath)) {
        try {
          const log = await readFile(contextLogPath, "utf-8")
          output.context.push(`
## Context Log

The following log was maintained during this session. Reference it for issue context and build history (source: ${contextLogPath}):

${log}
`)
        } catch {
          // File exists but couldn't be read — skip silently
        }
      }

      // Reinforce key behavioral rules that tend to get lost
      output.context.push(`
## Continuation Rules

After compaction, ensure these behaviors are maintained:

1. **Check in after each todo** - Stop and report what was done, wait for approval before next
2. **Update context log** - Append checkpoint after each commit
3. **Commit timing** - Commit after each green test, don't batch commits
4. **Never skip todos** - Complete all items unless user explicitly says to skip
5. **Tone** - Use Humble Inquiry, prefix agent-authored prose with \`[ai]\`, stay concise — see Tone section in your global AGENTS.md
6. **Issue context** - If the user references an issue/ticket/PR by ID, fetch it via the \`issues\` capability before any other action
7. **Review before commit/push** - Load the \`review\` skill before producing review output, staging commits, or pushing
`)
    },
  }
}
