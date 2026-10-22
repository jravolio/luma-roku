import { randomUUID } from 'node:crypto';
import { GatewayError, identifier, ticks } from './errors.mjs';
import { apiUrl, normalizeServerUrl, mediaUrl } from './urls.mjs';
import { discoverServers } from './discovery.mjs';
import { SessionStore } from './store.mjs';
import { browserCompatible, playbackChoices, playbackProfile, publicSource, publicTracks, qualityOptions, selectPlayback, setMediaQuery, streamSummary } from './playback.mjs';

export const browserProfile = {
  Name: 'Browser Preview H264 AAC', MaxStreamingBitrate: 20_000_000, MaxStaticBitrate: 20_000_000,
  DirectPlayProfiles: [{ Container: 'mp4,m4v', Type: 'Video', VideoCodec: 'h264', AudioCodec: 'aac,mp3' }],
  TranscodingProfiles: [{ Container: 'ts', Type: 'Video', VideoCodec: 'h264', AudioCodec: 'aac', Protocol: 'hls', Context: 'Streaming', MaxAudioChannels: '2', MinSegments: 2, SegmentLength: 4, BreakOnNonKeyFrames: false }],
  CodecProfiles: [{ Type: 'Video', Codec: 'h264', Conditions: [
    { Condition: 'LessThanEqual', Property: 'VideoBitDepth', Value: '8', IsRequired: true },
    { Condition: 'Equals', Property: 'VideoRangeType', Value: 'SDR', IsRequired: false },
  ] }],
  SubtitleProfiles: [{ Format: 'vtt', Method: 'External' }],
};

export async function limitedText(response, max = 8_000_000) {
  if (Number(response.headers.get('content-length')) > max) { await response.body?.cancel(); throw new GatewayError('upstream_error', 'Upstream response too large.'); }
  const reader = response.body?.getReader();
  if (!reader) return '';
  const parts = []; let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > max) { await reader.cancel(); throw new GatewayError('upstream_error', 'Upstream response too large.'); }
      parts.push(Buffer.from(value));
    }
  } finally { reader.releaseLock(); }
  return Buffer.concat(parts).toString('utf8');
}

function pageInteger(value, label, fallback, min, max = Number.MAX_SAFE_INTEGER) {
  if (value === undefined) return fallback;
  const number = typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value;
  if (!Number.isSafeInteger(number) || number < min || number > max) {
    throw new GatewayError('invalid_request', `${label} must be an integer between ${min} and ${max}.`, 400);
  }
  return number;
}

export class JellyfinGateway {
  constructor({ store = new SessionStore(), discovery = discoverServers, discoveryOptions = {}, timeoutMs = 3000, fetchImpl = fetch } = {}) {
    Object.assign(this, { store, discovery, discoveryOptions, timeoutMs, fetchImpl });
    this.resources = new Map(); this.plays = new Map(); this.queue = Promise.resolve();
  }

  async init() {
    this.state = await this.store.load();
    const a = this.state.account;
    this.selected = a ? { id: a.serverId, name: a.serverName, url: a.url } : undefined;
    return this;
  }

  exclusive(fn) {
    const next = this.queue.then(fn);
    this.queue = next.catch(() => {});
    return next;
  }

  header(token) {
    return `MediaBrowser Client="Jellyfin Browser Preview", Device="Browser", DeviceId="${this.state.deviceId}", Version="0.1.0"${token ? `, Token="${token}"` : ''}`;
  }

  async request(url, { token, method = 'GET', body, headers = {}, stream = false, signal, timeoutMs = this.timeoutMs } = {}) {
    let response;
    const controller = stream ? new AbortController() : undefined;
    const timer = stream ? setTimeout(() => controller.abort(), 30000) : undefined;
    const timeoutSignal = controller?.signal ?? AbortSignal.timeout(timeoutMs);
    try {
      response = await this.fetchImpl(url, {
        method, redirect: 'manual', signal: signal ? AbortSignal.any([signal, timeoutSignal]) : timeoutSignal,
        headers: { Authorization: this.header(token), ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}), ...headers },
        ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
      });
    } catch { throw new GatewayError('offline', 'Jellyfin is unreachable. The saved account is preserved.', 503); }
    finally { if (timer) clearTimeout(timer); }
    if (!response.ok) {
      await response.body?.cancel();
      if (response.status >= 300 && response.status < 400) throw new GatewayError('redirect_rejected', 'Upstream redirects are refused. Enter the final Jellyfin base URL.');
      throw new GatewayError(response.status === 401 ? 'upstream_unauthorized' : response.status === 403 ? 'forbidden' : response.status === 404 ? 'not_found' : 'upstream_error',
        response.status === 401 ? 'Jellyfin rejected authentication.' : response.status === 403 ? 'Jellyfin denied this operation.' : 'Jellyfin could not complete the request.',
        response.status === 401 ? 401 : response.status === 403 ? 403 : response.status === 404 ? 404 : 502);
    }
    if (stream) return response;
    try {
      const text = await limitedText(response);
      return text ? JSON.parse(text) : undefined;
    } catch (error) {
      if (error instanceof GatewayError) throw error;
      throw new GatewayError('upstream_error', 'Jellyfin returned an invalid response.');
    }
  }

  async verify(url, options = {}) {
    url = normalizeServerUrl(url);
    const info = await this.request(apiUrl(url, 'System/Info/Public'), options);
    try { identifier(info?.Id); } catch { throw new GatewayError('invalid_server', 'URL did not return a Jellyfin server identity.'); }
    if (typeof info.ProductName !== 'string' || !/^Jellyfin(?: Server)?$/i.test(info.ProductName)) throw new GatewayError('invalid_server', 'URL did not identify itself as Jellyfin.');
    return { id: info.Id, name: typeof info.ServerName === 'string' ? info.ServerName.slice(0, 256) : 'Jellyfin', url };
  }

  discover(options = {}) { return this.discovery({ ...this.discoveryOptions, ...options, verify: (url, settings) => this.verify(url, settings) }); }

  async resolveServer(server) {
    let failed;
    try {
      const verified = await this.verify(server.url);
      if (verified.id === server.id) return verified;
      failed = new GatewayError('identity_mismatch', 'Cached address now belongs to another server. Saved account is preserved.', 503);
    } catch (error) { failed = error; }
    const { servers } = await this.discover({ cachedServer: server, expectedServerId: server.id });
    const match = servers.find(candidate => candidate.id === server.id);
    if (!match) throw failed;
    // Discovery results are not trusted as a substitute for this final check.
    const verified = await this.verify(match.url);
    if (verified.id !== server.id) throw new GatewayError('identity_mismatch', 'Rediscovered server identity changed.', 503);
    return verified;
  }

  async accountServer() {
    const a = this.state.account;
    if (!a) throw new GatewayError('login_required', 'Sign in to Jellyfin.', 401);
    if (this.selected && this.selected.id !== a.serverId) throw new GatewayError('login_required', 'Sign in to the selected server.', 401);
    const server = await this.resolveServer({ id: a.serverId, name: a.serverName, url: a.url });
    if (a.url !== server.url || a.serverName !== server.name) {
      a.url = server.url; a.serverName = server.name;
      await this.store.save(this.state);
    }
    this.selected = server;
    if (!a.token) await this.reauthenticate(server);
    return server;
  }

  async reauthenticate(server) {
    const a = this.state.account;
    if (!a?.username || typeof a.password !== 'string') throw new GatewayError('auth_revoked', 'Sign in to Jellyfin.', 401);
    // resolveServer/accountServer must verify the durable ServerId before any
    // saved credential is sent to the cached or rediscovered address.
    const checked = await this.resolveServer(server);
    if (checked.id !== a.serverId) throw new GatewayError('identity_mismatch', 'Saved credentials were not sent because the server identity changed.', 409);
    let result;
    try { result = await this.request(apiUrl(checked.url, 'Users/AuthenticateByName'), { method: 'POST', body: { Username: a.username, Pw: a.password } }); }
    catch (error) { if (error.code === 'upstream_unauthorized') throw new GatewayError('auth_revoked', 'Jellyfin rejected the saved credentials. Sign in again.', 401); throw error; }
    if (result?.ServerId && result.ServerId !== a.serverId) throw new GatewayError('identity_mismatch', 'Authentication response has a different server identity.', 409);
    if (!result?.User?.Id || typeof result.AccessToken !== 'string' || !/^[a-zA-Z0-9_-]{1,4096}$/.test(result.AccessToken)) throw new GatewayError('upstream_error', 'Invalid Jellyfin authentication response.');
    a.token = result.AccessToken;
    a.userId = result.User.Id;
    a.userName = String(result.User.Name ?? a.username).slice(0, 256);
    a.url = checked.url; a.serverName = checked.name;
    this.selected = checked;
    this.resources.clear(); this.plays.clear();
    await this.store.save(this.state);
    return checked;
  }

  async invalidate() {
    delete this.state.account.token;
    this.resources.clear(); this.plays.clear();
    await this.store.save(this.state);
    throw new GatewayError('auth_revoked', 'The saved Jellyfin token was revoked. Sign in again.', 401);
  }

  async authorized(path, options = {}) {
    const server = await this.accountServer();
    const a = this.state.account;
    try { return await this.request(apiUrl(server.url, path, options.query), { ...options, token: a.token }); }
    catch (error) {
      if (error.code !== 'upstream_unauthorized') throw error;
      // A token can expire during a request. Revalidate server identity,
      // re-authenticate once, and retry the original request once.
      const checked = await this.accountServer();
      await this.reauthenticate(checked);
      return this.request(apiUrl(checked.url, path, options.query), { ...options, token: a.token });
    }
  }

  publicSession(connected = false, reason) {
    const a = this.state.account;
    return { connected, ...(this.selected ? { server: this.selected } : {}),
      ...(a && (!this.selected || a.serverId === this.selected.id) ? { user: { id: a.userId, name: a.userName } } : {}), ...(reason ? { reason } : {}) };
  }

  async session() {
    if (!this.state.account?.token) return this.publicSession(false, this.state.account ? 'auth_revoked' : 'login_required');
    try {
      const user = await this.authorized(`Users/${this.state.account.userId}`);
      if (user?.Id !== this.state.account.userId) throw new GatewayError('upstream_error', 'Jellyfin returned the wrong user identity.');
      return this.publicSession(true);
    } catch (error) { if (!(error instanceof GatewayError)) throw error; return this.publicSession(false, error.code); }
  }

  async connect(url) {
    const server = await this.verify(url);
    this.selected = server;
    const a = this.state.account;
    if (a?.serverId === server.id) {
      a.url = server.url; a.serverName = server.name;
      await this.store.save(this.state);
    }
    this.resources.clear(); this.plays.clear();
    return { server };
  }

  async login({ serverId, username, password }) {
    identifier(serverId, 'serverId');
    if (!this.selected || this.selected.id !== serverId) throw new GatewayError('server_not_selected', 'Connect to this server before signing in.', 409);
    if (typeof username !== 'string' || !username.trim() || username.length > 256 || typeof password !== 'string' || password.length > 4096) throw new GatewayError('invalid_request', 'Username and password are required.', 400);
    const server = await this.resolveServer(this.selected);
    let result;
    try { result = await this.request(apiUrl(server.url, 'Users/AuthenticateByName'), { method: 'POST', body: { Username: username, Pw: password } }); }
    catch (error) { if (error.code === 'upstream_unauthorized') throw new GatewayError('invalid_credentials', 'Jellyfin rejected the username or password.', 401); throw error; }
    if (result?.ServerId && result.ServerId !== server.id) throw new GatewayError('identity_mismatch', 'Authentication response has a different server identity.');
    if (!result?.User?.Id || typeof result.AccessToken !== 'string' || !/^[a-zA-Z0-9_-]{1,4096}$/.test(result.AccessToken)) throw new GatewayError('upstream_error', 'Invalid Jellyfin authentication response.');
    identifier(result.User.Id, 'userId');
    this.state.account = { serverId: server.id, serverName: server.name, url: server.url, token: result.AccessToken, username, password, userId: result.User.Id, userName: String(result.User.Name ?? username).slice(0, 256) };
    this.selected = server;
    this.resources.clear(); this.plays.clear();
    await this.store.save(this.state);
    return this.publicSession(true);
  }

  async logout() {
    // Explicit logout may clear credentials, even when the server is offline.
    try { if (this.state.account?.token) await this.authorized('Sessions/Logout', { method: 'POST' }); } catch { /* Local logout still succeeds. */ }
    delete this.state.account;
    this.resources.clear(); this.plays.clear();
    await this.store.save(this.state);
    return this.publicSession(false, 'login_required');
  }

  resource(url, prefix, extension = '', playSessionId) {
    const server = this.selected;
    const checked = mediaUrl(server.url, String(url), prefix);
    const relative = checked.pathname.slice(new URL(server.url).pathname.length) + checked.search;
    // Deduplicate playlist segments so long playbacks do not evict active URLs.
    const key = `${server.id}:${playSessionId ?? ''}:${relative}`;
    const existing = this.resources.get(key);
    if (existing && existing.expires > Date.now()) return existing.local;
    const id = randomUUID();
    const local = `/api/media/${id}${extension ? `/stream.${extension}` : ''}`;
    const entry = { relative, prefix, playSessionId, serverId: server.id, userId: this.state.account.userId, local, expires: Date.now() + 6 * 60 * 60 * 1000 };
    this.resources.set(id, entry); this.resources.set(key, { ...entry, id });
    while (this.resources.size > 16384) {
      const oldest = this.resources.entries().next().value;
      this.resources.delete(oldest[0]);
      if (oldest[1].id) this.resources.delete(oldest[1].id);
    }
    return local;
  }

  image(item, type) {
    const id = type === 'Logo' ? (item.ImageTags?.Logo ? item.Id : item.ParentLogoImageTag ? item.ParentLogoItemId : undefined)
      : type === 'Primary' ? (item.ImageTags?.Primary ? item.Id : item.ParentPrimaryImageItemId ?? item.SeriesId) : (item.BackdropImageTags?.length ? item.Id : item.ParentBackdropItemId);
    if (!id) return null;
    identifier(id);
    const path = `Items/${id}/Images/${type}${type === 'Backdrop' ? '/0' : ''}`;
    return this.resource(apiUrl(this.selected.url, path, { maxWidth: type === 'Primary' ? 500 : type === 'Logo' ? 1000 : 1600, quality: 85 }), `Items/${id}/Images/`);
  }

  item(value, { detail = false } = {}) {
    identifier(value.Id);
    const chapters = detail ? (value.Chapters ?? []).flatMap((chapter, index) => {
      if (!Number.isSafeInteger(chapter.StartPositionTicks) || chapter.StartPositionTicks < 0) return [];
      const prefix = `Items/${value.Id}/Images/`;
      return [{ name: chapter.Name?.trim() || `Chapter ${index + 1}`, startTimeTicks: chapter.StartPositionTicks,
        ...(chapter.ImageTag ? { image: this.resource(apiUrl(this.selected.url, `${prefix}Chapter/${index}`, { maxWidth: 480, quality: 85 }), prefix) } : {}) }];
    }) : undefined;
    return { id: value.Id, name: value.Name ?? '', type: value.Type ?? 'Unknown', overview: value.Overview ?? '',
      year: value.ProductionYear ?? null, runtimeTicks: value.RunTimeTicks ?? 0, positionTicks: value.UserData?.PlaybackPositionTicks ?? 0, played: Boolean(value.UserData?.Played),
      poster: this.image(value, 'Primary'), backdrop: this.image(value, 'Backdrop'), logo: this.image(value, 'Logo'), genres: value.Genres ?? [], rating: value.CommunityRating ?? null,
      seriesName: value.SeriesName ?? null, indexNumber: value.IndexNumber ?? null, parentIndexNumber: value.ParentIndexNumber ?? null,
      ...(value.SeriesId ? { seriesId: identifier(value.SeriesId, 'seriesId') } : {}), ...(value.ParentId ? { parentId: identifier(value.ParentId, 'parentId') } : {}),
      ...(detail ? { chapters } : {}) };
  }

  async items({ search, type, parentId, startIndex, limit } = {}) {
    startIndex = pageInteger(startIndex, 'startIndex', 0, 0);
    limit = pageInteger(limit, 'limit', 100, 1, 100);
    if (type && !['Movie', 'Series'].includes(type)) throw new GatewayError('invalid_request', 'Type must be Movie or Series.', 400);
    if (parentId) identifier(parentId, 'parentId');
    if (search && search.length > 256) throw new GatewayError('invalid_request', 'Search is too long.', 400);
    const newestFirst = !parentId && !search;
    const data = await this.authorized('Items', { query: { userId: this.state.account?.userId, searchTerm: search || undefined, includeItemTypes: type || (parentId ? undefined : 'Movie,Series'), parentId,
      // MediaSources (every track of every file) made the movie page ~8x larger; item() never reads it.
      recursive: !parentId, startIndex, limit, enableTotalRecordCount: true, fields: 'Overview,Genres,ParentId',
      sortBy: parentId ? 'ParentIndexNumber,IndexNumber,SortName' : newestFirst ? 'DateCreated,SortName' : 'SortName',
      sortOrder: newestFirst ? 'Descending,Ascending' : 'Ascending', enableUserData: true } });
    if (!Array.isArray(data?.Items) || !Number.isSafeInteger(data.TotalRecordCount) || data.TotalRecordCount < 0) {
      throw new GatewayError('upstream_error', 'Jellyfin returned an invalid item page.');
    }
    const items = data.Items.slice(0, limit).map(value => this.item(value));
    const next = startIndex + items.length;
    return { items, total: data.TotalRecordCount, startIndex,
      nextStartIndex: items.length && Number.isSafeInteger(next) && next < data.TotalRecordCount ? next : null };
  }

  async getItem(id) {
    identifier(id);
    return { item: this.item(await this.authorized(`Items/${id}`, { query: { userId: this.state.account?.userId } }), { detail: true }) };
  }

  async home() {
    await this.accountServer();
    const userId = this.state.account.userId;
    const [resume, latest, movies, series] = await Promise.all([
      this.authorized('UserItems/Resume', { query: { userId, mediaTypes: 'Video', limit: 12, fields: 'Overview,Genres,ParentId', enableUserData: true } }),
      this.authorized('Items/Latest', { query: { userId, includeItemTypes: 'Movie,Episode', limit: 12, fields: 'Overview,Genres,ParentId', groupItems: false } }),
      this.items({ type: 'Movie' }), this.items({ type: 'Series' }),
    ]);
    return { resume: (resume?.Items ?? []).map(value => this.item(value)), latest: (Array.isArray(latest) ? latest : latest?.Items ?? []).map(value => this.item(value)), movies: movies.items, series: series.items };
  }

  async playback(id, options = {}) {
    identifier(id);
    const choices = playbackChoices(options), { startTimeTicks } = choices;
    // GET supplies all versions and raw streams, including embedded subtitles
    // without DeliveryUrl. POST is reserved for the validated selected version.
    const metadata = await this.authorized(`Items/${id}/PlaybackInfo`, { query: { userId: this.state.account?.userId } });
    const sources = (metadata?.MediaSources ?? []).filter(s => s.Id && !s.RequiresOpening);
    const source = choices.mediaSourceId === undefined
      ? sources.find(browserCompatible) ?? sources[0]
      : sources.find(s => s.Id === choices.mediaSourceId);
    if (!source) throw new GatewayError(choices.mediaSourceId === undefined ? 'unsupported_media' : 'invalid_request',
      choices.mediaSourceId === undefined ? 'No supported video version was returned by Jellyfin.' : 'The selected version is not available for this item.', choices.mediaSourceId === undefined ? 422 : 400);
    identifier(source.Id, 'mediaSourceId');
    const plan = selectPlayback(source, choices);
    const info = await this.authorized(`Items/${id}/PlaybackInfo`, { method: 'POST', body: {
      UserId: this.state.account?.userId, DeviceProfile: playbackProfile(browserProfile, plan, source), StartTimeTicks: startTimeTicks, MaxStreamingBitrate: plan.maxBitrate,
      MediaSourceId: source.Id, AudioStreamIndex: plan.selection.audioStreamIndex, SubtitleStreamIndex: plan.selection.subtitleStreamIndex,
      EnableDirectPlay: plan.allowDirectPlay, EnableDirectStream: false, EnableTranscoding: true, AllowVideoStreamCopy: plan.allowVideoStreamCopy,
      AllowAudioStreamCopy: false, AutoOpenLiveStream: false, AlwaysBurnInSubtitleWhenTranscoding: plan.encodeSubtitles,
    } });
    if (info?.ErrorCode || !info?.PlaySessionId) throw new GatewayError('unsupported_media', 'Jellyfin did not provide a playable browser stream.', 422);
    const negotiated = info.MediaSources?.find(s => s.Id === source.Id && !s.RequiresOpening);
    if (!negotiated) throw new GatewayError('unsupported_media', 'Jellyfin did not return the selected version.', 422);
    identifier(info.PlaySessionId, 'playSessionId');
    if (this.plays.has(info.PlaySessionId)) throw new GatewayError('upstream_error', 'Jellyfin reused an active playback session.');
    const direct = plan.allowDirectPlay && negotiated.SupportsDirectPlay && browserCompatible({ ...source, ...negotiated });
    const prefix = `Videos/${id}/`;
    let url, extension, playMethod;
    if (!direct) {
      if (!negotiated.TranscodingUrl) throw new GatewayError('unsupported_media', 'This selection requires HLS transcoding, which Jellyfin did not allow.', 422);
      url = mediaUrl(this.selected.url, negotiated.TranscodingUrl, prefix);
      if (!url.pathname.endsWith('.m3u8') || negotiated.TranscodingSubProtocol !== 'hls') throw new GatewayError('unsupported_media', 'Unsupported Jellyfin transcoding format.', 422);
      const negotiatedBitrate = Number([...url.searchParams].find(([key]) => key.toLowerCase() === 'videobitrate')?.[1]);
      const validNegotiatedBitrate = Number.isFinite(negotiatedBitrate) && negotiatedBitrate > 0 ? negotiatedBitrate : undefined;
      const conversionBudget = plan.maxBitrate - plan.audioBitrate;
      const videoBitrate = plan.codecConversion && plan.selection.quality !== 'original'
        ? Math.min(validNegotiatedBitrate ?? conversionBudget, conversionBudget)
        : plan.videoBitrate ?? validNegotiatedBitrate;
      setMediaQuery(url, {
        mediaSourceId: source.Id, playSessionId: info.PlaySessionId, deviceId: this.state.deviceId,
        audioStreamIndex: plan.selection.audioStreamIndex, subtitleStreamIndex: plan.selection.subtitleStreamIndex,
        subtitleMethod: plan.encodeSubtitles ? 'Encode' : undefined,
        // Dynamic HLS exposes the full VOD timeline and seeks by segment index.
        // A nonzero startTimeTicks is forwarded to hls1 segments and rejected by
        // Jellyfin, even though both manifests return 200. Remove any casing of
        // that query parameter and let the player seek within the full playlist.
        startTimeTicks: undefined, copyTimestamps: false, static: false,
        width: undefined, height: undefined, maxWidth: plan.maxWidth, maxHeight: plan.maxHeight,
        videoCodec: 'h264', audioCodec: 'aac', videoBitRate: videoBitrate, audioBitRate: plan.audioBitrate || undefined,
        audioChannels: undefined, maxAudioChannels: 2, transcodingMaxAudioChannels: 2, allowVideoStreamCopy: plan.allowVideoStreamCopy,
        allowAudioStreamCopy: false, enableAutoStreamCopy: plan.allowVideoStreamCopy,
      });
      extension = 'm3u8'; playMethod = 'Transcode';
    } else {
      // Only construct the documented static stream endpoint after PlaybackInfo
      // explicitly declares direct play of a browser-compatible source.
      url = apiUrl(this.selected.url, `Videos/${id}/stream`, { static: true, mediaSourceId: source.Id, playSessionId: info.PlaySessionId, deviceId: this.state.deviceId });
      extension = 'mp4'; playMethod = 'DirectPlay';
    }
    const subtitles = (negotiated.MediaStreams ?? []).filter(s => s.Type === 'Subtitle' && s.DeliveryMethod === 'External' && s.DeliveryUrl &&
      (['webvtt', 'vtt'].includes(s.Codec) || /\.vtt(?:\?|$)/i.test(s.DeliveryUrl))).flatMap(s => {
      try {
        const subtitleUrl = mediaUrl(this.selected.url, s.DeliveryUrl, prefix);
        setMediaQuery(subtitleUrl, { startPositionTicks: 0, copyTimestamps: true, addVttTimeMap: false });
        return [{ index: s.Index, language: s.Language ?? 'und', label: s.DisplayTitle ?? s.Language ?? 'Subtitle', url: this.resource(subtitleUrl, prefix, 'vtt', info.PlaySessionId) }];
      } catch { return []; }
    });
    this.plays.set(info.PlaySessionId, { itemId: id, mediaSourceId: source.Id, playMethod, ...plan.selection });
    if (this.plays.size > 64) this.plays.delete(this.plays.keys().next().value);
    return { url: this.resource(url, prefix, extension, info.PlaySessionId), playSessionId: info.PlaySessionId, mediaSourceId: source.Id, itemId: id, startTimeTicks,
      playMethod, seekTimeTicks: startTimeTicks, positionOffsetTicks: 0,
      audioTracks: publicTracks(source, 'Audio'), subtitleTracks: publicTracks(source, 'Subtitle'), mediaSources: sources.map(publicSource),
      qualityOptions, selection: plan.selection, subtitleDelivery: plan.encodeSubtitles ? 'encoded' : 'off', stream: streamSummary(source, plan, direct),
      ...(subtitles.length ? { subtitles } : {}) };
  }

  async report(body) {
    const { event, itemId, playSessionId, mediaSourceId, positionTicks = 0, isPaused = false } = body;
    [itemId, playSessionId, mediaSourceId].forEach(value => identifier(value)); ticks(positionTicks);
    if (!['start', 'progress', 'stop'].includes(event) || typeof isPaused !== 'boolean') throw new GatewayError('invalid_request', 'Invalid playback event.', 400);
    const play = this.plays.get(playSessionId);
    if (!play || play.itemId !== itemId || play.mediaSourceId !== mediaSourceId) throw new GatewayError('invalid_request', 'Unknown playback session.', 409);
    await this.authorized(`Sessions/${event === 'stop' ? 'Playing/Stopped' : event === 'progress' ? 'Playing/Progress' : 'Playing'}`, { method: 'POST', body: {
      ItemId: itemId, PlaySessionId: playSessionId, MediaSourceId: mediaSourceId, PositionTicks: positionTicks,
      ...(event === 'stop' ? {} : { IsPaused: isPaused, PlayMethod: play.playMethod, CanSeek: true,
        AudioStreamIndex: play.audioStreamIndex, SubtitleStreamIndex: play.subtitleStreamIndex }),
    } });
    if (event === 'stop') {
      // Jellyfin's documented stop report kills jobs by device + playSessionId.
      // Never stop all jobs for a device: a replacement may already be playing.
      this.plays.delete(playSessionId);
      for (const [key, entry] of this.resources) if (entry.playSessionId === playSessionId) this.resources.delete(key);
    }
    return { ok: true };
  }

  async media(id, headers, signal) {
    const entry = this.resources.get(id);
    const a = this.state.account;
    if (!entry || entry.expires < Date.now() || (entry.playSessionId && !this.plays.has(entry.playSessionId)) || !a?.token || a.serverId !== entry.serverId || a.userId !== entry.userId) throw new GatewayError('not_found', 'Media link expired.', 404);
    const server = await this.accountServer();
    const url = mediaUrl(server.url, new URL(entry.relative, server.url).href, entry.prefix);
    const response = await this.authorized(entry.relative, { stream: true, headers, signal });
    const playlist = url.pathname.endsWith('.m3u8') || /mpegurl/i.test(response.headers.get('content-type') ?? '');
    if (!playlist) return { response };
    const text = await limitedText(response, 2_000_000);
    if (!text.trimStart().startsWith('#EXTM3U')) throw new GatewayError('unsupported_media', 'Jellyfin returned an invalid HLS playlist.');
    const rewrite = value => this.resource(mediaUrl(server.url, new URL(value, url).href, entry.prefix), entry.prefix, value.split('?')[0].endsWith('.m3u8') ? 'm3u8' : '', entry.playSessionId);
    const rewritten = text.split(/\r?\n/).map(line => {
      if (!line.trim()) return line;
      if (!line.startsWith('#')) return rewrite(line.trim());
      return line.replace(/URI="([^"]+)"/g, (_, uri) => `URI="${rewrite(uri)}"`);
    }).join('\n').replaceAll(a.token, '[redacted]');
    return { playlist: rewritten, response };
  }
}
