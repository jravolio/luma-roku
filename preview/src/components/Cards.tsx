import { memo } from 'react'
import { TICKS_PER_SECOND, type Chapter, type Item } from '../api/types'
import { episodeCode, formatPlayerClock, formatRuntime, playPath, progressOf, remainingLabel } from '../lib/format'
import { Artwork } from './Artwork'
import { CheckIcon } from './icons'
import { Link } from './Link'

function ProgressBar({ value }: { value: number }) {
  if (value <= 0) return null
  return (
    <span className="progress" aria-hidden="true">
      <span className="progress__fill" style={{ width: `${Math.max(4, value * 100)}%` }} />
    </span>
  )
}

function WatchedBadge({ played }: { played: Item['played'] }) {
  if (!played) return null
  return (
    <span className="card__badge" aria-hidden="true">
      <CheckIcon />
    </span>
  )
}

const TYPE_LABEL: Record<string, string> = { Movie: 'Filme', Series: 'Série', Episode: 'Episódio' }

export const PosterCard = memo(function PosterCard({ item }: { item: Item }) {
  const progress = progressOf(item)
  const label = [item.name, item.year, item.played ? 'assistido' : undefined, progress > 0 ? `${Math.round(progress * 100)}% assistido` : undefined]
    .filter(Boolean)
    .join(', ')
  return (
    <Link to={`/item/${encodeURIComponent(item.id)}`} className="card card--poster" aria-label={label} data-focus-key={`card:${item.id}`}>
      <span className="card__frame">
        <Artwork src={item.poster} title={item.name} />
        <ProgressBar value={progress} />
        <WatchedBadge played={item.played} />
      </span>
      <span className="card__caption" aria-hidden="true">
        <span className="card__title">{item.name}</span>
        {item.year ? <span className="card__meta">{item.year}</span> : null}
      </span>
    </Link>
  )
})

export type WideCardVariant = 'resume' | 'episode' | 'browse'

function wideCaption(item: Item, variant: WideCardVariant): { title: string; meta?: string } {
  const code = episodeCode(item)
  switch (variant) {
    case 'resume':
      return item.type === 'Episode'
        ? { title: item.seriesName ?? item.name, meta: [code, remainingLabel(item) ?? 'Continuar'].filter(Boolean).join(' · ') }
        : { title: item.name, meta: remainingLabel(item) ?? 'Continuar' }
    case 'episode':
      return {
        title: item.name,
        meta: [item.indexNumber != null ? `Episódio ${item.indexNumber}` : undefined, remainingLabel(item) ?? formatRuntime(item.runtimeTicks)]
          .filter(Boolean)
          .join(' · '),
      }
    case 'browse':
      return {
        title: item.type === 'Episode' && item.seriesName ? item.seriesName : item.name,
        meta: [item.type === 'Episode' ? code : TYPE_LABEL[item.type], item.year].filter(Boolean).join(' · '),
      }
  }
}

export const WideCard = memo(function WideCard({ item, variant }: { item: Item; variant: WideCardVariant }) {
  const progress = progressOf(item)
  const plays = variant !== 'browse'
  const { title, meta } = wideCaption(item, variant)
  const verb = progress > 0 ? 'Continuar' : 'Reproduzir'
  const label = plays
    ? [`${verb} ${item.seriesName && item.type === 'Episode' ? `${item.seriesName}, ` : ''}${item.name}`, episodeCode(item), remainingLabel(item), item.played ? 'assistido' : undefined]
    : [title, meta, item.played ? 'assistido' : undefined]
  return (
    <Link
      to={plays ? playPath(item) : `/item/${encodeURIComponent(item.id)}`}
      className="card card--wide"
      aria-label={label.filter(Boolean).join(', ')}
      data-focus-key={`wide:${item.id}`}
    >
      <span className="card__frame">
        <Artwork src={item.backdrop ?? item.poster} title={item.name} />
        <ProgressBar value={progress} />
        <WatchedBadge played={item.played} />
      </span>
      <span className="card__caption" aria-hidden="true">
        <span className="card__title">{title}</span>
        {meta ? <span className="card__meta">{meta}</span> : null}
      </span>
    </Link>
  )
})

export const EpisodeCard = memo(function EpisodeCard({ item }: { item: Item }) {
  const progress = progressOf(item)
  const verb = progress > 0 ? 'Continuar' : 'Reproduzir'
  const label = [`${verb} ${item.name}`, episodeCode(item), remainingLabel(item) ?? formatRuntime(item.runtimeTicks), item.played ? 'assistido' : undefined]
  return (
    <Link to={playPath(item)} className="card card--episode" aria-label={label.filter(Boolean).join(', ')} data-focus-key={`episode:${item.id}`}>
      <span className="card__frame">
        <Artwork src={item.backdrop ?? item.poster} title={item.name} />
        <ProgressBar value={progress} />
        <WatchedBadge played={item.played} />
      </span>
      <span className="card__caption" aria-hidden="true">
        {item.indexNumber != null ? <span className="card__eyebrow">Episódio {item.indexNumber}</span> : null}
        <span className="card__title">{item.name}</span>
        {item.overview ? <span className="card__synopsis">{item.overview}</span> : null}
        <span className="card__meta">{remainingLabel(item) ?? formatRuntime(item.runtimeTicks)}</span>
      </span>
    </Link>
  )
})

export function ChapterCard({ item, chapter, index }: { item: Item; chapter: Chapter; index: number }) {
  const name = chapter.name || `Capítulo ${index + 1}`
  const at = formatPlayerClock(chapter.startTimeTicks / TICKS_PER_SECOND)
  return (
    <Link
      to={`/play/${encodeURIComponent(item.id)}${chapter.startTimeTicks > 0 ? `?t=${Math.round(chapter.startTimeTicks)}` : ''}`}
      className="card card--wide"
      aria-label={`Reproduzir a partir de ${name}, ${at}`}
      data-focus-key={`chapter:${index}`}
    >
      <span className="card__frame">
        <Artwork src={chapter.image} title={name} />
      </span>
      <span className="card__caption" aria-hidden="true">
        <span className="card__title">{name}</span>
        <span className="card__meta">{at}</span>
      </span>
    </Link>
  )
}
