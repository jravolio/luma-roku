# Playback controls contract

Shared implementation brief for the browser and gateway. Roku implements the same user choices directly against Jellyfin.

`POST /api/playback/:id` accepts the existing `startTimeTicks` plus optional `mediaSourceId`, `audioStreamIndex`, `subtitleStreamIndex` (`-1` means Off), and `quality` (`auto`, `original`, `1080p`, `720p`, `480p`, `360p`). Stream indices are Jellyfin indices, never array positions. Validate choices against the selected source; unsupported choices return a useful error without erasing the account.

Preserve all existing response fields and add:

```ts
audioTracks: { index: number; label: string; language?: string; codec?: string; channels?: number; isDefault?: boolean }[]
subtitleTracks: { index: number; label: string; language?: string; codec?: string; isDefault?: boolean; isForced?: boolean }[]
mediaSources: { id: string; label: string; width?: number; height?: number }[]
qualityOptions: { id: string; label: string; maxHeight?: number; maxBitrate?: number }[]
selection: { mediaSourceId: string; audioStreamIndex: number | null; subtitleStreamIndex: number; quality: string }
subtitleDelivery: 'off' | 'encoded' | 'external'
stream: { width?: number; height?: number; bitrate?: number; videoCodec?: string; audioCodec?: string }
```

Use server-rendered subtitles for selected embedded/image formats so selection works with real MKV libraries. For an external selected subtitle, `subtitles` retains the existing opaque URL contract; align cues correctly with a resumed/transcoded stream. Never offer a decorative option that does not affect the media request. Quality means a resolution/bitrate ceiling; preserve aspect ratio and do not imply upscaling. Auto and original must accurately describe their distinct behavior.

The frontend retains the current absolute item position and paused state when changing any option, reports the old stream stopped, negotiates a replacement and resumes at that position without applying an HLS offset twice. Rapid choices cannot attach stale streams. Show the last successful selection until the new one succeeds; keep failures recoverable. Menus list real labels with a checkmark, close with Back/Escape and restore focus. Subtitle Off must actually disable rendering. Preserve options across quality/audio changes within the item.

Jellyfin dynamic HLS uses the full item timeline. Do not attach `startTimeTicks` to the master URL: this propagates to segment URLs and Jellyfin rejects nonzero values. The gateway returns `positionOffsetTicks: 0` and `seekTimeTicks` equal to the requested absolute resume position; the player seeks to that point. Keep using the response timing fields instead of assuming every transcoded stream starts at time zero. Native Roku uses the same full timeline and an absolute initial seek.

Do not put server tokens in the browser. Do not print passwords, tokens, Authorization or full upstream playback URLs in logs. Tests should exercise actual stream selection, resolution constraints, subtitles and resume/report behavior.

## Real artwork and chapter metadata

The real server has title-logo art on 106 of 113 movies/series and chapter metadata on 70. Extend normalized `Item` with optional `logo?: string | null` (opaque image resource), `chapters?: { name: string; startTimeTicks: number; image?: string }[]`, `seriesId?: string`, and `parentId?: string`. Return logo art on home/list/detail when present and chapters on detail. This enables authentic title treatment and real chapter/episode navigation, without dummy Apple features. Root confirmed these fields from authenticated server metadata; no download of Apple app assets is needed.
