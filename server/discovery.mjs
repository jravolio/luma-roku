import dgram from 'node:dgram';
import { networkInterfaces } from 'node:os';
import { normalizeServerUrl } from './urls.mjs';
import { identifier } from './errors.mjs';

export const DISCOVERY_MESSAGE = 'who is JellyfinServer?';

const ipv4 = value => /^\d{1,3}(?:\.\d{1,3}){3}$/.test(value) && value.split('.').every(o => Number(o) <= 255);
const privateAddress = value => {
  if (!ipv4(value)) return false;
  const [a, b] = value.split('.').map(Number);
  return a === 10 || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168);
};
const numberIp = value => value.split('.').reduce((acc, octet) => ((acc << 8) | Number(octet)) >>> 0, 0);

// Automatic discovery is for the home LAN. Tunnel adapters can consume the
// bounded probe budget or generate unsupported broadcast errors. A deliberate
// manual URL (including a VPN address) remains available through connect().
const tunnelInterface = /^(?:utun|tun\d*|tap\d*|tailscale|wg\d*|wireguard|ppp|ipsec|vpn)(?:\b|\d)/i;
const lanIPv4 = (name, entry) => !tunnelInterface.test(name) && !entry.internal
  && ['IPv4', 4].includes(entry.family) && privateAddress(entry.address) && ipv4(entry.netmask);

export function subnetCandidates(interfaces = networkInterfaces(), cachedServer) {
  const candidates = new Set();
  const networks = new Set();
  const template = new URL(normalizeServerUrl(cachedServer?.url ?? 'http://localhost:8096/'));
  for (const [name, entries] of Object.entries(interfaces)) {
    for (const entry of entries ?? []) {
      if (!lanIPv4(name, entry)) continue;
      const prefix = entry.address.split('.').slice(0, 3).join('.');
      if (networks.has(prefix) || networks.size >= 2) continue;
      networks.add(prefix);
      const mask = numberIp(entry.netmask), local = numberIp(entry.address);
      const network = (local & mask) >>> 0, broadcast = (network | (~mask >>> 0)) >>> 0;
      for (let host = 1; host <= 254; host++) {
        const address = `${prefix}.${host}`, candidate = numberIp(address);
        if (candidate === local || candidate <= network || candidate >= broadcast || ((candidate & mask) >>> 0) !== network) continue;
        const url = new URL(template); url.hostname = address;
        candidates.add(url.href);
      }
    }
  }
  return [...candidates];
}

export async function probeLocalServers({ verify, interfaces, cachedServer, expectedServerId, budgetMs = 13000, probeTimeoutMs = 650, concurrency = 24 } = {}) {
  const candidates = subnetCandidates(interfaces, cachedServer);
  const started = Date.now();
  budgetMs = Math.max(20, Math.min(13000, budgetMs));
  probeTimeoutMs = Math.max(10, Math.min(800, probeTimeoutMs));
  concurrency = Math.max(1, Math.min(24, concurrency));
  const deadline = started + budgetMs;
  const signal = AbortSignal.timeout(budgetMs);
  const servers = new Map();
  let index = 0, probed = 0;
  await Promise.all(Array.from({ length: Math.min(concurrency, candidates.length) }, async () => {
    while (index < candidates.length && Date.now() < deadline && !(expectedServerId && servers.has(expectedServerId))) {
      const url = candidates[index++]; probed++;
      try {
        const server = await verify(url, { timeoutMs: Math.min(probeTimeoutMs, Math.max(1, deadline - Date.now())), signal });
        if (!expectedServerId || server.id === expectedServerId) servers.set(server.id, server);
      } catch { /* A closed port or another product is normal during bounded LAN probing. */ }
    }
  }));
  return { servers: [...servers.values()], diagnostics: [{ code: 'http_probe_summary', candidates: candidates.length, probed, verified: servers.size, elapsedMs: Date.now() - started, bounded: true }] };
}

export function broadcastTargets(interfaces = networkInterfaces()) {
  const targets = [];
  for (const [name, entries] of Object.entries(interfaces)) {
    for (const entry of entries ?? []) {
      if (!lanIPv4(name, entry)) continue;
      const ip = entry.address.split('.').map(Number);
      const mask = entry.netmask.split('.').map(Number);
      const address = ip.map((octet, i) => (octet | (~mask[i] & 255))).join('.');
      for (const host of new Set([address, '255.255.255.255'])) {
        targets.push({ host, port: 7359, localAddress: entry.address, interface: name });
      }
    }
  }
  return targets;
}

export function parseDiscoveryReply(buffer) {
  if (buffer.length > 8192) throw new Error('Reply too large.');
  const reply = JSON.parse(buffer.toString('utf8').replace(/\0+$/, ''));
  return { id: identifier(reply.Id), name: typeof reply.Name === 'string' ? reply.Name.slice(0, 256) : 'Jellyfin', url: normalizeServerUrl(reply.Address) };
}

export async function discoverServers({ verify, targets = broadcastTargets(), attempts = 3, intervalMs = 250, timeoutMs = 1100,
  enableHttpFallback = true, interfaces, cachedServer, expectedServerId, probeOptions = {}, budgetMs = 14500 } = {}) {
  if (typeof verify !== 'function') throw new Error('Discovery requires identity verification.');
  attempts = Math.max(1, Math.min(5, attempts));
  timeoutMs = Math.max(20, Math.min(5000, timeoutMs));
  intervalMs = Math.max(10, Math.min(timeoutMs, intervalMs));
  budgetMs = Math.max(timeoutMs, Math.min(14500, budgetMs));
  const deadline = Date.now() + budgetMs;
  const signal = AbortSignal.timeout(budgetMs);
  const diagnostics = [];
  const note = (code, detail) => { if (diagnostics.length < 64) diagnostics.push({ code, ...detail }); };
  const candidates = new Map();
  const groups = Map.groupBy(targets.slice(0, 64), t => t.localAddress ?? '0.0.0.0');
  if (!groups.size) note('no_ipv4_interfaces', { message: 'No IPv4 broadcast interface. IPv6 servers can be connected using a manual URL.' });
  await Promise.all([...groups].map(([localAddress, destinations]) => new Promise(resolve => {
    const socket = dgram.createSocket('udp4');
    const timers = [];
    let finished = false;
    const finish = () => {
      if (finished) return;
      finished = true;
      timers.forEach(clearTimeout);
      try { socket.close(); } catch { /* Unbound socket. */ }
      resolve();
    };
    socket.on('error', error => { note('udp_error', { interface: destinations[0].interface, message: error.code ?? 'UDP failure' }); finish(); });
    socket.on('message', message => {
      try {
        const candidate = parseDiscoveryReply(message);
        if (candidates.size < 32) candidates.set(`${candidate.id}:${candidate.url}`, candidate);
      } catch { note('malformed_reply', { message: 'Ignored malformed discovery reply.' }); }
    });
    timers.push(setTimeout(finish, timeoutMs));
    socket.bind(0, localAddress, () => {
      try { socket.setBroadcast(true); } catch { note('broadcast_unavailable', {}); finish(); return; }
      const send = () => {
        if (finished) return;
        for (const target of destinations) socket.send(DISCOVERY_MESSAGE, target.port, target.host, error => {
          if (error) note('send_failed', { host: target.host, message: error.code ?? 'UDP failure' });
        });
      };
      send();
      for (let attempt = 1; attempt < attempts; attempt++) timers.push(setTimeout(send, intervalMs * attempt));
    });
  })));
  const servers = new Map();
  const pending = [...candidates.values()];
  await Promise.all(Array.from({ length: Math.min(4, pending.length) }, async () => {
    while (pending.length && Date.now() < deadline) {
      const candidate = pending.shift();
      try {
        const server = await verify(candidate.url, { timeoutMs: Math.min(650, Math.max(1, deadline - Date.now())), signal });
        if (server.id !== candidate.id) { note('identity_mismatch', { url: candidate.url }); continue; }
        if (!servers.has(server.id)) servers.set(server.id, server);
      } catch (error) { note('verification_failed', { url: candidate.url, reason: error.code ?? 'unreachable' }); }
    }
  }));
  if (Date.now() < deadline && enableHttpFallback && (!servers.size || (expectedServerId && !servers.has(expectedServerId)))) {
    const fallback = await probeLocalServers({ ...probeOptions, budgetMs: Math.min(probeOptions.budgetMs ?? 13000, deadline - Date.now()), verify, interfaces, cachedServer, expectedServerId });
    for (const server of fallback.servers) servers.set(server.id, server);
    fallback.diagnostics.forEach(diagnostic => note(diagnostic.code, diagnostic));
  }
  if (!servers.size) note('no_servers', { message: 'No verified server responded to UDP or bounded local HTTP probing. Use a manual URL.' });
  return { servers: [...servers.values()].sort((a, b) => a.name.localeCompare(b.name)), diagnostics };
}
