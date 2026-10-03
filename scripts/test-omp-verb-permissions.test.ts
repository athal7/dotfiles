import { describe, expect, mock, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const root = resolve(import.meta.dir, "..");
function render(name: string): string[] {
  const template = resolve(root, `dot_config/omp/private_agent/hooks/pre/${name}.json.tmpl`);
  return JSON.parse(execFileSync("chezmoi", ["execute-template", "-S", root, "--file", template], { encoding: "utf8" }));
}
const approvalAllows = render("mcp-approval-allows");
const mutatingVerbs = render("mcp-mutating-verbs");
const remoteMcpPrefixes = render("mcp-remote-servers");
mock.module("../dot_config/omp/private_agent/hooks/pre/mcp-approval-allows.json", () => ({ default: approvalAllows }));
mock.module("../dot_config/omp/private_agent/hooks/pre/mcp-mutating-verbs.json", () => ({ default: mutatingVerbs }));
mock.module("../dot_config/omp/private_agent/hooks/pre/mcp-remote-servers.json", () => ({ default: remoteMcpPrefixes }));
const { default: registerRemoteWriteApproval } = await import("../dot_config/omp/private_agent/hooks/pre/remote-write-approval");

type Event = { toolName: string; input: Record<string, unknown> };
type Result = { block: true; reason: string } | undefined;

function createHandler(confirm: (title: string, message: string) => Promise<boolean>, hasUI = true) {
  let handler: ((event: Event, ctx: { hasUI: boolean; ui: { confirm: typeof confirm } }) => Promise<Result | unknown>) | undefined;
  registerRemoteWriteApproval({ on: (_event, callback) => { handler = callback; } });
  if (!handler) throw new Error("tool_call handler was not registered");
  return (event: Event) => handler!(event, { hasUI, ui: { confirm } });
}

describe("known remote write approvals", () => {
  test("prompts for registered remote MCP writes and allows read-only and local MCP calls", async () => {
    let prompts = 0;
    const invoke = createHandler(async (title) => { prompts++; expect(title).toBe("Approve remote write"); return true; });
    expect(await invoke({ toolName: "mcp__slack_send_message", input: {} })).toBeUndefined();
    expect(await invoke({ toolName: "mcp__gmail_send_email", input: {} })).toBeUndefined();
    expect(await invoke({ toolName: "mcp__slack_read_channel", input: {} })).toBeUndefined();
    expect(await invoke({ toolName: "mcp__context7_query_docs", input: { query: "mutation { example }" } })).toBeUndefined();
    expect(await invoke({ toolName: "mcp__cq_confirm", input: {} })).toBeUndefined();
    expect(prompts).toBe(2);
  });

  test("prompts for HTTP method and GraphQL mutations only on remote MCP servers", async () => {
    let prompts = 0;
    const invoke = createHandler(async () => { prompts++; return true; });
    expect(await invoke({ toolName: "mcp__linear_save_issue", input: {} })).toBeUndefined();
    expect(await invoke({ toolName: "mcp__bigquery_query", input: { method: "POST" } })).toBeUndefined();
    expect(await invoke({ toolName: "mcp__pagerduty_query", input: { query: "mutation { updateIncident }" } })).toBeUndefined();
    expect(await invoke({ toolName: "mcp__codebase_memory_delete_project", input: {} })).toBeUndefined();
    expect(prompts).toBe(3);
  });

  test("prompts for known remote shell writes but allows local destructive commands", async () => {
    let prompts = 0;
    const invoke = createHandler(async () => { prompts++; return true; });
    for (const command of ["git push origin main", "git -C repo push origin main", "curl -X POST https://example.test", "xh DELETE https://example.test", "gh issue create --title example", "gh -R owner/repo issue create --title example", "bash -lc 'git push'"]) {
      expect(await invoke({ toolName: "bash", input: { command } })).toBeUndefined();
    }
    for (const command of ["rm -rf build", "mkdir folder", "git branch -D old", "brew uninstall old", "curl https://example.test"]) {
      expect(await invoke({ toolName: "bash", input: { command } })).toBeUndefined();
    }
    expect(prompts).toBe(7);
  });

  test("fails closed for remote writes when UI is unavailable or declines", async () => {
    const event = { toolName: "mcp__slack_send_message", input: {} };
    expect(await createHandler(async () => false)(event)).toEqual({ block: true, reason: "Remote write was not approved" });
    expect(await createHandler(async () => true, false)(event)).toEqual({ block: true, reason: "Remote write requires interactive approval" });
    expect(await createHandler(async () => { throw new Error("cancelled"); })(event)).toEqual({ block: true, reason: "Remote write approval failed" });
  });
});
