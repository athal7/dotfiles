---
description: QA and demo recording using Playwright MCP for browser automation
---

Perform QA verification or record a demo of a localhost workflow using Playwright MCP.

**Request:** $ARGUMENTS

## Capabilities

This command uses the Playwright MCP tools for:
- **Screenshots** - `playwright_browser_take_screenshot` for verification
- **Video recording** - Automatic via `--save-video` flag (saves on browser close)
- **Accessibility snapshots** - `playwright_browser_snapshot` for element references
- **Form filling** - `playwright_browser_fill_form` for authentication flows
- **Navigation** - `playwright_browser_navigate`, `playwright_browser_click`

## Modes

### QA Verification (default if no specific request)
1. Navigate to the feature/page
2. Take screenshots at key states
3. Verify UI elements match expectations
4. Report pass/fail with evidence

### Demo Recording
1. Plan the user flow to demonstrate
2. Navigate through the workflow (video records automatically)
3. Take screenshots at key moments for thumbnails/highlights
4. Close browser to finalize video
5. Convert webm to mp4 and save to ~/Downloads

## Workflow

### 1. Detect Port
Check in order:
1. **`.envrc`** - Worktrees have `export PORT=<number>`
2. **`AGENTS.local.md`** - Project-specific defaults
3. **Default** - 3000

```bash
grep -o 'PORT=[0-9]*' .envrc 2>/dev/null | cut -d= -f2 || echo 3000
```

### 2. Verify Server
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT
```

### 3. Set Viewport
```
playwright_browser_resize width=1280 height=720
```

### 4. Authenticate (if needed)
Use selectors from AGENTS.local.md - don't discover them:
```
playwright_browser_navigate url=http://localhost:$PORT/users/sign_in
playwright_browser_fill_form fields=[
  {"name": "Email", "type": "textbox", "ref": "...", "value": "admin@test.com"},
  {"name": "Password", "type": "textbox", "ref": "...", "value": "12345678"}
]
playwright_browser_click element="Sign in button" ref="..."
```

### 5. Execute Flow
Navigate through the workflow, taking screenshots at key moments:
```
playwright_browser_take_screenshot filename=01-initial-state.png
# ... perform actions ...
playwright_browser_take_screenshot filename=02-after-action.png
```

### 6. Finalize

**For QA:** Review screenshots, report findings.

**For Demo:**
1. Close browser to save video:
   ```
   playwright_browser_close
   ```
2. Find video in `/tmp/playwright-mcp-output/*/`
3. Convert and save:
   ```bash
   ffmpeg -i /tmp/playwright-mcp-output/*/*.webm -c:v libx264 -preset fast -crf 23 ~/Downloads/demo-$(date +%Y%m%d).mp4
   ```

## Key Rules

- **Use AGENTS.local.md selectors** - Don't write discovery scripts for known pages
- **Self-verify screenshots** - Read screenshots yourself before reporting to user
- **Iterate silently** - If something fails, fix and retry without asking user
- **Video saves on close** - Always close browser to get the video file
- **Accessibility snapshots** - Use `playwright_browser_snapshot` to get element refs for clicking

## Common Patterns

### Login Flow (Odin)
```
playwright_browser_navigate url=http://localhost:$PORT/users/sign_in
playwright_browser_snapshot  # Get refs
playwright_browser_fill_form fields=[...]
playwright_browser_click element="Sign in" ref="..."
playwright_browser_wait_for text="Signed in successfully"
```

### Navigate and Screenshot
```
playwright_browser_navigate url=http://localhost:$PORT/vulnerabilities
playwright_browser_snapshot  # Get current state
playwright_browser_take_screenshot filename=vulnerabilities-list.png
```

### Click and Verify
```
playwright_browser_click element="Submit button" ref="e123"
playwright_browser_wait_for text="Success"
playwright_browser_take_screenshot filename=after-submit.png
```

## Troubleshooting

### Browser not installed
If you get an error about the browser not being installed:
```
playwright_browser_install
```

### Video not saving
Ensure you close the browser properly with `playwright_browser_close` - the video only finalizes on close.

## Output

- **QA:** Summary of verification results with screenshot paths
- **Demo:** Path to mp4 in ~/Downloads, ready to drag to PR
