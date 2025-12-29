/**
 * Notification plugin
 * 
 * - Local session: macOS notification
 * - SSH session: ntfy.sh push notification (requires NTFY_TOPIC in env)
 */
export const Notify = async ({ $ }) => {
  const topic = process.env.NTFY_TOPIC
  const isSSH = !!process.env.SSH_CONNECTION
  
  async function notify(title, message) {
    if (isSSH) {
      if (topic) {
        try {
          await $`curl -sf -d ${message} -H ${'Title: ' + title} ${'ntfy.sh/' + topic}`.quiet()
        } catch {}
      }
    } else {
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
