import { useState } from 'react'
import type { Item, ItemPage } from '../api/types'
import { focusElement } from '../nav/remote'
import { useResource } from './useResource'

interface Extra {
  base: ItemPage
  items: Item[]
  next: number | null
}

export function usePagedItems(key: string | null, loadPage: (startIndex: number, signal?: AbortSignal) => Promise<ItemPage>) {
  const first = useResource(key, signal => loadPage(0, signal))
  const [extra, setExtra] = useState<Extra>()
  const [loadingMore, setLoadingMore] = useState(false)
  const [moreError, setMoreError] = useState<Error>()

  const page = first.data
  const appended = page && extra?.base === page ? extra : undefined
  const items = page ? (appended ? [...page.items, ...appended.items] : page.items) : undefined
  const next = appended ? appended.next : (page?.nextStartIndex ?? null)

  async function loadMore() {
    if (!page || next === null || loadingMore) return
    const firstNewIndex = items?.length ?? 0
    setLoadingMore(true)
    setMoreError(undefined)
    try {
      const more = await loadPage(next)
      setExtra({ base: page, items: [...(appended?.items ?? []), ...more.items], next: more.nextStartIndex })
      const firstNew = more.items[0]
      if (firstNew) {
        requestAnimationFrame(() => {
          const id = CSS.escape(firstNew.id)
          const card = document.querySelector<HTMLElement>(`[data-focus-key="card:${id}"], [data-focus-key="wide:${id}"]`)
          if (card && firstNewIndex > 0) focusElement(card)
        })
      }
    } catch (error) {
      setMoreError(error instanceof Error ? error : new Error(String(error)))
    } finally {
      setLoadingMore(false)
    }
  }

  return {
    items,
    total: page?.total,
    error: first.error,
    retry: first.retry,
    hasMore: next !== null,
    loadMore,
    loadingMore,
    moreError,
  }
}
