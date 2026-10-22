import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const entry = ['server/index.mjs', 'server/index.js', 'server/main.mjs'].find(file => existsSync(path.join(root, file)));
if (!entry || !existsSync(path.join(root, 'preview/node_modules'))) {
  console.error('Install dependencies first: npm install && npm --prefix preview install');
  if (!entry) console.error('The local gateway entry point is missing.');
  process.exit(1);
}

const children = [];
let stopping = false;
function stop(code = 0) {
  if (stopping) return;
  stopping = true;
  for (const child of children) {
    try {
      if (process.platform === 'win32') child.kill('SIGTERM');
      else process.kill(-child.pid, 'SIGTERM');
    } catch { /* Already exited. */ }
  }
  process.exitCode = code;
}
function launch(command, args) {
  const child = spawn(command, args, { cwd: root, stdio: 'inherit', detached: process.platform !== 'win32' });
  children.push(child);
  child.on('error', error => { console.error(error.message); stop(1); });
  child.on('exit', code => { if (!stopping) stop(code || 0); });
}
process.on('SIGINT', () => stop());
process.on('SIGTERM', () => stop());
launch(process.execPath, [entry]);
launch(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['--prefix', 'preview', 'run', 'dev']);
