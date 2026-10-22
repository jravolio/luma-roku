# Browser gateway

Requires Node 24. No runtime dependencies, root package changes, commits, or remote Git operations are needed.

From the project root:

```sh
node server/index.mjs
node --test tests/server/*.test.mjs
node server/diagnose.mjs
```

The gateway binds **127.0.0.1:3333**. `GATEWAY_PORT` overrides the port for testing. Default permitted browser origins are `http://localhost:5173`, `http://127.0.0.1:5173`, and the gateway's own localhost/127.0.0.1 origins. Set `GATEWAY_ORIGINS` to an explicit comma-separated list to use other preview origins.

Configure the frontend development server to proxy **all `/api` routes** to `http://127.0.0.1:3333` with **`changeOrigin: true`**. This includes image, video, subtitle, and nested HLS playlist/segment requests. Returned media URLs are relative local paths. The gateway checks Host as well as Origin, rejects cross-site browser requests, and exposes no general upstream URL proxy.

Session data defaults to **`server/.local/session.json`**, ignored by `server/.gitignore`. `GATEWAY_SESSION_FILE` may select another ignored location, including root `.local/session.json`. The directory is mode 0700, the atomic replacement file is mode 0600, and writes are synced before rename. Stored fields are version, deviceId, and an account containing serverId, serverName, URL, userId, userName, and token. Passwords and upstream response objects are never persisted. An unreadable or corrupt saved session is preserved and reported as a startup error.

Discovery sends `who is JellyfinServer?` to UDP7359 using directed and limited broadcasts on private LAN IPv4 interfaces. Automatic discovery excludes known Tailscale/VPN tunnel adapters and non-private addresses; a manually entered VPN URL remains supported. It does not alter system VPN settings. Retries, reply size/count, HTTP validation concurrency, and time are bounded. Advertised URLs are unauthenticated and checked against `/System/Info/Public`, including ProductName and the advertised stable ID. IPv6 literal addresses and base paths work through manual connection; IPv6 has no broadcast equivalent for this protocol.

If UDP has no suitable verified server, HTTP fallback probes only the local `/24` portion of up to two RFC1918 IPv4 interface subnets, at most 254 candidates per interface. It respects smaller interface subnets, skips local/network/broadcast addresses, limits concurrency to 24 and each probe to 650ms, and bounds the total discovery pass to 14.5 seconds. Initial discovery uses HTTP8096. Account recovery preserves the cached scheme, port and base path, and filters by saved stable server ID. Probes never carry tokens. Diagnostics include candidate/probe/verification counts and elapsed time.

Every authenticated request first verifies the stable ID at the current URL without a token. A moved or reused address triggers rediscovery. An outage or item-level permission error preserves the saved account. A token is removed only after a confirmed 401 from the user's identity endpoint, or explicit logout. A manual selection of another server preserves the old saved account until a successful replacement login or logout.

## Frontend API

The requested endpoints and normalized item fields are implemented. Errors use `{error:{code,message}}` with an appropriate HTTP status. `GET /api/session` returns status200 for disconnected/offline/revoked states and a `reason`, preserving known server/user display data during outages. Common reasons are `login_required`, `offline`, `identity_mismatch`, `auth_revoked`, `redirect_rejected`, and `upstream_error`.

`GET /api/items` (including search/type/parent filters) and `GET /api/items/:id/children` accept `startIndex` (default 0, nonnegative safe integer) and `limit` (default 100, integer 1–100). Query values must contain decimal digits; empty, negative, fractional, unsafe, or out-of-range values return HTTP400 `invalid_request`. Both return `{items,total,startIndex,nextStartIndex}`. `total` is Jellyfin's `TotalRecordCount` for the filtered result before pagination. Follow `nextStartIndex` with the same filters and limit until it is `null`; final, empty, and out-of-range pages have no continuation. Children always use the parent ID from the path. The gateway forwards both pagination parameters to the documented `/Items` route and explicitly requests the total count. Home shelves retain their existing arrays and at most 100 movies/series per shelf.

Normalized items now include `logo` (an opaque image URL or `null`) on home, list, and detail responses. A real parent logo is inherited when Jellyfin supplies `ParentLogoItemId` and its image tag. `seriesId` and `parentId` are included when present; list/resume/latest requests explicitly request `ParentId`. Detail responses additionally include `chapters: [{name,startTimeTicks,image?}]`, with an empty array when absent. Chapter images use the original Jellyfin chapter index, even when an invalid chapter time is filtered out. Neither source image paths nor tokens are exposed.

`POST /api/playback/:id` accepts:

```ts
{
  startTimeTicks?: number;
  mediaSourceId?: string;
  audioStreamIndex?: number;
  subtitleStreamIndex?: number; // -1 means Off
  quality?: 'auto' | 'original' | '1080p' | '720p' | '480p' | '360p';
}
```

Indices are actual Jellyfin indices, not array positions. The gateway reads all versions and tracks through `GET /Items/{itemId}/PlaybackInfo`, validates the choices within the selected version, and negotiates that specific version with POST. Invalid types, unavailable versions, wrong-track indices, and unknown quality IDs return HTTP400 `invalid_request`. A valid selection which the server cannot deliver returns HTTP422 `unsupported_media`. These failures retain credentials and existing playback resources.

Defaults are `startTimeTicks: 0` and `quality: 'auto'`. With no version specified, the gateway prefers a browser-compatible version, then the first available version. Audio uses Jellyfin's valid `DefaultAudioStreamIndex`, then an `IsDefault` track, then the first audio track, or `null` for silent video. Subtitles use Jellyfin's valid `DefaultSubtitleStreamIndex`; absent, invalid, or `-1` means Off. Consequently a saved Jellyfin subtitle preference may enable subtitles initially. Changing options is stateless: the caller resubmits the current version/audio/subtitle choices it wants to preserve.

All existing playback fields remain, with these additions:

```ts
audioTracks: { index: number; label: string; language?: string; codec?: string; channels?: number; isDefault?: boolean }[];
subtitleTracks: { index: number; label: string; language?: string; codec?: string; isDefault?: boolean; isForced?: boolean }[];
mediaSources: { id: string; label: string; width?: number; height?: number }[];
qualityOptions: { id: string; label: string; maxHeight?: number; maxBitrate?: number }[];
selection: { mediaSourceId: string; audioStreamIndex: number | null; subtitleStreamIndex: number; quality: string };
subtitleDelivery: 'off' | 'encoded' | 'external';
stream: { width?: number; height?: number; bitrate?: number; videoCodec?: string; audioCodec?: string };
```

Track menus include all indexed source tracks, including embedded SRT, styled ASS, and PGS image subtitles with no VTT URL. Labels prefer Jellyfin's localized `DisplayTitle` and otherwise combine title/language/codec/channels/default/forced information. Version labels include the version name, source dimensions, codec and container.

Browser quality choices:

- **Auto:** up to 20 Mbps combined video/audio, with source resolution retained unless Jellyfin needs another constraint. This is a fixed compatibility/bandwidth policy, not measured adaptive bandwidth. It has no explicit 1080p ceiling.
- **Original resolution · may transcode:** no application bandwidth or resolution reduction; the API's maximum int32 bitrate is used during negotiation. H264 may be copied; unsupported video/audio codecs, multiple audio tracks or selected subtitles can still require conversion. This is not a lossless/original-file promise and differs from Roku's explicitly direct-only Original option.
- **1080p:** maximum 1920×1080 and 10 Mbps.
- **720p:** maximum 1280×720 and 4 Mbps.
- **480p:** maximum 854×480 and 1.5 Mbps.
- **360p:** maximum 640×360 and 0.8 Mbps.

The bounded presets disable static playback and video stream copy. HLS URLs receive effective maximum dimensions, video/audio bitrate budgets, actual track indices, and copy flags, replacing conflicting query parameters case-insensitively. Dimensions preserve aspect ratio and never request upscaling. HLS audio is AAC, at most stereo/192 kbps; its budget is deducted from the total ceiling. `stream` describes the requested/estimated output from source metadata and constraints, not a probe of decoded frames or measured wire bitrate. Container overhead and variable encoder output can affect actual transfer rate.

All explicitly selected subtitles, including external text files, currently use server rendering (`subtitleDelivery: 'encoded'`) so embedded text/image formats and resumed HLS share the media timeline. Off sends `SubtitleStreamIndex: -1` and removes the encode method. The gateway currently emits only `off` and `encoded`; `external` remains in the shared contract for clients/providers which use it. Existing compatible VTT entries still appear under `subtitles` as opaque URLs when provided by Jellyfin; their request uses the full item timeline (`startPositionTicks=0`, `copyTimestamps=true`) for both HLS and direct play. Clients must not render these legacy text tracks on top of an encoded selection. Burning subtitles requires server video-transcoding permission and resources. Invalid/unsupported formats may still fail when Jellyfin starts FFmpeg; metadata negotiation alone cannot prove successful decoding.

Playback timing fields:

- `playMethod`: `DirectPlay` or `Transcode`.
- `seekTimeTicks`: time to seek the browser element after metadata loads; requested absolute start ticks for both direct play and HLS.
- `positionOffsetTicks`: add this to the browser element's current position when reporting to Jellyfin; zero for both direct play and dynamic HLS.

Use `positionTicks = Math.round(video.currentTime * 10000000) + positionOffsetTicks` for all start/progress/stop reports. `startTimeTicks` remains the originally requested absolute position. Dynamic HLS exposes the full VOD timeline: the player must seek to `seekTimeTicks / 10000000` (or set the HLS loader's initial position) to request the segment at resume. Keep the requested start in the PlaybackInfo POST, but never add nonzero `startTimeTicks` to the media URL. Jellyfin propagates that query through both successful manifests and then rejects it on the first segment. Its [dynamic HLS controller](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Controllers/DynamicHlsController.cs) seeks by segment index instead. Native HLS or the parent's hls.js player can load the returned `.m3u8` URL. Within the chosen version, compatible H264/AAC-or-MP3 MP4 direct play is preferred when there is at most one stereo audio track, no selected subtitle, and the requested policy permits it. Multiple audio tracks use HLS so the chosen track actually reaches browsers without relying on native audio-track switching. Unsupported sources fail with status422; no arbitrary movie URLs are fabricated.

Start/progress reports include the negotiated audio/subtitle indices from the server-owned playback session, ignoring client attempts to substitute other tracks. Reports use fields present in the observed Jellyfin12.2 DTOs; stop reports send item/source/play-session IDs and absolute position. The documented `POST /Sessions/Playing/Stopped` performs transcode cleanup scoped to the authenticated device and exact play-session ID ([Jellyfin controller](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Controllers/PlaystateController.cs)). No device-wide cleanup is issued. After a successful stop, all associated opaque master/variant/segment/subtitle resources expire, preventing stale requests from restarting that transcode. The replacement session remains usable. Stop retries after successful removal return HTTP409, and failed stop requests retain the session for retry.

Images and media are limited, expiring, opaque local resource handles. Upstream token query parameters are removed and authentication is sent only from the gateway. HLS playlists rewrite variant, segment, subtitle and quoted URI attributes to local resource handles. Cross-origin URLs, redirects and paths outside the requested media item are refused. Complete compact and dashed GUID segments compare as the same item ID; the configured base path and original upstream URL are preserved. Direct streams preserve single byte ranges, stream without the metadata body timeout, and cancel upstream reads on client disconnect. Transcoding needs the real server's H264/AAC HLS support and permissions.

The implementation and fixture were audited against the observed server's **Jellyfin12.2** OpenAPI document. Item detail is `/Items/{itemId}?userId=…`, latest is `/Items/Latest?userId=…`, and resume is `/UserItems/Resume?userId=…`. `api-audit.json` records the checked upstream routes and parameter names. The current online stable API documentation still contains older user-prefixed library routes; the live server's specification takes precedence.

## Deterministic fixture

Run in one terminal:

```sh
node tests/server/fixture.mjs
```

Run an isolated gateway in another:

```sh
GATEWAY_SESSION_FILE=server/.local/fixture-session.json JELLYFIN_DISCOVERY_TARGETS=127.0.0.1:7359 node server/index.mjs
```

Connect to `http://127.0.0.1:8096/jellyfin/`; log in as **demo / demo**. Discovery, login, home, search, movie detail, series seasons/episodes, poster/backdrop images, subtitles, real locally generated three-second H264/AAC direct/HLS playback, and playback reports are supported. `FIXTURE_MODE=direct` selects direct playback; default is HLS. `FIXTURE_PORT` and `FIXTURE_UDP_PORT` override listener ports. `JELLYFIN_DISCOVERY_TARGETS` is an explicit development override for UDP destinations, not an HTTP scan target override.

Controls are a separate loopback-only listener at8098. They reject browser Origin headers and check Host. They affect only the fake server, retain its ID/token, and allow repeated address changes:

```sh
curl http://127.0.0.1:8098/status
curl -X POST http://127.0.0.1:8098/move
curl -X POST http://127.0.0.1:8098/offline
curl -X POST http://127.0.0.1:8098/online
curl -X POST http://127.0.0.1:8098/revoke
curl -X POST http://127.0.0.1:8098/restore
```

Move alternates HTTP8096 and8097. Refreshing `/api/session` after move reconnects through discovery without login; offline preserves the account; revoke requires sign-in again. Unit/integration tests also cover old-address reuse by another identity, UDP-silent HTTP recovery, restart persistence, IPv6/manual base paths, wrong-server token leakage, redirect rejection, origin/Host protection, unsupported playback and a body delayed beyond the metadata timeout.

`tests/server/media/sample.mp4` and `sample.ts` are locally generated test-pattern video and sine-wave audio, with no external media licensing dependency. They need no ffmpeg at runtime.

## Documentation and LAN diagnostics

Context7 was queried before implementation for Node24 built-in HTTP, dgram, fs and test behavior, and Jellyfin's stable OpenAPI and discovery implementation. References: [Node24 docs](https://nodejs.org/docs/latest-v24.x/api/), [Jellyfin stable OpenAPI](https://api.jellyfin.org/openapi/jellyfin-openapi-stable.json), [official Python client's discovery](https://github.com/jellyfin/jellyfin-apiclient-python/blob/master/jellyfin_apiclient_python/connection_manager.py).

`.local/lan-diagnostic.json` at the project root is a timestamped **nonsecret, credential-free** actual LAN result, kept in ignored runtime storage. The observed UDP-silent LAN was successfully discovered through bounded local HTTP probing. The user has since signed in through the browser UI. Authenticated requests retrieve the real library over the LAN, and a real movie and episode decoded 1920×1080 video in Chrome after correcting dashed-GUID media validation. Run `node server/diagnose.mjs` to refresh the diagnostic; it never reads or creates a saved session. Local server names, stable IDs and interface addresses are recorded only in that ignored diagnostic.

Playback regressions include sanitized metadata captured from the actual resume MKV: audio indices 2/3/4 and all 16 subtitle indices (0, 5–19), including PGS at 6/10/18. The fixture verifies media-request constraints, Off, invalid indices, version boundaries, resume/report timing, and old-session cleanup while a replacement remains active. The HLS fixture forwards media query parameters through both manifests and rejects nonzero segment `startTimeTicks`, matching the real Jellyfin failure. The resumed MKV regression fetches TS bytes for 720p/audio 3 with text 0, PGS 6, and Off plus Auto/Off, and checks absolute report timing. Existing identity, credential, compact/dashed GUID, proxy-boundary, pagination and byte-range tests remain in place. `npm test` runs the full server and native suites. Actual playback decoding and visual subtitle/audio checks are a separate live QA step.

Run the opt-in LAN decoder acceptance with `node tests/server/live-playback-acceptance.mjs` when the saved account and `.local/playback-acceptance-item.json` (`id`, `positionTicks`) are available. It requires local `ffprobe` and `ffmpeg`, creates its own in-memory gateway without restarting the main listener, and verifies decoded audio/video from both the initial segment and the segment containing resume for the matrix above. It stops only its own sessions, checks that saved credentials remain byte-for-byte unchanged, and writes nonsecret results to `server/.local/live-playback-acceptance.json`. `GATEWAY_SESSION_FILE` and `JELLYFIN_ACCEPTANCE_ITEM_FILE` can override the two inputs. No upstream URLs, credentials, raw FFmpeg diagnostics, or original file paths are printed or passed to decoder processes. This test intentionally targets the observed acceptance item's stream indices; it is separate from the offline test suite.
