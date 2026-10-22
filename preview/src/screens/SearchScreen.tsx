import { useEffect, useState } from 'react'
import { PosterCard } from '../components/Cards'
import { SearchIcon } from '../components/icons'
import { EmptyState, ErrorState, LoadMore, LoadingNotice } from '../components/States'
import { usePagedItems } from '../data/usePagedItems'
import { navigate, useRoute } from '../nav/router'
import { useScreenFocus } from '../nav/useScreenFocus'
import { useSession } from '../session/SessionProvider'

const KEYS = 'abcdefghijklmnopqrstuvwxyz1234567890'.split('')
const FILTERS = [
  { value: '', label: 'Todos' },
  { value: 'Movie', label: 'Filmes' },
  { value: 'Series', label: 'Séries' },
] as const

type Filter = (typeof FILTERS)[number]['value']

const DEBOUNCE_MS = 300

export function SearchScreen() {
  const route = useRoute()
  const { library } = useSession()
  const query = route.params.get('q') ?? ''
  const filter = (route.params.get('type') ?? '') as Filter
  const [debounced, setDebounced] = useState(query)

  useEffect(() => {
    const timer = window.setTimeout(() => setDebounced(query), DEBOUNCE_MS)
    return () => window.clearTimeout(timer)
  }, [query])

  function update(nextQuery: string, nextFilter: Filter = filter) {
    const params = new URLSearchParams()
    if (nextQuery) params.set('q', nextQuery)
    if (nextFilter) params.set('type', nextFilter)
    const encoded = params.toString()
    navigate(`/search${encoded ? `?${encoded}` : ''}`, { replace: true })
  }

  const term = debounced.trim()
  const results = usePagedItems(term ? `search:${library.kind}:${filter}:${term}` : null, (start, signal) =>
    library.itemsPage({ search: term, type: filter || undefined }, start, signal),
  )
  useScreenFocus(true, 'search')
  const settling = query.trim() !== term

  return (
    <div className="screen screen--page screen--search">
      <h1 className="visually-hidden">Buscar</h1>
      <div className="search">
        <div className="search__panel" data-focus-group>
          <label className="search__field">
            <SearchIcon className="search__icon" />
            <span className="visually-hidden">Buscar títulos</span>
            <input
              type="search"
              value={query}
              placeholder={library.kind === 'demo' ? 'Buscar na demonstração' : 'Filmes, séries e gêneros'}
              autoComplete="off"
              spellCheck={false}
              onChange={event => update(event.target.value)}
              data-autofocus
              data-focus-key="search:input"
            />
          </label>
          <div className="keyboard" role="group" aria-label="Teclado na tela">
            {KEYS.map(key => (
              <button type="button" key={key} className="key" onClick={() => update(query + key)} data-focus-key={`key:${key}`}>
                {key}
              </button>
            ))}
            <button type="button" className="key key--wide" onClick={() => update(`${query} `)} aria-label="Espaço">
              Espaço
            </button>
            <button
              type="button"
              className="key key--wide"
              onClick={() => update(query.slice(0, -1))}
              disabled={!query}
              aria-label="Apagar último caractere"
            >
              Apagar
            </button>
            <button type="button" className="key key--wide" onClick={() => update('')} disabled={!query}>
              Limpar
            </button>
          </div>
          <div className="chips" role="group" aria-label="Filtrar resultados">
            {FILTERS.map(option => (
              <button
                type="button"
                key={option.value || 'all'}
                className="chip"
                aria-pressed={filter === option.value}
                onClick={() => update(query, option.value)}
              >
                {option.label}
              </button>
            ))}
          </div>
        </div>
        <section className="search__results" aria-label="Resultados" aria-busy={(Boolean(term) && !results.items && !results.error) || settling}>
          {!term && !query.trim() ? (
            <EmptyState
              title="Encontre algo para assistir"
              detail={
                library.kind === 'demo'
                  ? 'Busque na biblioteca de demonstração. Experimente “llama”, “dragão” ou “ficção científica”.'
                  : 'Busque filmes, séries e episódios no seu servidor por título ou gênero.'
              }
            />
          ) : results.error ? (
            <ErrorState error={results.error} onRetry={results.retry} />
          ) : !results.items || settling ? (
            <LoadingNotice label="Buscando…" />
          ) : results.items.length === 0 ? (
            <EmptyState title={`Nenhum resultado para “${term}”`} detail="Confira a grafia ou tente buscar por gênero." />
          ) : (
            <>
              <p className="page-subtitle" role="status">
                {results.total ?? results.items.length} {(results.total ?? results.items.length) === 1 ? 'resultado' : 'resultados'} para “{term}”
              </p>
              <ul className="grid" role="list" aria-label="Resultados da busca">
                {results.items.map(item => (
                  <li key={item.id}>
                    <PosterCard item={item} />
                  </li>
                ))}
              </ul>
              <LoadMore
                shown={results.items.length}
                total={results.total}
                hasMore={results.hasMore}
                loading={results.loadingMore}
                error={results.moreError}
                onLoad={results.loadMore}
              />
            </>
          )}
        </section>
      </div>
    </div>
  )
}
