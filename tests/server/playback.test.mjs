import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createGateway } from '../../server/index.mjs';
import { createFixture, SERVER_ID, USER_ID, MOVIE_ID, SOURCE_ID, TOKEN } from './fixture.mjs';

// Sanitized shapes observed from the real MKV library: external index 0,
// multiple audio streams, embedded SRT/ASS and image subtitles without URLs.
const mkv = () => ({ Id: SOURCE_ID, Name: 'Cinema version', Container: 'mkv', Bitrate: 31_199_321,
  SupportsDirectPlay: false, SupportsTranscoding: true, DefaultAudioStreamIndex: 2, DefaultSubtitleStreamIndex: -1,
  MediaStreams: [
    { Type: 'Subtitle', Index: 0, Codec: 'subrip', Language: 'pt-br', IsExternal: true, DisplayTitle: 'Portuguese (Brazil) - SUBRIP - External' },
    { Type: 'Video', Index: 1, Codec: 'h264', Width: 1920, Height: 1080, BitRate: 29_153_322 },
    { Type: 'Audio', Index: 2, Codec: 'dts', Language: 'eng', Channels: 6, IsDefault: true, DisplayTitle: 'English DTS-HD HRA 5.1' },
    { Type: 'Audio', Index: 5, Codec: 'aac', Language: 'por', Channels: 2, IsDefault: false },
    { Type: 'Subtitle', Index: 7, Codec: 'subrip', Language: 'eng', IsExternal: false },
    { Type: 'Subtitle', Index: 11, Codec: 'PGSSUB', Language: 'nld', IsExternal: false, IsForced: true },
    { Type: 'Subtitle', Index: 15, Codec: 'ass', Language: 'eng', Title: 'Signs / Songs', IsExternal: false, IsDefault: true },
  ] });
const alternate = () => ({ Id: 'alternate-source', Name: 'Mobile edition', Container: 'mp4', Bitrate: 800_000,
  SupportsDirectPlay: true, SupportsTranscoding: true, DefaultAudioStreamIndex: 3, DefaultSubtitleStreamIndex: -1,
  MediaStreams: [{ Type: 'Video', Index: 0, Codec: 'h264', Width: 640, Height: 360, BitRate: 650_000 },
    { Type: 'Audio', Index: 3, Codec: 'aac', Language: 'eng', Channels: 2 }] });

async function setup(t, sources = [mkv()]) {
  const fixture = await createFixture(); t.after(() => fixture.close()); fixture.state.sources = sources;
  const saved = { version: 1, deviceId: 'test-device', account: { serverId: SERVER_ID, serverName: fixture.state.name, url: fixture.url, userId: USER_ID, userName: 'Demo Viewer', token: TOKEN } };
  let writes = 0;
  const gateway = await createGateway({ port: 0, store: { load: async () => structuredClone(saved), save: async () => { writes++; } } });
  t.after(() => gateway.close());
  const call = async (path, body) => {
    const response = await fetch(gateway.url + path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    return { status: response.status, data: await response.json() };
  };
  const play = (body = {}) => call(`/api/playback/${MOVIE_ID}`, body);
  const upstream = async playback => {
    assert.equal((await fetch(gateway.url + playback.url)).status, 200);
    return Object.fromEntries(Object.entries(fixture.state.requests.findLast(r => r.path.endsWith('/master.m3u8') || r.path.endsWith('/stream')).query).map(([k,v]) => [k.toLowerCase(),v]));
  };
  return { fixture, gateway, call, play, upstream, writes: () => writes };
}

test('all real MKV tracks and versions are exposed without leaking upstream metadata', async t => {
  const { play, writes } = await setup(t, [mkv(), alternate()]);
  const { status, data: p } = await play({ mediaSourceId: SOURCE_ID });
  assert.equal(status, 200);
  assert.deepEqual(p.audioTracks.map(t => t.index), [2,5]);
  assert.deepEqual(p.subtitleTracks.map(t => t.index), [0,7,11,15]);
  assert.equal(p.audioTracks[0].label, 'English DTS-HD HRA 5.1');
  assert.match(p.audioTracks[1].label, /Portuguese.*AAC.*Stereo/i);
  assert.match(p.subtitleTracks[2].label, /Dutch.*PGSSUB.*Forced/i);
  assert.match(p.subtitleTracks[3].label, /Signs \/ Songs/);
  assert.deepEqual(p.mediaSources.map(s => s.id), [SOURCE_ID,'alternate-source']);
  assert.match(p.mediaSources[0].label, /Cinema version.*1920.*1080/);
  assert.deepEqual(p.selection, { mediaSourceId: SOURCE_ID, audioStreamIndex: 2, subtitleStreamIndex: -1, quality: 'auto' });
  assert.equal(p.subtitleDelivery, 'off');
  assert.deepEqual(p.qualityOptions.map(o => o.id), ['auto','original','1080p','720p','480p','360p']);
  assert.ok(!JSON.stringify(p).includes(TOKEN)); assert.ok(!JSON.stringify(p).includes('http:')); assert.equal(writes(), 0);
});

test('selected audio and every subtitle format are applied to resumed HLS, including Off', async t => {
  const { play, upstream, fixture } = await setup(t);
  for (const subtitleStreamIndex of [0,7,11,15,-1]) {
    const { status, data: p } = await play({ audioStreamIndex: 5, subtitleStreamIndex, startTimeTicks: 123_450_000 });
    assert.equal(status, 200); assert.equal(p.playMethod, 'Transcode');
    assert.equal(p.selection.audioStreamIndex, 5); assert.equal(p.selection.subtitleStreamIndex, subtitleStreamIndex);
    assert.equal(p.subtitleDelivery, subtitleStreamIndex === -1 ? 'off' : 'encoded');
    assert.equal(p.seekTimeTicks, 123_450_000); assert.equal(p.positionOffsetTicks, 0);
    const body = fixture.state.playbackBody, q = await upstream(p);
    assert.equal(body.AudioStreamIndex, 5); assert.equal(body.SubtitleStreamIndex, subtitleStreamIndex); assert.equal(body.MediaSourceId, SOURCE_ID);
    assert.equal(q.audiostreamindex, '5'); assert.equal(q.subtitlestreamindex, String(subtitleStreamIndex));
    assert.equal(q.starttimeticks, undefined); assert.equal(q.copytimestamps, 'false');
    assert.equal(q.subtitlemethod, subtitleStreamIndex === -1 ? undefined : 'Encode');
    assert.equal(q.allowaudiostreamcopy, 'false');
    if (subtitleStreamIndex !== -1) { assert.equal(body.AlwaysBurnInSubtitleWhenTranscoding, true); assert.equal(q.allowvideostreamcopy, 'false'); }
  }
});

test('sanitized live resume MKV exposes all 16 subtitle tracks, including the three missing PGS tracks', async t => {
  const source = JSON.parse(await readFile(new URL('./media/real-mkv-metadata.json', import.meta.url), 'utf8'));
  const {play,upstream} = await setup(t,[source]);
  for (const subtitleStreamIndex of [6,10,18,-1]) {
    const {data:p,status} = await play({ audioStreamIndex:3,subtitleStreamIndex,quality:'720p',startTimeTicks:1_200_000_000 });
    assert.equal(status,200);
    assert.deepEqual(p.audioTracks.map(t=>t.index),[2,3,4]);
    assert.deepEqual(p.subtitleTracks.map(t=>t.index),[0,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19]);
    assert.equal((await upstream(p)).subtitlestreamindex,String(subtitleStreamIndex));
    assert.equal(p.subtitleDelivery,subtitleStreamIndex===-1?'off':'encoded');
  }
});

test('resumed dynamic HLS delivers actual TS segments with text, PGS and Off on the full item timeline', async t => {
  const source = JSON.parse(await readFile(new URL('./media/real-mkv-metadata.json', import.meta.url), 'utf8'));
  const { play, fixture, gateway, call } = await setup(t, [source]);
  const startTimeTicks = 7_663_648_540;
  for (const [quality, subtitleStreamIndex] of [['720p', 0], ['720p', 6], ['720p', -1], ['auto', -1]]) {
    const { status, data: p } = await play({ audioStreamIndex: 3, subtitleStreamIndex, quality, startTimeTicks });
    assert.equal(status, 200);
    let path = p.url;
    for (let depth = 0; depth < 2; depth++) {
      const response = await fetch(gateway.url + path);
      assert.equal(response.status, 200);
      path = (await response.text()).split('\n').find(line => line.startsWith('/api/media/'));
      assert.ok(path);
    }
    const segment = await fetch(gateway.url + path);
    assert.equal(segment.status, 200, 'A playable manifest must lead to playable segments at resume');
    const bytes = new Uint8Array(await segment.arrayBuffer());
    assert.ok(bytes.length > 188); assert.equal(bytes[0], 0x47);
    const request = fixture.state.requests.findLast(r => r.path.endsWith('/segment.ts'));
    const query = Object.fromEntries(Object.entries(request.query).map(([key, value]) => [key.toLowerCase(), value]));
    assert.equal(query.starttimeticks, undefined);
    assert.equal(query.audiostreamindex, '3');
    assert.equal(query.subtitlestreamindex, String(subtitleStreamIndex));
    assert.equal(query.subtitlemethod, subtitleStreamIndex === -1 ? undefined : 'Encode');
    if (quality === '720p') { assert.equal(query.maxwidth, '1280'); assert.equal(query.maxheight, '720'); }
    assert.equal(fixture.state.playbackBody.StartTimeTicks, startTimeTicks);
    assert.equal(p.seekTimeTicks, startTimeTicks); assert.equal(p.positionOffsetTicks, 0);
    const positionTicks = p.seekTimeTicks + 20_000_000 + p.positionOffsetTicks;
    const report = await call('/api/playback/report', { event: 'progress', itemId: p.itemId, mediaSourceId: p.mediaSourceId, playSessionId: p.playSessionId, positionTicks });
    assert.equal(report.status, 200);
    assert.equal(fixture.state.reports.at(-1).PositionTicks, startTimeTicks + 20_000_000);
  }
});

test('ceilings preserve a widescreen aspect ratio and do not pretend to upscale small sources', async t => {
  const source=mkv(); source.MediaStreams.find(t=>t.Type==='Video').Height=800;
  const {play,upstream}=await setup(t,[source]);
  const p=(await play({quality:'720p'})).data;
  assert.equal(p.stream.width,1280); assert.equal(p.stream.height,532);
  const q=await upstream(p);assert.equal(q.maxwidth,'1280');assert.equal(q.maxheight,'720');assert.equal(q.width,undefined);assert.equal(q.height,undefined);
});

test('every quality profile preserves an already-compatible source below its ceilings', async t => {
  const {play,fixture,upstream} = await setup(t,[alternate()]);
  for (const quality of ['auto','original','1080p','720p','480p','360p']) {
    const {status,data:p}=await play({quality,subtitleStreamIndex:-1});
    assert.equal(status,200);
    assert.equal(p.playMethod,'DirectPlay',`${quality} must not re-encode a fitting source`);
    assert.equal(fixture.state.playbackBody.AllowVideoStreamCopy,true);
    assert.equal((await upstream(p)).static,'true');
    assert.equal(p.stream.width,640);assert.equal(p.stream.height,360);
  }
});

test('a fitting multi-audio source copies video while selecting the requested audio', async t => {
  const source=alternate();source.Container='mkv';
  source.MediaStreams.push({Type:'Audio',Index:8,Codec:'aac',Channels:2});
  const {play,fixture,upstream}=await setup(t,[source]);
  const {status,data:p}=await play({quality:'720p',audioStreamIndex:8,subtitleStreamIndex:-1});
  assert.equal(status,200);assert.equal(p.playMethod,'Transcode');
  assert.equal(fixture.state.playbackBody.AllowVideoStreamCopy,true);
  assert.equal(fixture.state.playbackBody.EnableDirectPlay,false);
  const q=await upstream(p);assert.equal(q.allowvideostreamcopy,'true');assert.equal(q.audiostreamindex,'8');
});

test('video copy never bypasses unknown dimensions or width and bitrate ceilings', async t => {
  for (const change of [s=>{delete s.MediaStreams[0].Width;},s=>{s.MediaStreams[0].Width=2048;},s=>{s.Bitrate=5_000_000;}]) {
    const source=alternate();change(source);
    const {play,fixture}=await setup(t,[source]);
    const {status}=await play({quality:'720p',subtitleStreamIndex:-1});
    assert.equal(status,200);assert.equal(fixture.state.playbackBody.AllowVideoStreamCopy,false);
  }
});

test('legacy opaque VTT delivery uses the full item timeline for HLS and direct play', async t => {
  const {play,fixture,gateway}=await setup(t);
  fixture.state.sources=undefined;
  for (const mode of ['hls','direct']) {
    fixture.state.mode=mode;
    const {data:p,status}=await play({startTimeTicks:900_000_000});assert.equal(status,200);
    assert.match(p.subtitles[0].url,/^\/api\/media\/[^/]+\/stream\.vtt$/);
    assert.equal((await fetch(gateway.url+p.subtitles[0].url)).status,200);
    const q=fixture.state.requests.findLast(r=>r.path.endsWith('.vtt')).query;
    assert.equal(q.startPositionTicks,'0');assert.equal(q.copyTimestamps,'true');
  }
});

test('unsupported selection does not fall back silently and preserves an already negotiated stream', async t => {
  const {play,fixture,gateway}=await setup(t);
  const previous=(await play()).data;
  fixture.state.sources=[{...mkv(),Id:'alternate-source',SupportsDirectPlay:false,SupportsTranscoding:false}];
  const failed=await play({mediaSourceId:'alternate-source',quality:'720p'});
  assert.equal(failed.status,422);assert.equal(failed.data.error.code,'unsupported_media');
  assert.equal((await fetch(gateway.url+previous.url)).status,200);
});

test('resolution and total bitrate ceilings affect media requests without fixed-size upscaling', async t => {
  const { play, upstream, fixture } = await setup(t);
  for (const [quality,height,width,bitrate] of [['1080p',1080,1920,10_000_000],['720p',720,1280,4_000_000],['480p',480,854,1_500_000],['360p',360,640,800_000]]) {
    const { status, data:p } = await play({ quality }); assert.equal(status, 200);
    const q = await upstream(p);
    assert.equal(q.maxheight, String(height)); assert.equal(q.maxwidth, String(width));
    assert.equal(q.width, undefined); assert.equal(q.height, undefined);
    assert.equal(q.allowvideostreamcopy,'false'); assert.equal(q.enableautostreamcopy,'false');
    assert.ok(Number(q.videobitrate) + Number(q.audiobitrate) <= bitrate);
    assert.equal(fixture.state.playbackBody.MaxStreamingBitrate, bitrate);
    assert.equal(p.stream.height, height); assert.ok(p.stream.bitrate <= bitrate);
    assert.equal(p.selection.quality, quality);
  }
  fixture.state.sources = [alternate()];
  const {data:p} = await play({ quality:'1080p' }); const q = await upstream(p);
  assert.equal(p.playMethod,'DirectPlay');assert.equal(q.static,'true');
  assert.equal(q.maxheight,undefined);assert.equal(q.maxwidth,undefined);
  assert.equal(p.stream.width,640); assert.equal(p.stream.height,360);
});

test('Original removes the Auto bandwidth ceiling but still permits required codec conversion', async t => {
  const { play, upstream, fixture } = await setup(t);
  const auto = (await play()).data; const autoQ = await upstream(auto);
  assert.equal(fixture.state.playbackBody.MaxStreamingBitrate,20_000_000);
  assert.equal(autoQ.allowvideostreamcopy,'false');
  const original = (await play({ quality: 'original' })).data; const originalQ = await upstream(original);
  assert.ok(fixture.state.playbackBody.MaxStreamingBitrate >= 31_199_321);
  assert.equal(original.selection.quality,'original'); assert.equal(original.playMethod,'Transcode');
  assert.equal(originalQ.allowvideostreamcopy,'true'); assert.equal(originalQ.maxheight,'1080');
  assert.ok(!original.qualityOptions.find(o=>o.id==='original').maxBitrate);
});

test('Original leaves codec conversion bitrate to Jellyfin for HEVC and AV1 sources', async t => {
  for (const codec of ['hevc', 'av1']) {
    const source = alternate();
    source.MediaStreams[0].Codec = codec;
    source.MediaStreams[0].BitRate = 4_000_000;
    source.Bitrate = 4_192_000;
    const { play, fixture, upstream } = await setup(t, [source]);
    const { status, data: playback } = await play({ quality: 'original' });
    assert.equal(status, 200);
    assert.equal(playback.playMethod, 'Transcode');
    assert.equal(fixture.state.playbackBody.AllowVideoStreamCopy, false);
    assert.equal(fixture.state.playbackBody.MaxStreamingBitrate, 2_147_483_647);
    const query = await upstream(playback);
    assert.equal(query.videobitrate, '30000000', `${codec} needs Jellyfin's negotiated encode target`);
    assert.equal(playback.stream.bitrate, undefined, 'the negotiated output bitrate is unknown until Jellyfin encodes it');
    const capped = (await play({ quality: '720p' })).data;
    const cappedQuery = await upstream(capped);
    assert.ok(Number(cappedQuery.videobitrate) + Number(cappedQuery.audiobitrate) <= 4_000_000,
      `${codec} must still honor an explicit bitrate ceiling`);
  }
});

test('codec conversion can use profile headroom without exceeding explicit bitrate ceilings', async t => {
  for (const [codec, bitDepth] of [['hevc', 8], ['av1', 8], ['h264', 10]]) {
    const source = alternate();
    Object.assign(source.MediaStreams[0], { Codec: codec, BitDepth: bitDepth, BitRate: 4_000_000 });
    source.Bitrate = 4_192_000;
    const { play, upstream } = await setup(t, [source]);
    for (const [quality, budget] of [['auto', 20_000_000], ['1080p', 10_000_000], ['720p', 4_000_000], ['360p', 800_000]]) {
      const { status, data: playback } = await play({ quality });
      assert.equal(status, 200);
      assert.equal(playback.playMethod, 'Transcode');
      const query = await upstream(playback);
      const videoBitrate = Number(query.videobitrate);
      const audioBitrate = Number(query.audiobitrate);
      assert.ok(videoBitrate > 0 && videoBitrate + audioBitrate <= budget, `${codec} ${quality} exceeds its budget`);
      if (quality === 'auto' || quality === '1080p') {
        assert.ok(videoBitrate > 4_000_000, `${codec} ${quality} must not inherit the source codec bitrate cap`);
      }
      assert.equal(playback.stream.bitrate, undefined, 'the encoded output rate is not known yet');
    }
  }
});

test('alternate version indices are validated within that version and direct play is honest', async t => {
  const { play, upstream, fixture } = await setup(t,[mkv(),alternate()]);
  const {data:p,status} = await play({mediaSourceId:'alternate-source',audioStreamIndex:3,startTimeTicks:60_000_000,quality:'original'});
  assert.equal(status,200); assert.equal(p.mediaSourceId,'alternate-source'); assert.equal(p.playMethod,'DirectPlay');
  assert.equal(p.positionOffsetTicks,0); assert.equal(p.seekTimeTicks,60_000_000);
  assert.deepEqual(p.audioTracks.map(t=>t.index),[3]); assert.deepEqual(p.subtitleTracks,[]);
  assert.equal((await upstream(p)).mediasourceid,'alternate-source');
  assert.equal((await play({mediaSourceId:'alternate-source',audioStreamIndex:2})).status,400);
  fixture.state.sources = [{...mkv(),Container:'mp4',SupportsDirectPlay:true,Bitrate:3_000_000}];
  const switched = (await play({audioStreamIndex:5})).data;
  assert.equal(switched.playMethod,'Transcode'); assert.equal((await upstream(switched)).audiostreamindex,'5');
});

test('bad types, array positions, and unavailable options fail without mutating saved credentials or negotiating', async t => {
  const {play,fixture,writes} = await setup(t);
  const invalid = [ {mediaSourceId:'missing'}, {mediaSourceId:null}, {quality:'2160p'}, {quality:null}, {quality:[]},
    {audioStreamIndex:0},{audioStreamIndex:-1},{audioStreamIndex:2.5},{audioStreamIndex:'2'}, {audioStreamIndex:null},
    {subtitleStreamIndex:2},{subtitleStreamIndex:-2},{subtitleStreamIndex:'7'},{subtitleStreamIndex:null},{subtitleStreamIndex:1e20} ];
  for (const body of invalid) {const r=await play(body);assert.equal(r.status,400,JSON.stringify(body));assert.equal(r.data.error.code,'invalid_request');}
  assert.equal(fixture.state.playbackBodies.length,0); assert.equal(writes(),0);
  assert.equal((await play({audioStreamIndex:2,subtitleStreamIndex:11})).status,200);
});

test('start/progress report selected indices; stopping an old stream cleans up only its session and opaque URLs', async t => {
  const {play,call,fixture,gateway,upstream} = await setup(t);
  const old = (await play({audioStreamIndex:5,subtitleStreamIndex:11})).data;
  await upstream(old);
  const replacement = (await play({audioStreamIndex:2,subtitleStreamIndex:-1,quality:'720p'})).data;
  await upstream(replacement);
  for (const event of ['start','progress']) {
    const r=await call('/api/playback/report',{event,itemId:old.itemId,mediaSourceId:old.mediaSourceId,playSessionId:old.playSessionId,positionTicks:750_000_000,isPaused:true,audioStreamIndex:2,subtitleStreamIndex:7});assert.equal(r.status,200);
  }
  for (const r of fixture.state.reports) {assert.equal(r.AudioStreamIndex,5);assert.equal(r.SubtitleStreamIndex,11);assert.equal(r.PositionTicks,750_000_000);}
  const stop = {event:'stop',itemId:old.itemId,mediaSourceId:old.mediaSourceId,playSessionId:old.playSessionId,positionTicks:750_000_000};
  assert.equal((await call('/api/playback/report',stop)).status,200);
  assert.ok(!fixture.state.activeEncodings.has(old.playSessionId)); assert.ok(fixture.state.activeEncodings.has(replacement.playSessionId));
  assert.equal((await fetch(gateway.url+old.url)).status,404); assert.equal((await fetch(gateway.url+replacement.url)).status,200);
  const report=fixture.state.reports.at(-1);
  assert.deepEqual(Object.keys(report).sort(),['ItemId','MediaSourceId','PlaySessionId','PositionTicks','path']);
});
