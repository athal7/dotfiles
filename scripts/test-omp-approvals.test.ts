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
// bash allow baseline. The policy under test: prompt only when the command
// reaches another person or destroys shared state.
const globToRegExp = (glob: string): RegExp =>
  new RegExp(
    `^${glob
      .split("*")
      .map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
      .join(".*")}$`,
  );

const tools = config.tools;
const ghApproval = (command: string): string | undefined => {
  const segments = command.split(/&&|\|\||;/).map((segment) => segment.trim());
  for (const pattern of config.bash.patterns) {
    const matcher = globToRegExp(pattern.match);
    if (segments.some((segment) => matcher.test(segment))) return pattern.approval;
  }
  return tools.approval.bash;
};

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
    expect(tools.approval.mcp__gitmcp_search_generic_documentation).toBe("allow");
    expect(tools.approval.mcp__linear_get_status_updates).toBe("allow");
    expect(tools.approval.mcp__slack_read_channel).toBeUndefined();
  });

  test("disables native GitHub", () => {
    expect(config.github.enabled).toBe(false);
  });

  test("runs reads, draft-scoped writes, and pushes without an approval prompt", () => {
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
      "gh run watch 123",
      "gh release list",
      "gh auth status",
      "gh stack --help",
      "gh workflow list",
      // Draft PRs and their branches are not visible to reviewers yet.
      "gh pr create --draft --title 'fix it'",
      "gh stack submit --auto",
      "gh issue create --title 'bug' --assignee @me",
      "gh auth switch",
      // Push stays unattended.
      "git push origin fix-thing",
      "git push --force-with-lease origin fix-thing",
    ]) {
      expect(ghApproval(command)).toBe("allow");
    }
  });

  test("prompts only for actions that reach another person or shared state", () => {
    for (const command of [
      "gh pr create --title 'fix it'",
      "gh pr merge 42 --squash",
      "gh pr comment 42 --body 'ready for review'",
      "gh pr review 42 --approve",
      "gh pr ready 42",
      "gh pr edit 42 --add-reviewer me",
      "gh pr close 42",
      "gh issue comment 7 --body 'done'",
      "gh issue edit 7 --add-assignee me",
      "gh issue close 7",
      "gh release create v1.2.3",
      "gh workflow run deploy.yml",
      "gh secret set TOKEN",
      "gh repo delete me/app",
      "gh stack submit",
      "gh stack merge 42",
      "cd /Users/me/code/app && gh api repos/me/app/issues --method POST -f title=bug",
      "gh api repos/me/app/issues -f title=bug",
      "chezmoi-deploy fix-thing",
    ]) {
      expect(ghApproval(command)).toBe("prompt");
    }
  });

  test("keeps the gh catch-all allow last and every allow ahead of its prompt", () => {
    const ghRules = config.bash.patterns.filter((pattern) => pattern.match.startsWith("gh "));
    expect(ghRules.at(-1)).toEqual({ match: "gh *", approval: "allow" });
    // The only allows are the two draft-scoped shapes and the catch-all: any
    // other allow would let a person-visible write through unannounced.
    expect(ghRules.filter((rule) => rule.approval === "allow").map((rule) => rule.match))
      .toEqual(["gh pr create*--draft*", "gh stack submit*--auto*", "gh *"]);
  });

  test("prompts for GitHub MCP writes that reach another person, allows draft-scoped ones", () => {
    for (const name of [
      "add_issue_comment",
      "add_comment_to_pending_review",
      "add_pull_request_review_comment",
      "create_pull_request_review",
      "submit_pending_pull_request_review",
      "request_pull_request_reviewers",
      "merge_pull_request",
      "update_pull_request",
      "update_issue_comment",
      "issue_write",
      "actions_run_trigger",
    ]) {
      expect(tools.approval["mcp__github_" + name]).toBe("prompt");
    }
    for (const name of [
      "create_pull_request",
      "push_files",
      "create_or_update_file",
      "create_branch",
      "update_pull_request_branch",
      "resolve_review_thread",
      "delete_pending_pull_request_review",
    ]) {
      expect(tools.approval["mcp__github_" + name]).toBe("allow");
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
