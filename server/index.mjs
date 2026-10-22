import http from 'node:http';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { pathToFileURL } from 'node:url';
import { JellyfinGateway } from './jellyfin.mjs';
import { GatewayError } from './errors.mjs';
import { SessionStore } from './store.mjs';

const defaultOrigins = ['http://localhost:5173', 'http://127.0.0.1:5173'];

async function body(req) {
  if (req.headers['content-type'] && !/^application\/json(?:\s*;|$)/i.test(req.headers['content-type'])) throw new GatewayError('invalid_request', 'Use application/json.', 415);
  const chunks = []; let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 16384) throw new GatewayError('invalid_request', 'Request body too large.', 413);
    chunks.push(chunk);
  }
  const text = Buffer.concat(chunks).toString('utf8');
  if (!text) return {};
  if (!req.headers['content-type']) throw new GatewayError('invalid_request', 'Use application/json.', 415);
  try {
    const value = JSON.parse(text);
    if (!value || Array.isArray(value) || typeof value !== 'object') throw new Error();
    return value;
  } catch { throw new GatewayError('invalid_request', 'Expected a JSON object.', 400); }
}

function json(res, status, value) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(value));
}

export async function createGateway({ port = 3333, allowedOrigins = defaultOrigins, service, ...serviceOptions } = {}) {
  service ??= await new JellyfinGateway(serviceOptions).init();
  const server = http.createServer({ requestTimeout: 10000, headersTimeout: 10000, maxHeaderSize: 16384 }, async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cross-Origin-Resource-Policy', 'same-site');
    try {
      const actualPort = server.address().port;
      const hosts = [`127.0.0.1:${actualPort}`, `localhost:${actualPort}`];
      if (!hosts.includes(req.headers.host)) throw new GatewayError('host_forbidden', 'Invalid gateway Host.', 403);
      const origins = new Set([...allowedOrigins, ...hosts.map(host => `http://${host}`)]);
      const origin = req.headers.origin;
      if (origin && !origins.has(origin)) throw new GatewayError('origin_forbidden', 'Origin is not allowed.', 403);
      if (!origin && req.headers['sec-fetch-site'] === 'cross-site') throw new GatewayError('origin_forbidden', 'Cross-site access is refused.', 403);
      if (origin) {
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
      }
      if (req.method === 'OPTIONS') {
        res.writeHead(204, { 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Range', 'Access-Control-Max-Age': '600' });
        res.end(); return;
      }
      const url = new URL(req.url, `http://${req.headers.host}`);
      const path = url.pathname;
      const media = path.match(/^\/api\/media\/([a-f0-9-]{36})(?:\/stream\.(?:m3u8|mp4|vtt))?$/);
      if (req.method === 'GET' && media) {
        const controller = new AbortController();
        res.on('close', () => controller.abort());
        const headers = {};
        if (req.headers.range) {
          if (!/^bytes=\d*-\d*$/.test(req.headers.range)) throw new GatewayError('invalid_request', 'Only a single byte range is supported.', 400);
          headers.Range = req.headers.range;
        }
        const result = await service.exclusive(() => service.media(media[1], headers, controller.signal));
        if (result.playlist !== undefined) {
          res.writeHead(200, { 'Content-Type': 'application/vnd.apple.mpegurl' }); res.end(result.playlist); return;
        }
        const upstream = result.response;
        for (const key of ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
          const value = upstream.headers.get(key);
          if (value) res.setHeader(key, value);
        }
        // Never forward Set-Cookie, Location, authentication or upstream URLs.
        res.writeHead(upstream.status);
        if (upstream.body) await pipeline(Readable.fromWeb(upstream.body), res);
        else res.end();
        return;
      }
      const data = req.method === 'POST' ? await body(req) : {};
      const value = await service.exclusive(async () => {
        if (req.method === 'GET' && path === '/api/session') return service.session();
        if (req.method === 'POST' && path === '/api/discover') return service.discover();
        if (req.method === 'POST' && path === '/api/connect') return service.connect(data.url);
        if (req.method === 'POST' && path === '/api/login') return service.login(data);
        if (req.method === 'POST' && path === '/api/logout') return service.logout();
        if (req.method === 'GET' && path === '/api/home') return service.home();
        if (req.method === 'GET' && path === '/api/items') return service.items(Object.fromEntries(url.searchParams));
        const children = path.match(/^\/api\/items\/([^/]+)\/children$/);
        if (req.method === 'GET' && children) return service.items({ startIndex: url.searchParams.get('startIndex') ?? undefined,
          limit: url.searchParams.get('limit') ?? undefined, parentId: children[1] });
        const item = path.match(/^\/api\/items\/([^/]+)$/);
        if (req.method === 'GET' && item) return service.getItem(item[1]);
        if (req.method === 'POST' && path === '/api/playback/report') return service.report(data);
        const playback = path.match(/^\/api\/playback\/([^/]+)$/);
        if (req.method === 'POST' && playback) return service.playback(playback[1], data);
        throw new GatewayError('not_found', 'Unknown gateway endpoint.', 404);
      });
      json(res, 200, value);
    } catch (error) {
      if (res.headersSent || res.destroyed) { res.destroy(); return; }
      json(res, error instanceof GatewayError ? error.status : 500, { error: { code: error.code ?? 'internal_error', message: error instanceof GatewayError ? error.message : 'Gateway could not complete this request.' } });
    }
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(port, '127.0.0.1', resolve); });
  return { server, service, url: `http://127.0.0.1:${server.address().port}`, close: () => new Promise((resolve, reject) => { server.close(error => error ? reject(error) : resolve()); server.closeAllConnections(); }) };
}

export function optionsFromEnv(env = process.env) {
  const targets = env.JELLYFIN_DISCOVERY_TARGETS?.split(',').filter(Boolean).map(value => {
    const url = new URL(`http://${value}`);
    return { host: url.hostname, port: Number(url.port || 7359), localAddress: '0.0.0.0', interface: 'configured' };
  });
  return { port: Number(env.GATEWAY_PORT ?? 3333),
    ...(env.GATEWAY_ORIGINS ? { allowedOrigins: env.GATEWAY_ORIGINS.split(',').map(origin => new URL(origin).origin) } : {}),
    store: new SessionStore(env.GATEWAY_SESSION_FILE), ...(targets ? { discoveryOptions: { targets } } : {}) };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const gateway = await createGateway(optionsFromEnv());
  console.log(`Jellyfin browser gateway listening on ${gateway.url}`);
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, async () => { await gateway.close(); });
}
