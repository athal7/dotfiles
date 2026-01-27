import type { Plugin } from "@opencode-ai/plugin"
import { readFile } from "fs/promises"
import { existsSync } from "fs"

/**
 * Compaction hook that preserves context across session compaction.
 *
 * Injects:
 * - Context log contents (if .opencode/context-log.md exists)
 * - Continuation rules for key behavioral compliance
 */
export const ContextCompactionPlugin: Plugin = async (ctx) => {
  return {
    "experimental.session.compacting": async (input, output) => {
      // Inject context log if it exists
      const contextLogPath = ".opencode/context-log.md"
      if (existsSync(contextLogPath)) {
        try {
          const log = await readFile(contextLogPath, "utf-8")
          output.context.push(`
## Context Log

The following log was maintained during this session. Reference it for issue context and build history:

${log}
`)
        } catch (err) {
          // File exists but couldn't be read - skip silently
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
`)
    },
  }
}
