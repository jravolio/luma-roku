export type ItemType = 'Movie' | 'Series' | 'Season' | 'Episode' | (string & {})

export interface Item {
  id: string
  name: string
  type: ItemType
  overview?: string | null
  year?: number | null
  runtimeTicks?: number | null
  positionTicks?: number | null
  played?: boolean | null
  poster?: string | null
  backdrop?: string | null
  genres?: string[] | null
  rating?: number | string | null
  seriesName?: string | null
  indexNumber?: number | null
  parentIndexNumber?: number | null
  /** Title-logo art (opaque image resource). Text titles are the fallback. */
  logo?: string | null
  chapters?: Chapter[] | null
  seriesId?: string | null
  /** For an episode, its season (or series when there are no season folders). */
  parentId?: string | null
}

export interface Chapter {
  name: string
  startTimeTicks: number
  image?: string | null
}

export interface ServerInfo {
  id: string
  name: string
  url: string
}

export interface UserInfo {
  id: string
  name: string
}

export interface SessionResponse {
  connected: boolean
  server?: ServerInfo
  user?: UserInfo
  reason?: string
}

export type Diagnostic = string | ({ code?: string; message?: string; reason?: string } & Record<string, unknown>)

export interface DiscoverResponse {
  servers: ServerInfo[]
  diagnostics: Diagnostic[]
}

export interface HomeResponse {
  resume: Item[]
  latest: Item[]
  movies: Item[]
  series: Item[]
}

export interface Subtitle {
  url: string
  label?: string
  language?: string
  index?: number
}

export interface AudioTrack {
  /** Jellyfin stream index, never an array position. */
  index: number
  label: string
  language?: string
  codec?: string
  channels?: number
  isDefault?: boolean
}

export interface SubtitleTrack {
  index: number
  label: string
  language?: string
  codec?: string
  isDefault?: boolean
  isForced?: boolean
}

export interface MediaSourceOption {
  id: string
  label: string
  width?: number
  height?: number
}

export interface QualityOption {
  id: string
  label: string
  maxHeight?: number
  maxBitrate?: number
}

export interface PlaybackSelection {
  mediaSourceId: string
  audioStreamIndex: number | null
  /** -1 means Off. */
  subtitleStreamIndex: number
  quality: string
}

export interface StreamSummary {
  width?: number
  height?: number
  bitrate?: number
  videoCodec?: string
  audioCodec?: string
}

/** Choices sent with a playback negotiation. Omitted fields let the server pick its defaults. */
export interface PlaybackOptions {
  mediaSourceId?: string
  audioStreamIndex?: number
  subtitleStreamIndex?: number
  quality?: string
  signal?: AbortSignal
}

export interface PlaybackInfo {
  url: string
  playSessionId: string
  mediaSourceId: string
  itemId: string
  startTimeTicks: number
  subtitles?: Subtitle[]
  playMethod?: 'DirectPlay' | 'DirectStream' | 'Transcode' | (string & {})
  /** Stream time zero corresponds to this item position, e.g. an HLS transcode started at StartTimeTicks. */
  positionOffsetTicks?: number
  seekTimeTicks?: number
  /** Set only by the demo library; the gateway never sends it. */
  sample?: { title: string; credit: string }
  // Present when the gateway implements playback choices (docs/playback-controls-contract.md).
  audioTracks?: AudioTrack[]
  subtitleTracks?: SubtitleTrack[]
  mediaSources?: MediaSourceOption[]
  qualityOptions?: QualityOption[]
  selection?: PlaybackSelection
  /** `encoded` subtitles are burned into the video; only `external` ones are rendered by the browser. */
  subtitleDelivery?: 'off' | 'encoded' | 'external'
  stream?: StreamSummary
}

export interface PlaybackReport {
  event: 'start' | 'progress' | 'stop'
  itemId: string
  playSessionId: string
  mediaSourceId: string
  positionTicks: number
  isPaused: boolean
}

export interface ItemQuery {
  search?: string
  type?: 'Movie' | 'Series'
  parentId?: string
}

export interface ItemPage {
  items: Item[]
  total: number
  nextStartIndex: number | null
}

export interface LibrarySource {
  kind: 'server' | 'demo'
  home(signal?: AbortSignal): Promise<HomeResponse>
  itemsPage(query: ItemQuery, startIndex: number, signal?: AbortSignal): Promise<ItemPage>
  item(id: string, signal?: AbortSignal): Promise<Item>
  children(id: string, signal?: AbortSignal): Promise<Item[]>
  childrenPage(id: string, startIndex: number, signal?: AbortSignal): Promise<ItemPage>
  playback(id: string, startTimeTicks?: number, options?: PlaybackOptions): Promise<PlaybackInfo>
  report(report: PlaybackReport, options?: { keepalive?: boolean }): Promise<void>
}

export const TICKS_PER_SECOND = 10_000_000
