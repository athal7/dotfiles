import { execSync } from "child_process"

/**
 * Direnv plugin for OpenCode.
 *
 * Runs `direnv export json` before each shell execution and injects
 * the resulting environment variables. Handles null values correctly
 * by omitting them (direnv uses null to mean "unset this variable").
 * Strips DIRENV_* internal tracking variables to prevent stale state
 * accumulation that caused the PGGSSENCMODE=null bug.
 */
export const DirenvPlugin = async () => {
  return {
    "shell.env": async (input, output) => {
      try {
        const result = execSync("direnv export json", {
          cwd: input.cwd,
          encoding: "utf8",
          timeout: 5000,
          // Run with a clean DIRENV_* slate so direnv computes a fresh diff
          env: Object.fromEntries(
            Object.entries(process.env).filter(
              ([k]) => !k.startsWith("DIRENV_"),
            ),
          ),
        })

        if (!result || !result.trim()) return

        const envVars = JSON.parse(result)

        for (const [key, value] of Object.entries(envVars)) {
          // Skip direnv internal tracking variables
          if (key.startsWith("DIRENV_")) continue

          // null means "unset" — don't set it in output.env
          if (value === null) continue

          output.env[key] = value
        }
      } catch {
        // direnv not available or no .envrc — silently skip
      }
    },
  }
}
