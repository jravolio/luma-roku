import type { Item, LibrarySource } from '../api/types'

const MAX_PAGES = 20

/** Loads episode pages until the one after `afterId` (or, with null, the first episode) is known. */
async function loadEpisodes(library: LibrarySource, parentId: string, afterId: string | null, signal: AbortSignal): Promise<Item[]> {
  const episodes: Item[] = []
  let start: number | null = 0
  for (let page = 0; start !== null && page < MAX_PAGES; page += 1) {
    const result = await library.childrenPage(parentId, start, signal)
    episodes.push(...result.items.filter(child => child.type === 'Episode'))
    const found = afterId === null ? episodes.length > 0 : episodes.slice(0, -1).some(episode => episode.id === afterId)
    if (found) break
    start = result.nextStartIndex
  }
  return episodes
}

/** The episode after `item` in its season, else the first episode of the following season. */
export async function findNextEpisode(library: LibrarySource, item: Item, signal: AbortSignal): Promise<Item | null> {
  if (item.type !== 'Episode' || !item.parentId) return null
  const siblings = await loadEpisodes(library, item.parentId, item.id, signal)
  const index = siblings.findIndex(episode => episode.id === item.id)
  if (index < 0) return null
  const following = siblings[index + 1]
  if (following) return following
  if (!item.seriesId || item.seriesId === item.parentId) return null
  const seasons = (await library.childrenPage(item.seriesId, 0, signal)).items.filter(child => child.type === 'Season')
  const seasonIndex = seasons.findIndex(season => season.id === item.parentId)
  const nextSeason = seasonIndex >= 0 ? seasons[seasonIndex + 1] : undefined
  if (!nextSeason) return null
  return (await loadEpisodes(library, nextSeason.id, null, signal))[0] ?? null
}
