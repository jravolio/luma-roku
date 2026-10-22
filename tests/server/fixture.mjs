import http from 'node:http';
import dgram from 'node:dgram';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { DISCOVERY_MESSAGE } from '../../server/discovery.mjs';
import { randomUUID } from 'node:crypto';

export const SERVER_ID = 'a1111111111111111111111111111111a';
export const USER_ID = 'b2222222222222222222222222222222b';
export const MOVIE_ID = 'c3333333333333333333333333333333c';
export const SERIES_ID = 'd4444444444444444444444444444444d';
export const SEASON_ID = 'e5555555555555555555555555555555e';
export const EPISODE_ID = 'f6666666666666666666666666666666f';
export const SOURCE_ID = 'a7777777777777777777777777777777a';
export const PLAY_ID = 'b8888888888888888888888888888888b';
export const TOKEN = 'fixture-token';

const json = (res, status, data) => { res.writeHead(status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(data)); };
const baseItems = [
  { Id: MOVIE_ID, Name: 'The Test Pattern', Type: 'Movie', Overview: 'A deterministic locally generated preview film.', ProductionYear: 2026, RunTimeTicks: 30_000_000, Genres: ['Demo'], CommunityRating: 8.5,
    ImageTags: { Primary: 'poster' }, BackdropImageTags: ['backdrop'], UserData: { PlaybackPositionTicks: 10_000_000, Played: false } },
  { Id: SERIES_ID, Name: 'Gateway Stories', Type: 'Series', Overview: 'Small episodes with stable identities.', Genres: ['Demo'], ImageTags: { Primary: 'poster' }, BackdropImageTags: ['backdrop'] },
  { Id: SEASON_ID, ParentId: SERIES_ID, Name: 'Season 1', Type: 'Season', SeriesId: SERIES_ID, SeriesName: 'Gateway Stories', IndexNumber: 1, ParentPrimaryImageItemId: SERIES_ID },
  { Id: EPISODE_ID, ParentId: SEASON_ID, Name: 'An Address Changes', Type: 'Episode', SeriesId: SERIES_ID, SeriesName: 'Gateway Stories', IndexNumber: 1, ParentIndexNumber: 1, RunTimeTicks: 30_000_000, ParentPrimaryImageItemId: SERIES_ID },
];

export async function createFixture({ port = 0, udpPort = 0, basePath = '/jellyfin', id = SERVER_ID, mode = 'hls', bindHost = '127.0.0.1', items = baseItems } = {}) {
  basePath = '/' + basePath.replace(/^\/+|\/+$/g, '');
  if (basePath === '/') basePath = '';
  const state = { id, name: 'Fake Jellyfin', productName: 'Jellyfin Server', revoked: false, mode, loginCount: 0, requests: [], reports: [], playbackBodies: [], activeEncodings: new Set(), maliciousPlaylist: false, unavailable: false, denyItems: false, unauthorizedItems: false, publicRedirect: undefined, playbackError: false, bodyDelayMs: 0, mediaDisconnects: 0 };
  const itemsData = structuredClone(items);
  const servers = new Set();
  let current, currentPort = port;
  let cachedMedia;
  const handler = async (req, res, identity = state.id) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const auth = req.headers.authorization ?? '';
    const token = /Token="([^"]+)"/.exec(auth)?.[1];
    state.requests.push({ path: url.pathname, query: Object.fromEntries(url.searchParams), token, method: req.method, identity });
    if (state.requests.length > 10000) state.requests.shift();
    if (!url.pathname.startsWith(basePath + '/')) { json(res, 404, {}); return; }
    const path = url.pathname.slice(basePath.length);
    if (state.unavailable) { json(res, 503, {}); return; }
    if (path === '/System/Info/Public') {
      if (state.publicRedirect) { res.writeHead(302, { Location: state.publicRedirect }); res.end(); return; }
      json(res, 200, { Id: identity, ProductName: state.productName, Version: '12.2.0', ServerName: identity === state.id ? state.name : 'Wrong server' }); return;
    }
    if (path === '/Users/AuthenticateByName' && req.method === 'POST') {
      let text = '';
      for await (const chunk of req) text += chunk;
      const body = JSON.parse(text);
      if (body.Username !== 'demo' || body.Pw !== 'demo') { json(res, 401, {}); return; }
      state.revoked = false; state.loginCount++;
      json(res, 200, { ServerId: identity, AccessToken: TOKEN, User: { Id: USER_ID, Name: 'Demo Viewer' } }); return;
    }
    if (token !== TOKEN || state.revoked) { json(res, 401, {}); return; }
    if (path === `/Users/${USER_ID}`) { json(res, 200, { Id: USER_ID, Name: 'Demo Viewer' }); return; }
    if (path === '/Sessions/Logout') { res.writeHead(204); res.end(); return; }
    if (path.startsWith('/Sessions/Playing') && req.method === 'POST') {
      let text = ''; for await (const chunk of req) text += chunk;
      const report = JSON.parse(text); state.reports.push({ path, ...report });
      if (path === '/Sessions/Playing/Stopped') state.activeEncodings.delete(report.PlaySessionId);
      const item = itemsData.find(item => item.Id === report.ItemId);
      if (item) item.UserData = { PlaybackPositionTicks: report.PositionTicks, Played: report.PositionTicks >= item.RunTimeTicks };
      res.writeHead(204); res.end(); return;
    }
    if (state.denyItems && path.startsWith('/Items')) { json(res, 403, {}); return; }
    if (state.unauthorizedItems && path === '/Items') { json(res, 401, {}); return; }
    if (path === '/Items') {
      let items = itemsData;
      if (url.searchParams.has('parentId')) items = items.filter(item => item.ParentId === url.searchParams.get('parentId'));
      if (url.searchParams.has('includeItemTypes')) items = items.filter(item => url.searchParams.get('includeItemTypes').split(',').includes(item.Type));
      if (url.searchParams.has('searchTerm')) items = items.filter(item => item.Name.toLowerCase().includes(url.searchParams.get('searchTerm').toLowerCase()));
      const startIndex = Number(url.searchParams.get('startIndex') ?? 0);
      const limit = Number(url.searchParams.get('limit') ?? items.length);
      json(res, 200, { Items: items.slice(startIndex, startIndex + limit), TotalRecordCount: items.length, StartIndex: startIndex }); return;
    }
    if (path === '/UserItems/Resume') { json(res, 200, { Items: [itemsData[0]] }); return; }
    if (path === '/Items/Latest') { json(res, 200, [itemsData[0], itemsData[3]]); return; }
    const item = /^\/Items\/([^/]+)$/.exec(path);
    if (item) { const value = itemsData.find(value => value.Id === item[1]); json(res, value ? 200 : 404, value ?? {}); return; }
    if (/^\/Items\/[^/]+\/PlaybackInfo$/.test(path)) {
      let text = ''; for await (const chunk of req) text += chunk;
      if (req.method === 'POST') {
        state.playbackBody = JSON.parse(text);
        state.playbackBodies.push(state.playbackBody);
      }
      const playbackItemId = path.split('/')[2];
      const streamItemId = state.hyphenatedMediaIds
        ? playbackItemId.replace(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/, '$1-$2-$3-$4-$5')
        : playbackItemId;
      if (state.playbackError) { json(res, 200, { ErrorCode: 'NoCompatibleStream', MediaSources: [] }); return; }
      const sources = structuredClone(state.sources ?? [{ Id: SOURCE_ID, Container: 'mp4', Bitrate: 400000, SupportsDirectPlay: ['direct', 'both'].includes(state.mode),
        ...(state.mode !== 'direct' ? { TranscodingUrl: `${basePath}/Videos/${streamItemId}/master.m3u8?api_key=${TOKEN}`, TranscodingSubProtocol: 'hls' } : {}),
        MediaStreams: [{ Type: 'Video', Index: 0, Codec: 'h264', Width: 320, Height: 180 }, { Type: 'Audio', Index: 1, Codec: 'aac', Channels: 2 },
          { Type: 'Subtitle', Codec: 'subrip', Index: 2, Language: 'en', DeliveryMethod: 'External', DeliveryUrl: `${basePath}/Videos/${streamItemId}/${SOURCE_ID}/Subtitles/2/Stream.vtt?api_key=${TOKEN}` }] }]);
      if (req.method === 'GET') { json(res, 200, { MediaSources: sources }); return; }
      const playSessionId = state.playbackBodies.length === 1 ? PLAY_ID : randomUUID();
      const selected = sources.filter(s => !state.playbackBody.MediaSourceId || s.Id === state.playbackBody.MediaSourceId);
      for (const source of selected) {
        if (state.sources && source.SupportsTranscoding !== false) {
          // Deliberately include conflicting copy/size parameters to catch gateways
          // which merely label a quality choice without enforcing it on the URL.
          source.TranscodingUrl = `${basePath}/Videos/${streamItemId}/master.m3u8?api_key=${TOKEN}&AudioStreamIndex=2&SubtitleStreamIndex=7&SubtitleMethod=Encode&AllowVideoStreamCopy=true&AllowAudioStreamCopy=true&Width=3840&Height=2160&VideoBitrate=30000000&StartTimeTicks=990000000`;
          source.TranscodingSubProtocol = 'hls';
        }
      }
      json(res, 200, { PlaySessionId: playSessionId, MediaSources: selected }); return;
    }
    if (/\/Images\//.test(path)) {
      res.writeHead(200, { 'Content-Type': 'image/svg+xml' });
      res.end('<svg xmlns="http://www.w3.org/2000/svg" width="800" height="1200"><rect width="800" height="1200" fill="#163945"/><circle cx="400" cy="450" r="210" fill="#61c0af"/><text x="400" y="850" font-family="sans-serif" font-size="65" text-anchor="middle" fill="white">TEST PATTERN</text></svg>'); return;
    }
    if (path.endsWith('/master.m3u8')) {
      const playId = [...url.searchParams].find(([key]) => key.toLowerCase() === 'playsessionid')?.[1];
      if (playId) state.activeEncodings.add(playId);
      const mediaQuery = new URLSearchParams(url.search); mediaQuery.set('api_key', TOKEN);
      res.writeHead(200, { 'Content-Type': 'application/vnd.apple.mpegurl' });
      res.end(`#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=400000,CODECS="avc1.42c01e,mp4a.40.2"\n${state.maliciousPlaylist ? 'http://127.0.0.1:1/steal' : `main.m3u8?${mediaQuery}`}\n`); return;
    }
    if (path.endsWith('/main.m3u8')) {
      const mediaQuery = new URLSearchParams(url.search); mediaQuery.set('api_key', TOKEN);
      res.writeHead(200, { 'Content-Type': 'application/vnd.apple.mpegurl' });
      res.end(`#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:3\n#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:3.0,\nsegment.ts?${mediaQuery}\n#EXT-X-ENDLIST\n`); return;
    }
    if (path.endsWith('.vtt')) { res.writeHead(200, { 'Content-Type': 'text/vtt' }); res.end('WEBVTT\n\n00:00.000 --> 00:02.500\nBrowser preview is playing.\n'); return; }
    if (path.endsWith('/stream') || path.endsWith('/segment.ts')) {
      // DynamicHlsController forwards the playlist query to segments, then
      // rejects a nonzero startTimeTicks. Seeking uses segment numbers instead.
      if (path.endsWith('.ts') && [...url.searchParams].some(([key, value]) => key.toLowerCase() === 'starttimeticks' && Number(value) > 0)) {
        json(res, 400, { error: 'StartTimeTicks is not allowed.' }); return;
      }
      res.on('close', () => { if (!res.writableEnded) state.mediaDisconnects++; });
      cachedMedia ??= { mp4: await readFile(new URL('./media/sample.mp4', import.meta.url)), ts: await readFile(new URL('./media/sample.ts', import.meta.url)) };
      const media = path.endsWith('.ts') ? cachedMedia.ts : cachedMedia.mp4;
      const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range ?? '');
      if (range) {
        const start = Number(range[1]), end = Math.min(Number(range[2] || media.length - 1), media.length - 1);
        if (start > end) { res.writeHead(416); res.end(); return; }
        res.writeHead(206, { 'Content-Type': 'video/mp4', 'Content-Range': `bytes ${start}-${end}/${media.length}`, 'Accept-Ranges': 'bytes', 'Content-Length': end - start + 1 });
        res.end(media.subarray(start, end + 1)); return;
      }
      res.writeHead(200, { 'Content-Type': path.endsWith('.ts') ? 'video/mp2t' : 'video/mp4', 'Content-Length': media.length, 'Accept-Ranges': 'bytes' });
      if (state.bodyDelayMs) { res.flushHeaders(); res.write(media.subarray(0, 16)); await new Promise(resolve => setTimeout(resolve, state.bodyDelayMs)); res.end(media.subarray(16)); }
      else res.end(media);
      return;
    }
    json(res, 404, {});
  };
  async function startHttp(nextPort = 0, wrong = false, host = bindHost) {
    const server = http.createServer((req, res) => handler(req, res, wrong ? 'wrong-server-id' : state.id).catch(() => { if (!res.headersSent) json(res, 500, {}); else res.destroy(); }));
    await new Promise((resolve, reject) => { server.once('error', reject); server.listen(nextPort, host, resolve); });
    servers.add(server); return server;
  }
  const stopHttp = server => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); servers.delete(server); });
  current = await startHttp(currentPort); currentPort = current.address().port;
  let currentHost = bindHost;
  const udp = dgram.createSocket('udp4');
  const fixture = {
    state,
    get url() { return `http://${currentHost.includes(':') ? `[${currentHost}]` : currentHost}:${currentPort}${basePath}/`; },
    get udpPort() { return udp.address().port; },
    async move({ port = 0, wrongAtOld = false, host = bindHost } = {}) {
      const oldPort = currentPort, oldHost = currentHost;
      await stopHttp(current);
      current = await startHttp(port, false, host); currentPort = current.address().port; currentHost = host;
      if (wrongAtOld) await startHttp(oldPort, true, oldHost);
      return fixture.url;
    },
    async offline() { await stopHttp(current); },
    async online() { current = await startHttp(currentPort, false, currentHost); },
    async close() { await Promise.all([...servers].map(stopHttp)); await new Promise(resolve => udp.close(resolve)); },
  };
  udp.on('message', (msg, remote) => {
    if (msg.toString() !== DISCOVERY_MESSAGE || state.discoveryOffline) return;
    udp.send(JSON.stringify({ Id: state.id, Name: state.name, Address: fixture.url }), remote.port, remote.address);
  });
  await new Promise((resolve, reject) => { udp.once('error', reject); udp.bind(udpPort, '0.0.0.0', resolve); });
  return fixture;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const fixture = await createFixture({ port: Number(process.env.FIXTURE_PORT ?? 8096), udpPort: Number(process.env.FIXTURE_UDP_PORT ?? 7359), mode: process.env.FIXTURE_MODE ?? 'hls' });
  const control = http.createServer(async (req, res) => {
    try {
      if (req.headers.origin || !['127.0.0.1:8098', 'localhost:8098'].includes(req.headers.host)) { json(res, 403, {}); return; }
      if (req.method === 'GET' && req.url === '/status') { json(res, 200, { url: fixture.url, id: fixture.state.id, revoked: fixture.state.revoked }); return; }
      if (req.method !== 'POST') { json(res, 404, {}); return; }
      if (req.url === '/move') await fixture.move({ port: fixture.url.includes(':8096/') ? 8097 : 8096 });
      else if (req.url === '/offline') await fixture.offline();
      else if (req.url === '/online') await fixture.online();
      else if (req.url === '/revoke') fixture.state.revoked = true;
      else if (req.url === '/restore') fixture.state.revoked = false;
      else { json(res, 404, {}); return; }
      json(res, 200, { url: fixture.url, id: fixture.state.id, revoked: fixture.state.revoked });
    } catch { json(res, 500, { error: 'Fixture control failed.' }); }
  });
  await new Promise(resolve => control.listen(8098, '127.0.0.1', resolve));
  console.log(`Fake Jellyfin: ${fixture.url} (demo / demo); UDP ${fixture.udpPort}; controls http://127.0.0.1:8098`);
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, async () => { control.close(); control.closeAllConnections(); await fixture.close(); });
}
