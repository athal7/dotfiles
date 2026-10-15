import { describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const root = resolve(import.meta.dir, "..");
const rendered = execFileSync("chezmoi", ["cat", "-S", root, `${process.env.HOME}/.config/omp/agent/config.yml`], { encoding: "utf8" });
const config = JSON.parse(execFileSync("yq", ["-o=json", "."], { encoding: "utf8", input: rendered })) as {
  github: { enabled: boolean };
  statusLine: { preset: string; leftSegments: string[] };
  tools: { approval: Record<string, string>; approvalMode: string };
};
const tools = config.tools;

describe("OMP status line", () => {
  test("shows the model and prewalk mode while omitting git branch details", () => {
    expect(config.statusLine.preset).toBe("custom");
    expect(config.statusLine.leftSegments).toContain("model");
    expect(config.statusLine.leftSegments).toContain("mode");
    expect(config.statusLine.leftSegments).not.toContain("git");
  });
});

describe("native OMP approval configuration", () => {
  test("uses write baseline and preserves explicit tool allows", () => {
    expect(tools.approvalMode).toBe("write");
    expect(tools.approval.bash).toBe("allow");
    expect(tools.approval.browser).toBeUndefined();
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

  test("disables native GitHub and prompts for gh shell commands", () => {
    expect(config.github.enabled).toBe(false);
    expect(config.bash.patterns).toContainEqual({ match: "gh *", approval: "prompt" });
  });

  test("expands GitHub MCP write globs into exact OMP prompt keys", () => {
    for (const name of [
      "add_issue_comment",
      "add_comment_to_pending_review",
      "add_pull_request_review_comment",
      "create_pull_request_review",
      "submit_pending_pull_request_review",
      "delete_pending_pull_request_review",
      "request_pull_request_reviewers",
      "resolve_review_thread",
      "unresolve_review_thread",
      "actions_run_trigger",
    ]) {
      expect(tools.approval["mcp__github_" + name]).toBe("prompt");
    }
    expect(tools.approval.mcp__github_pull_request_read).toBeUndefined();
    expect(tools.approval.mcp__github_actions_get).toBeUndefined();
    expect(Object.keys(tools.approval).some((name) => name.includes("*"))).toBe(false);
  });

  test("prompts for known query tools with argument-sensitive writes", () => {
    expect(tools.approval.mcp__bigquery_query).toBe("prompt");
    expect(tools.approval.mcp__pagerduty_query).toBe("prompt");
  });
});
