import { tool, type Plugin } from "@opencode-ai/plugin"
import { execFileSync } from "child_process"

/**
 * Worktree-move plugin for OpenCode.
 *
 * Exposes a `move_to_worktree` tool that moves the CURRENT session into a new
 * git worktree for a given branch. Used by the /worktree command
 * (commands/worktree.md). Mirrors the session-rename pattern: the tool receives
 * the current session id deterministically via `context.sessionID`, so it acts
 * on "this session" without any template variable.
 *
 * The heavy lifting lives in the already-tested `opencode-cmd wt-move` verb,
 * which creates the worktree, moves the session into it, and prints the new
 * worktree directory. We resolve the session's current directory via the SDK
 * (`client.session.get` → Session.directory) so wt-move runs from the right
 * repo, falling back to process.cwd() if the SDK can't tell us.
 */
export const WorktreeMovePlugin: Plugin = async ({ client }) => {
  const cmd = `${process.env.HOME}/.local/bin/opencode-cmd`
  return {
    tool: {
      move_to_worktree: tool({
        description:
          "Move the current session into a new git worktree for the given branch, creating the worktree.",
        args: {
          branch: tool.schema
            .string()
            .describe("git branch name for the new worktree"),
        },
        async execute(args, context) {
          const sid = context.sessionID
          try {
            const res = await client.session.get({ path: { id: sid } })
            const dir = res.data?.directory ?? process.cwd()
            const out = execFileSync(
              cmd,
              ["-d", dir, "wt-move", sid, args.branch],
              { encoding: "utf8" },
            ).trim()
            return `Moved session into worktree: ${out}`
          } catch (err) {
            return `Failed to move session into worktree: ${
              err instanceof Error ? err.message : String(err)
            }`
          }
        },
      }),
    },
  }
}
