---
description: QA verification with video recording using Playwright scripts
---

Perform QA verification of a localhost workflow using Playwright. **Always records video.**

**Request:** $ARGUMENTS

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

### 3. Verify Server
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT
```

### 4. Write the Test Script

Create `.screencast/qa-test.spec.ts` (directory is globally gitignored):

```typescript
import { test, expect } from '@playwright/test';

test('QA: <feature name>', async ({ page }) => {
  await page.goto('/');
  
  // Perform actions and assertions
  await expect(page.locator('h1')).toBeVisible();
  
  // Take screenshots at key moments
  await page.screenshot({ path: 'screenshots/01-initial.png' });
  
  // ... more actions ...
  
  await page.screenshot({ path: 'screenshots/02-final.png' });
});
```

### 5. Create Playwright Config

Create `.screencast/playwright.config.ts`:

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  testMatch: 'qa-test.spec.ts',
  timeout: 60000,
  use: {
    baseURL: 'http://localhost:3000',
    viewport: { width: 1280, height: 720 },
    video: 'on',
    screenshot: 'on',
    trace: 'on',
  },
  outputDir: './results',
  reporter: [['list']],
});
```

### 6. Run the Test

```bash
mkdir -p .screencast
cd .screencast && npx playwright test --headed
```

### 7. Process Video

1. Find the video:
```bash
VIDEO=$(find .screencast/results -name "*.webm" -type f | head -1)
ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO"
```

2. Trim if needed (cut dead time at start/end):
```bash
ffmpeg -i "$VIDEO" -ss 0.5 -c:v libx264 -preset fast -crf 23 ~/Downloads/qa-<feature>-$(date +%Y%m%d).mp4
```

For longer videos with idle sections in the middle, extract and concat segments:
```bash
ffmpeg -i "$VIDEO" -ss 0 -t 5 -c copy seg1.webm
ffmpeg -i "$VIDEO" -ss 12 -t 8 -c copy seg2.webm
echo -e "file 'seg1.webm'\nfile 'seg2.webm'" > list.txt
ffmpeg -f concat -safe 0 -i list.txt -c:v libx264 -preset fast -crf 23 output.mp4
```

### 8. Report Results

- Pass/fail based on test exit code
- Video path in `~/Downloads/`
- Any assertion failures or errors from test output

## Key Rules

- **Check AGENTS.local.md first** - Use selectors/credentials documented there, don't rediscover
- **Write focused scripts** - One user flow per test
- **Add assertions** - Use `expect()` to verify expected behavior
- **Screenshots at key moments** - Capture before/after states
- **Self-verify screenshots** - Read screenshots yourself before reporting to user
- **Iterate silently** - If test fails, fix the script and retry without asking user

## Script Patterns

### Login Flow
```typescript
await page.goto('/login');
await page.fill('input[name="email"]', 'user@example.com');
await page.fill('input[name="password"]', 'password');
await page.click('button[type="submit"]');
await expect(page).toHaveURL('/dashboard');
```

### Wait for Navigation
```typescript
await page.click('a:has-text("Dashboard")');
await page.waitForURL('**/dashboard');
```

### Fill Form
```typescript
await page.fill('#title', 'Test Title');
await page.selectOption('#status', 'active');
await page.check('#published');
await page.click('button:has-text("Save")');
```

### Assert Table Content
```typescript
const rows = page.locator('table tbody tr');
await expect(rows).toHaveCount(10);
await expect(rows.first()).toContainText('Expected text');
```

## Troubleshooting

### Browser not installed
```bash
npx playwright install chromium
```

### Test times out
Increase timeout in config or add explicit waits:
```typescript
await page.waitForSelector('.loading', { state: 'hidden' });
```

### Selectors not found
Use Playwright's codegen to discover selectors:
```bash
npx playwright codegen http://localhost:3000
```

## Final Output

- Video path in `~/Downloads/`
- Pass/fail summary
- Test output with any failures
