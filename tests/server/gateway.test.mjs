import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, stat, readdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import http from 'node:http';
import { createGateway } from '../../server/index.mjs';
import { SessionStore } from '../../server/store.mjs';
import { createFixture, SERVER_ID, USER_ID, MOVIE_ID, SERIES_ID, SEASON_ID, SOURCE_ID, TOKEN } from './fixture.mjs';

async function setup(t, options = {}) {
  const fixture = await createFixture(options);
  t.after(() => fixture.close());
  const dir = await mkdtemp(join(tmpdir(), 'jellyfin-gateway-test-'));
  const path = join(dir, '.local', 'session.json');
  const opts = { port: 0, store: new SessionStore(path), timeoutMs: 300,
    discoveryOptions: { enableHttpFallback: false, targets: [{ host: '127.0.0.1', port: fixture.udpPort }], attempts: 2, intervalMs: 10, timeoutMs: 40 } };
  const gateway = await createGateway(opts);
  t.after(() => gateway.close());
  const call = async (route, body, extra = {}) => {
    const response = await fetch(gateway.url + route, { ...(body === undefined ? {} : { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }), ...extra });
    return { status: response.status, data: await response.json(), response };
  };
  const login = async () => {
    assert.equal((await call('/api/connect', { url: fixture.url })).status, 200);
    const result = await call('/api/login', { serverId: SERVER_ID, username: 'demo', password: 'demo' });
    assert.equal(result.status, 200); assert.equal(result.data.connected, true); return result;
  };
  return { fixture, gateway, opts, path, call, login };
}

test('session contract, discovery and manual connection preserve base paths; login saves credentials for silent sign-in', async t => {
  const { call, login, fixture, path } = await setup(t);
  assert.equal((await call('/api/session')).data.reason, 'login_required');
  const discovery = await call('/api/discover', {});
  assert.equal(discovery.data.servers[0].id, SERVER_ID);
  assert.equal(discovery.data.servers[0].url, fixture.url);
  const loggedIn = (await login()).data;
  assert.deepEqual(loggedIn.user, { id: USER_ID, name: 'Demo Viewer' });
  assert.ok(!JSON.stringify(loggedIn).includes(TOKEN));
  const stored = JSON.parse(await readFile(path, 'utf8'));
  assert.equal(stored.account.serverId, SERVER_ID); assert.equal(stored.account.userId, USER_ID);
  assert.equal(stored.account.token, TOKEN);
  assert.equal(stored.account.username, 'demo'); assert.equal(stored.account.password, 'demo'); assert.ok(!JSON.stringify(stored).includes('Pw'));
  assert.equal((await stat(path)).mode & 0o777, 0o600);
  assert.equal((await stat(join(path, '..'))).mode & 0o777, 0o700);
  assert.deepEqual(await readdir(join(path, '..')), ['session.json']);
  assert.ok(fixture.state.requests.filter(r => r.path.endsWith('/System/Info/Public')).every(r => !r.token));
});

test('saved account recovers after an HTTP address move and process restart without logging in again', async t => {
  const { login, fixture, gateway, opts, path } = await setup(t);
  await login();
  const deviceId = gateway.service.state.deviceId;
  const oldUrl = fixture.url;
  await fixture.move();
  assert.notEqual(fixture.url, oldUrl);
  const restarted = await createGateway(opts); t.after(() => restarted.close());
  const response = await fetch(restarted.url + '/api/session');
  const session = await response.json();
  assert.equal(session.connected, true); assert.equal(session.server.url, fixture.url);
  assert.equal(fixture.state.loginCount, 1); assert.equal(restarted.service.state.deviceId, deviceId);
  assert.equal(JSON.parse(await readFile(path, 'utf8')).account.url, fixture.url);
});

test('old address reused by another server never receives the saved token; stable server is rediscovered', async t => {
  const { login, fixture, call } = await setup(t);
  await login(); fixture.state.requests.length = 0;
  await fixture.move({ wrongAtOld: true });
  const session = (await call('/api/session')).data;
  assert.equal(session.connected, true); assert.equal(session.server.url, fixture.url);
  const wrongRequests = fixture.state.requests.filter(r => r.identity === 'wrong-server-id');
  assert.ok(wrongRequests.length);
  assert.ok(wrongRequests.every(r => !r.token && r.path.endsWith('/System/Info/Public')));
  assert.equal(fixture.state.loginCount, 1);
});

test('wrong server with no matching discovery reply does not receive token or erase account', async t => {
  const { login, fixture, call, path } = await setup(t);
  await login(); const before = await readFile(path, 'utf8');
  fixture.state.id = 'other-stable-server'; fixture.state.requests.length = 0;
  const session = (await call('/api/session')).data;
  assert.equal(session.connected, false); assert.equal(session.reason, 'identity_mismatch');
  assert.equal(await readFile(path, 'utf8'), before);
  assert.ok(fixture.state.requests.every(r => !r.token));
});

test('offline and temporary server errors preserve credentials byte-for-byte, reconnect automatically', async t => {
  const { login, fixture, call, path } = await setup(t);
  await login(); const before = await readFile(path, 'utf8');
  await fixture.offline();
  const disconnected = (await call('/api/session')).data;
  assert.equal(disconnected.connected, false); assert.equal(disconnected.reason, 'offline');
  assert.deepEqual(disconnected.user, { id: USER_ID, name: 'Demo Viewer' });
  assert.equal(await readFile(path, 'utf8'), before);
  await fixture.online(); fixture.state.unavailable = true;
  assert.equal((await call('/api/session')).data.connected, false);
  assert.equal(await readFile(path, 'utf8'), before);
  fixture.state.unavailable = false;
  assert.equal((await call('/api/session')).data.connected, true); assert.equal(fixture.state.loginCount, 1);
});

test('revoked token reauthenticates with saved credentials after checking server identity', async t => {
  const { login, fixture, call, path, gateway } = await setup(t);
  await login(); const deviceId = gateway.service.state.deviceId;
  fixture.state.revoked = true;
  assert.equal((await call('/api/session')).data.connected, true);
  const saved = JSON.parse(await readFile(path, 'utf8'));
  assert.equal(saved.account.token, TOKEN); assert.equal(saved.account.serverId, SERVER_ID); assert.equal(saved.account.userId, USER_ID); assert.equal(saved.deviceId, deviceId);
  assert.equal(saved.account.username, 'demo'); assert.equal(saved.account.password, 'demo');
  assert.equal(fixture.state.loginCount, 2);
});

test('item 401 retries once after reauthentication and permission 403 stays forbidden', async t => {
  const { login, fixture, call, path } = await setup(t); await login(); const before = await readFile(path, 'utf8');
  fixture.state.unauthorizedItems = true;
  const requestCount = fixture.state.requests.length;
  assert.equal((await call('/api/items')).status, 401);
  assert.equal(fixture.state.loginCount, 2);
  assert.ok(fixture.state.requests.length >= requestCount + 4, 'identity check, reauth, and one retry reached Jellyfin');
  fixture.state.unauthorizedItems = false; fixture.state.denyItems = true;
  const afterRetry = await readFile(path, 'utf8');
  assert.equal((await call('/api/items')).status, 403);
  assert.equal(await readFile(path, 'utf8'), afterRetry);
});

test('a failed login or selecting another server keeps the existing saved account', async t => {
  const { login, fixture, call, path } = await setup(t); await login(); const before = await readFile(path, 'utf8');
  assert.equal((await call('/api/login', { serverId: SERVER_ID, username: 'demo', password: 'wrong' })).data.error.code, 'invalid_credentials');
  assert.equal(await readFile(path, 'utf8'), before);
  const other = await createFixture({ id: 'different-server' }); t.after(() => other.close());
  assert.equal((await call('/api/connect', { url: other.url })).status, 200);
  assert.equal((await call('/api/session')).data.reason, 'login_required');
  assert.equal(await readFile(path, 'utf8'), before);
  assert.ok(other.state.requests.every(r => !r.token));
  await call('/api/connect', { url: fixture.url });
  assert.equal((await call('/api/session')).data.connected, true);
});

test('HLS playback accepts Jellyfin dashed UUID stream paths and proxies nested media for the same item', async t => {
  const itemId = '5c14a75749ebd89d90585009c1cd1840';
  const { login, call, fixture, gateway } = await setup(t, { items: [{ Id: itemId, Name: 'GUID fixture', Type: 'Movie' }] });
  fixture.state.hyphenatedMediaIds = true;
  await login();
  const response = await call(`/api/playback/${itemId}`, {});
  assert.equal(response.status, 200);
  const playback = response.data;
  const masterResponse = await fetch(gateway.url + playback.url);
  assert.equal(masterResponse.status, 200);
  const master = await masterResponse.text();
  const variant = master.split('\n').find(line => line.startsWith('/api/media/'));
  const variantResponse = await fetch(gateway.url + variant);
  assert.equal(variantResponse.status, 200);
  const playlist = await variantResponse.text();
  const segment = playlist.split('\n').find(line => line.startsWith('/api/media/'));
  const segmentResponse = await fetch(gateway.url + segment);
  assert.equal(segmentResponse.status, 200);
  assert.ok((await segmentResponse.arrayBuffer()).byteLength > 0);
  assert.equal((await fetch(gateway.url + playback.subtitles[0].url)).status, 200);
  assert.ok(!JSON.stringify(playback).includes(TOKEN));
  assert.ok(!master.includes(TOKEN)); assert.ok(!playlist.includes(TOKEN));
  assert.ok(fixture.state.requests.some(request => request.path.includes('/5c14a757-49eb-d89d-9058-5009c1cd1840/')));
});

test('home, search, item detail, season/episode children normalize metadata and opaque local images', async t => {
  const { login, call, gateway, fixture } = await setup(t); await login();
  const home = (await call('/api/home')).data;
  assert.equal(home.resume[0].id, MOVIE_ID); assert.equal(home.movies[0].type, 'Movie'); assert.equal(home.series[0].type, 'Series');
  const movie = (await call(`/api/items/${MOVIE_ID}`)).data.item;
  assert.equal(movie.positionTicks, 10_000_000); assert.equal(movie.year, 2026); assert.equal(movie.rating, 8.5);
  assert.match(movie.poster, /^\/api\/media\//); assert.match(movie.backdrop, /^\/api\/media\//);
  assert.ok(!JSON.stringify(home).includes(TOKEN));
  assert.equal((await fetch(gateway.url + movie.poster)).headers.get('content-type'), 'image/svg+xml');
  assert.equal((await call('/api/items?type=Movie&search=Test')).data.items.length, 1);
  assert.equal((await call('/api/items?search=not-found')).data.items.length, 0);
  assert.equal((await call(`/api/items/${SERIES_ID}/children`)).data.items[0].id, SEASON_ID);
  assert.equal((await call(`/api/items/${SEASON_ID}/children`)).data.items[0].type, 'Episode');
  // Lists never ask Jellyfin for MediaSources: the item mapper does not read it and it dominated page size.
  const listRequests = fixture.state.requests.filter(request => request.path.endsWith('/Items') || request.path.endsWith('/Items/Latest') || request.path.endsWith('/UserItems/Resume'));
  assert.ok(listRequests.length >= 4);
  assert.ok(listRequests.every(request => !String(request.query.fields ?? request.query.Fields ?? '').includes('MediaSources')));
});

test('default item pages traverse a library beyond 100 without omissions or duplicates', async t => {
  const items = Array.from({ length: 237 }, (_, index) => ({ Id: `movie-${index}`, Name: `Movie ${index}`, Type: 'Movie' }));
  const { login, call, fixture } = await setup(t, { items }); await login();
  fixture.state.requests.length = 0;
  const ids = [], sizes = [];
  let startIndex = 0;
  for (let pageNumber = 0; pageNumber < 3; pageNumber++) {
    const response = await call(pageNumber === 0 ? '/api/items' : `/api/items?startIndex=${startIndex}`);
    assert.equal(response.status, 200);
    const page = response.data;
    assert.deepEqual(Object.keys(page).sort(), ['items', 'nextStartIndex', 'startIndex', 'total']);
    assert.equal(page.startIndex, startIndex); assert.equal(page.total, 237);
    sizes.push(page.items.length); ids.push(...page.items.map(item => item.id));
    assert.equal(page.nextStartIndex, pageNumber === 2 ? null : startIndex + 100);
    startIndex = page.nextStartIndex;
  }
  assert.deepEqual(sizes, [100, 100, 37]);
  assert.deepEqual(ids, items.map(item => item.Id)); assert.equal(new Set(ids).size, 237);
  const requests = fixture.state.requests.filter(request => request.path === '/jellyfin/Items');
  assert.deepEqual(requests.map(request => request.query.startIndex), ['0', '100', '200']);
  assert.ok(requests.every(request => request.query.limit === '100' && request.query.enableTotalRecordCount === 'true'));
  const home = (await call('/api/home')).data;
  assert.equal(home.movies.length, 100); assert.ok(Array.isArray(home.series));
});

test('filtered pagination preserves the matching total and terminates on final or empty pages', async t => {
  const items = Array.from({ length: 230 }, (_, index) => ({ Id: `filtered-${index}`, Name: index < 205 ? `Match ${index}` : `Other ${index}`, Type: index < 220 ? 'Movie' : 'Series' }));
  const { login, call } = await setup(t, { items }); await login();
  const ids = [];
  for (const startIndex of [0, 80, 160]) {
    const page = (await call(`/api/items?type=Movie&search=Match&startIndex=${startIndex}&limit=80`)).data;
    assert.equal(page.total, 205); assert.equal(page.startIndex, startIndex);
    assert.equal(page.items.length, startIndex === 160 ? 45 : 80);
    assert.equal(page.nextStartIndex, startIndex === 160 ? null : startIndex + 80);
    ids.push(...page.items.map(item => item.id));
  }
  assert.deepEqual(ids, items.slice(0, 205).map(item => item.Id));
  for (const startIndex of [205, 300, Number.MAX_SAFE_INTEGER]) {
    const response = await call(`/api/items?type=Movie&search=Match&startIndex=${startIndex}&limit=1`);
    assert.equal(response.status, 200);
    assert.deepEqual(response.data, { items: [], total: 205, startIndex, nextStartIndex: null });
  }
  assert.deepEqual((await call('/api/items?search=missing')).data, { items: [], total: 0, startIndex: 0, nextStartIndex: null });
  const exact = (await call('/api/items?type=Movie&search=Match&startIndex=204&limit=1')).data;
  assert.equal(exact.items.length, 1); assert.equal(exact.nextStartIndex, null);
});

test('children forward bounded pagination and always use the parent in the route', async t => {
  const items = Array.from({ length: 113 }, (_, index) => ({ Id: `episode-${index}`, ParentId: SEASON_ID, Name: `Episode ${index}`, Type: 'Episode', IndexNumber: index + 1 }));
  items.push({ Id: 'unrelated-episode', ParentId: SERIES_ID, Name: 'Unrelated', Type: 'Episode' });
  const { login, call, fixture } = await setup(t, { items }); await login();
  fixture.state.requests.length = 0;
  const ids = [];
  for (const startIndex of [0, 37, 74, 111]) {
    const response = await call(`/api/items/${SEASON_ID}/children?startIndex=${startIndex}&limit=37&parentId=${SERIES_ID}`);
    assert.equal(response.status, 200);
    assert.equal(response.data.total, 113); assert.equal(response.data.startIndex, startIndex);
    assert.equal(response.data.items.length, startIndex === 111 ? 2 : 37);
    assert.equal(response.data.nextStartIndex, startIndex === 111 ? null : startIndex + 37);
    ids.push(...response.data.items.map(item => item.id));
  }
  assert.deepEqual(ids, items.slice(0, 113).map(item => item.Id));
  const requests = fixture.state.requests.filter(request => request.path === '/jellyfin/Items');
  assert.deepEqual(requests.map(request => request.query.startIndex), ['0', '37', '74', '111']);
  assert.ok(requests.every(request => request.query.limit === '37' && request.query.parentId === SEASON_ID && request.query.recursive === 'false'));
  const defaults = (await call(`/api/items/${SEASON_ID}/children`)).data;
  assert.equal(defaults.items.length, 100); assert.equal(defaults.startIndex, 0); assert.equal(defaults.nextStartIndex, 100);
  assert.deepEqual((await call(`/api/items/${SEASON_ID}/children?startIndex=113`)).data,
    { items: [], total: 113, startIndex: 113, nextStartIndex: null });
});

test('invalid pagination is rejected before any upstream request on both list routes', async t => {
  const { login, call, fixture } = await setup(t); await login();
  fixture.state.requests.length = 0;
  for (const route of ['/api/items', `/api/items/${SEASON_ID}/children`]) {
    for (const [key, values] of Object.entries({
      startIndex: ['', '-1', '1.5', 'NaN', 'Infinity', '1e2', '0x10', ' 1', '1 ', '+1', '9007199254740992'],
      limit: ['', '0', '-1', '101', '1.5', 'NaN', 'Infinity', '1e2', '0x10', ' 1', '1 ', '+1', '9007199254740992'],
    })) {
      for (const value of values) {
        const response = await call(`${route}?${new URLSearchParams({ [key]: value })}`);
        assert.equal(response.status, 400, `${route}: ${key}=${JSON.stringify(value)}`);
        assert.equal(response.data.error.code, 'invalid_request');
      }
    }
  }
  assert.equal(fixture.state.requests.length, 0);
});

test('HLS master, playlist, segment, subtitles and reports remain local with full-timeline resume', async t => {
  const { login, call, gateway, fixture } = await setup(t); await login();
  const playback = (await call(`/api/playback/${MOVIE_ID}`, { startTimeTicks: 10_000_000 })).data;
  assert.match(playback.url, /\.m3u8$/); assert.equal(playback.playMethod, 'Transcode');
  assert.equal(playback.seekTimeTicks, 10_000_000); assert.equal(playback.positionOffsetTicks, 0);
  assert.equal(fixture.state.playbackBody.StartTimeTicks, 10_000_000);
  const master = await (await fetch(gateway.url + playback.url)).text();
  assert.ok(!master.includes(TOKEN)); assert.ok(!master.includes(fixture.url));
  const playlistUrl = master.split('\n').find(line => line.startsWith('/api/media/'));
  const playlist = await (await fetch(gateway.url + playlistUrl)).text();
  const segmentUrl = playlist.split('\n').find(line => line.startsWith('/api/media/'));
  const segment = await fetch(gateway.url + segmentUrl);
  assert.equal(segment.status, 200); assert.equal(new Uint8Array(await segment.arrayBuffer())[0], 0x47);
  assert.ok((await (await fetch(gateway.url + playback.subtitles[0].url)).text()).startsWith('WEBVTT'));
  for (const event of ['start', 'progress', 'stop']) {
    const result = await call('/api/playback/report', { event, itemId: playback.itemId, playSessionId: playback.playSessionId, mediaSourceId: playback.mediaSourceId, positionTicks: 20_000_000, isPaused: event === 'progress' });
    assert.equal(result.status, 200);
  }
  assert.deepEqual(fixture.state.reports.map(r => r.path), ['/Sessions/Playing', '/Sessions/Playing/Progress', '/Sessions/Playing/Stopped']);
  assert.equal(fixture.state.reports[1].PositionTicks, 20_000_000); assert.equal(fixture.state.reports[1].PlayMethod, 'Transcode');
  assert.equal((await call(`/api/items/${MOVIE_ID}`)).data.item.positionTicks, 20_000_000);
});

test('browser-compatible direct play takes precedence, supports byte ranges and only client-side seek', async t => {
  const { login, call, gateway } = await setup(t, { mode: 'both' }); await login();
  const playback = (await call(`/api/playback/${MOVIE_ID}`, { startTimeTicks: 10_000_000 })).data;
  assert.equal(playback.playMethod, 'DirectPlay'); assert.equal(playback.seekTimeTicks, 10_000_000); assert.equal(playback.positionOffsetTicks, 0);
  const media = await fetch(gateway.url + playback.url, { headers: { Range: 'bytes=0-15' } });
  assert.equal(media.status, 206); assert.match(media.headers.get('content-range'), /^bytes 0-15\//);
  assert.equal((await media.arrayBuffer()).byteLength, 16);
});

test('a direct-video body can continue beyond the metadata timeout', async t => {
  const { login, call, gateway, fixture } = await setup(t, { mode: 'direct' }); await login();
  gateway.service.timeoutMs = 150;
  fixture.state.bodyDelayMs = 500;
  const playback = (await call(`/api/playback/${MOVIE_ID}`, {})).data;
  const started = Date.now();
  const response = await fetch(gateway.url + playback.url);
  const bytes = await response.arrayBuffer();
  assert.equal(response.status, 200); assert.ok(bytes.byteLength > 1000); assert.ok(Date.now() - started >= 450);
});

test('media URLs reconnect after a move, refuse malicious external playlist URIs and clear credentials at logout', async t => {
  const { login, call, gateway, fixture, path } = await setup(t); await login();
  const playback = (await call(`/api/playback/${MOVIE_ID}`, {})).data;
  await fixture.move();
  assert.equal((await fetch(gateway.url + playback.url)).status, 200);
  fixture.state.maliciousPlaylist = true;
  assert.equal((await fetch(gateway.url + playback.url)).status, 502);
  assert.equal((await call('/api/logout', {})).status, 200);
  const loggedOut = JSON.parse(await readFile(path, 'utf8'));
  assert.equal(loggedOut.account, undefined, 'logout removes the saved token and password');
  assert.equal((await fetch(gateway.url + playback.url)).status, 404);
  assert.equal((await call('/api/session')).data.reason, 'login_required');
});

test('unsupported playback returns a useful error instead of a guessed video URL', async t => {
  const { login, call, fixture } = await setup(t); await login(); fixture.state.playbackError = true;
  const result = await call(`/api/playback/${MOVIE_ID}`, {});
  assert.equal(result.status, 422); assert.equal(result.data.error.code, 'unsupported_media');
});

test('origin and host protection, invalid requests, no arbitrary proxy, and API CORS', async t => {
  const { call, gateway } = await setup(t);
  assert.equal((await call('/api/session', undefined, { headers: { Origin: 'https://evil.example' } })).status, 403);
  const badHost = await new Promise((resolve, reject) => {
    const req = http.get(gateway.url + '/api/session', { headers: { Host: `evil.example:${gateway.server.address().port}` } }, res => { res.resume(); resolve(res.statusCode); }); req.on('error', reject);
  });
  assert.equal(badHost, 403);
  assert.equal((await call('/api/session', undefined, { headers: { 'Sec-Fetch-Site': 'cross-site' } })).status, 403);
  const allowed = await call('/api/session', undefined, { headers: { Origin: 'http://localhost:5173' } });
  assert.equal(allowed.status, 200); assert.equal(allowed.response.headers.get('access-control-allow-origin'), 'http://localhost:5173');
  assert.equal((await call('/api/connect', { url: 'file:///etc/passwd' })).status, 400);
  assert.equal((await call('/api/items?type=Audio')).status, 400);
  assert.equal((await call('/api/items?parentId=..')).status, 400);
  assert.equal((await call('/api/proxy?url=http://example.com')).status, 404);
  assert.equal((await call('/api/discover', undefined, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{' })).status, 400);
  assert.equal((await call('/api/discover', undefined, { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: '{}' })).status, 415);
  assert.equal((await call(`/api/playback/${MOVIE_ID}`, { startTimeTicks: -1 })).status, 400);
  const preflight = await fetch(gateway.url + '/api/login', { method: 'OPTIONS', headers: { Origin: 'http://localhost:5173', 'Access-Control-Request-Method': 'POST' } });
  assert.equal(preflight.status, 204);
});

test('identity redirects are not followed and no token is sent to their target', async t => {
  const { login, fixture, call, path } = await setup(t); await login(); const before = await readFile(path, 'utf8');
  let hits = 0;
  const target = http.createServer((_req, res) => { hits++; res.end('{}'); });
  await new Promise(resolve => target.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => target.close(resolve)));
  fixture.state.publicRedirect = `http://127.0.0.1:${target.address().port}/steal`;
  assert.equal((await call('/api/session')).data.reason, 'redirect_rejected');
  assert.equal(hits, 0); assert.equal(await readFile(path, 'utf8'), before);
});

test('corrupt saved credentials are preserved for recovery rather than silently overwritten', async t => {
  const { path, gateway } = await setup(t);
  await writeFile(path, '{ broken JSON');
  await assert.rejects(new SessionStore(path).load(), /preserved/);
  assert.equal(await readFile(path, 'utf8'), '{ broken JSON');
  assert.ok(gateway.service.state.deviceId);
});

test('manual IPv6 server with base path authenticates normally', async t => {
  const { fixture, call } = await setup(t, { bindHost: '::1' });
  assert.match(fixture.url, /\[::1\]/);
  assert.equal((await call('/api/connect', { url: fixture.url })).status, 200);
  assert.equal((await call('/api/login', { serverId: SERVER_ID, username: 'demo', password: 'demo' })).data.connected, true);
});

test('silent UDP uses credential-free bounded local HTTP probes to recover a changed address without re-login', async t => {
  const fixture = await createFixture(); t.after(() => fixture.close());
  const dir = await mkdtemp(join(tmpdir(), 'jellyfin-http-fallback-'));
  let availableHost = '10.99.0.1';
  const requests = [];
  const fetchImpl = async (value, options) => {
    const url = new URL(value); const token = /Token="/.test(options.headers.Authorization);
    requests.push({ host: url.hostname, path: url.pathname, token });
    if (url.hostname !== availableHost) throw new Error('unreachable');
    const real = new URL(url); const target = new URL(fixture.url); real.hostname = target.hostname; real.port = target.port;
    return fetch(real, options);
  };
  const gateway = await createGateway({ port: 0, store: new SessionStore(join(dir, '.local', 'session.json')), fetchImpl,
    discoveryOptions: { targets: [], interfaces: { lan: [{ family: 'IPv4', address: '10.99.0.3', netmask: '255.255.255.248', internal: false }] }, probeOptions: { budgetMs: 500 } } });
  t.after(() => gateway.close());
  const call = async (path, data) => (await fetch(gateway.url + path, data ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) } : {})).json();
  const cached = new URL(fixture.url); cached.hostname = availableHost; cached.port = '18096';
  await call('/api/connect', { url: cached.href });
  assert.equal((await call('/api/login', { serverId: SERVER_ID, username: 'demo', password: 'demo' })).connected, true);
  availableHost = '10.99.0.2'; requests.length = 0;
  const recovered = await call('/api/session');
  assert.equal(recovered.connected, true);
  assert.equal(recovered.server.url, 'http://10.99.0.2:18096/jellyfin/');
  assert.equal(fixture.state.loginCount, 1);
  assert.ok(requests.filter(r => r.path.endsWith('/System/Info/Public')).every(r => !r.token));
  assert.ok(requests.filter(r => r.token).every(r => r.host === availableHost));
});

test('client disconnect cancels the upstream media body', async t => {
  const { login, call, gateway, fixture } = await setup(t, { mode: 'direct' }); await login();
  fixture.state.bodyDelayMs = 200;
  const playback = (await call(`/api/playback/${MOVIE_ID}`, {})).data;
  const response = await fetch(gateway.url + playback.url);
  const reader = response.body.getReader();
  assert.equal((await reader.read()).done, false);
  await reader.cancel();
  await new Promise(resolve => setTimeout(resolve, 50));
  assert.equal(fixture.state.mediaDisconnects, 1);
});

test('a non-Jellyfin product with a copied stable ID never receives credentials', async t => {
  const { login, fixture, call, path } = await setup(t); await login(); const before = await readFile(path, 'utf8');
  fixture.state.productName = 'Other media server'; fixture.state.requests.length = 0;
  const session = (await call('/api/session')).data;
  assert.equal(session.connected, false); assert.equal(session.reason, 'invalid_server');
  assert.ok(fixture.state.requests.every(request => !request.token));
  assert.equal(await readFile(path, 'utf8'), before);
});

test('fixture-backed metadata operations use routes present in the observed Jellyfin12.2 OpenAPI audit', async t => {
  const { login, call, fixture } = await setup(t); await login();
  await call('/api/home'); await call(`/api/items/${MOVIE_ID}`);
  const playback = (await call(`/api/playback/${MOVIE_ID}`, {})).data;
  await call('/api/playback/report', { event: 'start', itemId: MOVIE_ID, playSessionId: playback.playSessionId, mediaSourceId: SOURCE_ID, positionTicks: 0, isPaused: false });
  const audit = JSON.parse(await readFile(new URL('../../server/api-audit.json', import.meta.url), 'utf8'));
  assert.equal(audit.info.version, '12.2.0');
  for (const request of fixture.state.requests) {
    const path = request.path.replace(/^\/jellyfin/, '');
    const found = Object.entries(audit.endpoints).find(([template, methods]) => new RegExp('^' + template.replace(/\{[^}]+\}/g, '[^/]+') + '$').test(path) && methods[request.method.toLowerCase()]);
    assert.ok(found, `Unverified upstream route: ${request.method} ${path}`);
  }
  assert.ok(fixture.state.requests.some(r => r.path === `/jellyfin/Items/${MOVIE_ID}`));
  assert.ok(fixture.state.requests.some(r => r.path === '/jellyfin/Items/Latest'));
  assert.ok(!fixture.state.requests.some(r => /\/Users\/[^/]+\/Items/.test(r.path)));
});

test('real logos, chapter images, and navigation IDs use opaque item-scoped resources', async t => {
  const items = [
    { Id: MOVIE_ID, Name: 'Title art', Type: 'Movie', ImageTags: { Logo: 'real-logo' }, Chapters: [
      { Name: 'Opening', StartPositionTicks: 0, ImageTag: 'chapter-one', ImagePath: '/private/library/chapter.jpg' },
      { Name: 'Invalid chapter', StartPositionTicks: -1, ImageTag: 'invalid' },
      { Name: 'The reveal', StartPositionTicks: 900_000_000, ImageTag: 'chapter-three' },
      { StartPositionTicks: 1_200_000_000 },
    ] },
    { Id: SERIES_ID, Name: 'Series art', Type: 'Series', ImageTags: { Logo: 'series-logo' } },
    { Id: SEASON_ID, Name: 'Episode', Type: 'Episode', SeriesId: SERIES_ID, ParentId: 'season-parent', ParentLogoItemId: SERIES_ID, ParentLogoImageTag: 'series-logo' },
    { Id: 'no-art', Name: 'No art', Type: 'Movie' },
  ];
  const { login, call, gateway, fixture } = await setup(t, { items }); await login();
  const home = (await call('/api/home')).data;
  assert.match(home.movies[0].logo, /^\/api\/media\//);
  assert.equal(home.movies[0].chapters, undefined);
  const detail = (await call(`/api/items/${MOVIE_ID}`)).data.item;
  assert.deepEqual(detail.chapters.map(c=>[c.name,c.startTimeTicks]), [['Opening',0],['The reveal',900_000_000],['Chapter 4',1_200_000_000]]);
  assert.equal(detail.chapters[2].image, undefined);
  for (const image of [detail.logo, detail.chapters[0].image, detail.chapters[1].image]) assert.equal((await fetch(gateway.url+image)).status,200);
  assert.ok(fixture.state.requests.some(r=>r.path===`/jellyfin/Items/${MOVIE_ID}/Images/Chapter/2`));
  const episode = (await call(`/api/items/${SEASON_ID}`)).data.item;
  assert.equal(episode.seriesId,SERIES_ID); assert.equal(episode.parentId,'season-parent');
  assert.equal((await fetch(gateway.url+episode.logo)).status,200);
  assert.ok(fixture.state.requests.some(r=>r.path===`/jellyfin/Items/${SERIES_ID}/Images/Logo`));
  const noArt = (await call('/api/items/no-art')).data.item;
  assert.equal(noArt.logo,null); assert.deepEqual(noArt.chapters,[]);
  assert.ok(!JSON.stringify(detail).includes(TOKEN)); assert.ok(!JSON.stringify(detail).includes('/private/'));
});
