import { describe, expect, test } from "bun:test";
import registerVerbPermissions from "../dot_config/omp/private_agent/hooks/pre/verb-permissions";

type Event = { toolName: string; input: Record<string, unknown> };
type Result = { block: true; reason: string } | undefined;

function createHandler(confirm: (title: string, message: string) => Promise<boolean>, hasUI = true) {
  let handler: ((event: Event, ctx: { hasUI: boolean; ui: { confirm: typeof confirm } }) => Promise<Result | unknown>) | undefined;
  registerVerbPermissions({ on: (_event, callback) => { handler = callback; } });
  if (!handler) throw new Error("tool_call handler was not registered");
  const invoke = (event: Event) => handler!(event, { hasUI, ui: { confirm } });
  return invoke;
}

const noPrompt = async () => false;
describe("shared Bash/MCP verb permissions", () => {
  test("allows read-only Bash and MCP calls without UI prompts", async () => {
    const confirm = async () => { throw new Error("unexpected prompt"); };
    const invoke = createHandler(confirm);
    expect(await invoke({ toolName: "bash", input: { command: "git status --short --branch" } })).toBeUndefined();
    expect(await invoke({ toolName: "mcp__tracker_get_issue", input: { description: "delete this word from the prose" } })).toBeUndefined();
    expect(await invoke({ toolName: "read", input: {} })).toBeUndefined();
  });

  test("confirms mutating verbs across Bash and MCP naming styles", async () => {
    let count = 0;
    const invoke = createHandler(async () => { count++; return true; });
    for (const event of [
      { toolName: "bash", input: { command: "git push" } },
      { toolName: "mcp__tracker_save_issue", input: {} },
      { toolName: "mcp__provider_add_comment", input: {} },
      { toolName: "bash", input: { command: "echo ok && rm tmp" } },
    ]) expect(await invoke(event)).toBeUndefined();
    expect(count).toBe(4);
  });

  test("blocks refusal, missing UI, malformed Bash input, and UI failures", async () => {
    const event = { toolName: "bash", input: { command: "git push" } };
    expect(await createHandler(noPrompt)(event)).toEqual({ block: true, reason: "Action was not approved" });
    expect(await createHandler(noPrompt, false)(event)).toEqual({ block: true, reason: "Verb permission requires interactive approval" });
    expect(await createHandler(async () => { throw new Error("cancelled"); })(event)).toEqual({ block: true, reason: "Verb permission approval failed" });
    expect(await createHandler(noPrompt)({ toolName: "bash", input: {} })).toEqual({ block: true, reason: "Verb permission requires a valid Bash command" });
  });

  test("allows read-only Bash commands with mutation-like flag names", async () => {
    const invoke = createHandler(async () => { throw new Error("unexpected prompt"); });
    for (const command of [
      "git branch --show-current",
      "git stash list",
      "gh api repos/owner/repo/issues",
      "curl -X GET https://example.test",
      "chezmoi apply -n",
    ]) expect(await invoke({ toolName: "bash", input: { command } })).toBeUndefined();
  });

  test("prompts for network mutations and GraphQL mutations", async () => {
    let count = 0;
    const invoke = createHandler(async () => { count++; return true; });
    for (const event of [
      { toolName: "bash", input: { command: "gh api repos/owner/repo/issues -X POST" } },
      { toolName: "bash", input: { command: "curl --data value=1 https://example.test" } },
      { toolName: "mcp__generic_api", input: { method: "POST" } },
      { toolName: "mcp__generic_graphql", input: { query: "mutation { updateThing }" } },
    ]) expect(await invoke(event)).toBeUndefined();
    expect(count).toBe(4);
  });

  test("allows explicit safe xh methods but prompts if method is absent or mutating", async () => {
    let count = 0;
    const invoke = createHandler(async () => { count++; return true; });
    expect(await invoke({ toolName: "bash", input: { command: "xh GET https://example.test" } })).toBeUndefined();
    expect(await invoke({ toolName: "bash", input: { command: "xh https://example.test" } })).toBeUndefined();
    expect(await invoke({ toolName: "bash", input: { command: "xh POST https://example.test" } })).toBeUndefined();
    expect(count).toBe(2);
  });
  test("requires approval for directory creation and mutating subcommands", async () => {
    const invoke = createHandler(noPrompt);
    for (const command of [
      "mkdir folder",
      "env MODE=test mkdir -p folder",
      "gh issue create --title example",
      "echo ok && mkdir folder",
      "bash -c 'git push'",
      "git -C repo push",
      "gh -R owner/repo issue create --title example",
      "sh -lc 'echo ok && rm tmp'",
      "tmux send-keys -t demo 'git push' Enter",
      "tmux send-keys -t demo 'mkdir folder' C-m",
      "aoe send --help && git push",
    ]) expect(await invoke({ toolName: "bash", input: { command } })).toEqual({ block: true, reason: "Action was not approved" });
  });

  test("does not interpret help, terminal keys, filters, or quoted data as mutations", async () => {
    const invoke = createHandler(async () => { throw new Error("unexpected prompt"); });
    for (const command of [
      "aoe send --help",
      "tmux send-keys -t demo 'transition' Enter",
      "tmux send-keys -t demo 'echo transition' Enter",
      "cargo test test_transition -- --nocapture",
      "echo 'git push'",
      "sh -c 'git status --short'",
      "git -C repo branch --show-current",
      "mkdir --help",
    ]) expect(await invoke({ toolName: "bash", input: { command } })).toBeUndefined();
  });
});
