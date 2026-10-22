// Read-only: this checks a server's public specification without account access.
const input = process.argv[2];
if (!input) {
  console.error('Usage: npm run check:server -- http://your-jellyfin:8096[/basepath]');
  process.exit(1);
}
const base = new URL(input.endsWith('/') ? input : input + '/');
if (!['http:', 'https:'].includes(base.protocol) || base.username || base.password) {
  throw new Error('Use an HTTP(S) Jellyfin URL without credentials.');
}
const read = async path => {
  const response = await fetch(new URL(path, base), { signal: AbortSignal.timeout(10000) });
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  return response.json();
};
const [info, spec] = await Promise.all([read('System/Info/Public'), read('api-docs/openapi.json')]);
console.log(`${info.ServerName} — Jellyfin ${info.Version}`);
const required = [
  ['get', '/System/Info/Public'], ['post', '/Users/AuthenticateByName'],
  ['get', '/Users/{userId}'], ['get', '/Items'], ['get', '/Items/{itemId}'],
  ['get', '/Items/Latest'], ['get', '/UserItems/Resume'],
  ['get', '/Shows/{seriesId}/Seasons'], ['get', '/Shows/{seriesId}/Episodes'],
  ['post', '/Items/{itemId}/PlaybackInfo'], ['get', '/Videos/{itemId}/stream'],
  ['post', '/Sessions/Playing'], ['post', '/Sessions/Playing/Progress'],
  ['post', '/Sessions/Playing/Stopped'], ['post', '/Sessions/Logout'],
];
let missing = 0;
for (const [method, path] of required) {
  const present = Boolean(spec.paths?.[path]?.[method]);
  if (!present) missing++;
  console.log(`${present ? 'OK' : 'MISSING'} ${method.toUpperCase()} ${path}`);
}
if (missing) process.exitCode = 1;
console.log('This verifies advertised API routes, not authentication or media playback.');
