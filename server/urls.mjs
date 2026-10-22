import { GatewayError } from './errors.mjs';

export function normalizeServerUrl(value) {
  try {
    if (typeof value !== 'string' || value.length > 2048) throw new Error();
    const url = new URL(value.trim());
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash) throw new Error();
    if (/%2f|%5c|%00/i.test(url.pathname) || url.pathname.includes('\\')) throw new Error();
    url.pathname = url.pathname.replace(/\/+$/, '') + '/';
    return url.href;
  } catch {
    throw new GatewayError('invalid_url', 'Use an HTTP(S) server URL, including its base path, without credentials or query parameters.', 400);
  }
}

export function apiUrl(base, path, query = {}) {
  const url = new URL(path.replace(/^\/+/, ''), normalizeServerUrl(base));
  for (const [key, value] of Object.entries(query)) if (value !== undefined) url.searchParams.set(key, String(value));
  return url;
}

const guidSegment = /^(?:[a-f0-9]{32}|[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$/i;
function comparableMediaPath(path) {
  // Jellyfin serializes item IDs compactly in JSON but uses dashed GUIDs in
  // transcoding URLs. Compare equivalent complete GUID segments, while keeping
  // the original URL intact for the upstream request.
  return path.split('/').map(segment => guidSegment.test(segment)
    ? segment.replaceAll('-', '').toLowerCase() : segment.toLowerCase()).join('/');
}

// PlaybackInfo URLs may be absolute, origin-relative (already containing a base
// path), or Jellyfin-relative (e.g. /Videos/... even with a configured base URL).
export function mediaUrl(base, value, allowedPrefix) {
  if (typeof value !== 'string' || value.length > 8192 || /[\r\n\\]/.test(value)) throw new GatewayError('unsupported_media', 'Invalid media URL.');
  const root = new URL(normalizeServerUrl(base));
  let url;
  if (/^https?:\/\//i.test(value) || value.startsWith('//')) url = new URL(value, root);
  else if (value.startsWith(root.pathname)) url = new URL(value, root);
  else url = new URL(value.replace(/^\//, ''), root);
  if (url.origin !== root.origin || url.username || url.password || url.hash || /%2f|%5c|%2e|%00/i.test(url.pathname)) {
    throw new GatewayError('unsupported_media', 'Media must be hosted by the verified Jellyfin server.');
  }
  // Do not normalize the configured base path: it is a routing prefix, not an
  // item identity. The trailing slash also prevents partial-segment matches.
  const withinBase = url.pathname.toLowerCase().startsWith(root.pathname.toLowerCase());
  const relativePath = url.pathname.slice(root.pathname.length);
  if (!withinBase || !comparableMediaPath(relativePath).startsWith(comparableMediaPath(allowedPrefix))) {
    throw new GatewayError('unsupported_media', 'Media URL is outside the requested item.');
  }
  for (const key of [...url.searchParams.keys()]) if (/^(api_?key|access_?token|token)$/i.test(key)) url.searchParams.delete(key);
  return url;
}
