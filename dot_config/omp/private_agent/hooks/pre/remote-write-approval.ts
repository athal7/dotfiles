import approvalAllows from "./mcp-approval-allows.json";
import mutatingVerbs from "./mcp-mutating-verbs.json";
import remoteMcpPrefixes from "./mcp-remote-servers.json";

type ToolInput = Record<string, unknown>;
type ToolCallEvent = { toolName: string; input: ToolInput };
type HookContext = {
  hasUI: boolean;
  ui: { confirm(title: string, message: string): Promise<boolean> };
};
type HookAPI = {
  on(event: "tool_call", handler: (event: ToolCallEvent, ctx: HookContext) => unknown): void;
};

const MUTATING_VERBS = new Set(mutatingVerbs);
const MCP_APPROVAL_ALLOWS = new Set(approvalAllows.map((name) => name.toLowerCase()));
const REMOTE_MCP_PREFIXES = remoteMcpPrefixes;
const SHELLS: Record<string, true> = { sh: true, bash: true, zsh: true };
const HTTP_METHODS: Record<string, true> = { get: true, head: true, post: true, put: true, patch: true, delete: true, options: true };

function words(value: string): string[] {
  const result: string[] = [];
  let token = "";
  let quote = "";
  let escaped = false;
  const flush = () => { if (token) result.push(token); token = ""; };
  for (const char of value) {
    if (escaped) { token += char; escaped = false; continue; }
    if (char === "\\" && quote !== "'") { escaped = true; continue; }
    if (quote) { if (char === quote) quote = ""; else token += char; continue; }
    if (char === "'" || char === '"') { quote = char; continue; }
    if (/\s/.test(char)) { flush(); continue; }
    token += char;
  }
  flush();
  return result;
}

function normalize(value: string): string[] {
  return value.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
}

function commandSegments(command: string): string[][] {
  const segments: string[][] = [];
  let current = "";
  let quote = "";
  let escaped = false;
  for (const char of command) {
    if (escaped) { current += char; escaped = false; continue; }
    if (char === "\\" && quote !== "'") { current += char; escaped = true; continue; }
    if (quote) { current += char; if (char === quote) quote = ""; continue; }
    if (char === "'" || char === '"') { current += char; quote = char; continue; }
    if (char === ';' || char === '&' || char === '|' || char === '(' || char === ')' || char === '\n') {
      if (current.trim()) segments.push(words(current));
      current = "";
      continue;
    }
    current += char;
  }
  if (current.trim()) segments.push(words(current));
  return segments;
}

function remoteBashWrite(command: string): boolean {
  for (const tokens of commandSegments(command)) {
    let index = 0;
    while (index < tokens.length && ["command", "env", "exec", "builtin", "nohup", "time", "nice"].includes(tokens[index])) index++;
    const program = tokens[index]?.split("/").at(-1)?.toLowerCase();
    const args = tokens.slice(index + 1);
    if (!program) continue;
    if (SHELLS[program]) {
      const commandIndex = args.findIndex((arg) => /^-[a-z]*c[a-z]*$/.test(arg));
      if (commandIndex !== -1 && remoteBashWrite(args[commandIndex + 1] ?? "")) return true;
      continue;
    }
    if (program === "git") {
      let verbIndex = 0;
      while (verbIndex < args.length) {
        if (["-C", "-c", "--git-dir", "--work-tree"].includes(args[verbIndex])) { verbIndex += 2; continue; }
        if (args[verbIndex] === "--no-pager") { verbIndex++; continue; }
        break;
      }
      if (args[verbIndex] === "push") return true;
    }
    if (program === "curl") {
      const methodIndex = args.findIndex((arg) => arg === "-X" || arg === "--request");
      const method = args[methodIndex + 1]?.toLowerCase() ?? args.find((arg) => /^-[xX](post|put|patch|delete)$/i.test(arg))?.slice(2).toLowerCase();
      if (args.some((arg) => arg === "-d" || arg.startsWith("--data") || arg === "-T" || arg === "--upload-file") || ["post", "put", "patch", "delete"].includes(method ?? "")) return true;
    }
    if (program === "xh") {
      const method = args.find((arg) => HTTP_METHODS[arg.toLowerCase()])?.toLowerCase();
      if (method && method !== "get" && method !== "head") return true;
    }
    if (program === "gh") {
      const verbIndex = args.findIndex((arg, index) => !arg.startsWith("-") && !["-R", "--repo", "--hostname"].includes(args[index - 1]));
      const command = args.slice(verbIndex, verbIndex + 2).join(" ").toLowerCase();
      const methodIndex = args.findIndex((arg) => arg === "-X" || arg === "--method");
      if (args[verbIndex] === "api" && /^(post|put|patch|delete)$/i.test(args[methodIndex + 1] ?? "")) return true;
      if (["issue create", "issue edit", "issue close", "issue reopen", "pr create", "pr edit", "pr close", "pr merge", "release create", "release edit", "repo create", "repo delete", "gist create"].includes(command)) return true;
    }
  }
  return false;
}

function remoteMcpWrite(toolName: string, input: ToolInput): boolean {
  const normalizedName = toolName.toLowerCase();
  if (!REMOTE_MCP_PREFIXES.some((prefix) => normalizedName.startsWith(prefix))) return false;
  if (MCP_APPROVAL_ALLOWS.has(normalizedName)) return false;
  const toolWords = toolName.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
  for (const token of toolWords) for (const verb of MUTATING_VERBS) if (token === verb || token.startsWith(verb)) return true;
  const method = input.method;
  if (typeof method === "string" && /^(post|put|patch|delete)$/i.test(method.trim())) return true;
  const query = input.query;
  return typeof query === "string" && /^\s*(?:#[^\n]*\n\s*)*mutation\b/i.test(query);
}


export default function registerVerbPermissions(pi: HookAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash" && !event.toolName.startsWith("mcp__")) return;
    const input = event.input;
    if (!input || typeof input !== "object") return;
    const needsApproval = event.toolName === "bash"
      ? typeof input.command === "string" && remoteBashWrite(input.command)
      : remoteMcpWrite(event.toolName, input);
    if (!needsApproval) return;
    if (!ctx.hasUI) return { block: true, reason: "Remote write requires interactive approval" };
    try {
      const accepted = await ctx.ui.confirm("Approve remote write", event.toolName + ": " + (event.toolName === "bash" ? String(input.command).slice(0, 240) : event.toolName));
      return accepted ? undefined : { block: true, reason: "Remote write was not approved" };
    } catch {
      return { block: true, reason: "Remote write approval failed" };
    }
  });
}
