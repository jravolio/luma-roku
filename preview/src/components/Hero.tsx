import { useState, type KeyboardEvent as ReactKeyboardEvent } from 'react'
import type { Item } from '../api/types'
import { formatRating, kindLine, playPath, progressOf } from '../lib/format'
import { Backdrop } from './Backdrop'
import { ChevronIcon, InfoIcon, PlayIcon } from './icons'
import { Link } from './Link'
import { TitleArt } from './TitleArt'

interface HeroProps {
  items: Item[]
  highlight: (item: Item) => string | undefined
}

function RatingBadge({ rating }: { rating: Item['rating'] }) {
  const label = formatRating(rating)
  if (!label) return null
  return typeof rating === 'string' ? <span className="badge">{label}</span> : <span>{label}</span>
}

export function Hero({ items, highlight }: HeroProps) {
  const [index, setIndex] = useState(0)
  const item = items[Math.min(index, items.length - 1)]
  if (!item) return null
  const resuming = progressOf(item) > 0
  const playable = item.type === 'Movie' || item.type === 'Episode'
  const kinds = kindLine(item)
  const line = highlight(item)
  const count = items.length
  const go = (to: number) => setIndex((to + count) % count)

  function onActionsKey(event: ReactKeyboardEvent<HTMLDivElement>) {
    const first = event.currentTarget.querySelector('a, button')
    if (event.key === 'ArrowLeft' && event.target === first && index > 0) {
      event.preventDefault()
      go(index - 1)
    } else if (event.key === 'ArrowRight' && (event.target as HTMLElement).classList.contains('hero__next')) {
      event.preventDefault()
      go(index + 1)
    }
  }

  return (
    <section className="hero" aria-roledescription="carrossel" aria-label="Destaques" data-scroll-top>
      <Backdrop src={item.backdrop ?? item.poster} variant="hero" />
      <div className="hero__content">
        <div className="hero__copy" key={item.id} aria-live="polite">
          <h1 className="hero__title" id="hero-title">
            <TitleArt item={item} />
          </h1>
          {kinds.length || item.rating ? (
            <p className="meta hero__meta">
              {kinds.map(part => (
                <span key={part}>{part}</span>
              ))}
              <RatingBadge rating={item.rating} />
            </p>
          ) : null}
          {item.overview ? <p className="hero__overview">{item.overview}</p> : null}
          {line ? <p className="hero__highlight">{line}</p> : null}
        </div>
        <div className="hero__actions" onKeyDown={onActionsKey}>
          {playable ? (
            <Link to={playPath(item)} className="btn btn--primary btn--hero" data-autofocus data-focus-key="hero:play">
              <PlayIcon />
              {resuming ? 'Continuar' : 'Reproduzir'}
            </Link>
          ) : (
            <Link
              to={`/item/${encodeURIComponent(item.id)}`}
              className="btn btn--primary btn--hero"
              data-autofocus
              data-focus-key="hero:play"
            >
              Ver episódios
            </Link>
          )}
          <Link
            to={`/item/${encodeURIComponent(item.id)}`}
            className="glass-circle glass-circle--hero"
            aria-label={`Detalhes: ${item.name}`}
            data-focus-key="hero:info"
          >
            <InfoIcon />
          </Link>
          {count > 1 ? (
            <button
              type="button"
              className="hero__next"
              onClick={() => go(index + 1)}
              aria-label={`Próximo destaque (${(index + 1) % count + 1} de ${count})`}
              data-focus-key="hero:next"
            >
              <ChevronIcon />
            </button>
          ) : null}
        </div>
      </div>
      {count > 1 ? (
        <div className="hero__pager" aria-hidden="true">
          {items.map((candidate, dot) => (
            <button
              type="button"
              key={candidate.id}
              className="hero__dot"
              aria-current={dot === index || undefined}
              tabIndex={-1}
              data-spatial-skip
              onClick={() => go(dot)}
            />
          ))}
        </div>
      ) : null}
    </section>
  )
}
