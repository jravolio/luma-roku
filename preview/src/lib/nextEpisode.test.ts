import { describe, expect, it, vi } from 'vitest'
import type { Item, ItemPage, LibrarySource } from '../api/types'
import { findNextEpisode } from './nextEpisode'

const episode = (id: string, parentId: string, index: number): Item => ({ id, name: id, type: 'Episode', parentId, seriesId: 'show', indexNumber: index })

function libraryWith(pages: Record<string, ItemPage[]>) {
  const childrenPage = vi.fn(async (id: string, start: number) => {
    const page = pages[id]?.find((_, index) => index * 2 === start)
    return page ?? { items: [], total: 0, nextStartIndex: null }
  })
  return { library: { childrenPage } as unknown as LibrarySource, childrenPage }
}

const signal = new AbortController().signal

describe('findNextEpisode', () => {
  it('follows season pages until the episode after the current one is known', async () => {
    const { library, childrenPage } = libraryWith({
      s1: [
        { items: [episode('e1', 's1', 1), episode('e2', 's1', 2)], total: 4, nextStartIndex: 2 },
        { items: [episode('e3', 's1', 3), episode('e4', 's1', 4)], total: 4, nextStartIndex: null },
      ],
    })
    expect((await findNextEpisode(library, episode('e2', 's1', 2), signal))?.id).toBe('e3')
    expect(childrenPage).toHaveBeenCalledTimes(2)
  })

  it('continues with the first episode of the next season', async () => {
    const { library } = libraryWith({
      s1: [{ items: [episode('e1', 's1', 1)], total: 1, nextStartIndex: null }],
      show: [{ items: [{ id: 's1', name: 'Season 1', type: 'Season' }, { id: 's2', name: 'Season 2', type: 'Season' }], total: 2, nextStartIndex: null }],
      s2: [{ items: [episode('e5', 's2', 1)], total: 1, nextStartIndex: null }],
    })
    expect((await findNextEpisode(library, episode('e1', 's1', 1), signal))?.id).toBe('e5')
  })

  it('offers nothing after the final episode, or for movies', async () => {
    const { library, childrenPage } = libraryWith({
      s1: [{ items: [episode('e1', 's1', 1)], total: 1, nextStartIndex: null }],
      show: [{ items: [{ id: 's1', name: 'Season 1', type: 'Season' }], total: 1, nextStartIndex: null }],
    })
    expect(await findNextEpisode(library, episode('e1', 's1', 1), signal)).toBeNull()
    childrenPage.mockClear()
    expect(await findNextEpisode(library, { id: 'm', name: 'Movie', type: 'Movie' }, signal)).toBeNull()
    expect(childrenPage).not.toHaveBeenCalled()
  })
})
