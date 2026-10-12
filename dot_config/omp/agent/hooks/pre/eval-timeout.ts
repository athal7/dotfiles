type ToolCallEvent = { toolName: string; input: Record<string, unknown> };
type HookAPI = {
  on(event: "tool_call", handler: (event: ToolCallEvent) => { input: Record<string, unknown> } | void): void;
};

export default function defaultEvalTimeout(pi: HookAPI): void {
  pi.on("tool_call", (event) => {
    if (event.toolName !== "eval" || Object.hasOwn(event.input, "timeout")) return;
    return { input: { ...event.input, timeout: 0 } };
  });
}
