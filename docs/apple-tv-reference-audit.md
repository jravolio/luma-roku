# Apple TV reference audit — 11 October 2026

Use the living-room Apple TV app as the primary visual target. Official reference images are downloaded for inspection under ignored `.local/apple-tv-references/`; `manifest.json` records their exact source URLs. They are research material, not app assets.

## Design skill provenance

At the user's request, checked the author's GitHub repository directly on 11 October 2026. Both [Emil Design Engineering](https://github.com/emilkowalski/skills/blob/85e8e2363b713506e1d5b6e07a0eb2da66be1bc3/skills/emil-design-eng/SKILL.md) and [Apple Design](https://github.com/emilkowalski/skills/blob/85e8e2363b713506e1d5b6e07a0eb2da66be1bc3/skills/apple-design/SKILL.md) last changed at commit `85e8e2363b713506e1d5b6e07a0eb2da66be1bc3` (15 September 2026). Pinned research copies are under ignored `.local/skills/`. The installed Emil copy differs only in its introductory course link and popover library examples; the current upstream guidance is used for this pass.

Apply immediate remote/keyboard feedback, restrained pointer transitions, trigger-anchored menus, translucent layers, size-specific typography, reduced-motion and contrast accommodations. Official Apple TV screenshots and the requested remote behavior take precedence over generic skill recommendations. The skills guide craft; they do not establish pixel parity by themselves.

## Inspected references

| Surface | Source and local image | Concrete design evidence |
| --- | --- | --- |
| Current TV navigation/Home | [Apple app navigation guide](https://support.apple.com/guide/tvapp/navigate-the-apple-tv-app-atvb5e608b5e/web), `navigation-2.png` (1144×644) | Full-bleed bright artwork; expanded sidebar overlays the content rather than reserving a permanent column. Panel starts 20px from the edge, about 214px wide, with a 30px radius. Profile and clock at top; circular icons; white pill selection. Hero and first shelf begin about 48px from the left edge, underneath the overlay. Sidebar height follows content (ends near 462px), not full screen. |
| TV Home, earlier generation | [Apple newsroom](https://www.apple.com/newsroom/2023/12/redesigned-apple-tv-app-elevates-the-viewing-experience/), `home-0.png`, `home-2.png` | Same overlay principle, hero carousel pagination, wide continue-watching cards and restrained metadata. Later screenshots take priority over this 2023 reference. |
| Player | [Apple TV playback guide](https://support.apple.com/guide/tv/control-playback-atvb7944597f/tvos), `tvos-player-4.png` (1144×380 cropped controls) | Main title is above the timeline on the lower left; episode label is smaller and above the title. Circular captions/audio controls align right above timeline. Timeline is thin with small times below; supporting Info/Continue Watching pills sit beneath it. A giant centered transport cluster and title pinned at top are not this layout. |
| Title detail geometry | Same playback guide, `tvos-player-17.png` (1146×750; app canvas occupies the top 644px) | SILO's detail screen is visible behind a picture-in-picture overlay. Title logo near x48/y326, type/genre line below, synopsis around x48/y420 with 390px width, metadata around y506, Play pill and circular actions around y536; lower content rail starts y620. The PiP state dims the screenshot, so it is a geometry reference, not a target for backdrop darkness. |
| Audio/subtitles behavior | [App subtitle/audio guide](https://support.apple.com/guide/tvapp/access-controls-for-subtitles-and-audio-atvb4a139b9c/web), [cross-device language guide](https://support.apple.com/en-us/118411) | Separate audio and captions controls open selectable lists; captions include Off. Use media-language labels and checks, not a single button cycling invisibly. |
| Browser controls | `languages-10.png`, `languages-12.png` | Audio/captions controls are grouped on lower right. Browser fullscreen is a secondary control. Use only as a browser adaptation, not the primary TV layout. |
| Player menu architecture | [Apple developer playback overview](https://developer.apple.com/documentation/avkit/customizing-the-tvos-playback-experience) | Menus grow upward from transport actions; metadata and optional related-content tabs belong near the lower timeline. Quality can use a custom menu in this same hierarchy. |
| Library grid | [Apple TV library guide](https://support.apple.com/guide/tv/view-movies-and-tv-shows-in-your-library-atvba6a2c11c/tvos), `library-tvos-0.png` (1146×644) | Charcoal background rather than pure black. Category column about 234px; portrait posters begin at x263, each about 119×180px, six across at this canvas. The Library screen has its own category sidebar. Home's landscape shelves and Library's poster grid are distinct layouts. |

Correct smart-TV playback text URL: <https://support.apple.com/guide/tvapp/control-playback-atvb5e386e66/web>. The similarly named `atvb7944597f` identifier belongs to `guide/tv/`, not `guide/tvapp/` (the latter silently falls back to the welcome guide).

## Before / after / reason

| Before | After (target) | Why |
| --- | --- | --- |
| Permanent 210px-wide sidebar with content at x270 on 1280px canvas | Compact navigation when browsing; expandable overlay, content using TV safe margins | Apple allocates the screen to artwork and shelves. |
| Heavy always-dark hero with ordinary title text | Full-bleed artwork with only the contrast shading necessary for labels; supplied Jellyfin title art where available | Artwork carries the identity and color. Do not tint the whole app amber or make every backdrop muddy. |
| One fixed featured title | User-controllable featured carousel with visible page position and real library items | Match Home navigation rather than presenting a static landing page. |
| Upper-left player title, large centered transport row | Lower title/episode header, right-side circular action controls, thin timeline, compact lower actions | Match the inspected player hierarchy. |
| Fixed detail backdrop remained behind scrolled episode descriptions | Artwork ends with the first screen; episode and chapter rails sit on a dark background | Preserve contrast and the reference’s separation between title art and browsing content. |
| Subtitle button cycles only externally exposed VTT tracks | Explicit Off/track list, full audio list, real quality/version choices, visible selected states | Users need to discover and verify their choice. |

## Acceptance checks

Compare screenshots at 1920×1080 and 1280×720 for Home (collapsed and expanded navigation), movie detail, series/episodes, player visible/hidden controls, and audio/subtitle/quality menus. Verify actual playback after each setting change, selected marks, retained position and paused state, Back behavior, long menu scrolling, keyboard focus and small-screen overflow. Keep the current last successful choice if a request fails.

Do not claim pixel identity using different artwork, an uninspected Roku rendering, or merely matching colors. No Apple subscription/store, AirPlay, Siri or proprietary TV features are implemented by imitating their buttons. Resolution/bitrate selection is an explicitly requested Jellyfin extension; match the control style while accurately labeling its behavior.


## Native typography/motion comparison — 12 October 2026

Compared `.local/diagnostics/luma-hero-final.jpg` with Apple's official `navigation-2.png`, with an Opus5.5 design review. Home's extra FOR YOU label is removed. Hero metadata previously inherited0.66scale (22px became14.52px); it now animates its position independently and retains28px type. Card labels increase22→26px, row headings28→32px, footer18→24px, menu20→24px, navigation24→28px. Plain-word remote hints replace unsupported arrow/star glyphs.

Apple's current [typography HIG](https://developer.apple.com/design/human-interface-guidelines/typography) recommends29pt default and23pt minimum for tvOS. Roku canvas pixels are not claimed equivalent to Apple typographic points; visual verification on the1920×1080 TV is the acceptance check. Current HIG JSON downloaded from the official developer.apple.com tutorials data endpoint for inspectable content.

Motion changes under hardware validation: firmware-owned RowList scroll animations are enabled, retaining exclusive sibling focus; hero movement uses280ms piecewise easing with15% acceleration and75% deceleration. These are application tuning values, not measured Apple timings. The previous220ms outCubic hero travel and disabled row interpolation produced abrupt visual changes. Card lift remains4% within the verified12px clipping allowance.


## App acquisition and inspection feasibility — 12 October 2026

The installed Roku inventory currently reports **Apple TV 17.0.28**, app ID **551012**. The app is already available as the live reference on the user's Roku; downloading another copy is not required to study its visible behavior. No editable Apple TV Roku source or exportable developer ZIP was obtained.

Evidence and limits:

- Roku's [packaging documentation](https://developer.roku.com/dev/docs/packaging-channels) states that distribution packages encrypt app code and data using Roku hardware and the developer signing key. The development installer is not a source-export facility for third-party installed apps.
- The saved direct Apple TV `query/sgnodes/all` inspection returned `Channel access not authorized: active UI` (`.local/navigation/apple-all.xml`). A current read-only query returned the same result for the active production Netflix app. This is an inspection restriction, not proof that no UI exists.
- At this pass the Roku reported Netflix actively playing. A temporary switch to Apple TV was requested before interrupting it. No new Apple TV key trace or animation measurement is claimed while waiting.
- Inspected the REA repository at revision `2e45b4d7a5b3228fe8b283def6f047797561bee1`. Its [target inventory](https://github.com/morluto/rea#what-you-can-analyze) describes analysis of supplied artifacts. Its [Apple application projection](https://github.com/morluto/rea/blob/2e45b4d7a5b3228fe8b283def6f047797561bee1/docs/apple-application-analysis.md) inventories IPA/macOS bundles; that is not a Roku package decryptor. No REA runtime was installed and no Apple source was recovered.
- Read-only inspection of `/System/Applications/TV.app` found bundle `com.apple.TV` version 1.7, a universal Mach-O executable, native Apple framework dependencies (including TVLibrary, AppleMediaServices and AVFoundationCF), 2,106 files, and no standalone JavaScript or BrightScript files. This Mac build cannot be dropped into the Roku SceneGraph runtime. This inventory does not establish the Roku app's implementation language or exact behavior.

**Engineering conclusion:** there is currently no Apple TV frontend in this workspace whose backend URL can simply be replaced. Reproduce observable interaction contracts in Luma's own SceneGraph frontend and connect those contracts to Jellyfin. Keep the proprietary executable and Apple service/authentication stack outside the shipping app. Distinguish reference observations from our tuning decisions; do not describe reconstruction as an exact copy or measured timing parity.

### Current official living-room interaction contract

These are documented Apple behaviors, not newly measured Roku timings:

| Area | Apple evidence | Luma implication |
| --- | --- | --- |
| Sidebar | [Living-room navigation](https://support.apple.com/en-euro/guide/tvapp/atvb5e608b5e/web): remote Back/Up/Left reach navigation; Right closes it. | Preserve exclusive sidebar focus and edge routing; details Back should return to its originating page. |
| Playback HUD | [Playback controls](https://support.apple.com/en-euro/guide/tvapp/atvb5e386e66/web): Back hides controls; center/play toggles playback. | Dismiss menu, then HUD, then exit playback as separate layers. |
| Seeking | Same guide: left/right skips 10 seconds; holding seeks continuously; repeated presses can select 2x/3x/4x; center/play resumes. | Luma's existing accelerating hold uses 10/30/60-second local steps and commits on release. That is an intentional implementation difference, not exact Apple equivalence. Compare on hardware before changing the already-tested decoder behavior. |
| Tracks | [Audio/subtitles](https://support.apple.com/en-euro/guide/tvapp/atvb4a139b9c/web): separate audio and subtitle lists, subtitles Off and style controls. | Keep selected tracks explicit, preserve timeline, and expose only supported choices. Current subtitle style controls are not equivalent to Apple's. |
| Temporary captions | Same guide describes brief captions after replay or mute. | Not currently implemented in Luma; do not claim feature parity. |

Exact focus geometry, acceleration thresholds, interruption rules and animation curves remain unmeasured for Apple TV Roku 17.0.28. Reference screenshots alone do not establish these values.


## 1:1 parity pass — 22 October 2026

Each screen was captured from the native simulator at 1920×1080 (dev-installer screenshot, `.local/parity/shot.sh`) and compared with the Apple reference scaled ×1.678 (1144→1920). Captures are under ignored `.local/parity/`.

| Screen | Apple reference | Capture | Fixed in this pass | Still different, and why |
| --- | --- | --- | --- | --- |
| Home, hero | `navigation-2.png`, `home-0.png` | `home-initial.png` | Opens on the hero's Play action (was a shelf). Logo left-aligned on a y540 baseline (was centered in its box and overlapped the metadata). Genre/episode line, two-line synopsis, left scrim. Play/Continue pill with play glyph that plays directly, round (i), ‹ ›. Capsule page dots with a pill for the current page. First shelf peeks at the bottom. | No "+" (Up Next) button: Jellyfin has no equivalent list wired in. ‹ › stay visible because the Roku remote cannot swipe the carousel. |
| Home, shelves | `home-0.png` | `home-shelves.png` | Cards align with row titles at x80 (were 12px right). SemiBold row titles. Apple focus: 7% lift on a soft shadow, white title, no white outline. Hero copy fades and artwork dims when shelves take focus. | Cards show title only, not Apple's second line ("Next · S2, E8"). |
| Sidebar | `navigation-2.png` | `home-sidebar.png` | Profile row (initial avatar, name, clock), round icon chips, white selection pill, 50px radius, content-height panel at 34px. Order Buscar, Início, Filmes, Séries, Ajustes (Apple: Search first). Removed the always-on "Menu" label. | Blur material is approximated with a translucent fill; Roku has no backdrop blur. |
| Show page | `tvos-player-17.png` (SILO) | `detail-series.png`, `detail-series-episodes.png` | Next-up action ("Reproduzir T2, E2"/"Continuar …") replaces "Ver temporadas". Season rails sit under the hero and peek at the bottom like Apple's lower rail. Down lands on the next-up episode. The page refreshes in place after playback. | Seasons are rails rather than tabs. No episode synopsis under cards. |
| Movie/episode details | `tvos-player-17.png` | `detail-episode.png` | Bold title, glass secondary pill, play glyph, tight `·` metadata ("2022 · 1 h 32 min · 14"), "0 min" removed, genre list capped at 3. | No rating/format badges (4K, CC). Voltar remains because the user asked for it. |
| Library | `library-tvos-0.png` | `library-movies.png` | Charcoal background. Biblioteca column with a pill on the open category. Removed the duplicate eyebrow. | Categories are informational; switching uses the sidebar. |
| Search | Apple TV app on smart TVs | `search-results.png` | Bold headings. Shows/movies before episodes (Futurama now first page for "fu"). | Grid keyboard (smart-TV variant), not tvOS's single-row keyboard. |
| Player | `tvos-player-4.png` | `player-hud.png`, `player-menu.png` | Episode line + bold 50px title lower left. Icon-only round controls right-aligned above the timeline. Thin timeline, elapsed time under the playhead with pause glyph, remaining right. Capítulos as a lower pill. Menus anchored above their control. Stronger bottom gradient. Version hidden when there is only one file. | No PiP/InSight/Info tabs (no Jellyfin equivalent). Seek steps keep the tested 10/30/60 s acceleration. |
| Skip intro | Apple/Netflix "Skip Intro" | `player-skip-hidden-hud.png` | New: white pill bottom-right over the video during Intro/Recap segments; one OK skips. | Credits ending the file are not offered. Next-episode autoplay is not implemented. |
| Sign-in | — | `welcome-1.png` | Welcome panel moved below the hero actions (it overlapped them after the hero moved). | Username/password entry still uses Roku's system keyboard dialog. |

Typography is now Inter (Regular/Medium/SemiBold/Bold), the closest open substitute for SF Pro. Apple's own fonts and assets are not shipped.
