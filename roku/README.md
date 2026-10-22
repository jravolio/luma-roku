# Luma native channel

Luma runs entirely on the Roku. `source/main.brs` creates the SceneGraph scene; one persistent `JellyfinTask` owns network requests and the `Luma` registry section. The browser preview and Node bridge are not runtime dependencies.

## Implemented

- Official Jellyfin UDP discovery (`Who is JellyfinServer?`, broadcast port 7359), three bounded attempts.
- When UDP cannot locate the saved server, token-free public HTTP probes on the first RFC1918 IPv4 interface's local `/24`: at most 254 hosts, 24 concurrent transfers, 650 ms per host, a 15-second scan deadline. First run uses HTTP port 8096. Reconnection retains the saved scheme, port, and reverse-proxy base path. No household address is hardcoded.
- Public server-ID verification before cached-token use; accounts keyed by stable server ID, with a persistent generated device ID. Offline/mismatched addresses do not remove saved accounts. Authenticated request failures can discover and retry against the matching server's new address; reconnect attempts are throttled.
- Multiple-server picker, manual address/base-path input, native username/password dialogs, masked password entry, saved token/user ID, and explicit local sign-out. Passwords are not persisted.
- Continue watching, latest, movies, series, search, 48-item paged browsing, details, seasons, episodes, empty/error states, retry, settings, and Back navigation. Home includes up to five real featured titles with previous/next controls and page dots; carousel and shelf selection restore independently after details.
- Jellyfin PlaybackInfo negotiation, direct MP4/MKV or HLS transcoding, custom remote controls, resume, playing/progress/stopped reports, and recoverable playback-setting changes.
- Real audio, subtitle, quality and media-version menus; subtitles include Off and server-rendered text, ASS and image formats. Choices are validated against the selected source using Jellyfin stream indices. Optional chapter navigation uses actual item metadata.
- Playback replacement preserves absolute item position and paused state. The previous stream stays available until negotiation succeeds, then receives one stop report. The old decoder uses OS 12.5+ asynchronous stop; replacement waits for its stopped acknowledgment before creating the next Video node. Separate Video nodes reject late callbacks; cancelled replies cannot reopen playback. Decoder failures offer restoration of the previous settings.
- 1080p SceneGraph layout following inspected Apple TV references: full-width hero artwork and Jellyfin title logos, expanded overlay navigation, landscape Home shelves, six-column portrait Movies/TV catalog, Inter typography (bold titles, as in Apple's SF Pro) and Apple's lift-and-shadow card focus. Player title sits above a thin lower timeline; audio/captions menus open above right-side controls. OS 16 Effect support adds rounded panels and scrims. Detail geometry follows the underlying SILO canvas in Apple’s official `tvos-player-17.png`: lower-left title/logo, genre line, synopsis, metadata and play actions. Its PiP overlay/dimming is not reproduced; seasons/episodes remain a separate navigable shelf.

## API compatibility

Endpoint templates were audited against the actual Jellyfin 12.2 OpenAPI supplied during implementation. Library routes use `/UserItems/Resume`, `/Items/Latest`, `/Items`, and `/Items/{itemId}` with `UserId` query parameters. The removed `/Users/{userId}/Items...` and `/Videos/ActiveEncodings` routes are not used. Public info, authentication, image, seasons/episodes, PlaybackInfo, video-stream and playback-report routes also match that schema. Compatibility with older servers has not been exhaustively tested.

## Build and checks

From the repository root after its dependencies are installed:

```sh
node_modules/.bin/bsc --project roku/bsconfig.json
node --test tests/roku/native.test.mjs
```

The package is `dist/luma.zip`. The test suite executes the actual BrightScript policy/content/playback functions under `brs`, mocking network/discovery/registry I/O, device capabilities, URL escaping and rendering boundaries. It does not emulate SceneGraph rendering, Roku sockets, or the hardware video decoder. See `tests/roku/HARDWARE.md` for the on-device acceptance pass.

## Current limits

- Installed and exercised on the Philco G510X / Roku 16.0.4. Sampled 4K HDR10 decoding, continuous playback and a two-hour seek passed; this is not an exhaustive whole-library or whole-film guarantee. Roku installer screenshots do not validate the video plane.
- **Auto** preserves compatible source video: H.264 up to 1080p/20 Mbps, or HEVC up to 4K/25 Mbps after positive runtime checks. Separate HEVC-copy negotiation prevents H.264 fallback limits from reducing compatible 4K video; contradictory copy plans retry with bounded H.264. Audio conversion can keep source video unchanged. Explicit 1080/720/480/360 choices constrain both dimensions and total bitrate. They are ceilings, not upscaling requests.
- **Máxima · 4K/HDR compatível** preserves eligible HEVC video up to 65 Mbps with three-second HLS segments, positive runtime decoder/display checks and strict validation of the server response. Verified Dolby Vision profile 7 / compatibility ID 6 files may use their HDR10 base layer on HDR10-only TVs. It does not advertise Dolby Vision output. Audio may convert to AAC stereo. Unsupported sources and burned-in subtitles return a recoverable error instead of silently reducing quality. Auto remains the default; select Máxima in the player for eligible high-bitrate files.
- **Original · direct play** never transcodes or silently resizes. At runtime it adds 4K HEVC only with 2160p output and positive `CanDecodeVideo` HEVC level 5.1 support (plus HDCP 2.2 on set-top boxes). Main 10 requires its own positive query. HEVC is limited to at most 25 Mbps, compatible MP4/MKV and stereo AAC/MP3 for unchanged playback. HDR10 additionally requires Main10 and positive current display HDR10 support; unverified Dolby Vision, HDR10+, HLG and multichannel passthrough are not advertised. Unsupported Original combinations show a recoverable choose-Auto message.
- External SRT captions use Roku's native caption renderer. Switching between registered external SRT tracks and Off keeps the existing decoder/session; explicit caption changes also update Roku's device-wide caption mode. Embedded text, ASS and image subtitles still require Jellyfin rendering. Dynamic HLS `StartTimeTicks` URL parameters are removed because Jellyfin 12.2 rejects them on segment routes; Roku receives the absolute resume point through `Video.playStart` with no reporting offset. This requires working server transcoding and uses the original item timeline. Successful negotiation and passing host tests do not prove that the server can generate playable segments or that Roku decodes them. Device testing is still required for audio switches, PGS/ASS/text rendering, Off and resumed cue timing.
- Hidden playback has no persistent controls or hint. An arrow or OK first reveals controls without seeking or pausing; Star requests options, and Back closes the menu, hides the HUD, then exits. Roku can intercept Star for system captions when no app HUD is visible; Up followed by Star always exposes the app menu path. This firmware behavior needs hardware verification. System volume/Home remain platform-owned. No next-episode autoplay or Quick Connect is implemented.
- OS 16 rounded corners and gradients are guarded by runtime Effect support. Unsupported renderers use flat rectangular panels. No claim of pixel-identical Apple TV rendering is made without hardware screenshots.
- The fallback scans one private `/24`, not every subnet, custom port, or IPv6 network. First-run non-default ports and base paths require manual entry; saved values are retained afterward. HTTPS IP probes require certificates valid for those IPs. A stable DNS name is preferable for hostname certificates.
- Discovery identity is a Jellyfin ID comparison, not cryptographic server authentication. HTTPS uses Roku's certificate trust store; the registry is channel-private device storage, not an encrypted credential vault.
- An active video stream cannot seamlessly change its host mid-playback; use Retry/Reconnect after a stream/network error. Progress reports are best effort and can be lost if Home closes the channel immediately.

## Font and image provenance

The UI font is Inter 4.1 (Regular, Medium, SemiBold, Bold static TTFs from [rsms/inter](https://github.com/rsms/inter/releases/tag/v4.1)), the closest open typeface to Apple's SF Pro, under the bundled `Inter-OFL.txt`. Only `fonts/Inter-*.ttf` is packaged; the older Hanken Grotesk and Instrument Serif files are no longer referenced. The channel icons and splash ("Luma" in Fraunces Italic, closed by a warm crescent that cradles the final "a"; the font, under `scripts/brand-fonts/` with its OFL, is used only to render these images and is not packaged) are rendered by `scripts/generate-roku-brand.py`; scrims and spinner are original raster assets generated for Luma. No Apple assets are included.

See [measured performance and quality](../docs/performance-and-quality.md) for allocation budgets, source-frame checks and the distinction between local decoder tests and TV verification.
