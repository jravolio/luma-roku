import { useId, type ReactNode } from 'react'

export function Shelf({ title, children }: { title: string; children: ReactNode }) {
  const headingId = useId()
  return (
    <section className="shelf" aria-labelledby={headingId} data-focus-group>
      <h2 className="shelf__title" id={headingId}>
        {title}
      </h2>
      <div className="shelf__track" data-scroll-x role="list">
        {children}
      </div>
    </section>
  )
}

export function ShelfItem({ children }: { children: ReactNode }) {
  return (
    <div className="shelf__item" role="listitem">
      {children}
    </div>
  )
}
