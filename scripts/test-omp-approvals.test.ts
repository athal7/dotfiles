import { describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const root = resolve(import.meta.dir, "..");
const rendered = execFileSync("chezmoi", ["cat", "-S", root, `${process.env.HOME}/.config/omp/agent/config.yml`], { encoding: "utf8" });
const tools = JSON.parse(execFileSync("yq", ["-o=json", ".tools"], { encoding: "utf8", input: rendered })) as {
  approval: Record<string, string>;
  approvalMode: string;
};

describe("native OMP approval configuration", () => {
  test("uses write baseline and preserves explicit execution-tool allows", () => {
    expect(tools.approvalMode).toBe("write");
    expect(tools.approval.bash).toBe("allow");
    expect(tools.approval.browser).toBe("allow");
    expect(tools.approval.eval).toBe("allow");
    expect(tools.approval.hub).toBe("allow");
    expect(tools.approval.task).toBe("allow");
  });

  test("prompts for registered remote MCP mutation tools, not read-tool nouns", () => {
    expect(tools.approval.mcp__slack_send_message).toBe("prompt");
    expect(tools.approval.mcp__gmail_send_email).toBe("prompt");
    expect(tools.approval.mcp__linear_save_issue).toBe("prompt");
    expect(tools.approval.mcp__atlassian_createjiraissue).toBe("prompt");
    expect(tools.approval.mcp__linear_get_attachment).toBeUndefined();
    expect(tools.approval.mcp__linear_get_initiative).toBeUndefined();
    expect(tools.approval.mcp__gcalendar_quick_add).toBe("prompt");
    expect(tools.approval.mcp__linear_prepare_attachment_upload).toBe("prompt");
  });

  test("preserves explicit read-only MCP allows and leaves other read tools at the write baseline", () => {
    expect(tools.approval.mcp__context7_query_docs).toBe("allow");
    expect(tools.approval.mcp__linear_get_status_updates).toBe("allow");
    expect(tools.approval.mcp__slack_read_channel).toBeUndefined();
  });

  test("prompts for known query tools with argument-sensitive writes", () => {
    expect(tools.approval.mcp__bigquery_query).toBe("prompt");
    expect(tools.approval.mcp__pagerduty_query).toBe("prompt");
  });
});
