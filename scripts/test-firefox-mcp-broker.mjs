#!/usr/bin/env node
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { chmod, copyFile, mkdir, mkdtemp, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = join(repo, 'dot_local', 'share', 'firefox-mcp-broker');
const nightly = '/Applications/Firefox Nightly.app/Contents/MacOS/firefox';
const timeoutMs = 20_000;
// Keep Unix-socket fixtures below macOS's sockaddr_un path limit.
const temp = await mkdtemp('/tmp/f-');
const home = join(temp, 'home');
const brokerDir = join(home, '.local', 'share', 'firefox-mcp-broker');
const localBin = join(home, '.local', 'bin');
const socketPath = join(brokerDir, 'broker.sock');
const lockPath = `${socketPath}.owner`;
const ownerPidPath = `${lockPath}.pid`;
const brokerPath = join(brokerDir, 'broker.mjs');
const launcherPath = join(localBin, 'firefox-mcp-broker');
const basePath = process.env.PATH || '/usr/bin:/bin';
const env = { ...process.env, HOME: home, PATH: `${localBin}:${basePath}`, FIREFOX_NIGHTLY_BINARY: nightly };
const launchdEnv = { ...env, TMPDIR: join(temp, 'launchd-tmp') };
const clientEnv = { ...env, TMPDIR: join(temp, 'omp-tmp') };
const children = new Set();
let httpServer;

function child(command, args, childEnv = env) {
  const processChild = spawn(command, args, { cwd: repo, env: childEnv, stdio: ['pipe', 'pipe', 'pipe'] });
  children.add(processChild);
  processChild.once('exit', () => children.delete(processChild));
  processChild.stdout.setEncoding('utf8');
  processChild.stderr.setEncoding('utf8');
  processChild.stderrText = '';
  processChild.stderr.on('data', chunk => { processChild.stderrText += chunk; });
  return processChild;
}
function waitForExit(processChild, timeout = timeoutMs) {
  if (processChild.exitCode !== null || processChild.signalCode !== null) {
    return Promise.resolve({ code: processChild.exitCode, signal: processChild.signalCode });
  }
  return Promise.race([
    new Promise((resolveExit, rejectExit) => {
      processChild.once('error', rejectExit);
      processChild.once('exit', (code, signal) => resolveExit({ code, signal }));
    }),
    delay(timeout).then(() => { throw new Error(`process ${processChild.pid} (${processChild.spawnfile} ${processChild.spawnargs.join(' ')}) did not exit within ${timeout}ms; stderr=${processChild.stderrText}`); }),
  ]);
}
async function waitUntil(check, description, timeout = timeoutMs) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const value = await check();
    if (value) return value;
    await delay(100);
  }
  throw new Error(`timed out waiting for ${description}`);
}
function run(command, args, runEnv = env) {
  const result = spawnSync(command, args, { cwd: repo, env: runEnv, encoding: 'utf8' });
  if (result.error) throw result.error;
  assert.equal(result.status, 0, `${command} ${args.join(' ')} failed:\n${result.stderr}`);
  return result.stdout;
}

class McpClient {
  constructor(processChild) {
    this.process = processChild;
    this.buffer = '';
    this.nextId = 1;
    this.pending = new Map();
    this.stderr = '';
    processChild.stderr.on('data', chunk => { this.stderr += chunk; });
    processChild.stdout.on('data', chunk => {
      this.buffer += chunk;
      for (let end; (end = this.buffer.indexOf('\n')) >= 0;) {
        const line = this.buffer.slice(0, end);
        this.buffer = this.buffer.slice(end + 1);
        if (!line) continue;
        let message;
        try { message = JSON.parse(line); } catch (error) { this.rejectAll(new Error(`invalid MCP JSON from client: ${line}: ${error}`)); continue; }
        const pending = this.pending.get(message.id);
        if (!pending) continue;
        this.pending.delete(message.id);
        if (message.error) pending.reject(new Error(message.error.message));
        else pending.resolve(message.result);
      }
    });
    processChild.once('exit', (code, signal) => this.rejectAll(new Error(`MCP client exited ${code ?? signal}: ${this.stderr}`)));
  }
  rejectAll(error) {
    for (const pending of this.pending.values()) pending.reject(error);
    this.pending.clear();
  }
  request(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolveRequest, rejectRequest) => {
      const timer = setTimeout(() => { this.pending.delete(id); rejectRequest(new Error(`MCP ${method} timed out`)); }, timeoutMs);
      this.pending.set(id, { resolve: value => { clearTimeout(timer); resolveRequest(value); }, reject: error => { clearTimeout(timer); rejectRequest(error); } });
      this.process.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
    });
  }
  notify(method, params = {}) { this.process.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n'); }
  async start(protocolVersion = '2025-03-26') {
    const initialized = await this.request('initialize', { protocolVersion, capabilities: {}, clientInfo: { name: 'firefox-broker-regression', version: '1.0.0' } });
    assert.equal(initialized.protocolVersion, '2025-03-26', 'server must negotiate its supported protocol version, not echo the client value');
    this.notify('notifications/initialized');
    return this;
  }
  async call(name, args = {}) {
    return this.request('tools/call', { name, arguments: args });
  }
  async text(name, args = {}) {
    const result = await this.call(name, args);
    assert.equal(result.isError, undefined, `${name} failed: ${result.content?.map(item => item.text || item.type).join(' ')}`);
    return result.content?.find(item => item.type === 'text')?.text ?? '';
  }
  async close(signal) {
    if (this.process.exitCode !== null || this.process.signalCode !== null) return;
    if (signal) this.process.kill(signal);
    else this.process.stdin.end();
    await waitForExit(this.process);
  }
}

function pngBytes(item) {
  assert.equal(item?.type, 'image', 'screenshot call must return an MCP image content item');
  assert.equal(item.mimeType, 'image/png');
  const data = Buffer.from(item.data, 'base64');
  assert.deepEqual([...data.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10], 'image response must contain PNG bytes');
  return data;
}
function firefoxMainPids() {
  const result = spawnSync('/bin/ps', ['-Ao', 'pid,ppid,command'], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.split('\n').filter(line => line.includes(brokerDir) && line.includes(nightly) && line.includes('--profile')).map(line => Number(line.trim().split(/\s+/, 1)[0])).filter(Number.isInteger);
}
function daemonPids() {
  const result = spawnSync('/bin/ps', ['-Ao', 'pid,ppid,command'], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.split('\n').filter(line => line.includes(brokerPath) && line.includes('--daemon')).map(line => Number(line.trim().split(/\s+/, 1)[0])).filter(Number.isInteger);
}
function htmlPage(title, marker, { cookie = false, persist = false } = {}) {
  const setup = cookie ? "document.cookie='brokerLogin=shared; Max-Age=3600; path=/'" : '';
  const content = persist ? '<pre id="cookie"></pre>' : `<main>${marker}</main><button id="action" onclick="document.querySelector('main').textContent='${marker}-CLICKED'">Click ${marker}</button>`;
  const readCookie = persist ? "document.querySelector('#cookie').textContent=document.cookie" : '';
  return `<!doctype html><title>${title}</title><body>${content}<script>${setup};${readCookie}</script></body>`;
}

try {
  assert.ok(await stat(nightly).then(info => info.isFile()).catch(() => false), `Firefox Nightly binary missing: ${nightly}`);
  await mkdir(localBin, { recursive: true, mode: 0o700 });
  await mkdir(brokerDir, { recursive: true, mode: 0o700 });
  const brokerSource = await readFile(join(source, 'broker.mjs.tmpl'), 'utf8');
  assert.ok(!brokerSource.includes('{{'), 'broker source unexpectedly contains an unrendered chezmoi template');
  const syntax = spawnSync(process.execPath, ['--check', '--input-type=module'], { input: brokerSource, encoding: 'utf8' });
  assert.equal(syntax.status, 0, `broker syntax check failed: ${syntax.stderr}`);
  await writeFile(brokerPath, brokerSource, { mode: 0o700 });
  await chmod(brokerPath, 0o700);
  await copyFile(join(source, 'package.json'), join(brokerDir, 'package.json'));
  await copyFile(join(source, 'package-lock.json'), join(brokerDir, 'package-lock.json'));
  await copyFile(join(repo, 'dot_local', 'bin', 'executable_firefox-mcp-broker'), launcherPath);
  await chmod(launcherPath, 0o700);
  await mkdir(launchdEnv.TMPDIR, { recursive: true, mode: 0o700 });
  await mkdir(clientEnv.TMPDIR, { recursive: true, mode: 0o700 });

  // Exercise the actual after-packages installer against this isolated target HOME.
  run('bash', [join(repo, '.chezmoiscripts', 'run_onchange_after_z-firefox-mcp.sh.tmpl')], launchdEnv);
  assert.ok(await stat(join(brokerDir, 'node_modules', '@mozilla', 'firefox-devtools-mcp', 'dist', 'index.js')));

  // The stdio adapter must report a missing daemon and exit even while stdin remains open.
  const absentClient = child('firefox-mcp-broker', [], clientEnv);
  const absentError = await new Promise((resolveError, rejectError) => {
    let errorText = '';
    const timer = setTimeout(() => rejectError(new Error('no-broker client hung with stdin open')), 5000);
    absentClient.stderr.on('data', chunk => { errorText += chunk; });
    absentClient.once('exit', (code, signal) => { clearTimeout(timer); resolveError({ code, signal, errorText }); });
  });
  assert.equal(absentError.code, 1, `unexpected no-daemon client exit: ${JSON.stringify(absentError)}`);
  assert.match(absentError.errorText, /Firefox broker unavailable/);
  console.log('PASS no-broker stdio client exits with code 1 while stdin remains open');

  // An abandoned inode without PID metadata is not a held kernel lock.
  await writeFile(lockPath, '', { mode: 0o600 });
  const pageServer = await new Promise(resolveServer => {
    const server = createServer((request, response) => {
      const route = new URL(request.url, 'http://localhost').pathname;
      const [title, marker, opts = {}] = route === '/a1' ? ['A1', 'OWNER_A1', { cookie: true }] : route === '/a2' ? ['A2', 'OWNER_A2'] : route === '/b1' ? ['B1', 'OWNER_B1'] : route === '/b2' ? ['B2', 'OWNER_B2'] : route === '/disconnect' ? ['Disconnect', 'OWNER_DISCONNECT'] : route === '/persist' ? ['Persist', '', { persist: true }] : ['Unknown', 'UNKNOWN'];
      response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      response.end(htmlPage(title, marker, opts));
    });
    server.listen(0, '127.0.0.1', () => resolveServer(server));
  });
  httpServer = pageServer;
  const address = pageServer.address();
  const baseUrl = `http://127.0.0.1:${address.port}`;

  // Match the LaunchAgent ProgramArguments exactly, racing two daemon starters.
  const daemons = [child('/usr/bin/env', ['node', brokerPath, '--daemon'], launchdEnv), child('/usr/bin/env', ['node', brokerPath, '--daemon'], launchdEnv)];
  const clients = [];
  let clientA;
  let clientB;
  try {
    await waitUntil(async () => {
      const socketReady = (await stat(socketPath).catch(() => null))?.isSocket();
      if (socketReady) return true;
      if (daemons.every(candidate => candidate.exitCode !== null)) throw new Error(`LaunchAgents exited: ${daemons.map(candidate => `${candidate.exitCode}: ${candidate.stderrText}`).join('\\n')}`);
      return false;
    }, 'LaunchAgent socket');
    let ownerPid = Number((await readFile(ownerPidPath, 'utf8')).trim());
    const loser = daemons.find(candidate => candidate.pid !== ownerPid);
    assert.ok(loser, 'expected one daemon to lose the startup race');
    const loserExit = await waitForExit(loser, 5000);
    assert.equal(loserExit.code, 1, 'concurrent duplicate daemon must fail closed');
    const daemonsAtStart = daemonPids();
    assert.equal(daemonsAtStart.length, 1, `expected one daemon owner, got ${daemonsAtStart.join(', ')}`);
    assert.equal(daemonsAtStart[0], ownerPid, 'owner lock PID must identify the only live daemon');
    assert.match(loser.stderrText, /Firefox broker is already running/, 'duplicate daemon must fail without disturbing the owner');
    const lockOwnerAfterRace = Number((await readFile(ownerPidPath, 'utf8')).trim());
    assert.equal(lockOwnerAfterRace, ownerPid, 'failed duplicate startup must preserve the live owner lock');
    assert.ok((await stat(socketPath)).isSocket(), 'failed duplicate startup must preserve the owner socket');
    console.log(`PASS concurrent LaunchAgent startup; owner PID ${ownerPid}, duplicate exited ${loserExit.code}, socket intact`);

    // SIGKILL leaves both socket and PID metadata behind; the kernel releases
    // the lock when the holder sees EOF. Race recovery against that stale state.
    const crashedOwner = daemons.find(candidate => candidate.pid === ownerPid);
    crashedOwner.kill('SIGKILL');
    assert.equal((await waitForExit(crashedOwner)).signal, 'SIGKILL');
    await waitUntil(() => spawnSync('/usr/bin/lockf', ['-k', '-t', '0', lockPath, '/usr/bin/true']).status === 0, 'crashed owner lock release');
    const replacements = [child('/usr/bin/env', ['node', brokerPath, '--daemon'], launchdEnv), child('/usr/bin/env', ['node', brokerPath, '--daemon'], launchdEnv)];
    daemons.push(...replacements);
    ownerPid = await waitUntil(async () => {
      const pid = Number((await readFile(ownerPidPath, 'utf8').catch(() => '')).trim());
      return replacements.some(candidate => candidate.pid === pid) ? pid : false;
    }, 'replacement owner PID');
    const recoveryLoser = replacements.find(candidate => candidate.pid !== ownerPid);
    assert.equal((await waitForExit(recoveryLoser, 5000)).code, 1);
    assert.match(recoveryLoser.stderrText, /Firefox broker is already running/);
    assert.deepEqual(daemonPids(), [ownerPid], 'simultaneous crash recovery must leave exactly one owner');
    console.log('PASS concurrent crash recovery preserves one kernel-lock owner and replaces stale PID/socket state');

    clientA = new McpClient(child('firefox-mcp-broker', [], clientEnv)); clients.push(clientA);
    clientB = new McpClient(child('firefox-mcp-broker', [], launchdEnv)); clients.push(clientB);
    const [readyA, readyB] = await Promise.all([clientA.start('2025-03-26'), clientB.start('2099-01-01')]);
    assert.equal(readyA, clientA); assert.equal(readyB, clientB);
    const definitions = await clientA.request('tools/list');
    const byName = new Map(definitions.tools.map(tool => [tool.name, tool]));
    assert.equal(byName.get('cleanup_session').annotations.readOnlyHint, false);
    assert.ok(byName.get('type_text').inputSchema.properties.uid);
    assert.ok(byName.get('screenshot_page').inputSchema.properties.saveTo);
    assert.ok(byName.get('screenshot_by_uid').inputSchema.properties.saveTo);
    console.log('PASS MCP stdio initialize/tools/list with protocol 2025-03-26 and broker tool schemas');

    // Use the installed OMP client, not just the test's raw MCP implementation.
    const ompAgent = join(home, '.config', 'omp', 'agent');
    await mkdir(ompAgent, { recursive: true, mode: 0o700 });
    await writeFile(join(ompAgent, 'config.yml'), 'startup:\n  setupWizard: false\n  quiet: true\nbrowser:\n  enabled: false\n  relay: false\n', { mode: 0o600 });
    await writeFile(join(ompAgent, 'mcp.json'), JSON.stringify({ mcpServers: { 'firefox-devtools': { command: 'firefox-mcp-broker', args: [], enabled: true } } }), { mode: 0o600 });
    const omp = child('omp', ['--mode', 'rpc', '--config', join(ompAgent, 'config.yml'), '--no-session', '--no-skills', '--no-rules', '--no-lsp', '--no-title'], {
      ...clientEnv, PI_CONFIG_DIR: '.config/omp', PI_CODING_AGENT_DIR: ompAgent,
    });
    try {
      const testOutput = await new Promise((resolveTest, rejectTest) => {
        let buffer = '';
        let output = '';
        const timer = setTimeout(() => rejectTest(new Error(`OMP MCP test timed out: ${output} ${omp.stderrText}`)), timeoutMs);
        omp.once('exit', code => { clearTimeout(timer); rejectTest(new Error(`OMP exited ${code}: ${omp.stderrText}`)); });
        omp.stdout.on('data', chunk => {
          buffer += chunk;
          for (let end; (end = buffer.indexOf('\n')) >= 0;) {
            const line = buffer.slice(0, end); buffer = buffer.slice(end + 1);
            let message; try { message = JSON.parse(line); } catch { continue; }
            if (message.type === 'command_output') output += JSON.stringify(message);
            if (message.id === 'broker-commands' && message.type === 'response') {
              const commands = message.data?.commands ?? message.data;
              if (!Array.isArray(commands) || !commands.some(command => command.name === 'mcp' && command.subcommands?.some(subcommand => subcommand.name === 'test'))) {
                clearTimeout(timer); rejectTest(new Error('Installed OMP does not expose the local /mcp test command'));
              } else {
                omp.stdin.write(JSON.stringify({ id: 'broker-test', type: 'prompt', message: '/mcp test firefox-devtools' }) + '\n');
              }
            }
            if (message.id === 'broker-test' && message.type === 'response') {
              clearTimeout(timer);
              if (message.success && message.data?.agentInvoked === false) resolveTest(output);
              else rejectTest(new Error(`OMP MCP test did not finish locally: ${JSON.stringify(message)}`));
            }
          }
        });
        omp.stdin.write(JSON.stringify({ id: 'broker-commands', type: 'get_available_commands' }) + '\n');
      });
      assert.match(testOutput, /cleanup_session/);
      console.log('PASS installed OMP /mcp test negotiates the broker stdio handshake and lists its tools');
    } finally {
      omp.stdin.end();
      const exit = await waitForExit(omp);
      assert.equal(exit.code, 0, omp.stderrText);
    }

    await clientA.text('new_page', { url: `${baseUrl}/a1` });
    await clientA.text('new_page', { url: `${baseUrl}/a2` });
    await clientB.text('new_page', { url: `${baseUrl}/b1` });
    assert.match(await clientA.text('list_pages'), /A1/);
    assert.match(await clientA.text('list_pages'), /A2/);
    assert.doesNotMatch(await clientA.text('list_pages'), /B1/);
    assert.match(await clientB.text('list_pages'), /B1/);
    assert.doesNotMatch(await clientB.text('list_pages'), /A1|A2/);

    await clientA.text('close_page', { pageIdx: 0 });
    assert.match(await clientA.text('list_pages'), /\[0\].*A2/);
    assert.match(await clientA.text('get_page_text'), /OWNER_A2/);
    assert.match(await clientB.text('get_page_text'), /OWNER_B1/);
    await clientA.text('select_page', { url: '/a2' });
    assert.match(await clientA.text('get_page_text'), /OWNER_A2/);
    console.log('PASS caller-only tab listing, close/renumber mapping, URL selection, and correct active-tab targeting');

    const snapshotA = await clientA.call('take_snapshot', { includeText: true, includeAttributes: true, maxDepth: 12 });
    assert.equal(snapshotA.isError, undefined, snapshotA.content?.[0]?.text);
    const uidA = snapshotA.content?.find(item => item.type === 'text')?.text.match(/(?:uid\s*[=:]\s*|\[uid=)([\w-]+)/i)?.[1];
    assert.ok(uidA, `could not extract A snapshot UID from: ${snapshotA.content?.[0]?.text}`);
    const crossUid = await clientB.call('click_by_uid', { uid: uidA });
    assert.equal(crossUid.isError, true, 'client B must reject A’s UID before its own snapshot');
    assert.match(crossUid.content?.[0]?.text ?? '', /UID was not issued to this client/);
    const snapshotB = await clientB.call('take_snapshot', { includeText: true });
    assert.equal(snapshotB.isError, undefined, snapshotB.content?.[0]?.text);
    const uidB = snapshotB.content?.find(item => item.type === 'text')?.text.match(/uid=([\w-]+) button\b/)?.[1];
    assert.ok(uidB, `could not extract B snapshot UID from: ${snapshotB.content?.[0]?.text}`);
    const elementScreenshot = await clientB.call('screenshot_by_uid', { uid: uidB });
    assert.equal(elementScreenshot.isError, undefined, elementScreenshot.content?.[0]?.text);
    pngBytes(elementScreenshot.content?.[0]);
    const pageScreenshot = await clientB.call('screenshot_page', {});
    assert.equal(pageScreenshot.isError, undefined, pageScreenshot.content?.[0]?.text);
    pngBytes(pageScreenshot.content?.[0]);
    const savedPageScreenshot = await clientB.text('screenshot_page', { saveTo: true });
    const savedPath = savedPageScreenshot.match(/Screenshot saved to: (.+)$/)?.[1];
    assert.ok(savedPath, savedPageScreenshot);
    const savedImage = await readFile(savedPath);
    assert.deepEqual([...savedImage.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
    await rm(savedPath, { force: true });
    const clicked = await clientB.call('click_by_uid', { uid: uidB });
    assert.equal(clicked.isError, undefined, clicked.content?.[0]?.text);
    assert.match(await clientB.text('get_page_text'), /OWNER_B1-CLICKED/, `UID ${uidB}; snapshot: ${snapshotB.content?.[0]?.text}`);
    console.log('PASS per-client UID enforcement, screenshot MCP image content, screenshot saveTo PNG, and own-UID interaction');

    await clientA.text('cleanup_session');
    assert.equal(await clientA.text('list_pages'), 'No tabs open.');
    assert.match(await clientB.text('get_page_text'), /OWNER_B1-CLICKED/);
    assert.equal(firefoxMainPids().length, 1);
    console.log('PASS cleanup_session closes only the caller’s tabs while another client retains its browser');

    await clientA.text('new_page', { url: `${baseUrl}/disconnect` });
    const aProcess = clientA.process;
    aProcess.kill('SIGTERM');
    const aExit = await waitForExit(aProcess);
    assert.equal(aExit.signal, 'SIGTERM');
    await delay(100);
    await clientB.text('new_page', { url: `${baseUrl}/b2` });
    assert.match(await clientB.text('get_page_text'), /OWNER_B2/);
    const pagesAfterDisconnect = await clientB.text('list_pages');
    assert.match(pagesAfterDisconnect, /B1/);
    assert.match(pagesAfterDisconnect, /B2/);
    assert.equal(daemonPids().length, 1);
    assert.equal(firefoxMainPids().length, 1, `expected one Firefox owner before cleanup, got ${firefoxMainPids()}`);
    console.log('PASS client disconnect cleans only its tabs and restores the surviving client’s browser context');

    const cleanupA = await clientB.text('cleanup_session');
    assert.match(cleanupA, /Closed this session/);
    await waitUntil(async () => firefoxMainPids().length === 0, 'Firefox exit after last-session cleanup');
    assert.equal(await clientB.text('list_pages'), 'No tabs open.');
    assert.equal(daemonPids().length, 1, 'idle MCP clients must not keep Firefox alive or stop the daemon');
    console.log('PASS cleanup_session closes owned tabs and exits Firefox while MCP client remains connected');

    await clientB.text('new_page', { url: `${baseUrl}/persist` });
    assert.match(await clientB.text('get_page_text'), /brokerLogin=shared/, 'lazy restart must reuse the persistent automation profile');
    assert.equal(firefoxMainPids().length, 1);
    console.log('PASS lazy browser restart reuses the persistent profile and login cookie');

    // Shutdown while a client owns a tab must still close the browser and release the socket/lock.
    const daemonProcess = daemons.find(candidate => candidate.pid === ownerPid);
    daemonProcess.kill('SIGTERM');
    const daemonExit = await waitForExit(daemonProcess);
    assert.deepEqual(daemonExit, { code: 0, signal: null }, 'SIGTERM should run the broker shutdown handler cleanly');
    await waitUntil(async () => firefoxMainPids().length === 0, 'Firefox exit after broker shutdown');
    await waitUntil(async () => !(await stat(socketPath).catch(() => null)), 'broker socket cleanup');
    await waitUntil(async () => !(await stat(ownerPidPath).catch(() => null)), 'owner PID cleanup');
    assert.equal(daemonPids().length, 0);
    assert.equal(spawnSync('/usr/bin/lockf', ['-k', '-t', '0', lockPath, '/usr/bin/true']).status, 0, 'shutdown must release the kernel lock without unlinking its inode');
    console.log('PASS broker shutdown cleans tabs, Firefox, socket, PID metadata, and releases the kernel lock');
  } finally {
    for (const client of clients) {
      if (client.process.exitCode === null && client.process.signalCode === null) await client.close().catch(() => {});
    }
    for (const daemon of daemons) {
      if (daemon.exitCode === null && daemon.signalCode === null) {
        daemon.kill('SIGTERM');
        await waitForExit(daemon).catch(() => {});
      }
    }
  }
} finally {
  if (httpServer?.listening) await new Promise(resolveClose => httpServer.close(resolveClose));
  for (const childProcess of children) {
    if (childProcess.exitCode === null && childProcess.signalCode === null) childProcess.kill('SIGTERM');
  }
  await delay(100);
  await rm(temp, { recursive: true, force: true });
}
