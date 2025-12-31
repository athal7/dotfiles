/**
 * Notification plugin - sends push notifications via ntfy.sh
 * Requires NTFY_TOPIC in env and ntfy app on phone
 */
export const Notify = async ({ $ }) => {
  const topic = process.env.NTFY_TOPIC
  if (!topic) return {}

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        try {
          await $`curl -sf -d "Ready for input" -H "Title: OpenCode" ${"ntfy.sh/" + topic}`.quiet()
        } catch {}
      }
    },
  }
}
