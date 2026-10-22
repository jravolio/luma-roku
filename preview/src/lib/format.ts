import { TICKS_PER_SECOND, type Item } from '../api/types'

export function formatRuntime(ticks: number | null | undefined): string | undefined {
  if (!ticks || ticks <= 0) return undefined
  const totalMinutes = Math.max(1, Math.round(ticks / TICKS_PER_SECOND / 60))
  const hours = Math.floor(totalMinutes / 60)
  const minutes = totalMinutes % 60
  if (hours === 0) return `${minutes} min`
  return minutes === 0 ? `${hours} h` : `${hours} h ${minutes} min`
}

export function formatClock(seconds: number): string {
  const safe = Number.isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0
  const h = Math.floor(safe / 3600)
  const m = Math.floor((safe % 3600) / 60)
  const s = safe % 60
  const mm = h > 0 ? String(m).padStart(2, '0') : String(m)
  return `${h > 0 ? `${h}:` : ''}${mm}:${String(s).padStart(2, '0')}`
}

export function progressOf(item: Item): number {
  if (!item.positionTicks || !item.runtimeTicks) return 0
  return Math.min(1, Math.max(0, item.positionTicks / item.runtimeTicks))
}

export function remainingLabel(item: Item): string | undefined {
  if (!item.positionTicks || !item.runtimeTicks) return undefined
  const left = formatRuntime(item.runtimeTicks - item.positionTicks)
  return left ? `Faltam ${left}` : undefined
}

export function episodeCode(item: Item): string | undefined {
  if (item.type !== 'Episode' || item.indexNumber == null) return undefined
  return item.parentIndexNumber != null ? `S${item.parentIndexNumber}, E${item.indexNumber}` : `E${item.indexNumber}`
}

/** Player clock as on tvOS: 04:33, 1:02:09. */
export function formatPlayerClock(seconds: number): string {
  const safe = Number.isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0
  const h = Math.floor(safe / 3600)
  const m = Math.floor((safe % 3600) / 60)
  const s = safe % 60
  return `${h > 0 ? `${h}:` : ''}${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

const TYPE_LABELS: Record<string, string> = { Movie: 'Filme', Series: 'Série', Episode: 'Série', Season: 'Série' }

/** The Apple TV hero line: kind, then up to two genres. */
export function kindLine(item: Item): string[] {
  return [TYPE_LABELS[item.type], ...(item.genres?.slice(0, 2) ?? [])].filter((part): part is string => Boolean(part))
}

/** Year, runtime and (for episodes) the episode code, in that order. */
export function factsLine(item: Item): string[] {
  return [
    episodeCode(item),
    item.year ? String(item.year) : undefined,
    formatRuntime(item.runtimeTicks),
  ].filter((part): part is string => Boolean(part))
}

export function displayTitle(item: Item): string {
  return item.type === 'Episode' && item.seriesName ? item.seriesName : item.name
}

export function formatRating(rating: Item['rating']): string | undefined {
  if (typeof rating === 'number') return Number.isFinite(rating) ? `★ ${rating.toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 })}` : undefined
  return rating || undefined
}

export function metadataLine(item: Item): string[] {
  return [
    episodeCode(item),
    item.year ? String(item.year) : undefined,
    formatRuntime(item.runtimeTicks),
    formatRating(item.rating),
    item.genres?.slice(0, 2).join(', ') || undefined,
  ].filter((part): part is string => Boolean(part))
}

export function itemTitle(item: Item): string {
  return item.type === 'Episode' && item.seriesName ? `${item.seriesName}: ${item.name}` : item.name
}

export function playPath(item: Item): string {
  const resume = item.positionTicks && item.positionTicks > 0 ? `?t=${item.positionTicks}` : ''
  return `/play/${encodeURIComponent(item.id)}${resume}`
}
