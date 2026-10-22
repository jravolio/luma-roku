# Streaming quality and performance — 11 October 2026

Quality takes priority: preserve compatible source video, keep each explicit profile's resolution/bitrate ceilings, and use server conversion when compatibility or selected subtitles require it. None of this pass lowers artwork quality, animation timing, font sizes, or video profile budgets to obtain a faster result.

## Hardware target

The photographed device is a Philco PTV58G70R2CSGBL4K, hardware G510X, Roku OS 16. [Philco's model page](https://sac.philco.com.br/marketing/tv_PTV58G70R2CSGBL_4K_LED/) confirms a 3840×2160 panel and HDR10.

[Roku's hardware table](https://developer.roku.com/dev/docs/hardware) lists the G000X Athens TV family as quad-core ARM at 1 GHz, OpenGL ES 2.0, 1 GB RAM, 1920×1080 UI, and 3840×2160 playback. G510X's membership in that family is an inference from Roku's model-family convention, not a runtime `GetModel()` result from this powered-off TV. The implementation does not hard-code codec support from that inference. It checks current output, HEVC/Main10 decoding, HDR10 display capability, and HDCP where relevant.

This favors bounded reusable SceneGraph nodes, Task-based networking, one active Video decoder, and 1080p interface assets. A 1080p interface does not limit separately decoded video to 1080p. The TV was off during this pass; no device FPS, thermal behavior, app memory ceiling, or physical HDR output was measured.

## Measured improvements

| Workload | Before | After |
| --- | ---: | ---: |
| First HLS media available, compatible H.264 with another audio track, median of 3 LAN trials | 511 ms, video encoded | 216 ms, source video copied |
| 100 warm native carousel updates: node allocations | 2,010 | 0 |
| 100 warm native menu movements: node allocations | 2,500 | 0 |
| 100 recycled cards: effect allocations / tree lookups | 300 / 1,200 | 0 / 0 |
| Browser player: 40 subsecond media updates, React commits | 40 | at most 1 |
| Native catalog + negotiation requests across two selections | 4 | 3 |

The LAN sample's first-media median improved by about 58%. This measures manifest and first-segment delivery, not TV startup time or sustained FPS. The before branch explicitly forced video encoding; the after branch used the actual production native negotiation policy. Both used the same source, audio selection and 1080p profile, in alternating trials. The 72 decoded video frames included 49 distinct frames: source-copy hashes matched the original; the encoded baseline did not. This is a sampled lossless-video check, not a whole-file comparison or a subjective quality score.

The native operation counts run actual BrightScript rendering functions with counting SceneGraph doubles. See [the native benchmark methodology](../tests/roku/PERFORMANCE.md). The browser test still updates the timeline at media-event precision and retains exact report ticks; only redundant React work is reduced. These results do not substitute for measuring the actual TV.

The native catalog cache is a single entry lasting at most 30 seconds. It is scoped to item, server identity/address, account and token; live/opened streams are excluded. Every selection still gets fresh playback negotiation, and public server identity verification remains in place before authenticated requests.

## Quality policy

Compatible direct playback takes precedence. Audio conversion or changing audio can copy compatible video instead of re-encoding it. Selecting server-rendered subtitles or using decoder recovery requests compatible H.264 output. Explicit profiles never upscale.

| Profile | Native Roku ceiling | Browser ceiling |
| --- | --- | --- |
| Auto | H.264 up to 1080p/20 Mbps; verified HEVC up to 4K/25 Mbps | Compatible H.264 up to 20 Mbps |
| Original | Compatible unchanged file; no silent conversion | Original resolution, with codec conversion if needed |
| 1080p | 12 Mbps | 10 Mbps |
| 720p | 6 Mbps | 4 Mbps |
| 480p | 2.5 Mbps | 1.5 Mbps |
| 360p | 1 Mbps | 0.8 Mbps |

Budgets include audio. Width and height are both constrained, retaining aspect ratio. They are ceilings, not promised constant output bitrates. The browser preview and native channel have different playback capabilities and are deliberately documented separately.

HEVC requires positive runtime decoder checks and complete compatible media metadata. Main10 has its own check. HDR10 additionally requires current display HDR10 support; unverified Dolby Vision, HDR10+ and HLG are not advertised. The 25 Mbps HEVC limit follows Roku's conservative 4K guidance; this is not a measurement of this TV's absolute ceiling. See [Roku streaming specifications](https://developer.roku.com/dev/docs/media).

Actual production HEVC negotiation was also replayed with the real server response. Both 4K SDR (3840×1600) and HDR10 (3840×2160) retained source resolution and all 72 sampled frame hashes. HDR10 retained `yuv420p10le`, BT.2020 primaries and SMPTE ST 2084 transfer. The samples began around 18 and 20 seconds, avoiding all-black introductions. Missing capabilities and explicit 720p correctly produced H.264 fallback.

The browser does not clamp codec conversion to the source codec's bitrate merely because the numerical bitrate is lower. Jellyfin can compensate for HEVC/AV1-to-H.264 conversion while respecting the selected bandwidth ceiling. Source resolution is retained in Original, with no claim that a conversion is lossless. [Jellyfin's encoding implementation](https://github.com/jellyfin/jellyfin/blob/master/MediaBrowser.Controller/MediaEncoding/EncodingHelper.cs) supplies those conversion decisions.

Dolby audio (22 October 2026): when Roku's `CanDecodeAudio` confirms AC-3 or E-AC-3 at 5.1, those codecs are advertised for direct play and for copying into HLS, up to six channels. The TV decodes them itself, so this does not depend on a receiver or private-listening route. Anything that still needs conversion (Opus, DTS, TrueHD) keeps AAC first and stereo. Live negotiation with the real server, using a TV-like 4K/HDR10 capability: a single-track H.264 + DD+ 5.1 episode moved from HLS with stereo AAC to direct play of the original file; a HEVC + DD+ 5.1 episode likewise; a two-track DD+ series stays on HLS for track selection with E-AC-3 5.1 copied (`eac3-audiochannels=6`); an AV1 + Opus 5.1 episode still gets H.264 + stereo AAC. Without a positive runtime answer, the profile is unchanged.

The PC reports NVENC hardware acceleration and hardware encoding enabled, with HEVC/AV1 encoding disabled. Copying HEVC does not require a HEVC encoder: the real copied streams above worked under that configuration. The live tests verify decoded output, not a GPU utilization benchmark.

With user authorization, `EnableTonemapping` was changed from false to true; every other encoding setting was preserved and a private configuration backup retained. Actual HDR-to-SDR streams decoded successfully at 1080p, 720p, 480p and 360p with BT.709 color metadata. Fresh server encoder logs for the tested HDR source confirmed CUDA decoding, `tonemap_cuda`, and `h264_nvenc`, with no conversion failures. The first 1080p request took about 5.1 seconds to produce the requested segment; subsequent lower-resolution cases took 1.7–1.9 seconds. This correction prioritizes proper color over skipping the conversion work. It does not establish sustained GPU load or performance across every file.

HDR copied to a compatible HDR display retains its original signal; HDR converted to SDR needs tone mapping for appropriate colors. [Jellyfin's NVIDIA guidance](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/nvidia/) documents this pipeline. After enabling it, another actual 4K HDR10 copy test still matched all 72 source-frame hashes and retained 10-bit BT.2020/PQ output. The setting is shared by other Jellyfin clients. To revert only this change, disable tone mapping in Dashboard → Playback → Transcoding; avoid replacing the whole configuration if unrelated settings have subsequently changed.

## Verification and reproduction

The opt-in `tests/roku/live-quality-acceptance.mjs` obtains saved authentication privately, verifies the server's public identity, executes the production BrightScript negotiation policy, fetches real media and decodes it locally. Credentials and stream URLs are neither printed nor supplied to decoder processes. Cleanup is scoped to each QA device/session using Jellyfin's `Videos/ActiveEncodings` endpoint; it does not report watching progress.

```sh
npm test
npm --prefix preview test
npm run build
python3 scripts/check-package.py dist/luma.zip
# Requires an ignored private case manifest and the existing signed-in account:
node tests/roku/live-quality-acceptance.mjs
```

The private manifest contains cases with `label`, `itemId`, `request`, optional simulated `capabilities`, `expectedCodec`, `expectCopy`, `segmentIndex`, and `sampleBytes`. Capability-positive tests validate server decisions and output; they do not establish the physical TV's capabilities. Use nonblack scenes for frame comparisons. Default output is ignored `.local/performance/native-live-results.json`; `LUMA_QUALITY_CASES` and `LUMA_QUALITY_RESULTS` can select separate manifests/results.

Run `npm run dev` for the signed-in browser at http://127.0.0.1:5173/ and `npm run simulate:roku` for the native ZIP and remote viewer at http://127.0.0.1:8090/. The simulator's known discovery, resume and remote-screen limitations remain documented in [roku-simulator.md](roku-simulator.md).
