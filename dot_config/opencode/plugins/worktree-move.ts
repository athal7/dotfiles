import { tool, type Plugin } from "@opencode-ai/plugin"

/**
 * Worktree-move plugin for OpenCode.
 *
 * Exposes a `move_to_worktree` tool that moves the CURRENT session into a new
 * git worktree for a given branch. Used by the /worktree command
 * (commands/worktree.md). Mirrors the session-rename pattern: the tool receives
 * the current session id deterministically via `context.sessionID`, so it acts
 * on "this session" without any template variable.
 *
 * Everything runs through the injected SDK `client`, fully async. This is
 * load-bearing: opencode plugins execute inside the server's single-threaded
 * event loop, so any *blocking* call (e.g. execFileSync shelling out to
 * `opencode-cmd`, which POSTs back to this same server) freezes the loop and
 * deadlocks the server permanently. We must never block, and we must talk to
 * OUR OWN server — never a hardcoded port — which `client` guarantees.
 *
 * The two endpoints we need (`/experimental/worktree`,
 * `/experimental/control-plane/move-session`) are not in the generated SDK, so
 * we reach them via the SDK's underlying request client (`_client`). That core
 * client is already bound to this server instance's resolved base URL, so it
 * targets the same server that loaded the plugin regardless of port (Desktop
 * app on 4097, web on 4096, etc.).
 */

/**
 * Minimal shape of the SDK's underlying core request client. The OpencodeClient
 * subresources (client.session, client.app, …) all delegate to this same
 * `_client`; it carries the base URL of the server that created the client.
 */
type CoreRequestClient = {
  post: (options: {
    url: string
    body?: unknown
    query?: Record<string, unknown>
  }) => Promise<{
    data?: unknown
    error?: unknown
    response?: { ok: boolean; status: number }
  }>
}

export const WorktreeMovePlugin: Plugin = async ({ client }) => {
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
            const session = await client.session.get({ path: { id: sid } })
            const dir = session.data?.directory ?? process.cwd()

            const core = (client as unknown as { _client: CoreRequestClient })
              ._client

            // 1. Create the git worktree for the branch, scoped to the session's
            //    repo via the `directory` query param (matches `opencode-cmd
            //    worktree`). Returns a Worktree whose `.directory` is the path.
            const created = await core.post({
              url: "/experimental/worktree",
              query: { directory: dir },
              body: { name: args.branch },
            })
            if (created.error) {
              return `Failed to move session into worktree: worktree creation failed: ${describe(
                created.error,
              )}`
            }
            const newDir = (created.data as { directory?: string } | undefined)
              ?.directory
            if (!newDir) {
              return `Failed to move session into worktree: worktree creation returned no directory`
            }

            // 2. Move this session into the new worktree directory.
            const moved = await core.post({
              url: "/experimental/control-plane/move-session",
              body: {
                sessionID: sid,
                destination: { directory: newDir },
                moveChanges: true,
              },
            })
            if (moved.error || (moved.response && !moved.response.ok)) {
              return `Failed to move session into worktree: worktree created at ${newDir} but move failed${
                moved.response ? ` (HTTP ${moved.response.status})` : ""
              }${moved.error ? `: ${describe(moved.error)}` : ""}`
            }

            return `Moved session into worktree: ${newDir}`
          } catch (err) {
            return `Failed to move session into worktree: ${describe(err)}`
          }
        },
      }),
    },
  }
}

function describe(err: unknown): string {
  if (err instanceof Error) return err.message
  if (typeof err === "string") return err
  try {
    return JSON.stringify(err)
  } catch {
    return String(err)
  }
}
