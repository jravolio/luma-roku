import { PosterCard } from '../components/Cards'
import { Link } from '../components/Link'
import { EmptyState, ErrorState, LoadMore, LoadingNotice } from '../components/States'
import { usePagedItems } from '../data/usePagedItems'
import { useScreenFocus } from '../nav/useScreenFocus'
import { useSession } from '../session/SessionProvider'

const COPY = {
  Movie: { title: 'Filmes', empty: 'Nenhum filme por enquanto', singular: 'filme', plural: 'filmes' },
  Series: { title: 'Séries', empty: 'Nenhuma série por enquanto', singular: 'série', plural: 'séries' },
} as const

export function LibraryScreen({ type }: { type: 'Movie' | 'Series' }) {
  const { library } = useSession()
  const items = usePagedItems(`items:${library.kind}:${type}`, (start, signal) => library.itemsPage({ type }, start, signal))
  const copy = COPY[type]
  useScreenFocus(Boolean(items.items) || Boolean(items.error), `library:${type}`)
  const count = items.total ?? items.items?.length ?? 0

  return (
    <div className="screen screen--page screen--library">
      <header className="library__header">
        <h1 className="visually-hidden">{copy.title}</h1>
        {items.items ? (
          <p className="library__count">
            {count} {count === 1 ? copy.singular : copy.plural}
            {library.kind === 'demo' ? ' · Demo' : ''}
          </p>
        ) : null}
      </header>
      {items.error ? (
        <ErrorState error={items.error} onRetry={items.retry} />
      ) : !items.items ? (
        <LoadingNotice label={`Carregando ${copy.title.toLowerCase()}…`} />
      ) : count === 0 ? (
        <EmptyState title={copy.empty} detail={`Seu servidor Jellyfin não tem ${copy.plural} para mostrar no Luma.`}>
          <Link to="/" className="btn btn--primary" data-autofocus>
            Voltar ao início
          </Link>
        </EmptyState>
      ) : (
        <>
          <ul className="grid" role="list" aria-label={copy.title}>
            {items.items.map(item => (
              <li key={item.id}>
                <PosterCard item={item} />
              </li>
            ))}
          </ul>
          <LoadMore
            shown={items.items.length}
            total={items.total}
            hasMore={items.hasMore}
            loading={items.loadingMore}
            error={items.moreError}
            onLoad={items.loadMore}
          />
        </>
      )}
    </div>
  )
}
