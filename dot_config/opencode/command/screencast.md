---
description: Record a screencast demo of a localhost workflow using Playwright
---

Record a screencast demonstrating a user workflow on localhost using Playwright.

**Requested flow:** $ARGUMENTS

If no flow is specified, analyze the branch changes to determine what to demo.

## IMPORTANT: No Confirmation Required

All screencast operations are pre-approved and do not require user confirmation:
- Writing to `~/.local/share/opencode/screencast/` (persistent Playwright installation)
- Writing to `/tmp/screencast/<repo>/<branch>/` (recording workspace)
- Running npm install, node commands for recording
- Converting webm to mp4 with ffmpeg

**Proceed with all screencast setup and recording steps without asking for permission.**

## Devcontainer Handling

**CRITICAL**: Playwright requires a display and MUST run on the host, never inside a devcontainer.

1. **Check devcontainer status** - Use the `devcontainer` tool (no arguments)
2. **If a devcontainer is targeted**:
   - ALL screencast bash commands MUST use `HOST:` prefix (e.g., `HOST: node record.js`)
   - The dev server runs inside container but is accessible via forwarded localhost port
   - Get the forwarded port from devcontainer status output
3. **Otherwise** - Run commands normally on host

## Project Context from AGENTS.local.md

Before detecting ports/credentials, check `~/.config/opencode/AGENTS.local.md` for project-specific defaults:
- **Port**: Look for "Development Server" or "Port" sections
- **Test credentials**: Look for "Test Credentials" sections  
- **Login selectors**: Look for "Authentication Flow" sections
- **URL patterns**: Look for routing conventions (e.g., UUIDs vs integer IDs)

Only fall back to Port Detection (below) if AGENTS.local.md doesn't have the info.

## Workflow

1. **Plan** - Review branch changes, identify workflows to demo
2. **Pre-flight** - Run verification checks (see Pre-flight Checks)
3. **Setup** - Ensure Playwright is installed (see Setup section)
4. **Record** - Use Playwright with pink click indicators and smooth scrolling
5. **Check logs** - Verify no server errors during recording
6. **Review** - Show user the recording, get approval before posting
7. **Attach** - User drags MP4 to PR (no API upload for videos)

## Pre-flight Checks (REQUIRED)

Before writing ANY recording script, verify the environment:

```bash
# 1. Check ~/.config/opencode/AGENTS.local.md for project-specific port
# Look for "Development Server" or "Port" sections
# Default to 3000 if not specified
PORT=3000  # ← Update from AGENTS.local.md!

# 2. Verify server is running and responding
curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT
# Should return 200 or 302 (redirect to login)

# 3. If using devcontainer, check forwarded ports
# devcontainer status shows forwarded ports
```

**If curl fails**: The server isn't running. Do NOT proceed with recording.
**If wrong port**: Check AGENTS.local.md - it has the correct port for each project.

## Recording Template

Write this to `/tmp/screencast/<repo>/<branch>/record.js`:

```javascript
const { chromium } = require('playwright');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

(async () => {
  // CUSTOMIZE THESE VALUES (from AGENTS.local.md or detected):
  const repoName = 'REPO_NAME';      // e.g., 'odin'
  const branchName = 'BRANCH_NAME';  // e.g., '0DIN-701'
  const port = PORT_NUMBER;          // e.g., 3000 or devcontainer forwarded port
  
  const baseDir = `/tmp/screencast/${repoName}/${branchName}`;
  const recordingsDir = `${baseDir}/recordings/`;
  const downloadsDir = path.join(os.homedir(), 'Downloads');
  
  fs.mkdirSync(recordingsDir, { recursive: true });
  // Clear old recordings
  fs.readdirSync(recordingsDir).filter(f => f.endsWith('.webm')).forEach(f => fs.unlinkSync(path.join(recordingsDir, f)));
  
  console.log('Launching browser...');
  const browser = await chromium.launch({ headless: true, slowMo: 150 });
  const context = await browser.newContext({
    recordVideo: { dir: recordingsDir, size: { width: 1280, height: 720 } },
    viewport: { width: 1280, height: 720 }
  });
  const page = await context.newPage();
  
  // Inject click indicator styles (defined below)
  await page.addStyleTag({ content: CLICK_STYLES });
  
  try {
    await page.goto(`http://localhost:${port}`, { waitUntil: 'networkidle' });
    
    // === DEMO STEPS GO HERE ===
    // Use clickWithPointer(selector) and smoothScroll(selector)
    // Example login flow (customize from AGENTS.local.md):
    // await page.fill('input[name="user[email]"]', 'admin@test.com');
    // await page.fill('input[name="user[password]"]', '12345678');
    // await clickWithPointer('input[type="submit"]');
    
  } finally {
    await context.close();
    await browser.close();
    
    // Convert to MP4
    const files = fs.readdirSync(recordingsDir).filter(f => f.endsWith('.webm'));
    if (files.length > 0) {
      const webmPath = path.join(recordingsDir, files[0]);
      const mp4Path = path.join(downloadsDir, `demo-${repoName}-${branchName}.mp4`);
      console.log(`Converting to ${mp4Path}...`);
      execSync(`ffmpeg -y -i "${webmPath}" -c:v libx264 -preset fast -crf 22 "${mp4Path}"`);
      fs.unlinkSync(webmPath);
      console.log(`\n✅ Saved: ${mp4Path}`);
    }
  }
})();
```

Run with: `NODE_PATH=~/.local/share/opencode/screencast/node_modules node record.js`

## Click Indicator (Pink Pointer)

Show a pink pointer for 800ms before each click so viewers can follow along:

```javascript
const CLICK_STYLES = `
  .click-pointer {
    position: fixed; pointer-events: none; z-index: 999999;
    transform: translate(-5px, -5px);
    filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
  }
  .click-pointer svg { width: 40px; height: 40px; }
  .click-ring {
    position: fixed; width: 50px; height: 50px;
    border: 4px solid #ff69b4; border-radius: 50%;
    pointer-events: none; z-index: 999998;
    transform: translate(-50%, -50%);
    animation: ring-pulse 0.6s ease-out forwards;
  }
  @keyframes ring-pulse {
    0% { transform: translate(-50%, -50%) scale(0.5); opacity: 1; }
    100% { transform: translate(-50%, -50%) scale(1.5); opacity: 0; }
  }
`;

async function clickWithPointer(page, selector) {
  const box = await page.locator(selector).boundingBox();
  if (!box) throw new Error(`Not found: ${selector}`);
  
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;
  
  // Show pointer
  await page.evaluate(({x, y}) => {
    const p = document.createElement('div');
    p.className = 'click-pointer';
    p.innerHTML = `<svg viewBox="0 0 24 24" fill="#ff69b4" stroke="#fff" stroke-width="1">
      <path d="M4 4 L4 20 L9 15 L13 22 L16 20 L12 13 L19 13 Z"/></svg>`;
    p.style.cssText = `left:${x}px;top:${y}px`;
    document.body.appendChild(p);
    window._ptr = p;
  }, {x, y});
  
  await page.waitForTimeout(800);
  
  // Click with ring effect
  await page.evaluate(({x, y}) => {
    const r = document.createElement('div');
    r.className = 'click-ring';
    r.style.cssText = `left:${x}px;top:${y}px`;
    document.body.appendChild(r);
    setTimeout(() => r.remove(), 600);
    window._ptr?.remove();
  }, {x, y});
  
  await page.locator(selector).click();
}
```

## Smooth Scrolling

```javascript
async function smoothScroll(page, selector) {
  await page.evaluate((sel) => {
    document.querySelector(sel)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }, selector);
  await page.waitForTimeout(500);
}
```

## Key Rules

- **No confirmation needed** - All screencast operations are pre-approved
- **Click, don't navigate** - Use `clickWithPointer()` instead of `page.goto()` (except initial load)
- **Smooth scroll** - Use `smoothScroll()` instead of instant jumps
- **Type fast** - Use `page.fill()` for instant typing
- **Check logs after** - Look for 500s, exceptions, errors before showing to user
- **Get approval for posting only** - The recording itself doesn't need approval, but confirm before user uploads to PR
- **User uploads** - Videos can't be uploaded via API; user drags file to PR

## Iteration & Troubleshooting

When a recording fails or doesn't capture the right flow:

### Debug Mode (Non-headless)
Create a minimal debug script to inspect the page interactively:

```javascript
// debug.js - Run with: NODE_PATH=~/.local/share/opencode/screencast/node_modules node debug.js
const { chromium } = require('playwright');

(async () => {
  const port = 3000;  // ← Update this! Check AGENTS.local.md for project port
  const browser = await chromium.launch({ headless: false, slowMo: 500 });
  const page = await browser.newPage();
  
  await page.goto(`http://localhost:${port}`, { waitUntil: 'networkidle' });
  
  // Inspect selectors - copy these from browser DevTools
  const elements = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('button, a, input[type="submit"]'))
      .map(el => ({
        tag: el.tagName,
        text: el.innerText?.substring(0, 30),
        id: el.id,
        classes: el.className,
        visible: el.offsetParent !== null
      }))
      .slice(0, 20);
  });
  console.log('Clickable elements:', JSON.stringify(elements, null, 2));
  
  // Take screenshot for reference
  await page.screenshot({ path: '/tmp/debug-screenshot.png' });
  
  // Keep browser open for manual inspection
  console.log('Browser open for inspection. Press Ctrl+C to close.');
  await new Promise(() => {});  // Keep alive
})();
```

### Common Issues

| Problem | Solution |
|---------|----------|
| `ERR_CONNECTION_REFUSED` | Server not running. Start it first, then verify with curl. |
| Element not found | Use debug mode to inspect actual selectors. DOM may differ from expected. |
| Click indicator not showing | Call `await page.addStyleTag({ content: CLICK_STYLES });` after each `page.goto()`. |
| Video not created | Ensure `context.close()` is called - video is only saved on context close. |
| Wrong port | Check AGENTS.local.md for project-specific port. Don't guess. |

### Iteration Cycle

1. **Fail fast**: Run the script and capture the error
2. **Debug**: Use non-headless mode to see what's actually on the page
3. **Fix selectors**: Update selectors based on actual DOM
4. **Test incrementally**: Comment out later steps, verify each step works
5. **Record**: Only run full recording once individual steps are verified

## Port Detection (Fallback)

**First**: Check `~/.config/opencode/AGENTS.local.md` for project-specific port configuration.

**If not found**, detect the dev server port by checking these sources in order:

1. **Devcontainer forwarded port** - If using devcontainer, check the forwarded port from status
2. **`.env` or `.env.local`** - Look for `PORT=`, `APP_PORT=`, `DEV_PORT=`
3. **`package.json`** - Check `scripts.dev` or `scripts.start` for `--port` flags
4. **`devcontainer.json`** - Check `forwardPorts` array
5. **`docker-compose.yml`** - Check port mappings (e.g., `"3000:3000"`)
6. **Default** - Fall back to 3000

## Setup (No Confirmation Needed)

Playwright is installed once in a persistent location and reused across sessions.

### One-time Setup (if needed)
Check if Playwright is already installed:
```bash
# Check for existing installation
ls ~/.local/share/opencode/screencast/node_modules/playwright 2>/dev/null && echo "Playwright ready" || echo "Need to install"
```

If not installed, set it up (only once):
```bash
mkdir -p ~/.local/share/opencode/screencast
cd ~/.local/share/opencode/screencast
npm init -y
npm install playwright
npx playwright install chromium
```

### Per-Recording Setup
Create the recording workspace (fast, no npm install needed):
```bash
# Replace <repo> and <branch> with actual values
mkdir -p /tmp/screencast/<repo>/<branch>/recordings
```

### Recording Script Location
Write `record.js` to `/tmp/screencast/<repo>/<branch>/record.js`

Run it using the shared node_modules:
```bash
cd /tmp/screencast/<repo>/<branch>
NODE_PATH=~/.local/share/opencode/screencast/node_modules node record.js
```

### Requirements
- `ffmpeg` for webm→mp4 conversion (in Brewfile)
- Chromium browser (installed via `npx playwright install chromium`)
