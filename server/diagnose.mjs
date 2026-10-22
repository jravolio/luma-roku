import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { JellyfinGateway } from './jellyfin.mjs';
import { broadcastTargets } from './discovery.mjs';

// Discovery only: intentionally does not read or create the saved session.
const gateway = new JellyfinGateway();
gateway.state = { deviceId: 'discovery-diagnostic' };
const targets = broadcastTargets();
const result = { checkedAt: new Date().toISOString(), credentialsUsed: false, targets, ...await gateway.discover() };
const output = process.argv[2] ? resolve(process.argv[2]) : fileURLToPath(new URL('../.local/lan-diagnostic.json', import.meta.url));
await mkdir(dirname(output), { recursive: true, mode: 0o700 });
await writeFile(output, JSON.stringify(result, null, 2) + '\n', { mode: 0o600 });
console.log(JSON.stringify(result, null, 2));
