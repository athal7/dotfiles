---
description: Record a screencast demo of a localhost workflow using Playwright
---

Record a screencast demonstrating a user workflow on localhost using Playwright.

**Requested flow:** $ARGUMENTS

If no flow is specified, analyze the branch changes to determine what to demo.

## Workspace Detection

Before setting up or recording, check for active devcontainer context:

1. **Check devcontainer status** - Use the `devcontainer` tool (no arguments)
2. **If a devcontainer is targeted**:
   - The dev server runs inside the container (use forwarded port)
   - Playwright setup and recording **must run on the host** (requires display)
   - Use `HOST:` prefix for all bash commands
3. **Otherwise** - Run all commands normally on the host

## Workflow

1. **Plan** - Review branch changes, identify workflows to demo
2. **Verify** - Ensure dev server is running; determine port from project config (see Port Detection). If using a devcontainer, use the forwarded port on localhost.
3. **Record** - Use Playwright with pink click indicators and smooth scrolling
4. **Check logs** - Verify no server errors during recording
5. **Review** - Show user the recording, get approval before posting
6. **Attach** - User drags MP4 to PR (no API upload for videos)

## Recording Template

```javascript
const { chromium } = require('playwright');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

(async () => {
  // Branch-aware setup
  const branchName = execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf-8' })
    .trim().replace(/[^a-zA-Z0-9-_]/g, '-');
  
  // Port determined from project config (see Port Detection section)
  const port = PORT_FROM_PROJECT;
  
  const recordingsDir = `/tmp/screencast/${branchName}/`;
  const downloadsDir = path.join(os.homedir(), 'Downloads');
  
  fs.mkdirSync(recordingsDir, { recursive: true });
  fs.readdirSync(recordingsDir).forEach(f => fs.unlinkSync(path.join(recordingsDir, f)));
  
  const browser = await chromium.launch({ headless: false, slowMo: 150 });
  const context = await browser.newContext({
    recordVideo: { dir: recordingsDir, size: { width: 1280, height: 720 } },
    viewport: { width: 1280, height: 720 }
  });
  const page = await context.newPage();
  
  // Inject click indicator styles
  await page.addStyleTag({ content: CLICK_STYLES });
  
  try {
    await page.goto(`http://localhost:${port}`, { waitUntil: 'networkidle' });
    
    // Demo steps using clickWithPointer() and smoothScroll()
    // ...
    
  } finally {
    await context.close();
    await browser.close();
    
    // Convert to MP4
    const files = fs.readdirSync(recordingsDir).filter(f => f.endsWith('.webm'));
    if (files.length > 0) {
      const webmPath = path.join(recordingsDir, files[0]);
      const mp4Path = path.join(downloadsDir, `demo-${branchName}.mp4`);
      execSync(`ffmpeg -y -i "${webmPath}" -c:v libx264 -preset fast -crf 22 "${mp4Path}"`);
      fs.unlinkSync(webmPath);
      console.log(`Saved: ${mp4Path}`);
    }
  }
})();
```

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

- **Click, don't navigate** - Use `clickWithPointer()` instead of `page.goto()` (except initial load)
- **Smooth scroll** - Use `smoothScroll()` instead of instant jumps
- **Type fast, screenshot after** - Use `page.fill()` for instant typing, then take a screenshot to verify the input
- **Check logs after** - Look for 500s, exceptions, errors before showing to user
- **Get approval** - Never post without user confirming the recording looks good
- **User uploads** - Videos can't be uploaded via API; user drags file to PR

## Port Detection

Before recording, determine the dev server port by checking these sources in order:

1. **`.env` or `.env.local`** - Look for `PORT=`, `APP_PORT=`, `DEV_PORT=`
2. **`package.json`** - Check `scripts.dev` or `scripts.start` for `--port` flags
3. **`devcontainer.json`** - Check `forwardPorts` array
4. **`docker-compose.yml`** - Check port mappings (e.g., `"3000:3000"`)
5. **`README.md`** - Search for localhost URLs or port mentions
6. **Default** - Fall back to 3000

Replace `PORT_FROM_PROJECT` in the template with the detected port.

## Setup

**Important**: Playwright requires a display and must run on the host machine, not inside a devcontainer. If a devcontainer session is active, use `HOST:` prefix for these commands.

All screencast files go in `/tmp/screencast/` - this is a temp directory and does not require user confirmation for writes.

```bash
mkdir -p /tmp/screencast && cd /tmp/screencast
npm init -y && npm install playwright
```

Requires `ffmpeg` for webm→mp4 conversion.
