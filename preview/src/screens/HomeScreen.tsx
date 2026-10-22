import type { HomeResponse, Item } from '../api/types'
import { WideCard, type WideCardVariant } from '../components/Cards'
import { Hero } from '../components/Hero'
import { Link } from '../components/Link'
import { Shelf, ShelfItem } from '../components/Shelf'
import { EmptyState, ErrorState, ShelfSkeleton } from '../components/States'
import { useResource } from '../data/useResource'
import { episodeCode, factsLine, remainingLabel } from '../lib/format'
import { useScreenFocus } from '../nav/useScreenFocus'
import { useSession } from '../session/SessionProvider'

const FEATURED = 6

function Rail({ title, items, variant }: { title: string; items: Item[]; variant: WideCardVariant }) {
  if (!items.length) return null
  return (
    <Shelf title={title}>
      {items.map(item => (
        <ShelfItem key={item.id}>
          <WideCard item={item} variant={variant} />
        </ShelfItem>
      ))}
    </Shelf>
  )
}

/** The carousel leads with what to resume, then new arrivals; one page per series, art-bearing titles preferred. */
export function featuredFrom(data: HomeResponse): Item[] {
  const pool = [...data.resume.slice(0, 1), ...data.latest, ...data.movies, ...data.series, ...data.resume.slice(1)]
  const withArt = pool.filter(item => item.backdrop)
  const candidates = withArt.length && pool[0]?.backdrop ? withArt : pool
  const seen = new Set<string>()
  const featured: Item[] = []
  for (const item of candidates) {
    const key = item.type === 'Episode' ? (item.seriesId ?? item.seriesName ?? item.id) : item.id
    if (seen.has(key)) continue
    seen.add(key)
    featured.push(item)
    if (featured.length === FEATURED) break
  }
  return featured
}

export function HomeScreen() {
  const { library, session } = useSession()
  const home = useResource(`home:${library.kind}`, signal => library.home(signal))

  const data = home.data
  const featured = data ? featuredFrom(data) : []
  useScreenFocus(Boolean(data) || Boolean(home.error), 'home')
  const serverName = session.status === 'connected' ? session.server.name : 'seu servidor'

  function highlight(item: Item): string | undefined {
    if (library.kind === 'demo') return 'Demo · Filme aberto do Blender Studio'
    if (data?.resume.some(entry => entry.id === item.id)) {
      return ['Continue assistindo', episodeCode(item), remainingLabel(item)].filter(Boolean).join(' · ')
    }
    if (data?.latest.some(entry => entry.id === item.id)) return `Novo em ${serverName}`
    return factsLine(item).join(' · ') || undefined
  }

  return (
    <div className="screen screen--home">
      {home.error ? (
        <div className="screen--page">
          <ErrorState error={home.error} onRetry={home.retry} />
        </div>
      ) : !data ? (
        <>
          <div className="hero hero--placeholder" aria-hidden="true" />
          <div className="shelves">
            <ShelfSkeleton />
          </div>
        </>
      ) : !featured.length ? (
        <div className="screen--page">
          <EmptyState
            title="Sua biblioteca está vazia"
            detail="O Luma está conectado, mas este servidor Jellyfin ainda não tem filmes ou séries. Adicione uma biblioteca no painel do Jellyfin e volte aqui."
          >
            <Link to="/account" className="btn btn--primary" data-autofocus>
              Abrir conta
            </Link>
          </EmptyState>
        </div>
      ) : (
        <>
          <Hero items={featured} highlight={highlight} />
          <div className="shelves">
            <Rail title="Continue assistindo" items={data.resume} variant="resume" />
            <Rail title="Adicionados recentemente" items={data.latest} variant="browse" />
            <Rail title="Filmes" items={data.movies} variant="browse" />
            <Rail title="Séries" items={data.series} variant="browse" />
          </div>
        </>
      )}
    </div>
  )
}
