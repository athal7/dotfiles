import approvalAllows from "./mcp-approval-allows.json";

type ToolInput = Record<string, unknown>;
type ToolCallEvent = { toolName: string; input: ToolInput };
type HookContext = {
  hasUI: boolean;
  ui: { confirm(title: string, message: string): Promise<boolean> };
};
type HookAPI = {
  on(event: "tool_call", handler: (event: ToolCallEvent, ctx: HookContext) => unknown): void;
};

const MUTATING_VERBS = new Set([
  "add", "append", "apply", "attach", "autofill", "branch", "checkout", "clean", "commit", "copy",
  "create", "delete", "deploy", "destroy", "drop", "edit", "forget", "format", "group", "init",
  "insert", "link", "mark", "merge", "move", "patch", "post", "publish", "purge", "push", "put",
  "reboot", "remove", "rename", "replace", "reply", "reset", "resolve", "respond", "restore", "save",
  "schedule", "send", "set", "share", "shutdown", "stash", "submit", "transition", "update", "upgrade",
  "upload", "write", "mutation",
]);
const DANGEROUS_PROGRAMS = new Set(["sudo", "diskutil", "dd", "mkfs", "wget", "chezmoi-deploy", "mkdir", "rm"]);
const SHELL_INTERPRETERS = new Set(["sh", "bash", "zsh"]);
const NESTED_SUBCOMMANDS = new Set(["issue", "pr", "repo", "remote", "worktree", "session", "container", "image", "service", "secret", "config"]);
const SUBCOMMAND_PROGRAMS = new Set(["git", "gh", "chezmoi", "aoe", "docker", "kubectl", "brew", "npm", "pnpm", "yarn", "bun", "cargo", "xh", "tmux"]);
const COMMAND_PREFIXES = new Set(["command", "env", "exec", "builtin", "nohup", "time", "nice"]);
const HTTP_METHODS = new Set(["get", "head", "post", "put", "patch", "delete", "options"]);
const SEGMENT_BREAK = /[;&|()\n]/;
const MCP_APPROVAL_ALLOWS = new Set(approvalAllows);

function words(value: string): string[] {
  const result: string[] = [];
  let token = "";
  let quote = "";
  let escaped = false;
  const flush = () => { if (token) result.push(token); token = ""; };
  for (let i = 0; i < value.length; i++) {
    const char = value[i];
    if (escaped) { token += char; escaped = false; continue; }
    if (char === "\\" && quote !== "'") { escaped = true; continue; }
    if (quote) { if (char === quote) quote = ""; else token += char; continue; }
    if (char === "'" || char === '"') { quote = char; continue; }
    if (char === "\n" || char === ";" || char === "&" || char === "|" || char === "(" || char === ")") {
      flush();
      continue;
    }
    if (/\s/.test(char)) { flush(); continue; }
    token += char;
  }
  flush();
  return result;
}

function normalize(value: string): string[] {
  return value
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter(Boolean);
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
    if (SEGMENT_BREAK.test(char)) {
      if (current.trim()) segments.push(words(current));
      current = "";
      continue;
    }
    current += char;
  }
  if (current.trim()) segments.push(words(current));
  return segments;
}

function executableIndex(tokens: string[]): number {
  let index = 0;
  while (index < tokens.length) {
    const token = tokens[index];
    if (COMMAND_PREFIXES.has(token)) { index++; continue; }
    if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(token)) { index++; continue; }
    if (token === "!") { index++; continue; }
    break;
  }
  return index;
}

function subcommandIndex(program: string, args: string[]): number {
  if (program !== "git" && program !== "gh") return 0;
  let index = 0;
  while (index < args.length) {
    const arg = args[index];
    if ((program === "git" && /^(?:-C|-c|--git-dir|--work-tree)$/.test(arg)) ||
        (program === "gh" && /^(?:-R|--repo)$/.test(arg))) { index += 2; continue; }
    if (program === "git" && arg === "--no-pager") { index++; continue; }
    break;
  }
  return index;
}

function bashNeedsApproval(command: string): boolean {
  for (const tokens of commandSegments(command)) {
    const index = executableIndex(tokens);
    const program = tokens[index]?.split("/").at(-1)?.toLowerCase();
    if (!program) continue;
    const args = tokens.slice(index + 1);
    if (args.length <= 2 && args.at(-1) === "--help" && program !== "sudo") continue;

    if (SHELL_INTERPRETERS.has(program)) {
      const commandIndex = args.findIndex((arg) => /^-[a-z]*c[a-z]*$/.test(arg));
      if (commandIndex !== -1 && bashNeedsApproval(args[commandIndex + 1] ?? "")) return true;
    }

    // Check a command submitted in this call, but do not treat ordinary keystrokes as verbs.
    if (program === "tmux" && args[0] === "send-keys") {
      if (!args.includes("-l")) {
        const enterIndex = args.findIndex((arg) => arg === "Enter" || arg === "C-m");
        const targetIndex = args.indexOf("-t");
        let payload = "";
        for (let i = 1; i < enterIndex; i++) {
          if (i === targetIndex || i === targetIndex + 1 || ["-H", "-R"].includes(args[i])) continue;
          payload += (payload ? " " : "") + args[i];
        }
        if (payload.includes(" ") && bashNeedsApproval(payload)) return true;
      }
      continue;
    }
    if (DANGEROUS_PROGRAMS.has(program)) return true;
    const verbIndex = subcommandIndex(program, args);

    if (program === "chezmoi" && args[0] === "apply" && args.some((arg) => arg === "-n" || arg === "--dry-run")) continue;
    if (program === "git" && args[verbIndex] === "branch") {
      if (args.some((arg, index) => index > verbIndex && ["-d", "-D", "-m", "-M", "-c", "-C", "--delete", "--move", "--copy"].includes(arg))) return true;
      continue;
    }
    if (program === "git" && args[verbIndex] === "stash" && ["list", "show"].includes(args[verbIndex + 1] ?? "")) continue;
    if (program === "curl") {
      if (args.some((arg) => arg === "-d" || arg === "-T" || arg === "--upload-file" || arg.startsWith("--data"))) return true;
      const methodIndex = args.findIndex((arg) => arg === "-X" || arg === "--request");
      const method = args[methodIndex + 1]?.toLowerCase() ?? args.find((arg) => /^-[xX](post|put|patch|delete)$/i.test(arg))?.slice(2).toLowerCase();
      if (["post", "put", "patch", "delete"].includes(method ?? "")) return true;
    }

    if (program === "gh" && args[verbIndex] === "api") {
      const methodIndex = args.findIndex((arg) => arg === "-X" || arg === "--method");
      if (methodIndex !== -1 && /^(post|put|patch|delete)$/i.test(args[methodIndex + 1] ?? "")) return true;
    }

    // Only command positions are verbs. Paths, payloads and test filters are data.
    const commandWords = [program];
    if (SUBCOMMAND_PROGRAMS.has(program)) {
      commandWords.push(args[verbIndex] ?? "");
      if (NESTED_SUBCOMMANDS.has(args[verbIndex] ?? "")) commandWords.push(args[verbIndex + 1] ?? "");
    }
    const normalizedWords = commandWords.flatMap(normalize);
    if (normalizedWords.some((word) => MUTATING_VERBS.has(word) || word === "rm")) return true;
    if (program === "xh") {
      const method = args.map((token) => token.toLowerCase()).find((token) => HTTP_METHODS.has(token));
      if (method !== "get" && method !== "head") return true;
    }
  }
  return false;
}

function mcpNeedsApproval(toolName: string, input: ToolInput): boolean {
  if (MCP_APPROVAL_ALLOWS.has(toolName)) return false;
  const toolWords = normalize(toolName);
  if (toolWords.some((token) => [...MUTATING_VERBS].some((verb) => token === verb || token.startsWith(verb)))) return true;
  const method = input.method;
  if (typeof method === "string" && /^(post|put|patch|delete)$/i.test(method.trim())) return true;
  const query = input.query;
  return typeof query === "string" && /^\s*(?:#[^\n]*\n\s*)*mutation\b/i.test(query);
}

function blocked(reason: string) {
  return { block: true, reason };
}

export default function registerVerbPermissions(pi: HookAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash" && !event.toolName.startsWith("mcp__")) return;
    const input = event.input;
    if (!input || typeof input !== "object") return blocked("Verb permission requires a valid tool input");

    let needsApproval: boolean;
    let summary: string;
    if (event.toolName === "bash") {
      if (typeof input.command !== "string") return blocked("Verb permission requires a valid Bash command");
      summary = input.command.slice(0, 240);
      needsApproval = bashNeedsApproval(input.command);
    } else {
      summary = event.toolName.slice(0, 200);
      needsApproval = mcpNeedsApproval(event.toolName, input);
    }
    if (!needsApproval) return;
    if (!ctx.hasUI) return blocked("Verb permission requires interactive approval");
    try {
      const accepted = await ctx.ui.confirm("Approve action", event.toolName + ": " + summary);
      return accepted ? undefined : blocked("Action was not approved");
    } catch {
      return blocked("Verb permission approval failed");
    }
  });
}
