/**
 * Notification plugin - sends push notifications via ntfy.sh
 * Requires NTFY_TOPIC in env and ntfy app on phone
 * Only notifies after 5 minutes of idle
 */
export const Notify = async ({ $ }) => {
  const topic = process.env.NTFY_TOPIC
  if (!topic) return {}

  const cwd = process.cwd()
  const dir = cwd.split("/").pop() || cwd
  const DELAY_MS = 5 * 60 * 1000

  let timer = null

  return {
    event: async ({ event }) => {
      if (event.type === "session.status") {
        const status = event.properties?.status?.type
        if (status === "idle" && !timer) {
          timer = setTimeout(async () => {
            try {
              await $`curl -sf -d ${dir} -H "Title: OpenCode" ${"ntfy.sh/" + topic}`.quiet()
            } catch {}
            timer = null
          }, DELAY_MS)
        } else if (status === "busy" && timer) {
          clearTimeout(timer)
          timer = null
        }
      }
    },
  }
}
