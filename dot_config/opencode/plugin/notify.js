/**
 * Notification plugin
 * 
 * - Local session: macOS notification (skipped if terminal is focused)
 * - SSH session: ntfy.sh push notification (requires NTFY_TOPIC in env)
 */
export const Notify = async ({ $ }) => {
  const topic = process.env.NTFY_TOPIC
  const isSSH = !!process.env.SSH_CONNECTION
  
  async function isTerminalFocused() {
    if (isSSH) return false
    try {
      const result = await $`osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'`.quiet()
      const frontApp = result.stdout.toString().trim()
      const terminals = ["Terminal", "iTerm2", "Alacritty", "kitty", "WezTerm", "Hyper"]
      return terminals.some(t => frontApp.includes(t))
    } catch {
      return false
    }
  }
  
  async function notify(title, message) {
    if (isSSH) {
      if (topic) {
        try {
          await $`curl -sf -d ${message} -H ${'Title: ' + title} ${'ntfy.sh/' + topic}`.quiet()
        } catch {}
      }
    } else {
      if (await isTerminalFocused()) return
      try {
        await $`osascript -e ${'display notification "' + message + '" with title "' + title + '"'}`.quiet()
      } catch {}
    }
  }

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await notify("OpenCode", "Ready for input")
      }
    },
  }
}
