import {
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type ComponentType,
  type FocusEvent as ReactFocusEvent,
  type KeyboardEvent as ReactKeyboardEvent,
  type SVGProps,
} from 'react'
import { BACK_EVENT, focusElement, focusableIn } from '../nav/remote'
import type { RouteName } from '../nav/router'
import { useSession } from '../session/SessionProvider'
import type { SessionState } from '../session/sessionState'
import { ChevronLeftIcon, FilmIcon, GearIcon, HomeIcon, SearchIcon, TvIcon } from './icons'
import { Link } from './Link'

interface Destination {
  route: RouteName
  to: string
  label: string
  Icon: ComponentType<SVGProps<SVGSVGElement>>
}

const MAIN: Destination[] = [
  { route: 'search', to: '/search', label: 'Buscar', Icon: SearchIcon },
  { route: 'home', to: '/', label: 'Início', Icon: HomeIcon },
  { route: 'movies', to: '/movies', label: 'Filmes', Icon: FilmIcon },
  { route: 'shows', to: '/shows', label: 'Séries', Icon: TvIcon },
]

const SETTINGS: Destination = { route: 'settings', to: '/settings', label: 'Configurações', Icon: GearIcon }

const ALL = [...MAIN, SETTINGS]

interface AccountSummary {
  name: string
  detail: string
  tone: 'ok' | 'warn' | 'demo' | 'muted'
  description: string
}

function summarize(session: SessionState, demo: boolean): AccountSummary {
  if (demo) {
    return { name: 'Demo', detail: 'Não é seu servidor', tone: 'demo', description: 'biblioteca de demonstração, sem conexão com um servidor' }
  }
  switch (session.status) {
    case 'connected':
      return {
        name: session.user.name,
        detail: session.server.name,
        tone: 'ok',
        description: `${session.user.name} em ${session.server.name}`,
      }
    case 'offline': {
      const server = session.server?.name ?? 'Servidor'
      return { name: session.user.name, detail: `${server} indisponível`, tone: 'warn', description: `${session.user.name}, ${server} indisponível` }
    }
    case 'gatewayDown':
      return {
        name: session.remembered?.user?.name ?? 'Conta',
        detail: 'Serviço interrompido',
        tone: 'warn',
        description: 'serviço local não está em execução',
      }
    default:
      return { name: 'Sem conexão', detail: 'Conectar um servidor', tone: 'muted', description: 'sem conexão' }
  }
}

function useClock(): string {
  const format = () => new Intl.DateTimeFormat('pt-BR', { hour: 'numeric', minute: '2-digit' }).format(new Date())
  const [now, setNow] = useState(format)
  useEffect(() => {
    const timer = window.setInterval(() => setNow(format()), 15_000)
    return () => window.clearInterval(timer)
  }, [])
  return now
}

function NavItem({ destination, current }: { destination: Destination; current: RouteName }) {
  const { route, to, label, Icon } = destination
  return (
    <Link
      to={to}
      className="sidebar__item"
      aria-current={current === route ? 'page' : undefined}
      data-focus-key={`nav:${route}`}
    >
      <span className="sidebar__glyph" aria-hidden="true">
        <Icon />
      </span>
      <span className="sidebar__label">{label}</span>
    </Link>
  )
}

function contentTarget(remembered: HTMLElement | null): HTMLElement | null {
  if (remembered?.isConnected && focusableIn(document).includes(remembered)) return remembered
  const main = document.getElementById('main')
  if (!main) return null
  return main.querySelector<HTMLElement>('[data-autofocus]') ?? focusableIn(main)[0] ?? null
}

export function Sidebar({ current, showTab }: { current: RouteName; showTab: boolean }) {
  const { session, demo } = useSession()
  const account = summarize(session, demo)
  const clock = useClock()
  const navRef = useRef<HTMLElement>(null)
  const panelRef = useRef<HTMLDivElement>(null)
  const lastContent = useRef<HTMLElement | null>(null)
  const [expanded, setExpanded] = useState(false)
  const [focusPanel, setFocusPanel] = useState(false)
  const here = ALL.find(destination => destination.route === current) ?? (current === 'account' ? undefined : MAIN[1]!)
  const TabIcon = here?.Icon

  useEffect(() => {
    function remember(event: FocusEvent) {
      const target = event.target
      if (target instanceof HTMLElement && !navRef.current?.contains(target) && target.closest('#main')) lastContent.current = target
    }
    document.addEventListener('focusin', remember)
    return () => document.removeEventListener('focusin', remember)
  }, [])

  useLayoutEffect(() => {
    if (!expanded || !focusPanel) return
    setFocusPanel(false)
    const panel = panelRef.current
    const target = panel?.querySelector<HTMLElement>('[aria-current="page"]') ?? (panel ? focusableIn(panel)[0] : undefined)
    if (target) focusElement(target)
  }, [expanded, focusPanel])

  useEffect(() => {
    if (!expanded) return
    function onBack(event: Event) {
      if (!navRef.current?.contains(document.activeElement)) return
      event.preventDefault()
      returnToContent()
    }
    window.addEventListener(BACK_EVENT, onBack)
    return () => window.removeEventListener(BACK_EVENT, onBack)
  }, [expanded])

  function open() {
    setExpanded(true)
    setFocusPanel(true)
  }

  function returnToContent() {
    const target = contentTarget(lastContent.current)
    setExpanded(false)
    if (target) focusElement(target)
  }

  function onBlur(event: ReactFocusEvent<HTMLElement>) {
    const next = event.relatedTarget
    if (next instanceof Node && navRef.current?.contains(next)) return
    setExpanded(false)
  }

  function onKeyDown(event: ReactKeyboardEvent<HTMLElement>) {
    const panel = panelRef.current
    if (!expanded || !panel || !panel.contains(document.activeElement)) return
    const items = focusableIn(panel)
    const index = items.indexOf(document.activeElement as HTMLElement)
    switch (event.key) {
      case 'ArrowRight':
        event.preventDefault()
        returnToContent()
        break
      case 'ArrowDown':
      case 'ArrowUp': {
        // The panel overlays content; spatial search would leak into the art behind it.
        event.preventDefault()
        const target = items[index + (event.key === 'ArrowDown' ? 1 : -1)]
        if (target) focusElement(target)
        break
      }
      case 'ArrowLeft':
        event.preventDefault()
        break
    }
  }

  return (
    <nav
      ref={navRef}
      className="sidebar"
      data-expanded={expanded}
      aria-label="Menu principal"
      data-focus-group
      data-focus-current
      data-no-scroll={current !== 'item' || undefined}
      data-scroll-top={current === 'item' || undefined}
      onBlur={onBlur}
      onKeyDown={onKeyDown}
      onPointerLeave={() => {
        if (!navRef.current?.contains(document.activeElement)) setExpanded(false)
      }}
    >
      {showTab ? (
        <button
          type="button"
          className="sidebar__tab"
          aria-label={`Abrir menu. Página atual: ${here?.label ?? 'Conta'}`}
          aria-expanded={expanded}
          aria-controls="sidebar-panel"
          onFocus={open}
          onClick={open}
          onPointerEnter={() => setExpanded(true)}
          data-focus-key="nav:tab"
        >
          <ChevronLeftIcon className="sidebar__tab-chevron" />
          <span className="sidebar__glyph" aria-hidden="true">
            {TabIcon ? <TabIcon /> : account.name.charAt(0).toLocaleUpperCase()}
          </span>
          <span className="sidebar__tab-label">{here?.label ?? 'Conta'}</span>
        </button>
      ) : null}
      <div className="sidebar__panel" id="sidebar-panel" ref={panelRef}>
        <Link
          to="/account"
          className="sidebar__item sidebar__account"
          aria-current={current === 'account' ? 'page' : undefined}
          aria-label={`Conta: ${account.description}`}
          data-focus-key="nav:account"
        >
          <span className={`avatar avatar--${account.tone}`} aria-hidden="true">
            {account.name.charAt(0).toLocaleUpperCase()}
          </span>
          <span className="sidebar__who" aria-hidden="true">
            <span className="sidebar__name">{account.name}</span>
            <span className="sidebar__detail">
              <span className={`dot dot--${account.tone}`} />
              {account.detail}
            </span>
          </span>
          <span className="sidebar__clock" aria-hidden="true">
            {clock}
          </span>
        </Link>
        <div className="sidebar__main">
          {ALL.map(destination => (
            <NavItem key={destination.route} destination={destination} current={current} />
          ))}
        </div>
      </div>
    </nav>
  )
}
