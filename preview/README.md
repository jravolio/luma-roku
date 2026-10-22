# Luma preview

Browser preview of Luma, the Jellyfin client for Roku. It is the visual reference for the native channel (`DESIGN.md`) and a working client in its own right. It connects to your Jellyfin server first, then offers browse, search, details, seasons and episodes, and playback with resume and progress reporting.

```sh
npm install
npm run dev        # http://127.0.0.1:5173, /api proxied to the gateway on 127.0.0.1:3333
npm test           # vitest + Testing Library (jsdom)
npm run build      # typecheck + production build
```

`LUMA_GATEWAY_URL=http://127.0.0.1:3334 npx vite --port 5174` points a second instance at another gateway. The gateway only accepts the 5173 origin unless configured otherwise (see `../server/README.md`).

## First run

With no signed-in server, Luma opens on **Connect to Jellyfin** and starts looking for servers on your network right away. Each result shows its name, address and network, e.g. `media-pc · 192.168.1.50:8096 · Home network`. Choose it, or type the address (the direct LAN address works without Tailscale), then sign in with your Jellyfin username and password. If the gateway already knows a server but has no sign-in, Luma goes straight to **Sign in to media-pc**.

Luma never says a server is connected before sign-in succeeds. A server it has just reached is marked **Reachable**.

## How it fits together

- **`src/api/`**: `types.ts` is the gateway contract. `gateway.ts` calls `/api/*` and turns failures into an `ApiError` with a `kind` (`unreachable`, `unauthorized`, `notFound`, `invalid`, `server`). `demo.ts` implements the same `LibrarySource` interface over the bundled open films, with progress kept in memory only.
- **`src/session/`**: `SessionProvider` polls `GET /api/session` and derives one `SessionState` (`connected`, `offline`, `signedOut`, `noServer`, `gatewayDown`). `appMode` maps that, plus the demo choice, onto what the shell shows: `setup` (onboarding), `unavailable` (saved account, server not answering), or `library`. Refreshes are deduplicated in flight. While offline, it re-checks 15 s after each attempt finishes. A change of status, server or user clears cached library data. Only non-secret server/user identity is remembered in the browser. The token stays in the gateway.
- **`src/nav/`**: hash router with Back depth and per-entry focus restore (`router.ts`); a spatial focus engine for arrow keys with per-row memory, which enters the sidebar on the current item (`spatial.ts`, `remote.ts`); and `useScreenFocus` for initial focus.
- **`src/data/`**: `useResource` (keyed cache, abort, retry, stale-response guard) and `usePagedItems` (follows `nextStartIndex` behind a **Show more** button).
- **`src/components/`**: `Sidebar` (collapsed tab that expands into the account, Search, Home, Movies, TV Shows, Settings overlay), `Hero` (featured carousel), `TitleArt` (server title logo, text fallback), `Shelf`, `Cards` (landscape `WideCard`, `EpisodeCard`, `ChapterCard`, `PosterCard`), `PlayerMenu` (checked choice lists), `ServerCard` and `NetworkTag` for server and account status, `DemoBanner`.
- **`src/screens/`**: Connect (onboarding and sign-in), Home, Movies/Shows, Search (on-screen keyboard), Detail (series → seasons → episodes), Player, Account, Settings.
- **`src/lib/`**: `network.ts` labels an address as Home network, Tailscale, This computer or Internet. `playbackOptions.ts` turns a menu choice into the next negotiation and decides which subtitle the browser may draw. `nextEpisode.ts` finds the following episode from season pages. `playbackTiming.ts` maps stream time to item time.

## Behaviour worth knowing

- **Demo is opt-in**: the demo appears only when chosen with **Try the demo** (connect screen footer, or the unavailable screen). It lasts for this launch only: a reload, **Exit demo**, or signing in ends it, and it stores nothing. While active, a **DEMO** pill is pinned to every screen, the sidebar account reads *Demo · Not your server*, and every title plays one 89-second public sample that the player labels.
- **Offline**: if the gateway reports `offline` or `identity_mismatch`, the account is kept and the sidebar stays. Library screens explain that the server isn't answering, with **Try again now**, **Find on network** and **Try the demo**. Account shows the last address, network and server ID.
- **Playback timing**: the player seeks to `seekTimeTicks` after metadata loads (hls.js also starts loading there) and reports `positionOffsetTicks + currentTime`. Jellyfin HLS playlists cover the whole item, so the gateway sends offset 0 and the resume time as the seek. A stream that starts later than a requested seek is renegotiated rather than clamped. Reports read a snapshot captured from media events, so a stop report has the true position after the `<video>` is torn down.
- **Playback choices**: Subtitles, Audio, and Quality and version menus send `library.playback(id, ticks, options)` with every current choice resent, at the current absolute time, keeping pause state (see `DESIGN.md`, Playback choices, and `docs/playback-controls-contract.md`). Every negotiated session is stopped exactly once, including sessions that never played or lost a race. The player screen negotiates its first session itself, outside the shared resource cache, so cache invalidation never restarts playback; library data refreshes once after leaving the player.
- **HLS**: `.m3u8` URLs play natively where supported, otherwise through a lazily loaded `hls.js`.
- **Pagination**: Movies, Shows, search results, seasons and episodes load 100 at a time, including series without season folders. Counts use the server's `total`, never the loaded length. Home rails use the gateway's fixed arrays.
- **Fonts**: the preview uses the system sans (SF Pro on Apple devices). No web fonts are bundled; the Roku channel should bundle Inter (see `DESIGN.md`).
