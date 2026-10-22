import { createHash, randomBytes } from 'node:crypto';
import { createReadStream, createWriteStream, existsSync, openSync, closeSync } from 'node:fs';
import { mkdir, readFile, writeFile, chmod, rename } from 'node:fs/promises';
import { spawn, spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { setTimeout as delay } from 'node:timers/promises';

// Official upstream macOS release, pinned and checked against its published digest.
const version = '2.6.2';
const digest = 'd782fffc7290020b96301d5c096e61dd9db0f0b15bbd0b8186b2457fd2dd34d5';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const tools = resolve(root, '.local/tools/brs-desktop');
const state = resolve(root, '.local/roku-simulator');
const profile = resolve(state, 'profile');
const archive = resolve(tools, `brs-desktop-${version}-macOS.zip`);
const binary = resolve(tools, `v${version}/BrightScript Simulator.app/Contents/MacOS/BrightScript Simulator`);
const zip = resolve(root, 'dist/luma.zip');
const ecp = 'http://127.0.0.1:8060';

async function request(path, method = 'GET') {
  const response = await fetch(ecp + path, { method, signal: AbortSignal.timeout(2000) });
  if (!response.ok) throw new Error(`Simulator ECP returned HTTP ${response.status}`);
  return response.text();
}

async function current() {
  try {
    const info = await request('/query/device-info');
    if (!info.includes('<keyed-developer-id>luma-local-simulator</keyed-developer-id>')) {
      throw new Error('Port 8060 belongs to another device/profile; leaving it untouched.');
    }
    return { info, active: await request('/query/active-app') };
  } catch (error) {
    if (error.message.includes('leaving it untouched')) throw error;
    return null;
  }
}

function report(device) {
  console.log('Native Roku simulator is running.');
  console.log('Remote screen and controls: http://127.0.0.1:8090/');
  console.log('Display: 1080p; reported model: G510X (identity only, not hardware emulation).');
  console.log(`Active channel: ${device.active.includes('>Luma</app>') ? 'Luma' : 'none — rerun npm run simulate:roku'}`);
  console.log('Use arrows, Enter/OK and Escape/Back. The desktop window provides sound; the web viewer is video-only.');
  console.log('Known discovery/resume limitations and TV checklist: docs/roku-simulator.md');
}

async function install() {
  await mkdir(tools, { recursive: true });
  if (!existsSync(archive)) {
    console.log(`Downloading official BrightScript Simulator ${version} (about 236 MB)…`);
    const response = await fetch(`https://github.com/lvcabral/brs-desktop/releases/download/v${version}/brs-desktop-${version}-macOS.zip`, {
      signal: AbortSignal.timeout(300_000),
    });
    if (!response.ok || !response.body) throw new Error(`Download failed: HTTP ${response.status}`);
    await pipeline(Readable.fromWeb(response.body), createWriteStream(archive + '.part', { mode: 0o600 }));
    await rename(archive + '.part', archive);
  }
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(archive)) hash.update(chunk);
  if (hash.digest('hex') !== digest) throw new Error(`Simulator archive checksum mismatch. Do not run it: ${archive}`);
  if (!existsSync(binary)) {
    const result = spawnSync('ditto', ['-xk', archive, resolve(tools, `v${version}`)], { stdio: 'inherit' });
    if (result.status !== 0) throw new Error('Could not extract the simulator archive.');
  }
}

async function start() {
  if (process.platform !== 'darwin') throw new Error('This local launcher currently supports macOS. See docs/roku-simulator.md for upstream alternatives.');
  if (!existsSync(zip)) throw new Error('Build the native ZIP first: npm run build:roku');
  await install();
  await mkdir(profile, { recursive: true, mode: 0o700 });
  await chmod(state, 0o700);
  await chmod(profile, 0o700);
  const settings = resolve(profile, 'brs-settings.json');
  if (!existsSync(settings)) {
    await writeFile(settings, JSON.stringify({
      simulator: { options: ['statusBar', 'debugOnCrash'] },
      services: { installer: ['enabled'], webPort: 8070, password: randomBytes(24).toString('base64url'),
        ecp: ['enabled'], telnet: ['enabled'], debug: ['enabled'], screen: ['enabled'], remoteAccess: [] },
      device: { deviceModel: 'G510X', developerId: 'luma-local-simulator' },
      display: { displayMode: '1080p', overscanMode: 'disabled', maxFps: 60, options: [] },
      localization: { locale: 'pt_BR', countryCode: 'BR', clockFormat: '24h', timeZone: 'system' },
    }, null, 2), { mode: 0o600 });
  } else {
    const config = JSON.parse(await readFile(settings, 'utf8'));
    if (config.device?.developerId !== 'luma-local-simulator' || config.services?.remoteAccess?.length !== 0) {
      throw new Error('Expected the isolated, localhost-only Luma simulator profile. Check its settings before launching.');
    }
  }
  const env = { ...process.env };
  delete env.ELECTRON_RUN_AS_NODE;
  // --debug is consumed by Electron as an obsolete Node switch. Enable it in settings instead.
  const log = openSync(resolve(state, 'simulator.log'), 'a', 0o600);
  const child = spawn(binary, [`--user-data-dir=${profile}`, '--mode=fhd', '--ecp', '--rc', '--screen', '--web=8070', zip], {
    cwd: root, env, detached: true, stdio: ['ignore', log, log],
  });
  closeSync(log);
  await new Promise((resolveSpawn, reject) => { child.once('spawn', resolveSpawn); child.once('error', reject); });
  child.unref();
  await writeFile(resolve(state, 'process.json'), JSON.stringify({ pid: child.pid, binary, profile }), { mode: 0o600 });
  for (let attempt = 0; attempt < 30; attempt++) {
    await delay(500);
    const device = await current();
    if (device?.active.includes('>Luma</app>')) return device;
  }
  throw new Error('Simulator did not finish loading Luma. Inspect .local/roku-simulator/simulator.log or the desktop window.');
}

async function main() {
  const command = process.argv[2] ?? 'start';
  if (!['start', 'status'].includes(command)) throw new Error('Usage: node scripts/roku-simulator.mjs [start|status]');
  let device = await current();
  if (command === 'status') {
    if (!device) throw new Error('Luma simulator is not running. Use npm run simulate:roku.');
    report(device);
    return;
  }
  if (device) {
    // Only relaunch the single Luma channel in our isolated simulator profile.
    const apps = await request('/query/apps');
    const appId = [...apps.matchAll(/<app\b[^>]*id="(\d+)"[^>]*>Luma<\/app>/g)].map(match => match[1]);
    if (appId.length !== 1) throw new Error('Cannot identify one Luma channel. Open dist/luma.zip in the simulator window.');
    if (device.active.includes('>Luma</app>')) {
      await request(`/exit-app/${appId[0]}`, 'POST');
      // ECP acknowledges before the worker exits. Launching in that gap can
      // be overtaken by the delayed Home transition and silently lose Luma.
      let exited = false;
      for (let attempt = 0; attempt < 30; attempt++) {
        await delay(250);
        const active = await request('/query/active-app');
        if (!active.includes('>Luma</app>')) { exited = true; break; }
      }
      if (!exited) throw new Error('Luma has not finished exiting; leaving the simulator untouched.');
      await delay(500);
    }
    await request(`/launch/${appId[0]}`, 'POST');
    for (let attempt = 0; attempt < 30; attempt++) {
      await delay(500);
      device = await current();
      if (device?.active.includes('>Luma</app>')) break;
    }
    if (!device?.active.includes('>Luma</app>')) throw new Error('Simulator did not finish reloading Luma; inspect its desktop window.');
  } else device = await start();
  if (device) report(device);
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
