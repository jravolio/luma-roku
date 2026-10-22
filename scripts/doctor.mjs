import os from 'node:os';
import { existsSync } from 'node:fs';

console.log('Luma local development check');
console.log(`Node ${process.version} (${Number(process.versions.node.split('.')[0]) >= 24 ? 'supported' : 'upgrade to Node 24+'})`);
for (const file of ['node_modules/brighterscript/package.json', 'preview/node_modules/vite/package.json']) {
  console.log(`${existsSync(file) ? 'OK' : 'MISSING'} ${file}`);
}
const interfaces = Object.entries(os.networkInterfaces()).flatMap(([name, addresses]) =>
  addresses.filter(address => address.family === 'IPv4' && !address.internal)
    .map(address => `${name}: ${address.address} / ${address.netmask}`));
console.log(`Network interfaces: ${interfaces.join(', ') || 'none'}`);
for (const url of ['http://127.0.0.1:5173', 'http://127.0.0.1:3333/api/session']) {
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(3000) });
    console.log(`${response.ok ? 'OK' : 'HTTP ' + response.status} ${url}`);
  } catch {
    console.log(`NOT RUNNING ${url} — start with npm run dev`);
  }
}
console.log('Discovery uses UDP 7359, with a bounded local HTTP fallback. The Jellyfin PC must be on the same LAN with its HTTP port reachable.');
