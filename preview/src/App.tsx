import { useEffect } from 'react'
import { DemoBanner } from './components/DemoBanner'
import { Link } from './components/Link'
import { Sidebar } from './components/Sidebar'
import { BackIcon } from './components/icons'
import { EmptyState } from './components/States'
import { useRemoteNavigation } from './nav/remote'
import { goBack, navigate, useRoute, type Route } from './nav/router'
import { useScreenFocus } from './nav/useScreenFocus'
import { AccountScreen, ServerUnavailableScreen } from './screens/AccountScreen'
import { ConnectScreen } from './screens/ConnectScreen'
import { DetailScreen } from './screens/DetailScreen'
import { HomeScreen } from './screens/HomeScreen'
import { LibraryScreen } from './screens/LibraryScreen'
import { PlayerScreen } from './screens/PlayerScreen'
import { SearchScreen } from './screens/SearchScreen'
import { SettingsScreen } from './screens/SettingsScreen'
import { SessionProvider, useSession } from './session/SessionProvider'
import { appMode, type SessionState } from './session/sessionState'

function NotFound() {
  useScreenFocus(true, 'notFound')
  return (
    <div className="screen screen--page">
      <EmptyState title="Nada por aqui" detail="Esta página não existe no Luma.">
        <Link to="/" className="btn btn--primary" data-autofocus>
          Ir para o início
        </Link>
      </EmptyState>
    </div>
  )
}

function Screen({ route, libraryOpen }: { route: Route; libraryOpen: boolean }) {
  switch (route.name) {
    case 'settings':
      return <SettingsScreen />
    case 'account':
      return <AccountScreen />
    case 'notFound':
      return <NotFound />
  }
  if (!libraryOpen) return <ServerUnavailableScreen />
  switch (route.name) {
    case 'movies':
      return <LibraryScreen type="Movie" />
    case 'shows':
      return <LibraryScreen type="Series" />
    case 'search':
      return <SearchScreen />
    case 'item':
      return <DetailScreen key={route.id} id={route.id!} />
    default:
      return <HomeScreen />
  }
}

function Shell() {
  useRemoteNavigation()
  const route = useRoute()
  const { session, demo } = useSession()
  const mode = appMode(session, demo)

  useEffect(() => {
    if (mode === 'setup' && route.name !== 'connect') navigate('/connect', { replace: true })
  }, [mode, route.name])

  if (mode === 'checking') {
    return (
      <main id="main" className="app app--bare">
        <div className="splash" role="status">
          <span className="wordmark wordmark--large">Luma</span>
          <span className="visually-hidden">Verificando seu servidor</span>
        </div>
      </main>
    )
  }

  if (mode === 'setup' || route.name === 'connect') {
    return (
      <main id="main" className="app app--bare">
        <ConnectScreen />
      </main>
    )
  }

  if (route.name === 'play' && route.id && mode === 'library') {
    return (
      <main id="main" className="app app--player">
        <PlayerScreen key={route.path} id={route.id} />
      </main>
    )
  }

  return (
    <div className={`app app--shell app--${route.name}`}>
      <a
        className="skip-link"
        href="#main"
        data-spatial-skip
        onClick={event => {
          event.preventDefault()
          document.getElementById('main')?.focus()
        }}
      >
        Ir para o conteúdo
      </a>
      <Sidebar current={route.name} showTab />
      {route.name === 'item' ? (
        <button type="button" className="glass-circle detail-back" aria-label="Voltar" onClick={goBack} data-focus-key="detail:back" data-no-scroll>
          <BackIcon />
        </button>
      ) : null}
      <main id="main" className="app__main" tabIndex={-1}>
        <Screen route={route} libraryOpen={mode === 'library'} />
        <DemoBanner />
      </main>
    </div>
  )
}

export function App({ initialSession }: { initialSession?: SessionState }) {
  return (
    <SessionProvider initial={initialSession}>
      <Shell />
    </SessionProvider>
  )
}
