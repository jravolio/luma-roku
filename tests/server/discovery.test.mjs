import { test } from 'node:test';
import assert from 'node:assert/strict';
import dgram from 'node:dgram';
import { broadcastTargets, parseDiscoveryReply, discoverServers, probeLocalServers, subnetCandidates, DISCOVERY_MESSAGE } from '../../server/discovery.mjs';
import { normalizeServerUrl, mediaUrl, apiUrl } from '../../server/urls.mjs';

test('broadcasts use each home LAN IPv4 interface, correct netmask and bounded limited broadcast', () => {
  const targets = broadcastTargets({ en0: [{ family: 'IPv4', address: '192.168.5.9', netmask: '255.255.252.0', internal: false }],
    eth0: [{ family: 4, address: '10.8.1.5', netmask: '255.255.255.0', internal: false }],
    lo: [{ family: 'IPv4', address: '127.0.0.1', netmask: '255.0.0.0', internal: true }], v6: [{ family: 'IPv6', address: '::1', internal: false }] });
  assert.deepEqual(targets.map(t => [t.host, t.localAddress]), [['192.168.7.255', '192.168.5.9'], ['255.255.255.255', '192.168.5.9'], ['10.8.1.255', '10.8.1.5'], ['255.255.255.255', '10.8.1.5']]);
  assert.ok(targets.every(t => t.port === 7359));
});

test('automatic discovery skips Tailscale and VPN adapters without consuming the LAN probe budget', () => {
  const entry = (address, netmask = '255.255.255.0') => [{ family: 'IPv4', address, netmask, internal: false }];
  const interfaces = {
    utun6: entry('100.118.26.5', '255.255.255.255'),
    tailscale0: entry('100.100.1.2'),
    tun0: entry('10.8.0.2'),
    wg0: entry('10.9.0.2'),
    'WireGuard Tunnel': entry('10.10.0.2'),
    en0: entry('192.168.1.104'),
  };
  const targets = broadcastTargets(interfaces);
  assert.equal(targets.length, 2);
  assert.ok(targets.every(target => target.interface === 'en0' && target.localAddress === '192.168.1.104'));
  const candidates = subnetCandidates(interfaces);
  assert.equal(candidates.length, 253);
  assert.ok(candidates.every(url => url.startsWith('http://192.168.1.')));
});

test('reply parsing supports IPv6, base paths and null termination, rejects malformed or credential URLs', () => {
  const parsed = parseDiscoveryReply(Buffer.from('{"Id":"stable-id","Name":"Living room","Address":"http://[::1]:8096/jellyfin"}\0'));
  assert.deepEqual(parsed, { id: 'stable-id', name: 'Living room', url: 'http://[::1]:8096/jellyfin/' });
  for (const reply of ['nope', '{}', '{"Id":"valid","Address":"ftp://host"}', '{"Id":"bad id","Address":"http://host"}', '{"Id":"valid","Address":"http://user:secret@host"}']) {
    assert.throws(() => parseDiscoveryReply(Buffer.from(reply)));
  }
  assert.throws(() => parseDiscoveryReply(Buffer.alloc(8193)));
});

test('URLs preserve base paths and never allow external media or item escape', () => {
  assert.equal(normalizeServerUrl('http://localhost:8096/jellyfin///'), 'http://localhost:8096/jellyfin/');
  assert.equal(apiUrl('http://host/base/', 'System/Info/Public').href, 'http://host/base/System/Info/Public');
  for (const input of ['/Videos/id/main.m3u8?api_key=secret', '/base/Videos/id/main.m3u8?AccessToken=secret', 'http://host/base/Videos/id/main.m3u8?token=secret']) {
    assert.equal(mediaUrl('http://host/base/', input, 'Videos/id/').href, 'http://host/base/Videos/id/main.m3u8');
  }
  for (const input of ['http://evil/Videos/id/main.m3u8', '//evil/anything', '/Videos/id/../../System/Info', '/Videos/id/%2e%2e/anything', '/Videos/id/%2fanything', 'http://user:password@host/base/Videos/id/main.m3u8']) {
    assert.throws(() => mediaUrl('http://host/base/', input, 'Videos/id/'));
  }
  for (const input of ['file:///private', 'http://user:pw@host', 'http://host/?key=secret', 'http://host/#hash']) assert.throws(() => normalizeServerUrl(input));
});

test('media URLs accept equivalent compact and dashed GUIDs only inside the selected item and base path', () => {
  const id = '5c14a75749ebd89d90585009c1cd1840';
  const dashed = '5c14a757-49eb-d89d-9058-5009c1cd1840';
  const base = 'http://host:8096/jellyfin/';
  for (const path of [`/videos/${dashed}/master.m3u8?api_key=secret`, `/jellyfin/videos/${dashed.toUpperCase()}/hls1/main/0.ts`]) {
    const actual = mediaUrl(base, path, `Videos/${id}/`);
    assert.ok(actual.pathname.startsWith('/jellyfin/videos/'));
    assert.ok(actual.pathname.includes('-'));
    assert.ok(!actual.searchParams.has('api_key'));
  }
  assert.equal(mediaUrl(base, `/Videos/${id}/main.m3u8`, `videos/${dashed}/`).pathname, `/jellyfin/Videos/${id}/main.m3u8`);
  for (const path of [
    `/videos/5c14a757-49eb-d89d-9058-5009c1cd1841/master.m3u8`,
    `/videos/${dashed}extra/master.m3u8`,
    `/videos/5c14-a75749ebd89d90585009c1cd1840/master.m3u8`,
    `/videos/${dashed}/../another/master.m3u8`,
    `/videos/${dashed}/%2e%2e/another/master.m3u8`,
    `http://other:8096/jellyfin/videos/${dashed}/master.m3u8`,
  ]) assert.throws(() => mediaUrl(base, path, `Videos/${id}/`));
  assert.throws(() => mediaUrl(`http://host/${id}/`, `http://host/${dashed}/Videos/${id}/stream`, `Videos/${id}/`));
});

test('UDP retries, deduplication, multiple servers, malformed replies and advertised identity mismatch', async t => {
  const socket = dgram.createSocket('udp4');
  await new Promise(resolve => socket.bind(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => socket.close(resolve)));
  let probes = 0;
  socket.on('message', (msg, remote) => {
    assert.equal(msg.toString(), DISCOVERY_MESSAGE); probes++;
    for (const reply of [
      'malformed', { Id: 'one', Name: 'One', Address: 'http://127.0.0.1:8001/base' },
      { Id: 'two', Name: 'Two', Address: 'http://[::1]:8002/' },
      { Id: 'forged', Name: 'Forged', Address: 'http://127.0.0.1:8003/' },
    ]) socket.send(typeof reply === 'string' ? reply : JSON.stringify(reply), remote.port, remote.address);
  });
  const result = await discoverServers({ targets: [{ host: '127.0.0.1', port: socket.address().port }], attempts: 3, intervalMs: 15, timeoutMs: 80,
    verify: async url => ({ id: url.includes('8001') ? 'one' : url.includes('8002') ? 'two' : 'different', name: 'Verified', url }) });
  assert.equal(probes, 3);
  assert.equal(result.servers.length, 2);
  assert.ok(result.diagnostics.some(d => d.code === 'malformed_reply'));
  assert.ok(result.diagnostics.some(d => d.code === 'identity_mismatch'));
});

test('offline discovery finishes within the bounded deadline and IPv6-only networks explain manual fallback', async () => {
  const start = Date.now();
  const result = await discoverServers({ enableHttpFallback: false, targets: [{ host: '127.0.0.1', port: 9 }], attempts: 2, intervalMs: 10, timeoutMs: 40, verify: async () => assert.fail('No reply expected') });
  assert.ok(Date.now() - start < 1000);
  assert.equal(result.servers.length, 0);
  const noInterfaces = await discoverServers({ targets: [], interfaces: {}, verify: async () => {} });
  assert.ok(noInterfaces.diagnostics.some(d => d.code === 'no_ipv4_interfaces'));
});

test('HTTP fallback scans only local private subnets, caps broad networks to /24 and at most two interfaces', () => {
  const interfaces = {
    privateA: [{ family: 'IPv4', address: '10.20.30.40', netmask: '255.0.0.0', internal: false }],
    duplicate: [{ family: 'IPv4', address: '10.20.30.41', netmask: '255.255.255.0', internal: false }],
    privateB: [{ family: 'IPv4', address: '172.16.8.5', netmask: '255.255.255.0', internal: false }],
    third: [{ family: 'IPv4', address: '192.168.7.9', netmask: '255.255.255.0', internal: false }],
    public: [{ family: 'IPv4', address: '8.8.8.8', netmask: '255.255.255.0', internal: false }],
    loop: [{ family: 'IPv4', address: '127.0.0.1', netmask: '255.255.255.0', internal: true }],
    link: [{ family: 'IPv4', address: '169.254.8.9', netmask: '255.255.0.0', internal: false }],
  };
  const urls = subnetCandidates(interfaces, { url: 'https://old:8920/a/base/' });
  assert.equal(urls.length, 506); assert.ok(urls.every(value => value.startsWith('https://10.20.30.') || value.startsWith('https://172.16.8.')));
  assert.ok(urls.every(value => value.endsWith(':8920/a/base/')));
  assert.ok(!urls.includes('https://10.20.30.40:8920/a/base/'));
  assert.ok(!urls.some(value => value.includes('192.168.') || value.includes('8.8.8.8')));
  assert.equal(subnetCandidates({ test: [{ family: 'IPv4', address: '192.168.1.5', netmask: '255.255.255.252', internal: false }] }).length, 1);
});

test('HTTP fallback is concurrency-bounded, deadline-bounded and filters stable identity', async () => {
  let active = 0, maxActive = 0;
  const result = await probeLocalServers({ interfaces: { en: [{ family: 'IPv4', address: '10.99.0.3', netmask: '255.255.255.248', internal: false }] },
    expectedServerId: 'wanted', concurrency: 2, budgetMs: 500, verify: async (url, options) => {
      active++; maxActive = Math.max(maxActive, active);
      assert.ok(options.timeoutMs <= 650); assert.ok(options.signal);
      await new Promise(resolve => setTimeout(resolve, 5)); active--;
      return { id: url.includes('10.99.0.2:') ? 'wanted' : 'other', name: 'Server', url };
    } });
  assert.ok(maxActive <= 2); assert.equal(result.servers.length, 1); assert.equal(result.servers[0].id, 'wanted');
  assert.ok(result.diagnostics[0].probed <= 5);
  const started = Date.now();
  const offline = await probeLocalServers({ interfaces: { en: [{ family: 'IPv4', address: '192.168.99.3', netmask: '255.255.255.0', internal: false }] },
    budgetMs: 35, concurrency: 2, verify: async (_url, options) => {
      await new Promise((resolve, reject) => { const timer = setTimeout(resolve, options.timeoutMs); options.signal.addEventListener('abort', () => { clearTimeout(timer); reject(new Error('deadline')); }, { once: true }); });
      throw new Error('offline');
    } });
  assert.ok(Date.now() - started < 150); assert.equal(offline.servers.length, 0);
});
