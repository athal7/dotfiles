import { describe, expect, test } from "bun:test";
import defaultEvalTimeout from "../dot_config/omp/private_agent/hooks/pre/eval-timeout";

type Event = { toolName: string; input: Record<string, unknown> };

function transform(event: Event): Record<string, unknown> {
  let handler: ((event: Event) => { input: Record<string, unknown> } | void) | undefined;
  defaultEvalTimeout({ on: (_name, callback) => { handler = callback; } });
  if (!handler) throw new Error("tool_call handler was not registered");
  return handler(event)?.input ?? event.input;
}

describe("Eval timeout default", () => {
  test("disables the Eval deadline when omitted", () => {
    const input = { language: "js", code: "await tool.bash({ command: 'gh pr view' })" };
    expect(transform({ toolName: "eval", input })).toEqual({ ...input, timeout: 0 });
    expect(input).toEqual({ language: "js", code: "await tool.bash({ command: 'gh pr view' })" });
  });

  test("preserves an explicit Eval deadline", () => {
    const input = { language: "js", code: "1 + 1", timeout: 12 };
    expect(transform({ toolName: "eval", input })).toBe(input);
  });

  test("does not alter non-Eval tool inputs", () => {
    const input = { command: "sleep 1", timeout: 5 };
    expect(transform({ toolName: "bash", input })).toBe(input);
  });
});
