import { mkdir, readFile, writeFile } from "node:fs/promises"
import { homedir } from "node:os"
import { join } from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

/**
 * Anthropic extended prompt-cache TTL plugin for OpenCode.
 *
 * opencode's stable Anthropic request path (provider/transform.ts's
 * applyCaching()) hardcodes 5-minute ephemeral cache markers
 * (`cache_control: {type: "ephemeral"}`, no ttl) with no user-facing config
 * to request Anthropic's 1-hour extended cache TTL (GA on Anthropic's side
 * now, no beta header required). This plugin uses the `auth.loader` hook to
 * inject a custom `fetch` for the "anthropic" provider that rewrites those
 * markers in the outgoing request body before forwarding to the real
 * network fetch.
 *
 * `auth.loader` only fires when `auth.get("anthropic")` returns a STORED
 * auth record (i.e. `opencode auth login` was run) — a plain
 * ANTHROPIC_API_KEY env var does not trigger it (see provider.ts: `stored =
 * yield* auth.get(providerID); if (!stored) continue`). Confirmed against
 * this machine's ~/.local/share/opencode/auth.json, which has a stored
 * `{"type": "api"}` record for anthropic, so the loader is eligible here.
 *
 * Deliberate simplification: this rewrites ALL Anthropic requests globally,
 * not scoped to a single agent — the fetch hook has no clean per-agent
 * signal to filter on. Tradeoff: build's smaller write volume also pays the
 * 1h TTL's slightly higher per-token cache rate, but the absolute cost is
 * small relative to the read-cost savings a long-running agent like lead
 * gets from not re-writing its cache every 5 minutes of idle time.
 */

const EXTENDED_TTL = "1h" as const
const SIDECAR_DIR = join(
  homedir(),
  ".local",
  "share",
  "opencode",
  "storage",
  "plugin",
  "anthropic-extended-cache",
)
const SIDECAR_MAX_ENTRIES = 200

export function isAnthropicMessagesRequest(input: RequestInfo | URL): boolean {
  try {
    const url = input instanceof Request ? input.url : String(input)
    const { hostname, pathname } = new URL(url)
    return hostname.endsWith("anthropic.com") && pathname.endsWith("/messages")
  } catch {
    return false
  }
}

/**
 * Mutates `value` in place, upgrading every 5-minute ephemeral cache marker
 * to the 1-hour extended TTL. Walks generically by key name (`cache_control`)
 * rather than hardcoding the `system[]` / `messages[].content[]` positions
 * opencode/@ai-sdk/anthropic currently use, so it keeps working if those
 * internal positions shift — as long as the marker's key name and shape
 * (Anthropic's own wire contract) stay put. Leaves markers with an existing
 * ttl or a non-"ephemeral" type untouched.
 */
export function upgradeEphemeralCacheControl(value: unknown): void {
  if (Array.isArray(value)) {
    for (const item of value) upgradeEphemeralCacheControl(item)
    return
  }
  if (value === null || typeof value !== "object") return

  const obj = value as Record<string, unknown>
  const cacheControl = obj.cache_control
  if (cacheControl && typeof cacheControl === "object") {
    const cc = cacheControl as Record<string, unknown>
    if (cc.type === "ephemeral" && !("ttl" in cc)) cc.ttl = EXTENDED_TTL
  }

  for (const key of Object.keys(obj)) {
    if (key === "cache_control") continue
    upgradeEphemeralCacheControl(obj[key])
  }
}

/**
 * Scrapes the cache-creation TTL breakdown out of a response body via regex
 * rather than full SSE/JSON parsing — Anthropic responses may be streamed
 * (SSE) or plain JSON depending on the request, and a regex scan over the
 * raw text handles both without needing to know which shape applies. Used
 * only for the audit sidecar signal below; never affects what's returned to
 * the caller.
 */
export function extractCacheCreationTokens(
  text: string,
): { ephemeral1h: number; ephemeral5m: number } | null {
  const oneHour = text.match(/"ephemeral_1h_input_tokens"\s*:\s*(\d+)/)
  const fiveMin = text.match(/"ephemeral_5m_input_tokens"\s*:\s*(\d+)/)
  if (!oneHour && !fiveMin) return null
  return {
    ephemeral1h: oneHour ? Number(oneHour[1]) : 0,
    ephemeral5m: fiveMin ? Number(fiveMin[1]) : 0,
  }
}

function sidecarPathFor(date: Date): string {
  return join(SIDECAR_DIR, `${date.toISOString().slice(0, 10)}.json`)
}

/**
 * Audit health-check sidecar: records whether the 1h-TTL rewrite is actually
 * taking effect on Anthropic's side, so /audit can detect a silent
 * regression (e.g. an opencode upgrade changes the internal cache_control
 * shape and desyncs upgradeEphemeralCacheControl's key-name match). Mirrors
 * DCP's own sidecar pattern
 * (~/.local/share/opencode/storage/plugin/dcp/<id>.json). No session id is
 * available at this layer (fetch has no session context), so entries roll
 * into one file per UTC day instead of per session.
 *
 * Best-effort and fire-and-forget: the caller does not await this, and any
 * failure here is swallowed — sidecar bookkeeping must never affect a real
 * request.
 */
async function recordCacheTtlSignal(responseClone: Response): Promise<void> {
  try {
    const text = await responseClone.text()
    const tokens = extractCacheCreationTokens(text)
    if (!tokens) return

    const path = sidecarPathFor(new Date())
    let entries: unknown[] = []
    try {
      const parsed = JSON.parse(await readFile(path, "utf8"))
      if (Array.isArray(parsed)) entries = parsed
    } catch {
      // No sidecar file yet for today, or it's corrupt — start fresh.
    }

    entries.push({
      timestamp: Date.now(),
      ephemeral_1h_input_tokens: tokens.ephemeral1h,
      ephemeral_5m_input_tokens: tokens.ephemeral5m,
    })
    if (entries.length > SIDECAR_MAX_ENTRIES) {
      entries = entries.slice(entries.length - SIDECAR_MAX_ENTRIES)
    }

    await mkdir(SIDECAR_DIR, { recursive: true })
    await writeFile(path, JSON.stringify(entries))
  } catch {
    // Diagnostics only — never let sidecar bookkeeping affect a real request.
  }
}

export const AnthropicExtendedCachePlugin: Plugin = async () => {
  return {
    auth: {
      provider: "anthropic",
      // opencode's built-in login flow already owns anthropic's auth methods
      // (`opencode auth login`); this hook only needs the loader escape
      // hatch below to inject a custom fetch, so it declares no additional
      // login methods of its own.
      methods: [],
      async loader() {
        const networkFetch = fetch

        return {
          async fetch(input: RequestInfo | URL, init?: RequestInit) {
            if (!isAnthropicMessagesRequest(input) || typeof init?.body !== "string") {
              return networkFetch(input, init)
            }

            let rewrittenBody: string
            try {
              const parsed = JSON.parse(init.body)
              upgradeEphemeralCacheControl(parsed)
              rewrittenBody = JSON.stringify(parsed)
            } catch {
              // Fail open: non-JSON or unexpected body shape forwards
              // unchanged rather than breaking or dropping the request.
              return networkFetch(input, init)
            }

            const response = await networkFetch(input, { ...init, body: rewrittenBody })
            void recordCacheTtlSignal(response.clone())
            return response
          },
        }
      },
    },
  }
}
