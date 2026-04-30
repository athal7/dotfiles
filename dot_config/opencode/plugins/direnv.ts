import type { Plugin } from "@opencode-ai/plugin"
import { execFileSync } from "child_process"

/**
 * Direnv plugin for OpenCode.
 *
 * Runs `direnv export json` before each shell execution and injects
 * the resulting environment variables.
 *
 * Behavior notes:
 * - Handles null values correctly by omitting them (direnv uses null to mean
 *   "unset this variable").
 * - Strips DIRENV_* internal tracking variables to prevent stale state
 *   accumulation that caused the PGGSSENCMODE=null bug.
 * - Silences direnv's own "direnv: loading ..." status messages by setting
 *   DIRENV_LOG_FORMAT="" — without this, those messages bleed onto the TUI
 *   because execSync inherits stderr to the parent process.
 * - Captures stderr explicitly (rather than inheriting) so any *unexpected*
 *   direnv output (errors, warnings) doesn't leak to the TUI either; we
 *   surface real errors via client.app.log instead.
 */
export const DirenvPlugin: Plugin = async ({ client }) => {
  return {
    "shell.env": async (input, output) => {
      try {
        const env = Object.fromEntries(
          Object.entries(process.env).filter(
            ([k]) => !k.startsWith("DIRENV_"),
          ),
        )
        // Silence direnv's own status messages on stderr.
        env.DIRENV_LOG_FORMAT = ""

        const stdout = execFileSync("direnv", ["export", "json"], {
          cwd: input.cwd,
          encoding: "utf8",
          timeout: 5000,
          env,
          // Capture stderr instead of inheriting it, so direnv messages never
          // leak onto the parent process's stderr (visible in the TUI).
          stdio: ["ignore", "pipe", "pipe"],
        })

        if (!stdout || !stdout.trim()) return

        const envVars = JSON.parse(stdout) as Record<string, unknown>

        for (const [key, value] of Object.entries(envVars)) {
          // Skip direnv internal tracking variables
          if (key.startsWith("DIRENV_")) continue

          // null means "unset" — don't set it in output.env
          if (value === null || value === undefined) continue

          // output.env is typed as Record<string, string>; coerce defensively.
          output.env[key] = typeof value === "string" ? value : String(value)
        }
      } catch (err) {
        // Log so we can diagnose without the message bleeding to the TUI.
        // Common harmless cases (no .envrc in cwd, direnv not installed) still
        // log at debug — adjust grep accordingly when investigating.
        try {
          await client.app.log({
            body: {
              service: "direnv-plugin",
              level: "debug",
              message: "direnv export failed (may be benign)",
              extra: {
                cwd: input.cwd,
                error: err instanceof Error ? err.message : String(err),
              },
            },
          })
        } catch {
          // Logging itself failed — give up silently.
        }
      }
    },
  }
}
