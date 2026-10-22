import type { PlaybackInfo, PlaybackOptions, Subtitle } from '../api/types'

/** One user choice in the player menus. Stream indices are Jellyfin indices, never array positions. */
export type PlaybackChange =
  | { kind: 'subtitles'; index: number }
  | { kind: 'audio'; index: number }
  | { kind: 'quality'; id: string }
  | { kind: 'version'; id: string }
  /** Re-negotiates the current selection at a new position (a stream that starts after the requested time). */
  | { kind: 'position' }

export const SUBTITLES_OFF = -1

const QUALITY_LABELS: Record<string, string> = {
  auto: 'Automática · até 20 Mbps',
  original: 'Resolução original · pode transcodificar',
  '1080p': 'Até 1080p · 10 Mbps',
  '720p': 'Até 720p · 4 Mbps',
  '480p': 'Até 480p · 1,5 Mbps',
  '360p': 'Até 360p · 0,8 Mbps',
}

export function qualityLabel(option: { id: string; label: string }): string {
  return QUALITY_LABELS[option.id] ?? option.label
}

export function supportsChoices(info: PlaybackInfo): boolean {
  return Boolean(info.selection)
}

export function selectionOptions(info: PlaybackInfo): PlaybackOptions {
  const selection = info.selection
  if (!selection) return {}
  return {
    mediaSourceId: selection.mediaSourceId,
    ...(selection.audioStreamIndex !== null ? { audioStreamIndex: selection.audioStreamIndex } : {}),
    subtitleStreamIndex: selection.subtitleStreamIndex,
    quality: selection.quality,
  }
}

/** Unchanged choices are resent with every change so audio, subtitles and quality survive each other. */
export function applyChange(current: PlaybackOptions, change: PlaybackChange): PlaybackOptions {
  switch (change.kind) {
    case 'subtitles':
      return { ...current, subtitleStreamIndex: change.index }
    case 'audio':
      return { ...current, audioStreamIndex: change.index }
    case 'quality':
      return { ...current, quality: change.id }
    case 'version':
      // Stream indices belong to one version, so only Off and the quality ceiling carry over.
      return {
        mediaSourceId: change.id,
        ...(current.quality !== undefined ? { quality: current.quality } : {}),
        ...(current.subtitleStreamIndex === SUBTITLES_OFF ? { subtitleStreamIndex: SUBTITLES_OFF } : {}),
      }
    case 'position':
      return current
  }
}

export function chosen(options: PlaybackOptions, change: PlaybackChange): boolean {
  switch (change.kind) {
    case 'subtitles':
      return options.subtitleStreamIndex === change.index
    case 'audio':
      return options.audioStreamIndex === change.index
    case 'quality':
      return options.quality === change.id
    case 'version':
      return options.mediaSourceId === change.id
    case 'position':
      return false
  }
}

/**
 * The browser renders a subtitle only when the server delivers it as an external file.
 * Burned-in (`encoded`) and Off render nothing, so a server-rendered track is never shown twice.
 */
export function renderedSubtitle(info: PlaybackInfo, legacyIndex: number): Subtitle | null {
  const subtitles = info.subtitles ?? []
  if (!info.selection) return legacyIndex >= 0 ? (subtitles[legacyIndex] ?? null) : null
  if (info.subtitleDelivery !== 'external') return null
  const wanted = info.selection.subtitleStreamIndex
  if (wanted === SUBTITLES_OFF) return null
  return subtitles.find(subtitle => subtitle.index === wanted) ?? (subtitles.length === 1 && subtitles[0]?.index === undefined ? subtitles[0]! : null)
}

export function changeLabel(info: PlaybackInfo, change: PlaybackChange): string {
  switch (change.kind) {
    case 'subtitles':
      return change.index === SUBTITLES_OFF
        ? 'Legendas desativadas'
        : (info.subtitleTracks?.find(track => track.index === change.index)?.label ?? 'Legendas')
    case 'audio':
      return info.audioTracks?.find(track => track.index === change.index)?.label ?? 'Audio'
    case 'quality':
      const option = info.qualityOptions?.find(option => option.id === change.id)
      return option ? qualityLabel(option) : 'Qualidade'
    case 'version':
      return info.mediaSources?.find(source => source.id === change.id)?.label ?? 'Versão'
    case 'position':
      return 'Nova posição'
  }
}

function megabits(bitrate: number): string {
  return `${(bitrate / 1_000_000).toLocaleString('pt-BR', { minimumFractionDigits: bitrate >= 10_000_000 ? 0 : 1, maximumFractionDigits: bitrate >= 10_000_000 ? 0 : 1 })} Mbps`
}

/** What is actually playing, e.g. "1280 × 720 · H264 · AAC · 3.9 Mbps · Transcoding". */
export function streamSummary(info: PlaybackInfo): string | undefined {
  const stream = info.stream
  const parts = [
    stream?.width && stream.height ? `${stream.width} × ${stream.height}` : undefined,
    stream?.videoCodec?.toUpperCase(),
    stream?.audioCodec?.toUpperCase(),
    stream?.bitrate ? megabits(stream.bitrate) : undefined,
    info.playMethod === 'DirectPlay' ? 'Reprodução direta' : info.playMethod === 'Transcode' ? 'Transcodificação' : undefined,
  ].filter((part): part is string => Boolean(part))
  return parts.length ? parts.join(' · ') : undefined
}
