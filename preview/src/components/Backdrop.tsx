import { useEffect, useState } from 'react'

// Letting the source settle first keeps quick changes from strobing the art.
const SETTLE_MS = 150

interface Layer {
  src: string
  id: number
}

interface BackdropProps {
  src: string | null | undefined
  variant: 'hero' | 'detail'
}

export function Backdrop({ src, variant }: BackdropProps) {
  const [layers, setLayers] = useState<Layer[]>([])

  useEffect(() => {
    if (!src) return
    const timer = window.setTimeout(() => {
      setLayers(previous => {
        if (previous.at(-1)?.src === src) return previous
        return [...previous.slice(-1), { src, id: (previous.at(-1)?.id ?? 0) + 1 }]
      })
    }, SETTLE_MS)
    return () => window.clearTimeout(timer)
  }, [src])

  return (
    <div className={`backdrop backdrop--${variant}`} aria-hidden="true">
      {layers.map(layer => (
        <img key={layer.id} className="backdrop__image" src={layer.src} alt="" decoding="async" />
      ))}
      <div className="backdrop__scrim" />
    </div>
  )
}
