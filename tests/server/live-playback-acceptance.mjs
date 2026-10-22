// Explicit, opt-in LAN acceptance. Never included in the offline *.test suite.
// Uses saved credentials in memory; no listener, login, logout or session writes.
// Requires ffprobe/ffmpeg. Neither process receives a URL or credentials.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import { JellyfinGateway } from '../../server/jellyfin.mjs';
import { defaultSessionPath } from '../../server/store.mjs';

function run(command, args, input) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: 'pipe', timeout: 30_000 });
    const chunks = [];
    child.stdout.on('data', chunk => chunks.push(chunk));
    // Suppress raw diagnostics, which can include input metadata or paths.
    child.stderr.resume();
    child.stdin.on('error', () => {});
    child.on('error', () => reject(new Error('Decoder unavailable')));
    child.on('close', code => code === 0 ? resolve(Buffer.concat(chunks)) : reject(new Error('Decode failed')));
    child.stdin.end(input);
  });
}

async function decode(bytes, quality) {
  const data = JSON.parse(await run('ffprobe', ['-v', 'error', '-count_frames', '-show_entries',
    'stream=codec_type,codec_name,width,height,channels,nb_read_frames', '-of', 'json', '-i', 'pipe:0'], bytes));
  const video = data.streams.find(s => s.codec_type === 'video');
  const audio = data.streams.find(s => s.codec_type === 'audio');
  assert.equal(video?.codec_name, 'h264'); assert.equal(audio?.codec_name, 'aac');
  assert.ok(Number(video.nb_read_frames) > 0); assert.ok(Number(audio.nb_read_frames) > 0);
  assert.ok(audio.channels <= 2);
  if (quality === '720p') { assert.equal(video.width, 1280); assert.equal(video.height, 720); }
  await run('ffmpeg', ['-v', 'error', '-xerror', '-i', 'pipe:0', '-map', '0:v:0', '-map', '0:a:0', '-f', 'null', '-'], bytes);
  return { video, audio };
}

function segments(playlist) {
  let startSeconds = 0, duration = 0;
  const entries = [];
  for (const line of playlist.split(/\r?\n/)) {
    if (line.startsWith('#EXTINF:')) duration = Number(line.slice(8).split(',')[0]);
    else if (line && !line.startsWith('#')) {
      assert.ok(line.startsWith('/api/media/'));
      entries.push({ path: line, startSeconds, duration }); startSeconds += duration;
    }
  }
  return entries;
}

async function main() {
  const savedBytes = await readFile(process.env.GATEWAY_SESSION_FILE ?? defaultSessionPath);
  const saved = JSON.parse(savedBytes);
  const item = JSON.parse(await readFile(process.env.JELLYFIN_ACCEPTANCE_ITEM_FILE ?? '.local/playback-acceptance-item.json', 'utf8'));
  const gateway = await new JellyfinGateway({ store: {
    load: async () => structuredClone(saved),
    save: async () => { throw new Error('Acceptance must not change saved credentials'); },
  } }).init();
  const results = [];
  for (const [quality, subtitleStreamIndex] of [['720p', 0], ['720p', 6], ['720p', -1], ['auto', -1]]) {
    let playback, phase = 'negotiate';
    const result = { quality, audioStreamIndex: 3, subtitleStreamIndex, segments: [] };
    try {
      playback = await gateway.playback(item.id, { startTimeTicks: item.positionTicks, audioStreamIndex: 3, subtitleStreamIndex, quality });
      assert.equal(playback.seekTimeTicks, item.positionTicks); assert.equal(playback.positionOffsetTicks, 0);
      phase = 'master';
      const master = await gateway.media(playback.url.split('/')[3]);
      const variantPath = master.playlist.split('\n').find(line => line.startsWith('/api/media/'));
      phase = 'variant';
      const variant = await gateway.media(variantPath.split('/')[3]);
      const entries = segments(variant.playlist);
      const resumeIndex = entries.findIndex(s => s.startSeconds + s.duration > playback.seekTimeTicks / 1e7);
      assert.ok(resumeIndex >= 0);
      for (const index of new Set([0, resumeIndex])) {
        phase = `segment-${index}`;
        const segment = await gateway.media(entries[index].path.split('/')[3], {}, AbortSignal.timeout(30_000));
        assert.equal(segment.response.status, 200);
        const bytes = Buffer.from(await segment.response.arrayBuffer());
        phase = `decode-${index}`;
        result.segments.push({ index, startSeconds: entries[index].startSeconds, bytes: bytes.length, ...await decode(bytes, quality) });
      }
      result.passed = true;
    } catch {
      result.passed = false; result.failedPhase = phase; process.exitCode = 1;
    } finally {
      if (playback) {
        try {
          await gateway.report({ event: 'stop', itemId: playback.itemId, mediaSourceId: playback.mediaSourceId,
            playSessionId: playback.playSessionId, positionTicks: item.positionTicks });
          result.scopedCleanup = true;
        } catch { result.scopedCleanup = false; result.passed = false; process.exitCode = 1; }
      }
    }
    results.push(result); console.log(JSON.stringify(result));
  }
  assert.ok(savedBytes.equals(await readFile(process.env.GATEWAY_SESSION_FILE ?? defaultSessionPath)), 'Saved session changed during acceptance');
  await writeFile(new URL('../../server/.local/live-playback-acceptance.json', import.meta.url),
    JSON.stringify({ checkedAt: new Date().toISOString(), results }, null, 2) + '\n', { mode: 0o600 });
}

main().catch(() => { console.error('Live acceptance failed during setup or final verification; no credentials or diagnostics were printed.'); process.exitCode = 1; });
