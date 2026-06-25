import { tool, type Plugin } from "@opencode-ai/plugin"

/**
 * Session-rename plugin for OpenCode.
 *
 * Exposes a `rename_session` tool that updates the current session's title.
 * Used by the /rename command (commands/rename.md): the small model reads the
 * accumulated conversation, synthesizes a better title, and calls this tool.
 * opencode has no built-in session-rename mechanism, so this tool is the only
 * way to set a title programmatically from within a session.
 */
export const SessionRenamePlugin: Plugin = async ({ client }) => {
  return {
    tool: {
      rename_session: tool({
        description:
          "Rename the current session by setting a new, more semantic title. Call this once with the final title.",
        args: {
          title: tool.schema
            .string()
            .describe(
              "The new session title. <=50 chars, single line, names the work (feature/file/bug/subsystem), not the workflow or command.",
            ),
        },
        async execute(args, context) {
          await client.session.update({
            path: { id: context.sessionID },
            body: { title: args.title },
          })
          return `Renamed session to: "${args.title}"`
        },
      }),
    },
  }
}
