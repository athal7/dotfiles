Approved but not pushed.

1. **Commit and push.** Load `commit`, then `push`. For PR repos this opens the draft request; otherwise it's the whole ship step.
2. **Watch CI and automated review** per the `push` skill. CI failure routes like any Review finding: code fix → `build` (or direct), approach problem → update the plan, flaky → re-run. Never terminal.
3. **Publish the QA report** when QA ran — load `qa-report-publish`.

Ends with: pushed and verified.
