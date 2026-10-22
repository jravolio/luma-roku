import { useEffect, useId, useRef, type KeyboardEvent as ReactKeyboardEvent, type RefObject } from 'react'
import { CheckIcon } from './icons'

export interface MenuItem {
  key: string
  label: string
  detail?: string
  checked: boolean
  /** A request for this choice is in flight; the check stays on the last successful choice. */
  pending?: boolean
  onSelect: () => void
}

export interface MenuSection {
  title: string
  items: MenuItem[]
  empty?: string
}

interface PlayerMenuProps {
  label: string
  sections: MenuSection[]
  footer?: string
  trigger: RefObject<HTMLButtonElement | null>
  onClose: () => void
}

function menuItems(root: HTMLElement | null): HTMLButtonElement[] {
  return root ? Array.from(root.querySelectorAll<HTMLButtonElement>('[role="menuitemradio"]:not(:disabled)')) : []
}

export function PlayerMenu({ label, sections, footer, trigger, onClose }: PlayerMenuProps) {
  const ref = useRef<HTMLDivElement>(null)
  const baseId = useId()
  const onCloseRef = useRef(onClose)
  useEffect(() => {
    onCloseRef.current = onClose
  })

  useEffect(() => {
    const items = menuItems(ref.current)
    const start = items.find(item => item.getAttribute('aria-checked') === 'true') ?? items[0] ?? ref.current
    start?.focus({ preventScroll: true })
    start?.scrollIntoView?.({ block: 'nearest' })
    const opener = trigger.current
    function onPointerDown(event: PointerEvent) {
      const target = event.target as Node
      if (ref.current?.contains(target) || opener?.contains(target)) return
      onCloseRef.current()
    }
    document.addEventListener('pointerdown', onPointerDown)
    return () => {
      document.removeEventListener('pointerdown', onPointerDown)
      if (opener?.isConnected) opener.focus({ preventScroll: true })
    }
  }, [trigger])

  function onKeyDown(event: ReactKeyboardEvent<HTMLDivElement>) {
    const items = menuItems(ref.current)
    const index = items.indexOf(document.activeElement as HTMLButtonElement)
    const move = (to: number) => {
      const target = items[(to + items.length) % items.length]
      target?.focus({ preventScroll: true })
      target?.scrollIntoView?.({ block: 'nearest' })
    }
    switch (event.key) {
      case 'Escape':
      case 'Backspace':
      case 'GoBack':
      case 'BrowserBack':
        event.preventDefault()
        event.stopPropagation()
        onClose()
        return
      case 'Tab':
        event.preventDefault()
        move(index + (event.shiftKey ? -1 : 1))
        return
      case 'ArrowDown':
        event.preventDefault()
        if (index < items.length - 1) move(index + 1)
        return
      case 'ArrowUp':
        event.preventDefault()
        if (index > 0) move(index - 1)
        return
      case 'Home':
        event.preventDefault()
        move(0)
        return
      case 'End':
        event.preventDefault()
        move(items.length - 1)
        return
      case 'ArrowLeft':
      case 'ArrowRight':
        // Focus never leaks to the controls behind an open menu.
        event.preventDefault()
        return
    }
    // Playback shortcuts (Space, j, k, l, c) belong to the player, not the open list.
    if (event.key !== 'Enter') event.stopPropagation()
  }

  return (
    <div
      ref={ref}
      className="menu"
      role="menu"
      aria-label={label}
      tabIndex={-1}
      onKeyDown={onKeyDown}
      data-focus-scope
    >
      <div className="menu__scroll">
        {sections.map((section, sectionIndex) => {
          const headingId = `${baseId}-${sectionIndex}`
          return (
            <div className="menu__section" role="group" aria-labelledby={headingId} key={section.title}>
              <p className="menu__title" id={headingId}>
                {section.title}
              </p>
              {section.items.length === 0 ? (
                <p className="menu__empty">{section.empty ?? 'Nenhuma opção disponível.'}</p>
              ) : (
                section.items.map(item => (
                  <button
                    type="button"
                    role="menuitemradio"
                    aria-checked={item.checked}
                    aria-busy={item.pending || undefined}
                    className="menu__item"
                    key={item.key}
                    onClick={item.onSelect}
                  >
                    <span className="menu__check" aria-hidden="true">
                      {item.checked ? <CheckIcon /> : item.pending ? <span className="menu__pending" /> : null}
                    </span>
                    <span className="menu__text">
                      <span className="menu__label">{item.label}</span>
                      {item.detail ? (
                        <>
                          {' '}
                          <span className="menu__detail">{item.detail}</span>
                        </>
                      ) : null}
                    </span>
                  </button>
                ))
              )}
            </div>
          )
        })}
      </div>
      {footer ? <p className="menu__footer">{footer}</p> : null}
    </div>
  )
}
