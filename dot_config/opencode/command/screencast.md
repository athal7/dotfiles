---
description: Record a screencast demo of a localhost workflow using Playwright
---

Record a screencast demonstrating a user workflow on localhost using Playwright.

**Requested flow:** $ARGUMENTS

If no flow is specified, analyze the branch changes to determine what to demo.

## Directory Structure

Scripts go in the **project directory** under `.screencast/` (add to .gitignore if needed):

```
<project-root>/
└── .screencast/
    ├── record.js      # Recording script (edit in place, never create copies)
    └── recordings/    # Video output (temporary)
```

Shared Playwright installation (already set up):
```
~/.local/share/opencode/screencast/node_modules/
```

**Do NOT:**
- Run `npm install` - use shared node_modules via NODE_PATH
- Create numbered files (`debug2.js`, `record2.js`) - edit the ONE `record.js`

## Port Detection

Check in this order:
1. **`.envrc`** - Worktrees have `export PORT=<number>` (deterministic from worktree name)
2. **`AGENTS.local.md`** - Default port 3000 for main odin checkout
3. **Devcontainer** - Check forwarded ports if in container

```bash
# Read port from .envrc if present
grep -o 'PORT=[0-9]*' .envrc 2>/dev/null | cut -d= -f2 || echo 3000
```

## Workflow

1. **Detect port** - Check `.envrc` first, then AGENTS.local.md
2. **Verify server** - `curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT`
3. **Create .screencast/** - `mkdir -p .screencast/recordings .screencast/screenshots`
4. **Write record.js** - Single script, use selectors from AGENTS.local.md
5. **Run with screenshots** - Take screenshots at key moments for verification
6. **Review screenshots** - Read the screenshots to verify each step worked correctly
7. **Iterate if needed** - If screenshots show unexpected state, fix the script and re-run
8. **Convert** - ffmpeg to mp4, save to ~/Downloads
9. **Show user** - They drag to PR

## Recording Script Pattern

```javascript
const { chromium } = require('playwright');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

(async () => {
  // Port from .envrc or default
  const port = process.env.PORT || 3000;
  const recordingsDir = '.screencast/recordings';
  const screenshotsDir = '.screencast/screenshots';
  fs.mkdirSync(recordingsDir, { recursive: true });
  fs.mkdirSync(screenshotsDir, { recursive: true });
  
  // Clear old recordings and screenshots
  fs.readdirSync(recordingsDir).filter(f => f.endsWith('.webm')).forEach(f => 
    fs.unlinkSync(path.join(recordingsDir, f)));
  fs.readdirSync(screenshotsDir).filter(f => f.endsWith('.png')).forEach(f => 
    fs.unlinkSync(path.join(screenshotsDir, f)));

  const browser = await chromium.launch({ headless: true, slowMo: 150 });
  const context = await browser.newContext({
    recordVideo: { dir: recordingsDir, size: { width: 1280, height: 720 } },
    viewport: { width: 1280, height: 720 }
  });
  const page = await context.newPage();
  
  // Screenshot counter for ordering
  let screenshotIndex = 0;
  async function checkpoint(name) {
    screenshotIndex++;
    const filename = `${String(screenshotIndex).padStart(2, '0')}-${name}.png`;
    await page.screenshot({ path: path.join(screenshotsDir, filename) });
    console.log(`📸 ${filename}`);
  }

  try {
    // === YOUR DEMO STEPS ===
    // Use selectors from AGENTS.local.md - don't discover them
    // Call checkpoint('description') after each significant action
    
    await page.goto(`http://localhost:${port}`);
    await checkpoint('initial-load');
    
    // ... more steps with checkpoint() calls ...
    
  } finally {
    await context.close();
    await browser.close();
    
    const files = fs.readdirSync(recordingsDir).filter(f => f.endsWith('.webm'));
    if (files.length > 0) {
      const webmPath = path.join(recordingsDir, files[0]);
      const branchName = path.basename(process.cwd());
      const mp4Path = path.join(os.homedir(), 'Downloads', `demo-${branchName}.mp4`);
      execSync(`ffmpeg -y -i "${webmPath}" -c:v libx264 -preset fast -crf 22 "${mp4Path}"`);
      fs.unlinkSync(webmPath);
      console.log(`✅ Saved: ${mp4Path}`);
    }
    
    // List screenshots for review
    const screenshots = fs.readdirSync(screenshotsDir).filter(f => f.endsWith('.png')).sort();
    if (screenshots.length > 0) {
      console.log(`\n📷 Screenshots saved for review:`);
      screenshots.forEach(s => console.log(`   ${screenshotsDir}/${s}`));
    }
  }
})();
```

Run with:
```bash
NODE_PATH=~/.local/share/opencode/screencast/node_modules node .screencast/record.js
```

## Screenshot Verification (REQUIRED)

After each run, **you MUST review the screenshots** to verify the automation worked correctly:

1. **Read the screenshots** using the Read tool on each `.screencast/screenshots/*.png` file
2. **Verify each checkpoint** shows the expected UI state
3. **If something looks wrong**, fix the script and re-run before proceeding

**Common issues to catch:**
- Page didn't load correctly (blank or error page)
- Wrong element was clicked (unexpected state)
- Form didn't submit (still showing form instead of result)
- Modal didn't appear/disappear as expected
- Navigation didn't complete

**Do NOT proceed to video conversion** until screenshots confirm the flow is correct. The video is just a recording of what happened - if the screenshots show failures, the video will too.

## Click Indicator Helper

Add this to the script for visual click feedback:

```javascript
async function clickWithIndicator(page, selector) {
  const el = page.locator(selector);
  await el.scrollIntoViewIfNeeded();
  const box = await el.boundingBox();
  if (!box) throw new Error(`Not found: ${selector}`);
  
  await page.evaluate(({x, y}) => {
    const ring = document.createElement('div');
    ring.style.cssText = `position:fixed;left:${x}px;top:${y}px;width:40px;height:40px;
      border:3px solid #ff69b4;border-radius:50%;pointer-events:none;z-index:99999;
      transform:translate(-50%,-50%);animation:pulse 0.5s ease-out`;
    const style = document.createElement('style');
    style.textContent = '@keyframes pulse{0%{transform:translate(-50%,-50%) scale(0.5);opacity:1}100%{transform:translate(-50%,-50%) scale(1.5);opacity:0}}';
    document.head.appendChild(style);
    document.body.appendChild(ring);
    setTimeout(() => ring.remove(), 500);
  }, { x: box.x + box.width/2, y: box.y + box.height/2 });
  
  await page.waitForTimeout(300);
  await el.click();
}
```

## Key Rules

- **One script file** - Edit `record.js` in place, never create `record2.js` or `debug.js`
- **Use AGENTS.local.md selectors** - Don't write discovery scripts
- **Shared node_modules** - Never `npm install` in project directories
- **Always checkpoint** - Add `await checkpoint('description')` after each significant action
- **Always review screenshots** - Read every screenshot after each run to verify correctness
- **If it fails** - Read the error AND the screenshots, fix the ONE script, run again

## Devcontainer Note

If working in a devcontainer, run Playwright commands with `HOST:` prefix since browsers need display access.
