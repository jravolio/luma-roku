import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterEach } from 'vitest'
import { invalidateResources } from '../data/useResource'

// jsdom has no layout, so scrolling APIs the focus engine calls are absent.
Element.prototype.scrollIntoView = () => undefined
Element.prototype.scrollBy = () => undefined
window.scrollTo = () => undefined

afterEach(() => {
  cleanup()
  localStorage.clear()
  invalidateResources()
  window.history.replaceState(null, '', '/')
})
