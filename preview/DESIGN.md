# Luma design spec (1920×1080)

The browser preview is the reference. Every pixel value below is in 1080p UI coordinates (`ui_resolutions=fhd`). The preview uses `1rem = 16px` at a 1920-wide window, so `rem × 16` gives the native value.

Direction: the living-room Apple TV app (tvOS 26), adapted to a Jellyfin library. Full-bleed artwork carries every screen; navigation collapses to a small tab; one white focus. Values below were measured from Apple's own screenshots (next section), not from memory. Luma renders only the server's artwork and title logos; no Apple images, logos or titles ship in the app.

## References

Official images, cropped to the TV screen and scaled to 1920×1080 before measuring. The `.local/` copies are ignored research material (`.local/apple-tv-references/manifest.json` records each source URL).

| Surface | Local file | Official source |
|---|---|---|
| Home, collapsed tab, hero, first shelf (tvOS 26) | not copied locally | [Apple TV app guide](https://support.apple.com/guide/tvapp/welcome/web) image `https://help.apple.com/assets/6A5555C16AAC247AF40CA4C5/6A5555C53E8FA04C0B0A18E0/en_US/5a2bbd73164f60c01769f22aec1a84c6.png` ("Apple TV app shown on TV") |
| Expanded sidebar over Home (tvOS 26) | `.local/apple-tv-references/navigation-2.png` | [Navigate the Apple TV app](https://support.apple.com/guide/tvapp/navigate-the-apple-tv-app-atvb5e608b5e/web) |
| Title detail | `.local/apple-tv-references/tvos-player-17.png` | [Control playback on Apple TV](https://support.apple.com/guide/tv/control-whats-playing-atvb7944597f/tvos) |
| Player lower third | `.local/apple-tv-references/tvos-player-4.png` | same page, image "Playback controls" (`S0102_Playhead.png`) |
| Library poster wall | `.local/apple-tv-references/library-tvos-0.png` | [View movies and TV shows in your library](https://support.apple.com/guide/tv/view-movies-and-tv-shows-in-your-library-atvba6a2c11c/tvos) |
| Home with expanded sidebar (tvOS 17.2) | `.local/apple-tv-references/home-0.png` (2× copy: newsroom `Apple-TV-app-home-screen_big.jpg.large_2x.jpg`) | [Apple Newsroom, December 2023](https://www.apple.com/newsroom/2023/12/redesigned-apple-tv-app-elevates-the-viewing-experience/) |
| Subtitle / audio buttons (iOS, macOS) | `.local/apple-tv-references/languages-*.png` | [Change subtitles or languages](https://support.apple.com/en-us/118411) |

No official screenshot of an *open* tvOS audio or subtitle menu was found; the menu styling below is inferred from tvOS 26 materials and is not a measured match.

### Measured parity

Reference values from the images above; Luma values are DOM rectangles from the running preview at 1920×1080 (`left, top → right, bottom`).

| Element | Apple TV | Luma | Note |
|---|---|---|---|
| Collapsed tab pill | 62,58 → 230,122 | 62,58 → 232,122 | Width follows the label |
| Tab glyph circle | 65 → 115 | 69 → 119 | |
| Expanded panel | 37,37 → 392; radius ≈50 | 37,37 → 392; radius 50 | Height follows content |
| Panel row pitch / height | 76 / 75 | 76 / 75 | |
| Panel glyph | 66 → 110 | 67 → 111 | |
| Hero Play pill | 78,742 → 304,809 | 80,744 → 308,812 | |
| Hero circle | 325 → 390, ⌀ 65 | 330 → 396, ⌀ 66 | Luma has no Watchlist circle, so only Details |
| Pager | y 860 → 886 | y 860 → 886 | |
| First shelf title / cards | 913 / 960, cards 320×180, pitch 360 | 912 / 960, 320×180, pitch 360 | |
| Detail action row | y 900 → 960 | y 900 → 960 | |
| Player eyebrow / title | 750 / 801 → 852 | 751 / 788 → 844 | Title sits ~10px higher |
| Player option circles | ⌀ 70, right edge 1840, y 781 → 851 | ⌀ 70, 1840, 774 → 844 | |
| Timeline | 80 → 1840, centre y 895 | 80 → 1840, centre y 894 | |
| Lower pill row | y 956 → 1020 | y 956 → 1020 | |
| Library posters | 200×302, gaps 40 / 66, from x 441 | 200×300, gaps 40 / 66, from x 80 | No category column (see below) |

Known differences, by choice: Luma's Library has no category column (the gateway has no genre filter yet), so posters start at the safe edge. The player adds Back 10 / Play-Pause / Forward 10 circles, Mute and Full screen, because a browser has no Siri Remote; tvOS shows none of these. Hero carousels do not auto-advance. Typography is the system font (SF Pro on Apple devices), so other platforms differ in glyph metrics.

## Connection first

Luma opens on your server, not on sample content.

| Session | What the user sees |
|---|---|
| `checking` | Black splash with the wordmark. |
| `noServer` | Full-screen **Connect to Jellyfin**. Discovery starts immediately; manual address sits below it. |
| `signedOut` (server known) | Full-screen **Sign in to media-pc**: address, network tag, username, password. No discovery. |
| `gatewayDown`, nothing saved | Full-screen "Luma's local service isn't running" with **Try again**. |
| `offline` / `gatewayDown` with a saved account | The shell and sidebar stay. Library screens show **Your library is unavailable** with the kept account, **Try again now**, **Find on network** and **Try the demo**. Account and Settings still work. |
| `connected` | The library. |

Any library URL (`#/`, `#/movies`, `#/item/…`, `#/play/…`) redirects to `#/connect` while setup is needed.

**Status words.** Never say "Connected" before sign-in succeeds. A server found by discovery or reached by `/api/connect` may be labelled **Reachable**. A server remembered by the gateway shows only its address and network tag. After sign-in, the account shows **Signed in to media-pc** with a green dot.

**Network tag.** Each server shows where its address lives, from the host: `Home network` (RFC 1918, link-local, `.local`, `.lan`, `.home.arpa`; green icon), `Tailscale` (100.64.0.0/10, `*.ts.net`; orange icon), `This computer` (loopback), `Internet` (anything else). The preferred path is direct LAN: `media-pc · 192.168.1.50:8096 · Home network`.

## Demo

The demo is opt-in and temporary.

- It is offered only as a quiet footer on the connect screen (**Just looking around? · Try the demo**) and on the unavailable screen. It is never the default.
- It lives in memory for this launch. Reloading, **Exit demo**, or signing in to a server ends it. Demo watch progress is in memory too, and nothing is written to storage.
- While active: a floating **DEMO** pill at the top right of every screen ("Sample films from Blender Studio. Not your Jellyfin library." · **Exit demo**); the sidebar account reads **Demo · Not your server** with a yellow avatar; hero and detail eyebrows say **Demo · Open film by Blender Studio**; the player labels the shared sample clip. Demo credits appear in Settings only while the demo is active.

## Color

| Token | Value | Use |
|---|---|---|
| `bg` | `#000000` | App background, below hero and detail art |
| `charcoal` | `#1A1A1A` | Library, TV Shows and Search pages (measured `26,26,26`) |
| `surface` | `#1C1C1E` | Panels, rows, artwork placeholder |
| `material` | `#242428` at 66%, blur 24, saturate 1.8 | Sidebar panel, menus, notices, demo pill |
| `glass` | `#FFFFFF` at 14% (24% strong), blur 20 | Unfocused buttons, circles and pills |
| `text` | `#FFFFFF` | Primary text |
| `text-2` | `#EBEBF5` at 66% | Secondary text, metadata |
| `text-3` | `#EBEBF5` at 42% | Captions, episode eyebrows |
| `focus` | `#FFFFFF` | Focused fill; label turns `#000000` |
| `ok` / `warn` / `error` / `demo` | `#30D158` / `#FF9F0A` / `#FF453A` / `#FFD60A` | Status only |

Material blur is capped at 24px: Chromium silently drops much larger backdrop blurs. In the player, unfocused circles and pills use a darker glass (`#1C1C20` at 46%) so they stay legible over bright video.

Scrims keep the art bright: Home hero left `#000` 60% → 0 by 58% of the width, bottom `#000` → 0 over the lower 48%. Detail is darker (left 78% → 10%, bottom 70% → 0 over 45%) and stops at the first screen, so rails below sit on black.

## Type

One family: the system sans (SF Pro on Apple devices via `-apple-system`, then Inter, Segoe UI, Roboto). The Roku channel bundles Hanken Grotesk; Apple fonts are not redistributed. Tracking tightens as size grows.

| Role | Size / line | Weight |
|---|---|---|
| Title fallback (no server logo) | 72 / 73 | 700, −0.03em, 2 lines |
| Player title | 50 / 56 | 700, −0.02em |
| Collapsed tab label | 30 | 600 |
| Shelf title | 30 / 36 | 700; 72% white, white when the shelf has focus |
| Hero / detail kind line | 25 | 500, 88% white |
| Sidebar item | 26 / 75 row | 500; 600 when focused |
| Hero overview | 24 / 32 | 400, 62% white, 2 lines |
| Detail overview | 23 / 30 | 400, 62% white, 4 lines |
| Card title / meta | 24 / 30, 22 / 28 | 500 |
| Player eyebrow, times | 22 | 500 / 600, tabular |
| Menu row | 24 | 500 |

## Layout grid

- Safe area: 80 left and right, 60 top and bottom.
- **Navigation.** Collapsed, a glass tab at (62, 58), 64 high, shows `‹`, the current section's glyph and name. Focusing it (Left at the content's edge, Up from the top row, Tab, or a pointer) expands the overlay panel at (37, 37), 355 wide, radius 50, height following its rows: account (avatar, name, server status, clock), then Search, Home, Movies, TV Shows, Settings, 75-high rows on a 76 pitch with 44px glyph circles. The panel overlays the content; nothing reflows. Right, Back or leaving focus collapses it and returns focus to where it was. Detail pages show no tab (Back returns).
- **Home.** The hero fills the first screen. Copy is anchored to the bottom-left: title logo (max 576×160, bottom-left aligned) or text, kind line, 2-line overview, a highlight line (Continue Watching · S1, E2 · 12 min left; New on media-pc; demo label), then a 68-high Play/Resume pill, a 66px Details circle and a `›` that pages the carousel. Buttons end at y 812; the pager pill sits at 860; the first shelf title at 912 and its cards at 960 peek above the fold. Carousel: up to six titles, resume first, then recent arrivals, one page per series, art-bearing titles preferred.
- **Shelves.** Landscape 320×180, radius 12, 40 apart, starting at x 80. Title and one meta line under each card. Progress bar inside the bottom edge (inset 20, height 6).
- **Library (Movies, TV Shows, Search results).** Charcoal page, caption-less 200×300 posters, gaps 40 × 66, first row at y 159. The count sits top-right, level with the tab.
- **Detail.** Full-bleed art for the first screen only. Bottom-left: logo or title, kind line with rating, 4-line overview, facts (year · runtime · time left), then the action row ending at y 960 (60-high pill, 63px circles). The next section peeks at y 1038: season tabs and 410×230 episode cards (EPISODE n, title, 3-line synopsis, runtime) for series; a Chapters shelf for movies with chapter metadata.
- **Player.** Lower third only: eyebrow (S1, E2 · Episode, or year · genres) and title on the left; Subtitles, Audio, Quality and version, Mute and Full screen circles (⌀ 70, 24 apart) on the right, ending at x 1840; a 10px timeline from 80 to 1840 with a white playhead; elapsed time under the playhead with a play/pause glyph, remaining time at the right; then transport circles and Chapters / Next Episode pills. A gradient darkens only the lower half.

## Focus and motion

One focused element, always visible, always white.

- **Keyboard focus never animates.** Fill, lift and shadow land on the same frame as the key press; transitions exist only for pointer hover and press.
- Buttons, pills, circles, rows, keys, tabs, menu rows: focused = solid white fill, black label; buttons lift (scale 1.06).
- Cards: lift (scale 1.08) with a deep shadow and a faint specular edge, as on tvOS; no ring. The caption brightens.
- Press: scale 0.97, 120 ms, `cubic-bezier(0.23, 1, 0.32, 1)`.
- Sidebar panel: materialises from the tab (opacity + scale 0.96 → 1, 240 ms, iOS drawer curve), collapses faster (200 ms). Menus grow up from their control (160–200 ms, origin at the control). Both are occasional, so they may move; reduced motion removes the scale.
- Hero carousel copy fades over 220 ms; backdrops cross-fade over 280 ms.
- Player chrome: appears in 150 ms, hides after 4 s of playback over 400 ms. Paused, an open menu, or an error keeps it visible.
- `prefers-reduced-transparency` makes materials solid; `prefers-contrast: more` raises secondary text and outlines glass.

## Remote mapping

| Key | Browser preview | Behaviour |
|---|---|---|
| ← ↑ → ↓ | Arrow keys | Spatial move. Left at the content edge, or Up from the top row, opens the menu; Right returns |
| OK | Enter | Activate |
| Back | Esc / Backspace | Close menu → hide player controls (playing) → leave player → previous screen → Home |
| Play/Pause | Space (on the timeline or video), `k` | Space on a focused button activates it |
| Rewind / Fast-fwd | ← / → on the timeline, `j` / `l` | −10 s / +10 s |
| Options | `c` | Subtitles menu |
| — | `m`, `f` | Mute, full screen (browser only) |

## Playback choices

Contract: `docs/playback-controls-contract.md`.

- **Menus.** Subtitles (Off + every track), Audio (every track) and Quality and version (the server's quality ceilings, then its versions, then what is actually playing: decoded size from the video element, codecs, bitrate, Direct play / Transcoding). Labels come from the server verbatim. Empty states say what is missing (“No subtitles in this version.”; the demo says it plays one 480p sample). Rows are radio items with a check; arrows move, Tab wraps, Home/End jump, Escape/Back closes and focus returns to the control.
- **Switching.** A choice pauses the old stream, negotiates at the current absolute item time with every other choice resent, then stops the old session and attaches the new one, resuming playback only if it was playing. Rapid choices compose (audio then quality keeps both); only the newest response attaches, and superseded sessions are stopped. While a request is in flight the old check stays and the new row shows a spinner; a failure keeps the old stream and says why. Changing version resends only the quality and Off, because stream indices belong to a version.
- **Subtitles.** Off renders nothing. Burned-in (`encoded`) subtitles are never also drawn by the browser; only an `external` selection renders, and only that one track.
- **Sessions.** Every negotiated session is stopped exactly once (retired by a switch, superseded, abandoned during load, or on leaving), whether or not it played. Negotiation is owned by the player screen, not the shared data cache, so refreshing library data never starts playback again.
- **Chapters and Next Episode** appear only with real metadata: `item.chapters`, and an episode after this one in its season (or the next season's first).

## Screens and states

- **Connect**: discovery runs on arrival and can take up to 25 s ("Looking for Jellyfin servers… 4s"). Found servers list name, `host:port`, network tag, and "Signed in before" when it matches the remembered server. When the first server arrives and the user hasn't typed an address, focus moves to it. Manual address is always below. Diagnostics fold away under "What Luma tried".
- **Sign in**: username, then password (focus starts on password when the username is remembered). The password goes to the server once and is never stored; the gateway keeps the token. **Choose another server** returns to discovery.
- **Home**: featured carousel (resume item first, else latest), then shelves: Continue Watching (plays), Recently Added, Movies, TV Shows (open details). Empty shelves are omitted. An empty server shows one honest empty state.
- **Movies / TV Shows / Search results**: poster grid, 100 per page, then **Show more · 100 of 1,240**. After it loads, focus moves to the first new poster. Counts come from the server total.
- **Series detail**: one primary button, "Resume S1, E2" or "Play S1, E1" (first in-progress, else first unwatched). Season pills select on focus.
- **Account**: avatar, name, "Signed in to media-pc", server, address, network tag, server ID; **Switch server**, **Sign out** (press twice). Offline: "Can't reach server", last address, "Julio (kept)", **Try again now**, **Find on network**, **Forget this server**.
- **Settings**: Account row → Account; remote keys; demo credits while the demo is active.
- **Errors**: say what failed and what to do, with a Retry that works. No dead buttons and no spinners without an end.

## Assets

Demo art lives in `public/demo/art` (credits in `CREDITS.md`) and loads only inside the demo. On Roku, use server images at `maxWidth=500` (posters) and `1600` (backdrops, also used for landscape cards), matching the gateway.
