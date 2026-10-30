import { describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const root = resolve(import.meta.dir, "..");
const rendered = execFileSync("chezmoi", ["cat", "-S", root, `${process.env.HOME}/.config/omp/agent/config.yml`], { encoding: "utf8" });
const config = JSON.parse(execFileSync("yq", ["-o=json", "."], { encoding: "utf8", input: rendered })) as {
  bash: { patterns: { match: string; approval: string }[] };
  github: { enabled: boolean };
  statusLine: { preset: string; leftSegments: string[] };
  tools: { approval: Record<string, string>; approvalMode: string };
};

// OMP matches bash.patterns in order against each segment of a compound command
// with * globs; the first matching rule wins and an unmatched command keeps the
// bash allow baseline.
const globToRegExp = (glob: string): RegExp =>
  new RegExp(
    `^${glob
      .split("*")
      .map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
      .join(".*")}$`,
  );

const ghApproval = (command: string): string | undefined => {
  const segments = command.split(/&&|\|\||;/).map((segment) => segment.trim());
  for (const pattern of config.bash.patterns) {
    const matcher = globToRegExp(pattern.match);
    if (segments.some((segment) => matcher.test(segment))) return pattern.approval;
  }
  return undefined;
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

  test("disables native GitHub", () => {
    expect(config.github.enabled).toBe(false);
  });

  test("lets the listed read-only gh commands run without an approval prompt", () => {
    for (const command of [
      "gh pr view 4534 --json number,title,body",
      "gh pr diff 4534",
      "gh pr list --state open",
      "gh pr checks",
      "gh issue view 7",
      "gh search issues 'repo:me/app cost precision' --limit 5",
      "gh api repos/me/app/contents/README.md",
      "gh repo view me/app",
      "gh run view 123 --log",
      "gh release list",
      "gh auth status",
      "gh stack --help",
    ]) {
      expect(ghApproval(command)).toBe("allow");
    }
  });

  test("prompts for the catch-all rule instead of enumerating mutations", () => {
    for (const command of [
      "gh pr create --draft --title 'fix it'",
      "gh pr merge 42 --squash",
      "gh issue comment 7 --body 'done'",
      "gh release create v1.2.3",
      "gh workflow run deploy.yml",
      "gh secret set TOKEN",
      "gh stack submit --auto",
      "gh auth switch",
      "gh repo delete me/app",
      // Unlisted reads stay gated until someone adds them to the allowlist.
      "gh workflow list",
      "cd /Users/me/code/app && gh api repos/me/app/issues --method POST -f title=bug",
      "gh api repos/me/app/issues -f title=bug",
    ]) {
      expect(ghApproval(command)).toBe("prompt");
    }
  });

  test("keeps the gh catch-all prompt last so no allow can follow it", () => {
    const ghRules = config.bash.patterns.filter((pattern) => pattern.match.startsWith("gh "));
    expect(ghRules.at(-1)).toEqual({ match: "gh *", approval: "prompt" });
    expect(ghRules.filter((rule) => rule.approval === "prompt" && rule.match !== "gh *"))
      .toHaveLength(6);
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
