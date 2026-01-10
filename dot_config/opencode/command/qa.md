---
description: QA verification with video recording using Playwright MCP
---

Perform QA verification of a localhost workflow using Playwright MCP. **Always records video.**

**Request:** $ARGUMENTS

## Capabilities

This command uses the Playwright MCP tools for:
- **Video recording** - Automatic (saves on browser close)
- **Screenshots** - `playwright_browser_take_screenshot` for key moments
- **Accessibility snapshots** - `playwright_browser_snapshot` for element references
- **Form filling** - `playwright_browser_fill_form` for authentication flows
- **Navigation** - `playwright_browser_navigate`, `playwright_browser_click`

## Output

1. Video recording saved to `~/Downloads/qa-<feature>-<date>.mp4`
2. Pass/fail summary with any issues found

## Workflow

### 1. Plan the Flow
Based on the request, identify the user flow to verify. Keep it focused - one feature per QA run.

### 2. Detect Port
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

### 6. Finalize Recording

1. Close browser to save video:
   ```
   playwright_browser_close
   ```

2. Find and analyze the video:
   ```bash
   VIDEO=$(ls -t /tmp/playwright-mcp-output/*/*.webm | head -1)
   ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO"
   ```

3. Trim the video to remove dead time:
   - Track timestamps during recording: note when you start waiting (for snapshots, figuring out selectors, retries)
   - Identify segments to keep (actual user-visible interactions)
   - Cut out: initial loading, selector discovery pauses, idle time between actions, trailing time
   
   ```bash
   # Simple trim (start/end only):
   ffmpeg -i "$VIDEO" -ss 1.5 -t 26.5 -c:v libx264 -preset fast -crf 23 output.mp4
   
   # Multi-segment concat (cut out middle pauses):
   # 1. Extract good segments
   ffmpeg -i "$VIDEO" -ss 0 -t 5 -c copy seg1.webm
   ffmpeg -i "$VIDEO" -ss 12 -t 8 -c copy seg2.webm
   ffmpeg -i "$VIDEO" -ss 25 -t 10 -c copy seg3.webm
   # 2. Concat and encode
   echo -e "file 'seg1.webm'\nfile 'seg2.webm'\nfile 'seg3.webm'" > list.txt
   ffmpeg -f concat -safe 0 -i list.txt -c:v libx264 -preset fast -crf 23 ~/Downloads/qa-<feature>-$(date +%Y%m%d).mp4
   ```

4. Verify the output video plays correctly

5. Report pass/fail with video path

## Key Rules

- **Use AGENTS.local.md selectors** - Don't write discovery scripts for known pages
- **Self-verify screenshots** - Read screenshots yourself before reporting to user
- **Iterate silently** - If something fails, fix and retry without asking user
- **Video saves on close** - Always close browser to get the video file
- **Trim aggressively** - Remove all dead time: loading screens, selector discovery pauses, idle moments, blank frames
- **Track timestamps** - Note start/end of each meaningful action during recording so you know what to keep
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

## Final Output

- Video path in `~/Downloads/`
- Pass/fail summary
- Any issues found during verification
