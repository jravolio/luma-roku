// Pipe a Jellyfin PlaybackInfo catalog into this exporter. It executes the real
// BrightScript negotiation policy; no credentials or playback URLs are emitted.
// A stdin {catalog, negotiatedResponse} bundle replays the server response and
// returns {accepted, format, attempts, fallback, bodies}; never put URLs in argv.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = fileURLToPath(new URL('../../', import.meta.url));
const read = path => readFileSync(join(root, path), 'utf8');
const literal = value => `ParseJson("${JSON.stringify(value).replaceAll('"', '""')}")`;
const incoming = JSON.parse(readFileSync(0, 'utf8'));
const catalog = incoming.catalog ?? incoming;
const negotiatedResponse = incoming.negotiatedResponse;
const input = JSON.parse(process.argv[2] || '{}');
const request = { itemId: 'fixture-item', ticks: 0, ...input.request };
const caps = { hevc4k: false, hevcMain10: false, hdr10: false, ...input.capabilities };
const audioCaps = { ac3: false, eac3: false, ...input.audio };
const dir = mkdtempSync(join(tmpdir(), 'luma-native-policy-'));
try {
  const service = read('roku/components/JellyfinTask.brs')
    .replace(/^function Http\(/m, 'function NativeHttp(')
    .replace(/^function OriginalVideoCapabilities\(/m, 'function NativeOriginalVideoCapabilities(')
    .replace(/^function AudioCapabilities\(/m, 'function NativeAudioCapabilities(')
    // brs0.45 misdeclares SubtitleTracks as AA; real Roku expects an array.
    // Keep the production negotiation intact and substitute only its output node.
    .replace('node = CreateObject("roSGNode", "ContentNode")\n    node.url = url', 'node = {}\n    node.url = url');
  const script = join(dir, 'policy.brs');
  writeFileSync(script, `${read('roku/source/Utils.brs').replace(/^function Encode\(/m, 'function NativeEncode(')}\n${service}\n
sub Main()
    m.account = {id: "fixture-server", base: ${literal(incoming.serverBase ?? "http://fixture.invalid")}, userId: "fixture-user", token: ""}
    m.saved = {deviceId: "fixture-device"}
    m.verified = true
    m.catalog = ${literal(catalog)}
    m.negotiated = ${literal(negotiatedResponse ?? null)}
    result = PreparePlayback(${literal(request)})
    if m.payload = invalid then print "POLICY_ERROR"
    summary = {accepted: result.ok}
    if result.ok then summary.format = result.content.streamFormat
    print "POLICY_RESULT:"; FormatJson(summary)
end sub
function Http(base as String, path as String, method = "GET" as String, body = invalid as Dynamic, token = "" as String, timeout = 9000 as Integer) as Object
    if method = "GET" then return {ok: true, data: m.catalog}
    m.payload = body
    print "POLICY_JSON:"; FormatJson(body)
    if IsMap(m.negotiated) then return {ok: true, data: m.negotiated}
    return Failure("Export only", 400)
end function
function OriginalVideoCapabilities() as Object
    return ${literal(caps)}
end function
function AudioCapabilities() as Object
    return ${literal(audioCaps)}
end function
function Encode(value as Dynamic) as String
    return TextValue(value)
end function
`);
  const result = spawnSync(process.execPath, [join(root, 'node_modules/brs/bin/cli.js'), script], { cwd: dir, encoding: 'utf8', timeout: 30000 });
  const matches = [...(result.stdout ?? '').matchAll(/^POLICY_JSON:\s*(\{.*\})$/gm)];
  if (result.status !== 0 || !matches.length) throw new Error('Native policy could not prepare this selection');
  const bodies = matches.map(match => JSON.parse(match[1]));
  const summaryMatch = result.stdout.match(/^POLICY_RESULT:\s*(\{.*\})$/m);
  const summary = summaryMatch ? JSON.parse(summaryMatch[1]) : { accepted: false };
  const output = negotiatedResponse ? { ...summary, attempts: bodies.length, fallback: bodies.length > 1, bodies } : input.allBodies ? bodies : bodies[0];
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
} finally { rmSync(dir, { recursive: true, force: true }); }
