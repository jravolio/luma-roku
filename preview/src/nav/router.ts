import { useSyncExternalStore } from 'react'

export type RouteName =
  | 'home'
  | 'movies'
  | 'shows'
  | 'search'
  | 'item'
  | 'play'
  | 'settings'
  | 'account'
  | 'connect'
  | 'notFound'

export interface Route {
  name: RouteName
  id?: string
  params: URLSearchParams
  path: string
}

const NAVIGATE_EVENT = 'luma:navigate'

interface EntryState {
  lumaDepth?: number
  focusKey?: string
}

function entryState(): EntryState {
  return (window.history.state as EntryState | null) ?? {}
}

export function parseRoute(hash: string): Route {
  const path = hash.replace(/^#/, '') || '/'
  const [pathname = '/', query = ''] = path.split('?')
  const params = new URLSearchParams(query)
  const segments = pathname.split('/').filter(Boolean)
  const [first, second] = segments
  if (!first) return { name: 'home', params, path }
  if (segments.length === 1) {
    if (
      first === 'movies' ||
      first === 'shows' ||
      first === 'search' ||
      first === 'settings' ||
      first === 'account' ||
      first === 'connect'
    ) {
      return { name: first, params, path }
    }
  }
  if (segments.length === 2 && second && (first === 'item' || first === 'play')) {
    return { name: first, id: decodeURIComponent(second), params, path }
  }
  return { name: 'notFound', params, path }
}

function subscribe(callback: () => void) {
  window.addEventListener('popstate', callback)
  window.addEventListener('hashchange', callback)
  window.addEventListener(NAVIGATE_EVENT, callback)
  return () => {
    window.removeEventListener('popstate', callback)
    window.removeEventListener('hashchange', callback)
    window.removeEventListener(NAVIGATE_EVENT, callback)
  }
}

const getHash = () => window.location.hash

export function useRoute(): Route {
  const hash = useSyncExternalStore(subscribe, getHash)
  return parseRoute(hash)
}

function rememberFocus() {
  const key = (document.activeElement as HTMLElement | null)?.dataset?.focusKey
  if (key) window.history.replaceState({ ...entryState(), focusKey: key }, '')
}

export function navigate(path: string, options: { replace?: boolean } = {}) {
  const url = `#${path}`
  if (url === window.location.hash) return
  if (options.replace) {
    window.history.replaceState({ lumaDepth: entryState().lumaDepth ?? 0 }, '', url)
  } else {
    rememberFocus()
    window.history.pushState({ lumaDepth: (entryState().lumaDepth ?? 0) + 1 }, '', url)
  }
  window.dispatchEvent(new Event(NAVIGATE_EVENT))
}

export function goBack() {
  if ((entryState().lumaDepth ?? 0) > 0) window.history.back()
  else if (parseRoute(window.location.hash).name !== 'home') navigate('/', { replace: true })
}

export function restoredFocusKey(): string | undefined {
  return entryState().focusKey
}
