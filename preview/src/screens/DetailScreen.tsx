import { useState, type ReactNode } from 'react'
import type { Item, LibrarySource } from '../api/types'
import { Backdrop } from '../components/Backdrop'
import { ChapterCard, EpisodeCard } from '../components/Cards'
import { PlayIcon, RestartIcon } from '../components/icons'
import { Link } from '../components/Link'
import { Shelf, ShelfItem } from '../components/Shelf'
import { ErrorState, LoadMore, LoadingNotice } from '../components/States'
import { TitleArt } from '../components/TitleArt'
import { usePagedItems } from '../data/usePagedItems'
import { useResource } from '../data/useResource'
import { episodeCode, factsLine, formatRating, kindLine, playPath, progressOf, remainingLabel } from '../lib/format'
import { useScreenFocus } from '../nav/useScreenFocus'
import { useSession } from '../session/SessionProvider'

interface Season {
  key: string
  label: string
  id?: string
  episodes?: Item[]
}

function seasonsFrom(children: Item[]): Season[] {
  const seasons = children.filter(child => child.type === 'Season')
  if (seasons.length) {
    return seasons.map(season => ({ key: season.id, id: season.id, label: season.name || `Temporada ${season.indexNumber ?? ''}`.trim() }))
  }
  const grouped = new Map<number, Item[]>()
  for (const child of children) {
    if (child.type !== 'Episode') continue
    const index = child.parentIndexNumber ?? 1
    grouped.set(index, [...(grouped.get(index) ?? []), child])
  }
  return [...grouped.entries()]
    .sort(([a], [b]) => a - b)
    .map(([index, episodes]) => ({ key: `season-${index}`, label: index === 0 ? 'Especiais' : `Temporada ${index}`, episodes }))
}

export function nextUp(episodes: readonly Item[]): Item | undefined {
  return (
    episodes.find(episode => progressOf(episode) > 0 && !episode.played) ??
    episodes.find(episode => !episode.played) ??
    episodes[0]
  )
}

function DetailHero({ item, demo, actions }: { item: Item; demo: boolean; actions: ReactNode }) {
  const kinds = kindLine(item)
  const rating = formatRating(item.rating)
  const facts = [
    ...factsLine(item),
    item.type === 'Episode' && item.seriesName ? item.name : undefined,
    item.played ? 'Assistido' : remainingLabel(item),
  ].filter((part): part is string => Boolean(part))
  return (
    <section className="detail__hero" aria-labelledby="detail-title">
      {demo ? <p className="eyebrow">Demo · Filme aberto do Blender Studio</p> : null}
      <h1 className="detail__title" id="detail-title">
        <TitleArt item={item} />
      </h1>
      {kinds.length || rating ? (
        <p className="meta detail__kinds">
          {kinds.map(part => (
            <span key={part}>{part}</span>
          ))}
          {rating ? typeof item.rating === 'string' ? <span className="badge">{rating}</span> : <span>{rating}</span> : null}
        </p>
      ) : null}
      {item.overview ? <p className="detail__overview">{item.overview}</p> : null}
      {facts.length ? (
        <p className="meta detail__facts">
          {facts.map(part => (
            <span key={part}>{part}</span>
          ))}
        </p>
      ) : null}
      <div className="detail__actions">{actions}</div>
    </section>
  )
}

function SeriesDetail({ series, library }: { series: Item; library: LibrarySource }) {
  const children = usePagedItems(`series-children:${library.kind}:${series.id}`, (start, signal) =>
    library.childrenPage(series.id, start, signal),
  )
  const seasons = children.items ? seasonsFrom(children.items) : []
  const [chosenKey, setChosenKey] = useState<string>()
  const season = seasons.find(candidate => candidate.key === chosenKey) ?? seasons[0]
  const seasonEpisodes = usePagedItems(season?.id ? `children:${library.kind}:${season.id}` : null, (start, signal) =>
    library.childrenPage(season!.id!, start, signal),
  )
  const episodes = season?.episodes ?? seasonEpisodes.items?.filter(item => item.type === 'Episode')
  const error = children.error ?? seasonEpisodes.error
  const up = episodes ? nextUp(episodes) : undefined
  useScreenFocus(Boolean(episodes) || Boolean(error) || (Boolean(children.items) && seasons.length === 0), `series:${series.id}`)

  const actions = error ? null : !children.items || (seasons.length > 0 && !episodes) ? (
    <LoadingNotice label="Carregando episódios…" />
  ) : seasons.length === 0 ? (
    <>
      <p className="detail__note">Ainda não há episódios de {series.name} disponíveis.</p>
      <Link to="/shows" className="btn" data-autofocus>
        Explorar séries
      </Link>
    </>
  ) : up ? (
    <Link to={playPath(up)} className="btn btn--primary" data-autofocus data-focus-key="detail:play">
      <PlayIcon />
      {progressOf(up) > 0 ? 'Continuar' : 'Reproduzir'} {episodeCode(up) ?? up.name}
    </Link>
  ) : null

  return (
    <>
      <DetailHero item={series} demo={library.kind === 'demo'} actions={actions} />
      {error ? (
        <div className="detail__section">
          <ErrorState error={error} onRetry={children.error ? children.retry : seasonEpisodes.retry} />
        </div>
      ) : seasons.length ? (
        <section className="detail__section episodes" aria-label="Episódios">
          {seasons.length > 1 ? (
            <div className="season-tabs" role="tablist" aria-label="Temporadas" data-focus-group>
              {seasons.map(candidate => (
                <button
                  type="button"
                  role="tab"
                  key={candidate.key}
                  className="tab"
                  aria-selected={candidate.key === season?.key}
                  onClick={() => setChosenKey(candidate.key)}
                  onFocus={() => setChosenKey(candidate.key)}
                  data-focus-key={`season:${candidate.key}`}
                >
                  {candidate.label}
                </button>
              ))}
            </div>
          ) : (
            <h2 className="episodes__heading">{season?.label}</h2>
          )}
          {!episodes ? (
            <LoadingNotice label="Carregando episódios…" />
          ) : (
            <div className="shelf shelf--episodes" data-focus-group>
              <h3 className="visually-hidden">Episódios de {season?.label}</h3>
              <div className="shelf__track" data-scroll-x role="list">
                {episodes.map(episode => (
                  <div className="shelf__item" role="listitem" key={episode.id}>
                    <EpisodeCard item={episode} />
                  </div>
                ))}
                {seasonEpisodes.hasMore && !season?.episodes ? (
                  <div className="shelf__item shelf__item--more" role="listitem">
                    <LoadMore
                      shown={episodes.length}
                      total={seasonEpisodes.total}
                      hasMore
                      loading={seasonEpisodes.loadingMore}
                      error={seasonEpisodes.moreError}
                      onLoad={seasonEpisodes.loadMore}
                    />
                  </div>
                ) : null}
              </div>
            </div>
          )}
          {children.hasMore ? (
            <LoadMore
              shown={children.items?.length ?? 0}
              total={children.total}
              hasMore
              loading={children.loadingMore}
              error={children.moreError}
              onLoad={children.loadMore}
            />
          ) : null}
        </section>
      ) : null}
    </>
  )
}

export function DetailScreen({ id }: { id: string }) {
  const { library } = useSession()
  const item = useResource(`item:${library.kind}:${id}`, signal => library.item(id, signal))
  const data = item.data
  useScreenFocus((Boolean(data) && data?.type !== 'Series') || Boolean(item.error), `item:${id}`)

  if (item.error) {
    return (
      <div className="screen screen--page">
        <ErrorState error={item.error} onRetry={item.retry}>
          <Link to="/" className="btn">
            Voltar ao início
          </Link>
        </ErrorState>
      </div>
    )
  }
  if (!data) {
    return (
      <div className="screen screen--page">
        <LoadingNotice label="Carregando…" />
      </div>
    )
  }

  const resuming = progressOf(data) > 0
  const playable = data.type === 'Movie' || data.type === 'Episode'
  const chapters = data.chapters ?? []

  return (
    <div className="screen screen--detail">
      <Backdrop src={data.backdrop ?? data.poster} variant="detail" />
      <article className="detail">
        {data.type === 'Series' ? (
          <SeriesDetail series={data} library={library} />
        ) : (
          <>
            <DetailHero
              item={data}
              demo={library.kind === 'demo'}
              actions={
                playable ? (
                  <>
                    <Link to={playPath(data)} className="btn btn--primary" data-autofocus data-focus-key="detail:play">
                      <PlayIcon />
                      {resuming ? 'Continuar' : 'Reproduzir'}
                    </Link>
                    {resuming ? (
                      <Link
                        to={`/play/${encodeURIComponent(data.id)}`}
                        className="glass-circle"
                        aria-label="Reproduzir desde o início"
                        data-focus-key="detail:restart"
                      >
                        <RestartIcon />
                      </Link>
                    ) : null}
                    {data.type === 'Episode' && data.seriesId ? (
                      <Link to={`/item/${encodeURIComponent(data.seriesId)}`} className="btn" data-focus-key="detail:series">
                        Temporadas e episódios
                      </Link>
                    ) : null}
                  </>
                ) : null
              }
            />
            {playable && chapters.length ? (
              <div className="detail__section">
                <Shelf title="Capítulos">
                  {chapters.map((chapter, index) => (
                    <ShelfItem key={`${index}:${chapter.startTimeTicks}`}>
                      <ChapterCard item={data} chapter={chapter} index={index} />
                    </ShelfItem>
                  ))}
                </Shelf>
              </div>
            ) : null}
          </>
        )}
      </article>
    </div>
  )
}
