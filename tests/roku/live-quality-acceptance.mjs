// Opt-in real-server acceptance; excluded from the offline *.test suite.
// Manifest: {cases:[{label,itemId,request,capabilities,expectCopy?,baseline?}]}.
// Credentials and upstream URLs stay in memory. No progress/login/logout calls.
import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';

function run(command, args, input) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: 'pipe', timeout: 30_000 });
    const chunks = [];
    child.stdout.on('data', value => chunks.push(value));
    child.stderr.resume(); child.stdin.on('error', () => {});
    child.on('error', () => reject(new Error('Local decoder/policy unavailable')));
    child.on('close', code => code === 0 ? resolve(Buffer.concat(chunks)) : reject(new Error('Local decoder/policy failed')));
    child.stdin.end(input);
  });
}
const ms = start => Math.round(performance.now() - start);
const normalized = url => {
  for (const key of [...url.searchParams.keys()]) if (key.toLowerCase() === 'starttimeticks') url.searchParams.delete(key);
  return url;
};
const videoHashes = async (bytes, startSeconds = 0) => String(await run('ffmpeg', ['-v', 'error', '-i', 'pipe:0', '-ss', String(startSeconds), '-map', '0:v:0', '-frames:v', '72', '-an', '-f', 'framemd5', '-'], bytes))
  .split('\n').filter(line => line && !line.startsWith('#')).map(line => line.split(',').at(-1).trim());

async function main() {
  const sessionPath = 'server/.local/session.json';
  const savedBytes = await readFile(sessionPath), { account } = JSON.parse(savedBytes);
  const base = account.url.replace(/\/$/, '');
  const identity = await fetch(base + '/System/Info/Public', { signal: AbortSignal.timeout(10000) }).then(r => r.json());
  assert.equal(identity.Id, account.serverId);
  const deviceId = 'luma-quality-qa-' + randomUUID();
  const headers = { Authorization: `MediaBrowser Client="Luma Quality QA", Device="Mac", DeviceId="${deviceId}", Version="1.0", Token="${account.token}"` };
  async function request(path, options = {}) {
    const url = new URL(path, base + '/');
    assert.equal(url.origin, new URL(base).origin);
    const response = await fetch(url, { ...options, headers: { ...headers, ...options.headers }, signal: AbortSignal.timeout(30000), redirect: 'error' });
    if (!response.ok) throw new Error('Upstream status ' + response.status);
    return response;
  }
  const manifest = JSON.parse(await readFile(process.env.LUMA_QUALITY_CASES ?? '.local/performance/native-cases.json', 'utf8'));
  const results = [], sources = new Map();
  for (const entry of manifest.cases) {
    let phase = 'catalog', playSessionId;
    const result = { label: entry.label, quality: entry.request.quality, baseline: !!entry.baseline };
    try {
      const catalog = await request(`/Items/${entry.itemId}/PlaybackInfo?UserId=${account.userId}`).then(r => r.json());
      phase = 'native-policy';
      const payload = JSON.parse(await run(process.execPath, ['tests/roku/native-playback-request.mjs', JSON.stringify({ request: entry.request, capabilities: entry.capabilities })], JSON.stringify(catalog)));
      payload.UserId = account.userId;
      if (entry.baseline) { payload.EnableDirectPlay = false; payload.EnableDirectStream = false; payload.AllowVideoStreamCopy = false; }
      let start = performance.now(); phase = 'negotiate';
      const info = await request(`/Items/${entry.itemId}/PlaybackInfo`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }).then(r => r.json());
      result.negotiateMs = ms(start); playSessionId = info.PlaySessionId;
      phase = 'production-response-validation';
      if (!entry.baseline) {
        const replay = JSON.parse(await run(process.execPath, ['tests/roku/native-playback-request.mjs', JSON.stringify({ request: entry.request, capabilities: entry.capabilities })], JSON.stringify({ catalog, negotiatedResponse: info, serverBase: base })));
        result.policyAccepted = replay.accepted; result.policyAttempts = replay.attempts;
        assert.equal(replay.accepted, true); assert.equal(replay.attempts, 1);
      }
      const source = info.MediaSources.find(s => s.Id === payload.MediaSourceId);
      assert.ok(source);
      result.direct = source.SupportsDirectPlay && payload.EnableDirectPlay;
      const staticUrl = new URL(`${base}/Videos/${entry.itemId}/stream`);
      staticUrl.search = new URLSearchParams({ Static: 'true', MediaSourceId: source.Id, DeviceId: deviceId, PlaySessionId: playSessionId });
      let bytes, segmentStart = 0;
      if (result.direct) {
        phase = 'direct-sample'; start = performance.now();
        bytes = Buffer.from(await request(staticUrl, { headers: { Range: `bytes=0-${(entry.sampleBytes ?? 8388608) - 1}` } }).then(r => r.arrayBuffer()));
        result.firstMediaMs = ms(start);
      } else {
        assert.ok(source.TranscodingUrl, 'No compatible stream');
        const masterUrl = normalized(new URL(source.TranscodingUrl, base + '/'));
        // Scope the test job without altering negotiated codec/quality decisions.
        for (const key of [...masterUrl.searchParams.keys()]) if (key.toLowerCase() === 'deviceid') masterUrl.searchParams.delete(key);
        masterUrl.searchParams.set('DeviceId', deviceId);
        result.negotiated = Object.fromEntries([...masterUrl.searchParams].filter(([k]) => ['videocodec','audiocodec','allowvideostreamcopy','allowaudiostreamcopy','maxwidth','maxheight','videobitrate','audiobitrate','transcodereasons','subtitlemethod'].includes(k.toLowerCase())));
        phase = 'first-media'; start = performance.now();
        let playlistUrl = masterUrl;
        let playlist = await request(playlistUrl).then(r => r.text());
        if (playlist.includes('#EXT-X-STREAM-INF:')) {
          playlistUrl = new URL(playlist.split(/\r?\n/).find(l => l && !l.startsWith('#')), playlistUrl);
          playlist = await request(playlistUrl).then(r => r.text());
        }
        const entries = []; let elapsed = 0, duration = 0;
        for (const line of playlist.split(/\r?\n/)) {
          if (line.startsWith('#EXTINF:')) duration = Number(line.slice(8).split(',')[0]);
          else if (line && !line.startsWith('#')) { entries.push({ line, start: elapsed }); elapsed += duration; }
        }
        const chosen = entries[entry.segmentIndex ?? 0]; assert.ok(chosen);
        const segment = chosen.line; segmentStart = chosen.start;
        result.segmentStart = segmentStart;
        bytes = Buffer.from(await request(new URL(segment, playlistUrl)).then(r => r.arrayBuffer()));
        result.firstMediaMs = ms(start);
      }
      phase = 'decode';
      const decoded = JSON.parse(await run('ffprobe', ['-v', 'error', '-show_entries', 'stream=codec_type,codec_name,width,height,channels,pix_fmt,color_range,color_space,color_transfer,color_primaries', '-of', 'json', '-i', 'pipe:0'], bytes));
      result.video = decoded.streams.find(s => s.codec_type === 'video');
      result.audio = decoded.streams.find(s => s.codec_type === 'audio'); result.bytes = bytes.length;
      assert.ok(result.video); assert.ok(result.audio);
      if (entry.expectedCodec) assert.equal(result.video.codec_name, entry.expectedCodec);
      const limit = { '1080p': [1920,1080], '720p': [1280,720], '480p': [854,480], '360p': [640,360] }[entry.request.quality];
      if (limit) { assert.ok(result.video.width <= limit[0]); assert.ok(result.video.height <= limit[1]); }
      const hashes = await videoHashes(bytes); assert.equal(hashes.length, 72); result.distinctFrames = new Set(hashes).size; assert.ok(result.distinctFrames > 3, 'Sample must contain changing images');
      if (entry.expectCopy !== undefined || entry.baseline) {
        phase = 'compare-source';
        const sampleKey = `${source.Id}:${segmentStart}`;
        if (!sources.has(sampleKey)) {
          const sample = Buffer.from(await request(staticUrl, { headers: { Range: `bytes=0-${(entry.sampleBytes ?? 8388608) - 1}` } }).then(r => r.arrayBuffer()));
          sources.set(sampleKey, await videoHashes(sample, segmentStart));
        }
        result.identicalSourceFrames = JSON.stringify(hashes) === JSON.stringify(sources.get(sampleKey));
        if (entry.expectCopy !== undefined) assert.equal(result.identicalSourceFrames, entry.expectCopy);
      }
      result.passed = true;
    } catch (error) {
      result.passed = false; result.failedPhase = phase;
      // Only controlled error descriptions; never print upstream response bodies.
      result.reason = error.code === 'ERR_ASSERTION' ? 'Acceptance assertion failed' : 'Request/policy/decode failed';
      process.exitCode = 1;
    } finally {
      if (playSessionId) {
        try {
          await request('/Videos/ActiveEncodings?' + new URLSearchParams({ deviceId, playSessionId }), { method: 'DELETE' });
          result.scopedCleanup = true;
        } catch { result.scopedCleanup = false; process.exitCode = 1; }
      }
    }
    results.push(result); console.log(JSON.stringify(result));
  }
  assert.ok(savedBytes.equals(await readFile(sessionPath)), 'Saved login changed');
  await writeFile(process.env.LUMA_QUALITY_RESULTS ?? '.local/performance/native-live-results.json', JSON.stringify({ checkedAt: new Date().toISOString(), results }, null, 2), { mode: 0o600 });
}
main().catch(() => { console.error('Quality acceptance setup failed; private diagnostics suppressed.'); process.exitCode = 1; });
