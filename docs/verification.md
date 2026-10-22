# Verification — 11 October 2026

## Automated checks

- `npm test`: 63 server/native test cases pass (54 server cases plus nine native groups). The six behavior groups execute 455 passing assertions, with three additional native allocation/visual-state groups over identity, session persistence, DHCP recovery, playback reports, request backpressure, navigation, real stream choices and replacement lifecycle.
- `npm --prefix preview test`: 82 browser-component and state tests pass, including connection-first onboarding, explicit temporary demo mode, pagination, account changes, stale responses, resume timing, stop reports, and the asynchronous HLS initialization regression.
- `npm run build`: TypeScript/Vite production build and BrighterScript channel build pass.
- `python3 scripts/check-package.py dist/luma.zip`: manifest, component XML, packaged scripts, fonts and image references resolve. No session data or development dependencies enter the channel ZIP.

## Browser and network checks

Browser walkthroughs used the T3 preview, then isolated headless Chrome after the T3 browser host disconnected. Screenshots are in ignored `artifacts/`.

- The live home's Jellyfin server was found without entering its IP. Its UDP reply was absent; the bounded HTTP fallback found it in approximately 8.3 seconds. The actual server's Jellyfin 12.2 specification advertises all 15 core routes checked by `npm run check:server`.
- Demo navigation, arrow/Enter/Back controls, search results and empty search, series/episode browsing, sample playback, seeking and saved demo progress worked.
- An isolated local fixture exercised the complete discovery → sign-in → library flow, independent of the real account.
- HLS and direct H.264/AAC MP4 decoded actual video frames in Chrome. Pause and exit reported resume positions. The bundled test Chromium lacks the required H.264 codec; installed Chrome provided the media validation.
- Moving the fixture's address while leaving a different identity at the old address reconnected automatically. Login count remained one and the wrong identity received zero token-bearing requests.
- An outage preserved the account; retry restored it without login. Revoking the token requested sign-in.
- Desktop 1920×1080, laptop 1280×720 and phone 390×844 had no horizontal document overflow. No browser page errors occurred in the completed walkthroughs.

## Hardware verification remains

The user entered credentials privately through the preview UI. The gateway is authenticated to the real LAN server. A real movie and episode decoded 1920×1080 video in installed Chrome over the home network; movie pause and exit also worked. This verifies those sampled files, not every library format.

The native ZIP has not been installed or run on the Philco G510X. SceneGraph rendering, socket behavior, native remote focus, TLS and hardware decoding require the [Roku acceptance pass](../tests/roku/HARDWARE.md). The browser is a working client and visual preview, not a Roku emulator.

## Native desktop simulator acceptance

- Installed the official BrightScript Desktop Simulator 2.6.2 macOS archive and verified its published SHA-256 digest. The embedded engine is 2.6.1, with SceneGraph extension 0.6.1. The isolated local profile reports G510X and OS 16.0.4, uses 1080p UI and pt_BR locale; model identity does not reproduce Philco hardware.
- `npm run simulate:roku` builds/reloads the actual native ZIP. The remote viewer at `http://127.0.0.1:8090/` showed the real home library and artwork, native title details, and real movie and episode video. ECP remote input worked. Luma contacted the PC directly over the LAN, independent of the browser gateway for data/playback.
- The existing preview authorization was privately copied into the isolated simulator registry only after public server-ID verification. Reloading the ZIP and fully restarting the simulator process both retained that account and reopened the real library. Credentials are not part of the package; native first-time sign-in was not exercised in this pass.
- The runtime pass found and fixed white-backed transparent gradients. The audit also fixed Task result event consumption and restoring player controls when reopening playback.
- A live paused subtitle change initially hid a replacement video while it continued playing. Replacement now uses Roku's explicit asynchronous stop acknowledgment before creating the next Video node. Retest showed the new stream visible and paused, with Portuguese subtitle index 0 selected and controls no longer busy.
- Native on-screen menus then changed quality to 720p and audio to English. Jellyfin's live Luma session confirmed paused state, audio index 3, subtitle index 0 and a 1280×720 H.264/AAC stereo transcode at 5.872 Mbps. This confirms the actual stream choices and server output; the video-only remote viewer did not provide an auditory check.
- Resume accuracy cannot be validated with this engine: a live replacement's native `content.playStart` was 12 seconds, but the simulator started it at 0. Its source drops that metadata. This is distinct from the fixed stop-event race.
- Discovery also remains unverified here: the simulator's UDP helper fails, and its synchronous HTTP implementation can stall subnet scans before app deadlines can run. Luma's real asynchronous discovery was preserved. See [simulator limitations and sources](roku-simulator.md).
- The photographed TV address did not answer ECP or the developer installer, and a bounded local Roku discovery probe got no response. No physical device was sideloaded; its current IP/developer-mode state still needs confirmation.

Native Auto preserves compatible video, including HEVC up to 4K with runtime decoder checks and HDR10 with additional display checks, while retaining bounded H.264/stereo fallback. Original direct play remains unchanged-file playback. Physical G510X decoding remains unverified. Audio, subtitle, quality, version and chapter controls are implemented. Quick Connect and native automatic next-episode playback remain outside this version.

## Connection-first and Apple TV design follow-up

- Direct HTTP identity verification was repeated with proxies bypassed and `curl --interface en0`; the PC responds through the home network, independent of Tailscale.
- Automatic discovery now excludes Tailscale and known VPN tunnel adapters. A live credential-free discovery pass used only `en0`, found the PC through HTTP fallback, and produced no tunnel broadcast errors.
- Authenticated Home, Movies, and Shows requests returned 86 movies, 27 shows, and the real continue-watching list. Each was repeated three times with successful responses; the browser rendered the pages and artwork.
- Restarting the local gateway preserved the real saved login and connected directly to the same server without another password.
- The user clarified that “Something went wrong” occurred on playback. The failure was reproduced as HTTP502 `unsupported_media`: Jellyfin returned a dashed GUID in `/videos/{id}/master.m3u8`, while the item JSON used the equivalent compact GUID. Media validation now compares complete GUID segments canonically while preserving the original upstream URL, server origin, base path and item boundaries. Regression tests failed before the fix and passed after it, including nested HLS media, subtitles and rejected mismatched IDs. The native URL resolver already accepted the observed shape and now has explicit regression coverage.
- After restarting the gateway, the formerly failing playback negotiation returned HTTP200. Browser checks decoded a real movie and episode, with no page errors. Home, Movies, Shows, search, details, back navigation, sidebar keyboard focus, and layouts at 1920, 1280 and 390 pixels also passed.
- Updated browser and native UI: left sidebar, landscape home cards, black/charcoal surfaces, white controls, sans typography, immediate keyboard focus and scrolling. Physical native rendering still requires the TV.
- The redesigned preview was rechecked against the isolated fixture: moving the address recovered without another login, the reused old address received no tokens, offline mode retained the account, and retry restored the library. Demo content appeared only after an explicit selection and disappeared after reload.

## Live stream-control acceptance

- Actual Jellyfin metadata exposes three audio tracks and all 16 subtitle tracks on the sampled multilingual MKV, including sparse indices and image-based PGS tracks. Selection options use those real indices, not array positions.
- A resumed 720p negotiation initially returned successful HLS playlists but failed on media segments. The upstream response was HTTP400: Jellyfin dynamic HLS does not allow nonzero `StartTimeTicks` on segment routes. The gateway and Roku now omit that query parameter and seek on the full item timeline. A regression reproduced the failure before the fix.
- With the fixed gateway, both first and resume segments fetched and decoded for audio 3 with text subtitle 0, PGS 6 and Off at 720p, plus Auto/Off at 1080p. `ffprobe` counted 96 H.264 frames and 190 AAC stereo frames per tested segment; `ffmpeg` decoded without errors. Scoped stop cleanup passed, and saved session bytes stayed unchanged.
- Root independently repeated browser decoding through the restarted main gateway in installed Chrome. Text/PGS at 720p decoded 1280×720; commentary audio 4 with subtitles Off at 480p decoded 853×480. Each advanced over three seconds from the requested position around 12:46, with 114 video frames and no fatal HLS errors. Screenshots visibly confirmed Portuguese text and English image subtitles on the same scene. The saved resume position was restored after these probes.
- These checks validate actual output and timing for the sampled choices; they do not substitute for physical Roku decoding tests.
- The full redesigned app was then exercised through SessionProvider and the on-screen menus. Commentary audio 4, 720p and subtitles Off produced ready replacement video streams, retained the other settings and stayed paused at the same position (0.0-second delta on the audio switch). The 720p output decoded at 1280×720. All 17 subtitle choices including Off were reachable; End, Tab wrap, Escape focus restoration, Play/Pause and exit worked without page errors. Negotiations stayed bounded at five (two development StrictMode initial attempts plus three explicit switches).
- This full-app test caught two integration bugs that isolated decoder tests did not: the session wrapper discarded playback options, and global cache invalidation on player cleanup could recursively negotiate streams. Options now reach the gateway, and playback negotiation has its own lifecycle outside the shared library cache. Regression tests cover the full provider path and repeated invalidation.
- Final real-library screenshots covered Home, overlay navigation, movie detail, Movies (86), Shows (27), a series with four seasons (25 episodes in the first, 12 in the second), and the player. Home at 1280×720 and 390×844 had no horizontal document overflow; movie/series screens at 1920×1080 also rendered without page errors.

## Final design and control handoff

- Applied the latest checked upstream Emil Design Engineering and Apple Design guidance and measured the official TV screenshots. `preview/DESIGN.md` records exact geometry and deviations; this is a close adaptation, not verified pixel identity. The browser adds mouse-friendly transport/fullscreen controls, the library omits Apple’s category column, and the open audio/subtitle menu styling is inferred rather than measured.
- The isolated multi-version fixture exercised changing source versions while paused. The request sent the version ID and retained quality without leaking track indices from the previous file; the UI checkmarks and decoded-size summary updated. This validates the version-switch path, not a second real file from the user’s library.
- Final visual corrections cap the sidebar blur, darken player controls over bright video, size posters to 200×300 at 1080p, and end detail artwork before the episode/chapter rails. Production build passes after these corrections; all 81 preview tests pass. The lazy hls.js bundle retains a non-fatal 574 kB size warning.

## Quality-first performance pass

- Preserved source video through compatible direct play and audio-changing remuxes. Three alternating real-LAN trials reduced first HLS media median from 511 ms with forced encoding to 216 ms with video copy (about 58%); this is not TV startup time. All 72 sampled decoded frames matched the source in the copied output, versus different hashes in the encoded baseline.
- Exercised all six native profiles against the real server. Compatible Auto/Original/1080p stayed unchanged; lower profiles decoded at 1280×720, 852×480 and 640×360. Text and PGS subtitle output decoded successfully.
- Corrected an additional 4K bug: mixed H.264/HEVC HLS profiles applied H.264's 1080p dimensions globally. Strictly eligible HEVC now negotiates separately, validates the returned copy controls, and falls back to a fresh bounded H.264 request if needed. Real response replay passed with one negotiation, and actual 3840×1600 SDR plus 3840×2160 HDR10 output matched all 72 sampled source frames. HDR10 output retained 10-bit pixels, BT.2020 primaries and SMPTE ST 2084 transfer. This tests the server and local decoder with supplied capabilities, not the powered-off TV.
- Native carousel/menu/card work now reuses bounded nodes, fonts and effects; warm tests avoid thousands of allocations. Browser player updates retain precise timeline/report values while reducing 40 subsecond-event renders to at most one commit. No CSS, artwork compression or animation duration changed.
- Browser codec conversion no longer forces HEVC/AV1 output into the source codec's numerical bitrate. Original preserves Jellyfin's negotiated target; Auto and explicit profiles cap that target to their existing total budgets. The live HEVC-to-H.264 Auto and Original outputs both decoded successfully.
- Browser UI retest passed paused audio changes, 720p changes, subtitle selection/Off, long-menu keyboard navigation, playback and exit without page errors. Native simulator retest showed unchanged Home/detail layouts, visible player controls, checkmarks and subtitle scrolling after the reuse changes. Native QA restored the pre-test resume/history values. T3 snapshot timeouts required the documented installed-Chrome fallback.
- Full build, package inspection and all 15 advertised live API routes passed. Runtime native discovery/resume limitations and physical-TV measurements remain as above.

See [performance and quality](performance-and-quality.md) for methodology, budgets, hardware sources and reproducible checks.

- The user authorized the best-quality server option. Enabled only `EnableTonemapping`, preserving all other encoder settings and retaining a private backup. Real HDR material converted and decoded at all four lower-resolution profiles with BT.709 metadata; fresh server logs confirmed CUDA tone mapping and H.264 NVENC with no conversion errors. This affects other Jellyfin clients as well.
- After enabling tone mapping, repeated the compatible 4K HDR10 copy case: one accepted native negotiation, 3840×2160 HEVC, 10-bit BT.2020/PQ and 72 exact source-frame matches. Both localhost services and the latest native ZIP remained running at handoff.


## Physical Roku startup fix — 2026-10-12

- Reproduced immediate startup exit on Philco G510X, Roku OS 16.0.4 build 821. The original installed ZIP (161059 bytes) exited with `EXIT_APP_ERROR` before `Main`.
- Physical package isolation narrowed the failure to declaring `RunService` in the Task script. A minimal `init` alone launched; adding an empty `RunService` reproduced the exit. Changing only that callback name and its `functionName` reference to `RunJellyfinService` let the complete app launch. This is an empirically confirmed firmware name incompatibility, not a documented reserved BrightScript keyword.
- Rebuilt and installed the clean final `dist/luma.zip` (161121 bytes), with no diagnostic entry-point prints. The TV stayed in Luma and its own screenshot showed automatic discovery of `media-pc` and the sign-in keyboard. Native sign-in/playback beyond that screen was not tested in this pass.
- All 63 existing server/native tests passed. `build:roku` now runs the package checker, which rejects this incompatible function declaration. The checker failed against the preserved original ZIP and passed against the fixed release.
- Diagnostic packages, device logs and the real-TV screenshot are isolated in ignored `.local/diagnostics/`; none are shipped in the final ZIP. The browser UI and playback profiles were unchanged.


## Native navigation verification — 2026-10-12

On the Philco G510X, Roku OS16.0.4, the previous package reproduced overlapping focus: opening the sidebar left RowList in the focus chain, and Down moved the background shelf. The updated package targets sibling Groups for sidebar/actions, suspends shelf input while loading, and lets Back abandon a navigation request without stopping account work. Late cancelled responses cannot replace a newer page.

Physical checks on the installed build:
- Sidebar has focus and shelf does not; Down stays in the sidebar; Right restores the previous shelf title.
- Continue Watching: horizontal selection, Up to action, Down to shelf, details and Back all work.
- 80 rapid direction inputs across10 repeated shelf/action/sidebar cycles restored exclusive shelf focus every cycle.
- Immediate Select→Back returns to the shelf and remains there after the response arrives.
- Card scale sampled during animation at1.0273 and settled at1.04; outgoing card returned to1.0. Page entrance translation sampled mid-animation, then settled. Native animation nodes handle frames; warm card/carousel/menu allocation checks remain zero.
- All63 automated test groups pass;115 navigation assertions include physical-device focus behavior and request cancellation. Resume tick conversion additionally covers JSON integer values.

Apple TV17.0.28 (channel551012) launched successfully, but production-channel inspection returned `Channel access not authorized: active UI`; installer screenshot returned `Screenshot not ok`. Exact Apple TV motion timing/pixel parity could not be measured. The160ms card/page and120–180ms drawer motion are deliberate approximations, not claimed measured parity.

Package SHA-256: `cffb906f6ae5f7e50b16101ac91790c49568359c403e6fdb0db1bfa51371048a` (163206bytes). Authenticated installer reported Install Success. Private hardware traces are ignored under `.local/navigation/` and must not be published: SceneGraph URLs can contain account tokens.


## Collapsing Home hero — 2026-10-12

Reproduced on hardware: Up to the hero and Down into Continue Watching both left shelves at y712, so browsing retained a full-height hero. Home now retains two RowList rows and animates only cached parent transforms/opacities. Entering shelves scales hero identity to66%, fades its secondary copy/actions and dims artwork; the shelf parent moves up372px. Up from the first shelf restores the full hero. Sidebar preserves the content layout; leaving Home resets all transforms even if expansion is interrupted.

Hardware showed card scale clipping at RowList item boundaries. Added12px internal card padding, expanded each item's layout envelope and preserved card/image size and horizontal pitch. Landscape base moves to y688; compact shelf origin is y316. The two-row bounds finish at y1014, above the footer.

Verified on the installed final package: full/compact focus and geometry, mid-frame interpolation,12 rapid Up/Down reversals, details at normal scale, Back restoration, and lower-row navigation. Local tests:64 groups pass, including100 layout reversal/page-exit cycles with zero warm node allocations. Final package SHA-256: `6037e66c6d0f572cf318b89aa7a916b592e4ad375063885c954b3a517f6992bf`.


## Typography and motion refinement — 2026-10-12

Final native checks: Home eyebrow hidden; metadata stays unscaled at28px and moves from y333 to y246 when compact. Details retain y842 and normal scale. Card titles26px/40px high, row labels32px and footer24px; no unsupported arrow/star glyphs in the Home hint. RowList's firmware animation is enabled. Physical Down at70ms showed a transition, with the next row settled afterward. Twelve fast horizontal reversal inputs retained shelf focus; Left opened sidebar with no underlying shelf focus; Right/Up restored action focus. Details→Back restored compact metadata and exclusive shelf focus. The280ms hero transition uses documented piecewise easing (15% ease-in,75% ease-out), with retargeting and no per-frame BrightScript work.

All64 test groups pass. This is an Apple-reference-informed adaptation, not a measured pixel/timing clone. An Opus5.5 visual audit compared official Apple screenshots and Luma's real capture; Astra verified REA's current README plus52 docs: no documented Roku/BrightScript/SceneGraph bridge. Its Apple application analysis consumes supplied artifacts and does not expose installed Roku channel551012 through the denied ECP interface.


## Brazilian Portuguese and clean footer — 2026-10-12

Native interface uses pt-BR for navigation, connection/sign-in, settings, shelf labels, empty states, playback controls, quality/track fallbacks and generated errors. Media titles, descriptions and server-provided track names remain Jellyfin metadata. Transport keys, media types and quality IDs are unchanged. Removed bottom navigation guidance from Home and player; hidden controls never restore it.

All64 native/server test groups pass. Actual Roku SceneGraph checks confirm Continue assistindo, Adicionados recentemente, Filmes, Séries, Ajustes, Áudio, Legendas and Qualidade. Both hint nodes remain hidden; sidebar retains exclusive focus. Final screenshot `.local/diagnostics/luma-ptbr-final.jpg` confirms accented text and clear footer. Player labels measured with bundled23px Hanken font: longest Reproduzir114px fits128px button. Package SHA-256 `886d8da981547634e2a8e8aa3a4479cbeac667ac8154d4482c862028849edd93` installed successfully.

Browser preview localization also covers visible controls, accessibility labels, quality descriptions and mapped API errors. Preview validation: all 88 tests across 13 files pass; TypeScript and production build pass.


## G510X HDR and external-caption verification — 2026-10-12

- Runtime display reports 2160p60 and HDR10 support, no Dolby Vision. Avatar 2 source is 3840×2160 HEVC Main10, PQ/BT.2020, Dolby Vision profile 7 with HDR10-compatible base layer; video bitrate approximately 52.7 Mbps.
- Default six-second copy segments exceeded the TV's 31.6 MB playback buffer; one/two-second variants exceeded its playlist-size limit for this long film. Explicit three-second, keyframe-aligned HLS preserved the original HDR10 base-layer video and decoded on the TV. A diagnostic Video node reported 3840×2160 and hdrMode=2 (HDR10), sustained more than 90 seconds, and resumed around 7200 seconds after a timed seek. Only audio was converted (AAC stereo; no Atmos claim).
- Production Maximum policy replay against fresh Jellyfin negotiation passed in one POST. Installed production Luma played HEVC at approximately 55 Mbps with a 4.2-second quality switch. An audio 2→3 switch completed in 6.89 seconds and retained paused state/position. Audio switching is still a decoder/stream replacement, not seamless.
- Baseline external-SRT selection replaced the decoder and took 5.09 seconds. Updated production selection retained the same Video node and remained playing throughout 2.4 seconds of polling; position advanced and no startup/buffering occurred. This measures uninterrupted playback, not exact first-caption rendering latency.
- Native player/navigation icons use the same SVG geometry as the browser. 66 test groups passed, including 215 playback-option and 87 replacement assertions; native compiler and package validation passed.
- Roku documents installer screenshots as UI-only, excluding content playback. The captured HDR video plane was corrupted while controls were intact; the user directly confirmed the film image is normal on the TV. Caption appearance was not separately confirmed. Production Luma runtime inspection also returned width=3840, height=2160, hdrMode=2, caption mode On, captions unsuppressed and an external track selected.
- Sources: https://developer.roku.com/dev/docs/developer-setup ; https://developer.roku.com/dev/docs/video ; https://github.com/jellyfin/jellyfin-roku/blob/master/source/utils/deviceCapabilities.bs .
- Decoder frame-counter collection through the live debugger was inconclusive and is not reported as a zero-drop result. The debugger session was ended by relaunching the installed Luma app; native UI/focus and active-app checks then passed.


## Integrated search and held seek — 2026-10-12

- Opus implemented the on-page keyboard/results layout. Actual G510X capture: `.local/diagnostics/luma-integrated-search.jpg`. Query entry, keyboard/grid handoff, result → details → Back with the same selected card, keyboard → menu → keyboard, and Limpar were exercised on the TV. No system keyboard dialog opens for search.
- Search pagination was restored after review found the first implementation stopped at 48 results. A real 144-result query reached 49–96 using fast-forward and 97–144 by going down past the last row. Up at the first row returns to the prior page. Only 48 results are retained per page; edits reset the offset and stale replies cannot replace the current query.
- Held left/right and FF/RW preview on a 200 ms timer: 10-second steps initially, 30 seconds after two seconds, 60 seconds after five. Release performs one seek, preserving the prior playing/paused intent. A hidden HUD consumes a short arrow tap to reveal controls; continuing to hold starts movement.
- A single six-second Right keydown on the TV moved the target from 0 to about 14:30 while the same Video node remained paused at 33 ms; release completed in about 5.5 seconds. The initial build exposed a firmware behavior that resumed paused HLS after seek despite autoplayAfterSeek=false. A one-shot pause acknowledgement fixed it, and the installed build stayed paused at 867.9 seconds.
- A 2.8-second Left hold while playing accelerated from 10- to 30-second steps and resumed playing after release with the same Video node. Cancellation is covered by the native-code test; an ECP sequence that pressed Back while holding Right committed before Back and is not reported as a physical-remote cancellation pass.
- One initial resumed playback stalled for the 45-second test timeout. Starting from zero took 5.28 seconds; a later resume around 11 minutes took 5.57 seconds. The isolated startup stall was not reproduced or attributed to these changes; it remains an observation, not a fixed bug.
- All 71 native/server test groups passed, including 39 held-seek assertions, 95 playback-switch assertions and 53 search-screen assertions. Native compile/package checks passed. The final paginated build was installed through authenticated Chrome and its pagination behavior verified on the TV. Browser-preview files were unchanged.
- Package SHA-256: `f2a89f143389670c09115d288f8c2abacebdd7b1226e86a78e3717dc56da85f8`.


## Simulator audio resume correction — 2026-10-12

- Reproduced an audio replacement returning to 0:00 in the native desktop simulator. Regression coverage failed before the fix because the scene accepted the first `playing` state without checking the requested bookmark.
- Added position acknowledgement, one corrective native seek when required, pause preservation, hidden/muted startup until the bookmark lands, and a bounded recovery path. Pending zero samples never replace saved progress. Correct native bookmarks avoid the extra seek.
- Added execution coverage for incorrect/valid bookmarks, one-shot seeking, playing/paused intent, late timeout, failed resume cleanup and original progress retention. Full suite: 71/71; playback-switch suite: 121 assertions; native build/package validation passed.
- Verified real Avatar 2 media in BrightScript Desktop Simulator: paused 3:30 → alternate audio → paused 3:30; playing reverse switch retained the nonzero timeline and continued past 4:39. No physical-TV verification of this change yet.
- Research: [Apple AVFoundation alternate track selection](https://developer.apple.com/documentation/avfoundation/selecting-subtitles-and-alternative-audio-tracks) selects a track within the current player item; [Jellyfin Roku onAudioIndexChange](https://github.com/jellyfin/jellyfin-roku/blob/master/components/video/VideoPlayerView.bs) captures the current position before stopping/reloading metadata; [Roku bookmarking](https://github.com/rokudev/dev-doc/blob/v2.0/docs/DEVELOPER/media-playback/bookmarking.md) documents absolute Video.seek for resume. This app's current Jellyfin HLS path carries one selected audio track, so instantaneous multi-rendition switching is not claimed.


## Visible details Back action — 12 October 2026

Opus 5.5 implemented the pt-BR Voltar action for native detail pages. The regression test failed before the change (Up focused nav instead of back). Full suite passes 71/71, including 140 navigation and 58 search-scene assertions; compiler and ZIP package checks pass.

Root visually verified the actual native simulator: Home → Avatar: Fogo e Cinzas details displays Voltar; Up from Continuar highlights Voltar without opening the sidebar; OK returns to Home with the same Avatar card selected. The rebuilt ZIP is running in the local simulator. No TV deployment in this pass.


## Saved credentials, skip intro and Apple TV parity — 22 October 2026

- **Saved credentials:** the Roku Task stores `loginName`/`loginPassword` beside the token (keys chosen to avoid colliding with the display `userName`, since BrightScript keys are case-insensitive). A 401 triggers one identity-checked re-authentication and a single retry. Bootstrap signs in automatically when only credentials remain. Logout clears both. The browser gateway mirrors this. Unit tests cover re-auth success/failure, empty passwords, mismatched server IDs and logout.
- **Intro segments:** the live server (Jellyfin 12.2, Intro Skipper 12.0.5.0) returns segments from `/MediaSegments/{id}`. For example Futurama "Quero meu corpo de volta" has Intro 0–29.7 s and Outro 1308.8–1352.0 s; Cyberpunk: Mercenários T2 E2 has Intro 9.9–98.1 s. The legacy plugin routes return 404 on this server and remain fallbacks, with chapter names as a final fallback. Segments are fetched by a background `segments` action after playback starts. The simulator boxes JSON integers as `roInteger`, which exposed a type check that dropped intros; all numeric type names are now accepted.
- **End-to-end in the simulator:** Futurama played from the start showed **Pular abertura**; one OK moved playback from the intro to 0:36 without opening the HUD. Cyberpunk T2 E2 started from the show page's next-up action and showed the pill with the redesigned HUD.
- **Parity:** see the dated section in `docs/apple-tv-reference-audit.md`. Home Play → playback → Back reloads Home on the same featured title with its logo. A same-URI logo bug that showed plain text after a refresh was fixed.
- **Tests:** `npm test` 71/71 (164 navigation, 53 player-control assertions). `npm run check:roku` and `npm run build:roku` pass. The server UDP discovery test flaked once while the simulator was loading the machine and passed 3/3 in isolation.
- Not done in this pass: physical TV sideload (the TV was in use).


## One-press play, ambient mode and season posters — 22 October 2026 (second pass)

- **One-press play:** episode cards and started movies play on OK through the existing details→play path without pushing a page. The remote Play key does the same for any movie/episode. After playback, Home reloads focused on the shelf (Continue Watching at its first card); show pages refresh focused on the rail; library pages keep their card. Simulator: Home → Down → OK started the Futurama episode immediately; Back×2 returned to Continue assistindo.
- **Ambient mode:** new `AmbientScreen` component, idle timer 180 s. Verified in the simulator with a temporary 15 s timer: random backdrops with left-aligned logos, metadata, pt-BR clock/date, crossfade and drift. Down dismissed it back to the Home hero without moving focus. This exposed a real defect: the component's node IDs (`meta`, `clock`, `title`) were found by the Scene's breadth-first `FindNode`, so the Scene drove the screensaver's labels. All ambient IDs now carry an `amb` prefix, and a scan confirms no other component ID collides with a Scene lookup.
- **Posters:** one cached (10 min) library-wide season query. A newest season ≥2 with its own Primary image replaces the show poster in Séries: Cyberpunk: Mercenários now shows its Season 2 art. Breaking Bad, Westworld and other shows whose only season art is season 1 keep the show poster. Séries sorts by `DateLastContentAdded`.
- **Tests:** `npm test` 71/71 (174 navigation assertions, new Task tests for season posters and search paging); `npm run build:roku` passes with 8 components.


## Skip pill, interface sounds and lost Up presses — 22 October 2026 (third pass)

- **Lost Up/Left on shelves:** Roku sets `RowList.rowItemFocused` only when a scroll step finishes ([RowList docs](https://developer.roku.com/docs/references/scenegraph/list-and-grid-nodes/rowlist.md)). The Scene compared it with row 0 / column 0, so a quick second Up or Left that RowList passed on while still animating was dropped. RowList consumes every arrow it can still move with, so any Up/Left reaching the Scene now leaves the shelf.
- **Keys ignored after a dialog:** `Dialog.close` is write-only and Back/Home dismiss a dialog without it; only the `wasClosed` event reports every dismissal ([Dialog docs](https://developer.roku.com/docs/references/scenegraph/dialog-nodes/dialog.md)). The Scene read `close`, so after Ajustes (or any dialog) every key that bubbled to the Scene was ignored and idle ambient mode never started. The Scene now tracks `wasClosed`. Reproduced in the simulator (Right after closing Ajustes did nothing) and fixed there.
- **Skip pill:** moved into `PlayerControls.xml`; rises 116 px with fade over 0.5 s (outQuintic), sinks in 0.25 s, over a bottom gradient scrim when the HUD is hidden. A skip offered during playback takes focus from the timeline, so one OK skips with or without the HUD. Left/Right on the pill scrub; while scrubbing the pill follows the preview without taking focus. Simulator: Cyberpunk T2E1 at 2:39 → Down → OK landed on 2:46.
- **Sounds:** three synthesized PCM WAVs on the Scene, shared by `PlayUISound` in `Utils.brs`. Scene keys play a sound only when focus, page, request, dialog or playback actually changed; RowList moves play from `rowItemFocused`, muted for 250 ms after programmatic `Focus()`. Simulator trace: 12 visible moves produced 12 ticks, a no-op Left produced none, OK/Back produced select/back. **Ajustes → Sons da interface** persisted across relaunch. Roku's own menu click is user-controlled ([forum](https://forum.developer.roku.com/t/how-to-disable-menu-sound-in-roku-through-brightscript-for-my-app/11233)); `roDeviceInfo.GetSoundEffectsVolume()` is not implemented in the simulator, so Luma does not read it.
- **Deeper sounds (follow-up):** the first tick was a 1.85 kHz glassy tone (power centroid ≈1.7 kHz, nothing below 500 Hz) and sounded thin. All three are now pitch-dropping low knocks with a muffled tap: power centroids move 288 Hz, select 223 Hz, back 219 Hz; under 0.2% of power above 2 kHz and at most 3% below 150 Hz, so small TV speakers still carry them. Apple's own sound files are not bundled.
- **Saved sign-in check:** the simulator showed the welcome screen after a relaunch. Its renderer had run 8 h at ~87% CPU and its HTTP to the server failed. Restarted the simulator: Luma opened straight to Home with the saved account.
- **Tests:** `npm test` 71/71 (179 navigation, 65 player-control assertions); `npm run build:roku` passes with 56 entries and a PCM WAV check.


## Remembered tracks per series and next episode — 22 October 2026 (fourth pass)

- **Remembered tracks:** an audio or subtitle choice made in the player is sent to the Task once it is actually playing (in-place SRT switches immediately; renegotiated switches at the next `playing`), stored per series (latest 20) and applied when a later episode of that series starts with no explicit indices. Matching is by language (pt-BR = por), forced flag, title, label, codec and external flag. Cyberpunk: Mercenários T2E2 has an extra forced Japanese track at index 6, so "Brazilian Portuguese" is #31 in E1 and #32 in E2; index memory would have picked European Portuguese. Original keeps defaults; Máxima applies only external SRT.
- **Next episode:** `/Shows/{id}/Episodes?StartItemId=…&Limit=2` returns the following episode, including across seasons (Futurama S1E9 → S2E1), and only the current item for a series finale. It is fetched with the intro segments after playback starts. Credits that run to the end show **Próximo episódio**; OK reuses the track-switch handoff, so the finished episode reports stopped once and stays playable if the next one fails.
- **Simulator, end to end:** Futurama T2E11 at 20:01 → English audio and Portuguese subtitles (Jellyfin session: audio 2, subtitle 4) → credits at 22:03 → Down, OK → T2E12 started with audio 2 and subtitle 4, and its recap pill appeared. The test episodes' watch state was restored afterwards.
- **Tests:** `npm test` 71/71 (178 Task, 229 playback-option, 149 playback-switch, 72 player-control assertions).


## Loading indicator — 22 October 2026 (fifth pass)

- New `LoadingIndicator` component: tvOS-style eight-spoke indicator (`images/activity.png`, rendered at 4× and downsampled) ticking in 45° steps every 0.1 s, over a soft dark glow (`activity-glow.png`) for contrast on bright art. It fades in after 0.25 s so quick loads show nothing.
- Scene: replaces the 44 px corner `BusySpinner` and "Só um momento…" text with a centred indicator; only discovery keeps a caption. `spinner.png` was removed. The `status` label remains as the invisible focus holder while requests run.
- Player: until the first frame, the title's backdrop is shown dimmed under the indicator (artwork from the card the play started from), then the layer fades out over 0.4 s. Switches and the next episode reuse it over the frame with their message; rebuffering shows the indicator alone; errors stay in the HUD.
- Simulator: Avatar: Fogo e Cinzas from Continue Watching opened on its dimmed poster with the indicator fading in at centre, then the video. Homem-Aranha details loaded in under 0.3 s and correctly showed no indicator.
- Tests: `npm test` 71/71 (85 player-control assertions, including the loading layer).


## Title art on tiles — 22 October 2026 (sixth pass)

- Library survey: 83 of 86 films and 24 of 28 series have a Logo; 81 and 22 have a Thumb. Thumbs are studio landscape tiles but inconsistent (one with no title, Breaking Bad's reads "TEMPORADA 1 COMPLETA", one has an Apple TV bug), so tiles use the backdrop plus the transparent logo instead.
- `MakeCard` adds `tileLogo` (Logo at `maxWidth=360`, vs 1000 for heroes) and `caption` ("T2, E1 · name" for episodes). `PosterCard` fits the logo inside 190×64 on the tile baseline once its bitmap loads, over `bottom-shade.png` (the skip scrim, renamed and shared), and falls back to the name. Show-page rails set `plainTile`.
- Simulator: Home's Continue Watching, Adicionados recentemente and Filmes para hoje show logos (Cyberpunk, Futurama, O Drama, Homem-Aranha, Eternidade, Matrix…); Os Mestres do Dinheiro falls back to its name; the Cyberpunk show page's Temporada 2 rail stays plain.
- Tests: `npm test` 71/71, including title-art checks in the card allocation test (no nodes or lookups during recycling).


## Interface sounds removed — 22 October 2026

- At the user's request the navigation sounds are gone entirely: the three WAVs, `scripts/generate-roku-sounds.py`, `PlayUISound`, the Scene/player key wrappers, the **Sons da interface** setting and its Task `preferences` action, and the WAV package check. Roku's own menu click still follows **Settings → Audio → Menu volume**. The dialog dismissal and shelf-edge fixes from the same pass stay.


## New Luma logo — 22 October 2026

- The old "L + dot" mark with a generic-font wordmark and an English splash tagline is replaced by a slim warm crescent (light at movie night; *lume*) beside a lowercase Inter SemiBold "luma", on a near-black vertical gradient with a soft bloom around the mark only. The splash carries the pt-BR tagline "Seu cinema. Em casa." in Apple's secondary gray.
- Assets: `channel-icon-fhd.png` 540×405 (`mm_icon_focus_fhd`), `channel-icon-hd.png` 290×218 (`mm_icon_focus_hd`, also the legacy side icon) and `splash.png` 1920×1080, all from `scripts/generate-roku-brand.py`; `splash_color` matches the gradient. The old `channel-icon.png` is removed.


- **Wordmark font (follow-up):** the user found Inter too plain and chose Fraunces Italic from nine candidates (Instrument Serif, Playfair Display, DM Serif Display, Gloock, Syne, Bricolage Grotesque, Fraunces Roman and the current Inter). Settings: Softness 100, Wonky 1, Optical Size 9, Weight 560. The file is OFL and kept in `scripts/brand-fonts/`, outside the channel package.
- **Moon closes the word (follow-up):** at the user's request the wordmark is now "Luma" with a capital L, and the crescent moved from a separate mark on the left to the end of the word, its hollow facing left so the final "a" nests inside it (chosen over a moon forming the a's bowl). The crescent is 1.55× the x-height, centred on it, with a hairline gap to the "a"; the lockup is centred on its ink box.


## Backend performance loop — 22 October 2026

Method: `/tmp`-scripted replay of the Task's exact request sequences against the live server (median of 5, from the Mac on the same LAN), plus a temporary `roTimespan` around each Task `Dispatch` in the muted simulator. Bytes are the device-relevant measure: the TV's CPU pays for every kilobyte in `ParseJson` and again when card data crosses from the Task to the render thread. No visual change in any iteration.

| Iteration | Change | Home | Filmes | Search "a" | Simulator Home (first load) |
|---|---|---|---|---|---|
| Baseline | — | 5 req · 888 KB · 401 ms | 2 req · 767 KB · 160 ms | 3 req · 1285 KB · 323 ms | 527 ms |
| 1 | Lists stop requesting `MediaSources` (unused outside PlaybackInfo; every track of every file) | 5 req · 167 KB · 202 ms | 2 req · 91 KB · 48 ms | 3 req · 191 KB · 125 ms | 227 ms |
| 2 | Home's four lists go out together (`HttpAll`/`ApiAll`; 401 and network failures still retry through `Api`) | 1 check + 1 batch · 167 KB · 51 ms (115 ms sequential, same run) | — | — | 233 ms (the simulator serialises "async" HTTP, so it cannot show concurrency) |
| 3 | Show pages: episodes and next-up fetched together; cards now say they are a show (`DetailsRequest` adds `kind`), so the show, its episodes and next-up arrive in one batch | — | — | — | Cyberpunk page: 4 → 2 round trips, 66 → 38 ms median (simulator unchanged visually: same hero, "Reproduzir T2, E2", rail lands on E2) |
| 4 | Search's first page asks for titles and episodes together (later pages keep the exact sequential paging) | — | — | 1 check + 1 batch · "a" 87 → 54 ms, "fu" 59 → 43 ms | — |
| 5 | Cards that play at once (Continue Watching, Home Play, the remote Play key) fetch the item and its stream catalog in one batch; the play request reads the catalog from the existing 30 s cache, so negotiation itself is unchanged | — | — | — | Up to stream negotiation: Avatar 57 → 44 ms, Cyberpunk 61 → 44 ms (4 → 3 round trips) |
| 6 | A server-identity proof is reused for 15 s at the same address and ID (recorded in `Verify`); a network failure, reconnect or new address proves it again before any token is sent. The DHCP-reuse tests still pass, plus new ones for the window, a changed address and a network failure | Home after any action within 15 s: 1 batch, no check | Library right after Home: 1 request | — | Press → negotiation: 63 → 37 ms (4 → 2 round trips); each check costs ~8 ms from the Mac, more on the TV, and progress reports during playback now skip it |
| 7 | Quality and speed: Dolby (AC-3/E-AC-3 ≤ 5.1) is advertised only after Roku's runtime `CanDecodeAudio` says yes; AAC stays first and stereo for conversions | — | — | — | Live server, TV-like capability: Spider-Noir HLS + stereo AAC → direct play of the original file; Breaking Bad likewise; Silo keeps DD+ 5.1 copied; Família Soprano unchanged (stereo AAC). Simulator (no Dolby) unchanged |
| 8 | Cards carry only the nine item fields the UI reads (`CardFields`) instead of the whole Jellyfin item; the synopsis and progress already travel as card fields | 89 cards: 173 → 18 KB of card data copied Task → render thread and kept in memory (−90%) | — | — | Home rendering identical: hero line "T2, E1 · …", tile logos, captions |
| 9 | Node gateway (browser preview): item pages stop requesting `MediaSources`, which its item mapper never reads; a gateway test now fails if a list asks for it | — | Gateway Movies page (100 items): 1,360 → 162 KB, 192 → 47 ms | — | — |
| 10 | Show pages: the episode list stops requesting chapters (rail cards never read them; playing an episode fetches its full item); next-up keeps them, and a first-episode fallback is fetched in full | — | — | — | Episode lists: Attack on Titan 249 → 194 KB, Fullmetal Alchemist 171 → 136 KB, Jujutsu Kaisen 95 → 76 KB; playing next-up still shows Capítulos |
| 11 | First Séries visit fetches the show page and the season-poster index together (later visits reuse the 10-minute index) | — | First Séries visit 53 → 31 ms; season-2 art still applied on that first visit | — | — |
| 12 | Playback's background lookup fetches intro segments and the next episode together (older-plugin and chapter fallbacks still follow only when segments are empty) | — | — | — | 2 → 1 round trip after the first frame; the skip pill still appears on Cyberpunk T2E2 |

End-to-end, replaying the original and current request patterns back to back from the Mac (median of 7, best of 2 runs; "now" assumes the usual case of an action within the last 15 s, otherwise add one ~8 ms identity check):

| Journey | Before | Now |
|---|---|---|
| Launch → Home | 215 ms · 888 KB | 51 ms · 167 KB |
| Open a show page | 63 ms · 36 KB | 26 ms · 32 KB |
| Press play on Continue Watching (up to stream negotiation, which is unchanged) | 60 ms | 28 ms |

Stopped after iteration 12: what remains is marginal (Home's full reload after playback is one batch; connection reuse is not under app control). The TV's slower CPU benefits more than these LAN figures show, from the ~80–90% smaller list and card payloads. `npm test` 71/71 throughout (230 Task assertions).

Constraint from the user, applied to every iteration: never trade streaming quality for speed. `PreparePlayback`, `PlaybackQualities` and the device profile are untouched by this loop.


## Clearer loading and instant return to Home — 22 October 2026

- **Loading:** the indicator now sits on a dark rounded panel (340×200, Apple dark material, 28 px radius) with an 88 px spinner and a label ("Carregando…" unless a step names itself), and page loads dim the screen behind it. It appears after 0.15 s (was 0.25 s) so a press always gets feedback, while instant loads still show nothing. The soft glow image is gone. Captured in the simulator with a temporary build that delayed details by 2.5 s; the source never contained the delay.
- **Return to Home:** stopping playback on Home used to send a blocking `home` request (spinner, remote locked) and then replay the page's entrance animation, so Home visibly reloaded. Now Home is shown at once with the watched title's progress bar updated locally, and a quiet `home` request (not busy) replaces the rows in place, keeping focus on the same title (`CardLocation`) and the same featured title. A failed quiet refresh leaves Home as it was. Simulator: Avatar played from the third Continue Watching card; after Back, Home was there within 0.4 s with Avatar moved to the front and focused, no panel or animation.
- Tests: `npm test` 71/71 (191 navigation assertions, including the quiet refresh, local progress and focus-following).

## Suggestions round: speed, richer pages, up next, library filters, profiles — 22 October 2026

- **Ambient black band:** the slow zoom scaled each slide around a centre point, and the simulator rendered that scale with an uncovered strip on the right. Slides are now 10% larger than the screen (2112×1188 at −96, −54) and pan by translation only, alternating direction; the pan never exceeds the overscan. Six consecutive simulator frames had no black rows or columns.
- **gzip:** every Task transfer calls `EnableEncodings(true)`. Home's four lists from the live server, median of 7: 164 → 71 KB on the wire; the decompressed JSON is unchanged.
- **Display-size decoding:** posters set `loadWidth`/`loadHeight` to their focused size (7% lift) and tiles ask for 400 px images and library posters for 240 px, so the TV decodes only what it draws. Image URLs no longer carry `api_key` (Jellyfin serves images anonymously).
- **Placeholder colours:** cards paint the average colour from Jellyfin's `ImageBlurHashes` until the image arrives, instead of flat grey.
- **Cached Home on launch:** the last Home rows are written to `cachefs:` after each Home load and rebuilt at start for the saved account only, so Luma opens on Home while the server is verified, then refreshes in place. The simulator wipes `cachefs:` between launches, so it shows the normal path; the TV keeps it until reboot. A missing cache file no longer logs a `ReadAsciiFile` error.
- **Details prefetch:** a card held in focus for 0.6 s is fetched in the Task; OK then opens it without the network. Cards that play at once and info pages are cached separately (a "play" prefetch skipped the page's extra rows and was briefly reused for the info page; caught in the simulator, fixed, and covered by a test).
- **Instant Resume:** manifest `sdk_instant_resume=1` and `run_as_process=1`, `customSuspend` stops playback and ambient mode, `customResume` refreshes Home quietly and signals `AppResumeComplete`. The simulator does not support Instant Resume; this needs the TV.
- **Watched marks:** watched titles carry a check, shows and seasons with unwatched episodes show the count (99+ cap); a title in progress shows its bar instead.
- **Cast and "Mais como este":** movie and show pages end with **Elenco e equipe** (round portraits, name and character or Portuguese job title, initials when there is no photo) and **Mais como este** (Jellyfin's similar items), fetched in the same batch as the page. A person's page shows their biography over the backdrop of their newest title and **Na sua biblioteca**; **Ver títulos** moves to that row. Simulator: Avatar: Fogo e Cinzas → Sigourney Weaver → back returned to the same portrait.
- **Up next:** in the final credits (or the last 20 s when there is no credits marker) the next episode's still and "T#, E# · name" rise above the pill, which counts down "Próximo episódio em 10…1" while a bar fills across the still. At zero, or if the file ends first, the next episode starts in the same player. Back withdraws the offer and keeps the credits playing; after three episodes in a row with no remote input the offer waits for OK. Simulator: Futurama T2E11 counted down and continued into T2E12, whose intro pill then appeared.
- **Library column:** Filmes / Séries / Coleções, then **Ordenar por** (Data de adição, A–Z, Ano de lançamento), **Gênero** (the category's genres from Jellyfin) and **Não assistidos**. Left from the grid enters the column; changes reload the grid and keep focus there. An empty result keeps the column and says why. Simulator: Séries → A–Z → Drama → Não assistidos removed the watched shows. This server has no collections (0 BoxSets), so Coleções shows "Nenhuma coleção na biblioteca."; a collection's page lists **Nesta coleção** in release order.
- **Profiles:** sign-in now records whether the profile is the server's administrator (a session saved earlier learns it once, alongside Home, from `/Users/Me`). Only then does Ajustes offer **Trocar perfil**, listing the server's enabled users. A profile signed in here before switches without the network; another asks for its password once (none if it has none) and is then kept per server, so switching back never asks. Other profiles can return to the administrator because the administrator's session is kept on this Roku. A wrong password asks again instead of signing out. **Sair da conta** forgets every profile on that server. Passwords are not kept in the scene's retry state. Simulator: the administrator's Ajustes showed Trocar perfil and the list (the administrator ✓ and two family profiles). Switching to another profile was not exercised live (it needs that profile's password); the Task tests cover it.
- **Trickplay (not built):** at Jellyfin's defaults (320 px, one frame per 10 s, 10×10 JPEG sheets, quality 90) this library's ~472 hours would add about 1.4 GB on the PC (0.85–1.8 GB depending on picture content).
- Tests: `npm test` 71/71 (Task specs cover the batched page extras, the person and collection pages, intent-keyed prefetch, profiles, filters and genres; 101 player-control assertions including the countdown, Back and the three-episode guard; 228 navigation assertions including the column, the menu and the profile setting).

## Seek-aware up next, progressive scrubbing, portraits and trickplay — 22 October 2026

- **Up next only when watched into:** the offer (and its countdown) used to follow the playhead, so seeking or scrubbing into the credits or the last 20 s popped it. Now it appears only when at least 10 s of uninterrupted playback carried the position into that zone. A seek or scrub that lands there, or lands less than 10 s before it and plays on, offers nothing. Seeking back before the zone and watching through re-arms it. Simulator: scrubbing Futurama T2E11 into its credits (21:41, outro 21:51–22:35) showed no pill or card.
- **Progressive hold:** a held Right/Left (or FF/REW) moves 10 s per step for 1.5 s, then doubles every 1.2 s. The top speed is about 1/36 of the video per step (never under a minute), so a 22-minute episode tops out at 1 min per step and a 2-hour film at 3 min 20 s. A tap is still a plain 10 s jump. The speed now shows above the preview only while holding ("Avançando · 3 min 20 s por passo"); it used to overlap the elapsed time when the playhead was mid-screen.
- **Portraits:** cast photos looked squashed because posters were decoded into a fixed box of the slot's shape (a 2:3 photo into a square). Cards, search results and the up-next still now decode by width only, keeping the image's shape, and the display mode crops it. Simulator: the Spider-Man cast row shows natural faces.
- **Trickplay generated:** on the server, trickplay is enabled for Filmes and Séries, sheets are 5×5 (1600×900, which a Roku decodes at full size) instead of 10×10, and generation runs on the GPU (CUDA decode and resize, below-normal priority); the existing "Gerar imagens Trickplay" task was started and also runs nightly at 03:00 for new media. First film: 3096 Dias de Cativeiro (1 h 50 min remux) took 6 min 20 s and 6.3 MB (3.4 MB per hour, so about 1.6 GB for the library); episodes take 1½–2 min each, so the full library needs about a day.
- **Scrub previews:** playback's background lookup (segments + next episode) now also asks for the item's trickplay sheets. While holding to scrub, a 320 px frame cut from the right sheet rides above the playhead (clamped on screen), and the title and buttons step aside as on Apple TV. Sheets need the session: Jellyfin 12.2 accepts it as `ApiKey` and refuses the old `api_key` name with 401 (the stream and subtitle endpoints are anonymous, so they are unaffected). Simulator: holding through 3096 Dias de Cativeiro showed the matching frames (a kitchen scene at 1:33:52, the closing logo at 1:49:49). Items not processed yet show no preview.
- Simulator quirk seen while testing: releasing a scrub near the end of a *transcoded* stream sometimes jumps that stream to its end (Futurama, stopped at 1355 s) or back to 0:00 (a film released 1 s before the end); ordinary mid-film seeks land correctly. Jellyfin's log shows the HLS transcode itself, not Luma's seek target, so this needs checking on the TV (item 35).
- Watch state touched by these tests was restored: Futurama T2E11 back to unwatched at 18:39 (twice; the up-next test in the previous pass had also finished it), 3096 Dias de Cativeiro back to no progress.
- Tests: `npm test` 71/71 (player controls 121 assertions with natural-playback, seek and scrub cases and the preview's sheet/cell maths; held seek 46 with the new curve; Task specs for the trickplay request and URL).

## Quick Right/Left presses that went back or stalled — 22 October 2026

Reported: pressing Right and letting go sometimes sent the playhead back and did not advance where intended. Reproduced in the simulator (two quick taps on 3096 Dias de Cativeiro left it paused at 0:41). Three causes, all fixed in `PlayerControls`:

- **Stale start:** after a seek the decoder keeps reporting the old position until the seek lands, and a new press started from that. Every seek (scrub, tap, skip pill, chapter, instant replay) now goes through `RequestSeek`. Until a report arrives nearer the target than the old position (or 10 s pass), the timeline shows the target and the next press starts from it, so quick presses add up and the playhead never snaps back to where it was.
- **Dropped presses:** presses were ignored while the decoder read "buffering", which it does right after every seek. Scrubbing now starts in that state too.
- **Lost play state:** the play/pause intent was read from the decoder state, which reads "buffering" or "paused" mid-seek; some players also never report "playing" again after resuming from a seek. The last seek's intent now stands until the decoder reports a state of its own. A tap no longer pauses at all (only a hold does, for the preview). If a seek meant to keep playing settles paused anyway, the scene resumes it once, unless you pressed pause in between (the mirror of the existing `seekPausePending`). Instant replay is now an absolute seek from what is shown; the relative `seek` action is gone.

Simulator after the fix: taps 0:14 → 0:26 → 0:41 kept playing. Hold → release at 11:11 → tap landed 11:23 and kept playing. A landing can still be up to one segment short: Jellyfin cuts transcodes into 3 s segments and restarts at one (`-ss 00:09:00.000`); direct play lands on the nearest keyframe. It never lands behind where you started. The simulator still shows the pause glyph after a resume because it never reports "playing" again; playback runs. 3096 Dias de Cativeiro's progress was reset to 0 afterwards.

Tests: `npm test` 71/71 (held seek 63 assertions: quick taps while a seek lands, buffering, paused intent, the 10 s fallback, instant replay; playback switch 156 with the resume-once rule).
