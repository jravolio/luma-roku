import { createContext, use, useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { demoLibrary, resetDemoProgress } from '../api/demo'
import { ApiError, gateway, gatewayLibrary } from '../api/gateway'
import type { LibrarySource, ServerInfo } from '../api/types'
import { invalidateResources } from '../data/useResource'
import { deriveSession, readRemembered, writeRemembered, type SessionState } from './sessionState'

interface SessionContextValue {
  session: SessionState
  library: LibrarySource
  refresh: () => Promise<SessionState>
  connect: (url: string) => Promise<ServerInfo>
  login: (serverId: string, username: string, password: string) => Promise<SessionState>
  logout: () => Promise<void>
  demo: boolean
  startDemo: () => void
  exitDemo: () => void
}

const SessionContext = createContext<SessionContextValue | null>(null)

const RECHECK_MS = 15_000

function rememberFrom(state: SessionState) {
  if (state.status === 'connected') writeRemembered({ server: state.server, user: state.user })
  else if (state.status === 'offline' && state.server) writeRemembered({ server: state.server, user: state.user })
  else if (state.status === 'noServer') writeRemembered(undefined)
}

function identityOf(state: SessionState): string {
  const server = 'server' in state ? state.server?.id : undefined
  const user = 'user' in state ? state.user?.id : undefined
  return `${state.status}:${server ?? ''}:${user ?? ''}`
}

function failureState(error: unknown): SessionState {
  const message = error instanceof Error ? error.message : 'O Luma não conseguiu acessar o serviço local.'
  return { status: 'gatewayDown', remembered: readRemembered(), message }
}

export function SessionProvider({ children, initial }: { children: ReactNode; initial?: SessionState }) {
  const [session, setSession] = useState<SessionState>(initial ?? { status: 'checking' })
  const [demoChosen, setDemoChosen] = useState(false)
  const demo = demoChosen && session.status !== 'connected'
  const identityRef = useRef(identityOf(session))

  const apply = useCallback((next: SessionState) => {
    rememberFrom(next)
    if (next.status === 'connected') setDemoChosen(false)
    const identity = identityOf(next)
    if (identityRef.current !== identity) invalidateResources()
    identityRef.current = identity
    setSession(next)
    return next
  }, [])

  const inFlight = useRef<Promise<SessionState> | null>(null)
  const refresh = useCallback(() => {
    inFlight.current ??= gateway
      .session()
      .then(
        response => apply(deriveSession(response, readRemembered())),
        error => apply(failureState(error)),
      )
      .finally(() => {
        inFlight.current = null
      })
    return inFlight.current
  }, [apply])

  useEffect(() => {
    if (!initial) void refresh()
  }, [initial, refresh])

  const needsRecheck = session.status === 'offline' || session.status === 'gatewayDown'
  useEffect(() => {
    if (!needsRecheck) return
    let timer: number | undefined
    let stopped = false
    const schedule = () => {
      timer = window.setTimeout(() => {
        void refresh().finally(() => {
          if (!stopped) schedule()
        })
      }, RECHECK_MS)
    }
    schedule()
    const onOnline = () => void refresh()
    window.addEventListener('online', onOnline)
    return () => {
      stopped = true
      window.clearTimeout(timer)
      window.removeEventListener('online', onOnline)
    }
  }, [needsRecheck, refresh])

  const connect = useCallback(async (url: string) => (await gateway.connect(url)).server, [])

  const login = useCallback(
    async (serverId: string, username: string, password: string) => {
      await gateway.login(serverId, username, password)
      return refresh()
    },
    [refresh],
  )

  const logout = useCallback(async () => {
    await gateway.logout()
    writeRemembered(undefined)
    await refresh()
  }, [refresh])

  const startDemo = useCallback(() => {
    resetDemoProgress()
    invalidateResources()
    setDemoChosen(true)
  }, [])

  const exitDemo = useCallback(() => {
    setDemoChosen(false)
    resetDemoProgress()
    invalidateResources()
  }, [])

  const library = useMemo<LibrarySource>(() => {
    if (demo) return demoLibrary
    const recheckOn = async <T,>(work: Promise<T>): Promise<T> => {
      try {
        return await work
      } catch (error) {
        if (error instanceof ApiError && (error.kind === 'unreachable' || error.kind === 'unauthorized')) void refresh()
        throw error
      }
    }
    return {
      kind: 'server',
      home: signal => recheckOn(gatewayLibrary.home(signal)),
      itemsPage: (query, start, signal) => recheckOn(gatewayLibrary.itemsPage(query, start, signal)),
      item: (id, signal) => recheckOn(gatewayLibrary.item(id, signal)),
      children: (id, signal) => recheckOn(gatewayLibrary.children(id, signal)),
      childrenPage: (id, start, signal) => recheckOn(gatewayLibrary.childrenPage(id, start, signal)),
      playback: (id, ticks, options) => recheckOn(gatewayLibrary.playback(id, ticks, options)),
      report: (report, options) => gatewayLibrary.report(report, options),
    }
  }, [demo, refresh])

  const value = useMemo(
    () => ({ session, library, refresh, connect, login, logout, demo, startDemo, exitDemo }),
    [session, library, refresh, connect, login, logout, demo, startDemo, exitDemo],
  )
  return <SessionContext value={value}>{children}</SessionContext>
}

export function useSession(): SessionContextValue {
  const value = use(SessionContext)
  if (!value) throw new Error('useSession must be used inside SessionProvider')
  return value
}
