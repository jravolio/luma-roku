import { useEffect } from 'react'
import { focusElement, focusableIn } from './remote'
import { restoredFocusKey } from './router'

export function useScreenFocus(ready: boolean, screenKey: string) {
  useEffect(() => {
    if (!ready) return
    const main = document.getElementById('main')
    if (!main) return
    const active = document.activeElement
    if (active && active !== document.body && active.isConnected) return
    const key = restoredFocusKey()
    const restored = key ? main.querySelector<HTMLElement>(`[data-focus-key="${key.replace(/["\\]/g, '\\$&')}"]`) : null
    const target =
      restored ?? main.querySelector<HTMLElement>('[data-autofocus]') ?? focusableIn(main)[0] ?? null
    if (target) focusElement(target)
  }, [ready, screenKey])
}
