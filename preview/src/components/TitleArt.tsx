import { useState } from 'react'
import type { Item } from '../api/types'
import { displayTitle } from '../lib/format'

/** The server's title logo when it has one, else the title set in type. */
export function TitleArt({ item }: { item: Item }) {
  const title = displayTitle(item)
  const [failedSrc, setFailedSrc] = useState<string>()
  if (item.logo && failedSrc !== item.logo) {
    return <img className="title-art" src={item.logo} alt={title} decoding="async" onError={() => setFailedSrc(item.logo ?? undefined)} />
  }
  return <span className="title-text">{title}</span>
}
