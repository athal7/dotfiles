---
description: Record a screencast demo of a localhost workflow using Playwright
---

Record a screencast demonstrating a user workflow on localhost using Playwright.

## Workflow

1. **Plan** - Review branch changes, identify workflows to demo
2. **Verify** - Ensure dev server is running (auto-detects port from `devcontainer.local.json`)
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
  
  // Auto-detect port from devcontainer.local.json
  let port = 3000;
  if (fs.existsSync('.devcontainer/devcontainer.local.json')) {
    const match = fs.readFileSync('.devcontainer/devcontainer.local.json', 'utf-8').match(/"(\d+):\d+"/);
    if (match) port = parseInt(match[1], 10);
  }
  
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

## Setup

```bash
mkdir -p /tmp/screencast && cd /tmp/screencast
npm init -y && npm install playwright
```

Requires `ffmpeg` for webm→mp4 conversion.
