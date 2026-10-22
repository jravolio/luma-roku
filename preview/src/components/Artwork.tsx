import { useState } from 'react'

interface ArtworkProps {
  src: string | null | undefined
  title: string
  className?: string
  eager?: boolean
}

export function Artwork({ src, title, className = '', eager = false }: ArtworkProps) {
  const [failedSrc, setFailedSrc] = useState<string>()
  if (!src || failedSrc === src) {
    return (
      <div className={`artwork artwork--missing ${className}`} aria-hidden="true">
        <span>{title}</span>
      </div>
    )
  }
  return (
    <img
      className={`artwork ${className}`}
      src={src}
      alt=""
      loading={eager ? 'eager' : 'lazy'}
      decoding="async"
      draggable={false}
      onError={() => setFailedSrc(src)}
    />
  )
}
