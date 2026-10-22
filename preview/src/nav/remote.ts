import { useEffect } from 'react'
import { goBack } from './router'
import { pickNext, type Direction } from './spatial'

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

const ARROWS: Record<string, Direction> = {
  ArrowUp: 'up',
  ArrowDown: 'down',
  ArrowLeft: 'left',
  ArrowRight: 'right',
}

export const BACK_EVENT = 'luma:back'

const groupMemory = new WeakMap<Element, HTMLElement>()

function isVisible(element: HTMLElement): boolean {
  if (element.closest('[inert], [aria-hidden="true"]')) return false
  if (element.getClientRects().length === 0) return false
  return getComputedStyle(element).visibility !== 'hidden'
}

function focusScope(): ParentNode {
  const scopes = document.querySelectorAll<HTMLElement>('[data-focus-scope]')
  return scopes[scopes.length - 1] ?? document
}

export function focusableIn(root: ParentNode): HTMLElement[] {
  return Array.from(root.querySelectorAll<HTMLElement>(FOCUSABLE)).filter(
    element => isVisible(element) && !element.hasAttribute('data-spatial-skip'),
  )
}

function isTextEntry(element: Element | null): element is HTMLInputElement | HTMLTextAreaElement {
  if (element instanceof HTMLTextAreaElement) return true
  return element instanceof HTMLInputElement && !['button', 'checkbox', 'radio', 'range', 'submit'].includes(element.type)
}

function caretCanLeave(input: HTMLInputElement | HTMLTextAreaElement, direction: Direction): boolean {
  if (direction === 'up' || direction === 'down') return !(input instanceof HTMLTextAreaElement)
  const { selectionStart, selectionEnd, value } = input
  if (selectionStart === null || selectionStart !== selectionEnd) return selectionStart === null
  return direction === 'left' ? selectionStart === 0 : selectionEnd === value.length
}

export function revealFocused(target: HTMLElement) {
  if (target.closest('[data-no-scroll]')) return
  // Remote and keyboard focus must remain visible immediately, even during repeated key presses.
  const behavior: ScrollBehavior = 'auto'
  if (target.closest('[data-scroll-top]')) {
    window.scrollTo({ top: 0, behavior })
  } else {
    const block = target.closest<HTMLElement>('[data-focus-group]') ?? target
    block.scrollIntoView({ block: 'nearest', behavior })
  }
  const track = target.closest<HTMLElement>('[data-scroll-x]')
  if (track) {
    const padding = parseFloat(getComputedStyle(track).scrollPaddingInlineStart) || 0
    const trackBox = track.getBoundingClientRect()
    const box = target.getBoundingClientRect()
    if (box.left < trackBox.left + padding || box.right > trackBox.right - padding) {
      track.scrollBy({ left: box.left - trackBox.left - padding, behavior })
    }
  }
}

export function focusElement(target: HTMLElement) {
  target.focus({ preventScroll: true })
  revealFocused(target)
}

export function moveFocus(direction: Direction): boolean {
  const active = document.activeElement instanceof HTMLElement ? document.activeElement : null
  const candidates = focusableIn(focusScope())
  if (!active || active === document.body || !candidates.includes(active)) {
    const first = candidates.find(element => element.hasAttribute('data-autofocus')) ?? candidates[0]
    if (first) focusElement(first)
    return Boolean(first)
  }
  const others = candidates.filter(element => element !== active)
  const index = pickNext(active.getBoundingClientRect(), others.map(element => element.getBoundingClientRect()), direction)
  let target = others[index]
  if (!target) return false

  const fromGroup = active.closest('[data-focus-group]')
  const toGroup = target.closest('[data-focus-group]')
  if (toGroup && toGroup !== fromGroup) {
    // Entering the sidebar lands on the current screen's item, as on tvOS, not on whichever row is level with focus.
    const current = toGroup.hasAttribute('data-focus-current') ? toGroup.querySelector<HTMLElement>('[aria-current="page"]') : null
    const remembered = direction === 'up' || direction === 'down' ? groupMemory.get(toGroup) : undefined
    const preferred = current ?? remembered
    if (preferred?.isConnected && isVisible(preferred)) target = preferred
  }
  focusElement(target)
  return true
}

function isBackKey(event: KeyboardEvent): boolean {
  if (event.key === 'Escape' || event.key === 'BrowserBack' || event.key === 'GoBack') return true
  return event.key === 'Backspace' && !isTextEntry(document.activeElement)
}

export function useRemoteNavigation() {
  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey) return
      if (isBackKey(event)) {
        const handledByScreen = !window.dispatchEvent(new Event(BACK_EVENT, { cancelable: true }))
        if (!handledByScreen) goBack()
        event.preventDefault()
        return
      }
      const direction = ARROWS[event.key]
      if (!direction) return
      const active = document.activeElement
      if (isTextEntry(active) && !caretCanLeave(active, direction)) return
      if (moveFocus(direction)) event.preventDefault()
    }

    function onFocusIn(event: FocusEvent) {
      const target = event.target
      if (!(target instanceof HTMLElement)) return
      const group = target.closest('[data-focus-group]')
      if (group) groupMemory.set(group, target)
    }

    window.addEventListener('keydown', onKeyDown)
    document.addEventListener('focusin', onFocusIn)
    return () => {
      window.removeEventListener('keydown', onKeyDown)
      document.removeEventListener('focusin', onFocusIn)
    }
  }, [])
}
