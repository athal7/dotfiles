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
const DANGEROUS_PROGRAMS = new Set(["sudo", "diskutil", "dd", "mkfs", "wget", "chezmoi-deploy"]);
const SCRIPT_INTERPRETERS = new Set(["sh", "bash", "python", "node", "bun", "deno", "ruby", "perl", "php", "lua", "awk", "osascript"]);
const COMMAND_PREFIXES = new Set(["command", "env", "exec", "builtin", "nohup", "time", "nice"]);
const HTTP_METHODS = new Set(["get", "head", "post", "put", "patch", "delete", "options"]);
const SEGMENT_BREAK = /[;&|()\n]/;

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

function bashNeedsApproval(command: string): boolean {
  for (const tokens of commandSegments(command)) {
    const index = executableIndex(tokens);
    const program = tokens[index]?.split("/").at(-1)?.toLowerCase();
    if (!program) continue;
    const args = tokens.slice(index + 1);
    if (DANGEROUS_PROGRAMS.has(program)) return true;

    if (program === "chezmoi" && args[0] === "apply" && args.some((arg) => arg === "-n" || arg === "--dry-run")) continue;
    if (program === "git" && args[0] === "branch") {
      if (args.some((arg) => ["-d", "-D", "-m", "-M", "-c", "-C", "--delete", "--move", "--copy"].includes(arg))) return true;
      continue;
    }
    if (program === "git" && args[0] === "stash" && ["list", "show"].includes(args[1] ?? "")) continue;
    if (program === "curl") {
      if (args.some((arg) => arg === "-d" || arg === "-T" || arg === "--upload-file" || arg.startsWith("--data"))) return true;
      const methodIndex = args.findIndex((arg) => arg === "-X" || arg === "--request");
      const method = args[methodIndex + 1]?.toLowerCase() ?? args.find((arg) => /^-[xX](post|put|patch|delete)$/i.test(arg))?.slice(2).toLowerCase();
      if (["post", "put", "patch", "delete"].includes(method ?? "")) return true;
    }

    const normalizedWords = tokens.filter((token) => !token.startsWith("-")).flatMap(normalize);
    if (normalizedWords.some((word) => MUTATING_VERBS.has(word) || word === "rm")) return true;
    if (program === "xh") {
      const method = args.map((token) => token.toLowerCase()).find((token) => HTTP_METHODS.has(token));
      if (method !== "get" && method !== "head") return true;
    }
    if (SCRIPT_INTERPRETERS.has(program) && args.includes("--help")) return true;
  }
  return false;
}

function mcpNeedsApproval(toolName: string, input: ToolInput): boolean {
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
