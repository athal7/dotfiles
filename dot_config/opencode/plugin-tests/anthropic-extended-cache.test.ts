/**
 * Tests for the anthropic-extended-cache plugin.
 *
 * Functions under test are extracted copies of their production counterparts
 * (matching skill-inject.test.ts's convention) so they can be called directly
 * without importing the plugin module at runtime. A final "production
 * wiring" section imports the real module directly — this plugin's only
 * @opencode-ai/plugin dependency is a type-only import (erased at build
 * time, unlike skill-inject's runtime `tool` import), so the module resolves
 * fine under `bun test` and we can cross-check the extracted copies against
 * the real implementation to catch drift.
 *
 * Sections:
 *   1. isAnthropicMessagesRequest  — request targeting filter
 *   2. upgradeEphemeralCacheControl — 5m -> 1h cache_control rewrite
 *   3. extractCacheCreationTokens  — audit signal scrape from response text
 *   4. wrapped fetch (composed)    — end-to-end request rewrite + fail-open
 *   5. production wiring           — real module exports agree with 1-3
 */
import { describe, expect, it } from "bun:test"

// ---------------------------------------------------------------------------
// Extracted: isAnthropicMessagesRequest
// ---------------------------------------------------------------------------

function isAnthropicMessagesRequest(input: RequestInfo | URL): boolean {
  try {
    const url = input instanceof Request ? input.url : String(input)
    const { hostname, pathname } = new URL(url)
    return hostname.endsWith("anthropic.com") && pathname.endsWith("/messages")
  } catch {
    return false
  }
}

// ---------------------------------------------------------------------------
// Extracted: upgradeEphemeralCacheControl
// ---------------------------------------------------------------------------

const EXTENDED_TTL = "1h"

function upgradeEphemeralCacheControl(value: unknown): void {
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

// ---------------------------------------------------------------------------
// Extracted: extractCacheCreationTokens
// ---------------------------------------------------------------------------

function extractCacheCreationTokens(
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

// ---------------------------------------------------------------------------
// Composed: a fetch wrapper built from the extracted pieces above, mirroring
// the shape the plugin's auth.loader returns. Takes the underlying network
// fetch as a parameter so tests can inject a capturing stub.
// ---------------------------------------------------------------------------

function buildCachingFetch(networkFetch: typeof fetch): typeof fetch {
  return async function (input: RequestInfo | URL, init?: RequestInit) {
    if (!isAnthropicMessagesRequest(input) || typeof init?.body !== "string") {
      return networkFetch(input, init)
    }

    let rewrittenBody: string
    try {
      const parsed = JSON.parse(init.body)
      upgradeEphemeralCacheControl(parsed)
      rewrittenBody = JSON.stringify(parsed)
    } catch {
      return networkFetch(input, init)
    }

    return networkFetch(input, { ...init, body: rewrittenBody })
  }
}

// ---------------------------------------------------------------------------
// 1. isAnthropicMessagesRequest — request targeting filter
// ---------------------------------------------------------------------------

describe("isAnthropicMessagesRequest — targeting", () => {
  it("matches the Anthropic messages endpoint given as a string URL", () => {
    expect(isAnthropicMessagesRequest("https://api.anthropic.com/v1/messages")).toBe(true)
  })

  it("matches when given a Request object", () => {
    const req = new Request("https://api.anthropic.com/v1/messages", { method: "POST" })
    expect(isAnthropicMessagesRequest(req)).toBe(true)
  })

  it("rejects a different host", () => {
    expect(isAnthropicMessagesRequest("https://api.openai.com/v1/messages")).toBe(false)
  })

  it("rejects a different Anthropic endpoint path", () => {
    expect(isAnthropicMessagesRequest("https://api.anthropic.com/v1/count_tokens")).toBe(false)
  })

  it("fails open (returns false, does not throw) on a malformed URL", () => {
    expect(() => isAnthropicMessagesRequest("not a url")).not.toThrow()
    expect(isAnthropicMessagesRequest("not a url")).toBe(false)
  })
})

// ---------------------------------------------------------------------------
// 2. upgradeEphemeralCacheControl — 5m -> 1h cache_control rewrite
// ---------------------------------------------------------------------------

describe("upgradeEphemeralCacheControl — happy path", () => {
  it("upgrades a bare ephemeral marker inside a system block", () => {
    const body = {
      system: [{ type: "text", text: "prompt", cache_control: { type: "ephemeral" } }],
    }
    upgradeEphemeralCacheControl(body)
    expect(body.system[0].cache_control).toEqual({ type: "ephemeral", ttl: "1h" })
  })

  it("upgrades a marker nested inside messages[].content[]", () => {
    const body = {
      messages: [
        {
          role: "user",
          content: [{ type: "text", text: "hi", cache_control: { type: "ephemeral" } }],
        },
      ],
    }
    upgradeEphemeralCacheControl(body)
    expect(body.messages[0].content[0].cache_control).toEqual({
      type: "ephemeral",
      ttl: "1h",
    })
  })

  it("upgrades multiple markers across system and messages in one pass", () => {
    const body = {
      system: [{ type: "text", text: "s", cache_control: { type: "ephemeral" } }],
      messages: [
        { role: "user", content: [{ type: "text", text: "u", cache_control: { type: "ephemeral" } }] },
        { role: "assistant", content: [{ type: "text", text: "a", cache_control: { type: "ephemeral" } }] },
      ],
    }
    upgradeEphemeralCacheControl(body)
    expect(body.system[0].cache_control).toEqual({ type: "ephemeral", ttl: "1h" })
    expect(body.messages[0].content[0].cache_control).toEqual({ type: "ephemeral", ttl: "1h" })
    expect(body.messages[1].content[0].cache_control).toEqual({ type: "ephemeral", ttl: "1h" })
  })
})

describe("upgradeEphemeralCacheControl — leaves non-matching markers alone", () => {
  it("does not touch a cache_control that already has a ttl", () => {
    const cacheControl = { type: "ephemeral", ttl: "1h" }
    const body = { system: [{ type: "text", cache_control: cacheControl }] }
    upgradeEphemeralCacheControl(body)
    // Same object reference, untouched — proves it wasn't blindly overwritten.
    expect(body.system[0].cache_control).toBe(cacheControl)
  })

  it("does not add a ttl to a non-ephemeral cache_control type", () => {
    const body = { system: [{ type: "text", cache_control: { type: "persistent" } }] }
    upgradeEphemeralCacheControl(body)
    expect(body.system[0].cache_control).toEqual({ type: "persistent" })
  })

  it("is a no-op on a body with no cache_control markers at all", () => {
    const body = { messages: [{ role: "user", content: [{ type: "text", text: "hi" }] }] }
    expect(() => upgradeEphemeralCacheControl(body)).not.toThrow()
    expect(body).toEqual({ messages: [{ role: "user", content: [{ type: "text", text: "hi" }] }] })
  })
})

// ---------------------------------------------------------------------------
// 3. extractCacheCreationTokens — audit signal scrape
// ---------------------------------------------------------------------------

describe("extractCacheCreationTokens — happy path", () => {
  it("extracts both 1h and 5m token counts from usage.cache_creation", () => {
    const text = JSON.stringify({
      usage: { cache_creation: { ephemeral_1h_input_tokens: 42, ephemeral_5m_input_tokens: 7 } },
    })
    expect(extractCacheCreationTokens(text)).toEqual({ ephemeral1h: 42, ephemeral5m: 7 })
  })

  it("scrapes across SSE-framed chunks, not just a single JSON document", () => {
    const text = [
      'event: message_start\ndata: {"type":"message_start"}\n\n',
      'event: message_delta\ndata: {"usage":{"cache_creation":{"ephemeral_1h_input_tokens":9,"ephemeral_5m_input_tokens":0}}}\n\n',
    ].join("")
    expect(extractCacheCreationTokens(text)).toEqual({ ephemeral1h: 9, ephemeral5m: 0 })
  })
})

describe("extractCacheCreationTokens — partial or absent fields", () => {
  it("defaults the 1h count to 0 when only the 5m field is present", () => {
    const text = JSON.stringify({ usage: { cache_creation: { ephemeral_5m_input_tokens: 12 } } })
    expect(extractCacheCreationTokens(text)).toEqual({ ephemeral1h: 0, ephemeral5m: 12 })
  })

  it("returns null when neither field appears", () => {
    const text = JSON.stringify({ usage: { input_tokens: 5 } })
    expect(extractCacheCreationTokens(text)).toBeNull()
  })

  it("fails open (returns null, does not throw) on garbage text", () => {
    expect(() => extractCacheCreationTokens("not json at all {{{")).not.toThrow()
    expect(extractCacheCreationTokens("not json at all {{{")).toBeNull()
  })
})

// ---------------------------------------------------------------------------
// 4. wrapped fetch (composed) — end-to-end rewrite + fail-open
// ---------------------------------------------------------------------------

describe("wrapped fetch — rewrites matching requests", () => {
  it("upgrades cache_control markers in the forwarded body for an Anthropic messages request", async () => {
    let capturedBody: string | undefined
    const stubFetch = (async (_input: RequestInfo | URL, init?: RequestInit) => {
      capturedBody = init?.body as string
      return new Response("{}", { status: 200 })
    }) as typeof fetch

    const wrapped = buildCachingFetch(stubFetch)
    const body = JSON.stringify({
      system: [{ type: "text", text: "s", cache_control: { type: "ephemeral" } }],
      messages: [{ role: "user", content: [{ type: "text", text: "u", cache_control: { type: "ephemeral" } }] }],
    })

    await wrapped("https://api.anthropic.com/v1/messages", { method: "POST", body })

    const forwarded = JSON.parse(capturedBody!)
    expect(forwarded.system[0].cache_control).toEqual({ type: "ephemeral", ttl: "1h" })
    expect(forwarded.messages[0].content[0].cache_control).toEqual({ type: "ephemeral", ttl: "1h" })
  })

  it("passes non-Anthropic requests through untouched", async () => {
    let capturedBody: string | undefined
    const stubFetch = (async (_input: RequestInfo | URL, init?: RequestInit) => {
      capturedBody = init?.body as string
      return new Response("{}", { status: 200 })
    }) as typeof fetch

    const wrapped = buildCachingFetch(stubFetch)
    const body = JSON.stringify({ cache_control: { type: "ephemeral" } })
    await wrapped("https://api.openai.com/v1/responses", { method: "POST", body })

    expect(capturedBody).toBe(body)
  })
})

describe("wrapped fetch — fails open on malformed bodies", () => {
  it("forwards a non-JSON body to an Anthropic messages request unchanged, without throwing", async () => {
    let capturedBody: string | undefined
    const stubFetch = (async (_input: RequestInfo | URL, init?: RequestInit) => {
      capturedBody = init?.body as string
      return new Response("{}", { status: 200 })
    }) as typeof fetch

    const wrapped = buildCachingFetch(stubFetch)
    const malformed = "{not valid json"

    await expect(
      wrapped("https://api.anthropic.com/v1/messages", { method: "POST", body: malformed }),
    ).resolves.toBeInstanceOf(Response)
    expect(capturedBody).toBe(malformed)
  })

  it("forwards a request with no body unchanged, without throwing", async () => {
    const stubFetch = (async (_input: RequestInfo | URL, _init?: RequestInit) => {
      return new Response("{}", { status: 200 })
    }) as typeof fetch

    const wrapped = buildCachingFetch(stubFetch)
    await expect(
      wrapped("https://api.anthropic.com/v1/messages", { method: "GET" }),
    ).resolves.toBeInstanceOf(Response)
  })
})

// ---------------------------------------------------------------------------
// 5. production wiring — real module exports agree with the extracted copies
// ---------------------------------------------------------------------------

describe("production wiring — real module exports match extracted behavior", () => {
  it("exports the same pure helpers with matching behavior", async () => {
    const prod = await import("../plugins/anthropic-extended-cache.ts")

    const prodBody = {
      system: [{ type: "text", text: "s", cache_control: { type: "ephemeral" } }],
    }
    prod.upgradeEphemeralCacheControl(prodBody)
    expect(prodBody.system[0].cache_control).toEqual({ type: "ephemeral", ttl: "1h" })

    expect(prod.isAnthropicMessagesRequest("https://api.anthropic.com/v1/messages")).toBe(true)
    expect(prod.isAnthropicMessagesRequest("https://api.anthropic.com/v1/count_tokens")).toBe(false)

    expect(
      prod.extractCacheCreationTokens(
        JSON.stringify({ usage: { cache_creation: { ephemeral_1h_input_tokens: 3 } } }),
      ),
    ).toEqual({ ephemeral1h: 3, ephemeral5m: 0 })
    expect(prod.extractCacheCreationTokens("garbage")).toBeNull()
  })
})
