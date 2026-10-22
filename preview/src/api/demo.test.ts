import { describe, expect, it } from 'vitest'
import { demoLibrary, resetDemoProgress } from './demo'
import { DEMO_SAMPLE } from './demoCatalog'
import { TICKS_PER_SECOND } from './types'

describe('demo library', () => {
  it('labels playback as a sample, never a server stream', async () => {
    const info = await demoLibrary.playback('demo-sintel')
    expect(info.url).toBe(DEMO_SAMPLE.url)
    expect(info.sample?.title).toBe(DEMO_SAMPLE.title)
  })

  it('maps sample progress back onto the film runtime and resumes from it', async () => {
    const film = await demoLibrary.item('demo-sintel')
    const info = await demoLibrary.playback(film.id)
    const halfway = (DEMO_SAMPLE.seconds / 2) * TICKS_PER_SECOND
    await demoLibrary.report({ event: 'stop', itemId: film.id, playSessionId: info.playSessionId, mediaSourceId: info.mediaSourceId, positionTicks: halfway, isPaused: true })

    const after = await demoLibrary.item(film.id)
    expect(after.positionTicks).toBe(Math.round(film.runtimeTicks! / 2))
    const home = await demoLibrary.home()
    expect(home.resume[0]?.id).toBe(film.id)

    const resumed = await demoLibrary.playback(film.id, after.positionTicks!)
    expect(resumed.startTimeTicks).toBeCloseTo(halfway, -3)
  })

  it('marks a title played near the end', async () => {
    const info = await demoLibrary.playback('demo-spring')
    await demoLibrary.report({ event: 'stop', itemId: 'demo-spring', playSessionId: info.playSessionId, mediaSourceId: info.mediaSourceId, positionTicks: DEMO_SAMPLE.seconds * TICKS_PER_SECOND, isPaused: true })
    expect(await demoLibrary.item('demo-spring')).toMatchObject({ played: true, positionTicks: 0 })
  })

  it('searches titles and genres', async () => {
    expect((await demoLibrary.itemsPage({ search: 'llama' }, 0)).items.map(item => item.id)).toContain('demo-caminandes-e1')
    expect((await demoLibrary.itemsPage({ search: 'ficção científica', type: 'Movie' }, 0)).items.map(item => item.name)).toContain('Tears of Steel')
  })

  it('keeps progress in memory only, and forgets it on reset', async () => {
    const info = await demoLibrary.playback('demo-charge')
    await demoLibrary.report({ event: 'stop', itemId: 'demo-charge', playSessionId: info.playSessionId, mediaSourceId: info.mediaSourceId, positionTicks: 30 * TICKS_PER_SECOND, isPaused: true })
    expect((await demoLibrary.item('demo-charge')).positionTicks).toBeGreaterThan(0)
    expect(localStorage.length).toBe(0)

    resetDemoProgress()
    expect((await demoLibrary.item('demo-charge')).positionTicks).toBeUndefined()
  })

  it('walks series → seasons → episodes', async () => {
    const [season] = await demoLibrary.children('demo-caminandes')
    expect(season?.type).toBe('Season')
    const page = await demoLibrary.childrenPage(season!.id, 0)
    expect(page.items.map(item => item.indexNumber)).toEqual([1, 2, 3])
    expect(page.nextStartIndex).toBeNull()
  })

  it('offers only the sample clip’s real version and audio, and no invented quality choices', async () => {
    const info = await demoLibrary.playback('demo-sintel')
    expect(info.mediaSources).toEqual([expect.objectContaining({ id: 'demo-sample', width: 854, height: 480 })])
    expect(info.audioTracks).toHaveLength(1)
    expect(info.subtitleTracks).toEqual([])
    expect(info.qualityOptions).toEqual([])
    expect(info.subtitleDelivery).toBe('off')
    await expect(demoLibrary.playback('demo-sintel', 0, { quality: '720p' })).rejects.toMatchObject({ kind: 'invalid' })
    await expect(demoLibrary.playback('demo-sintel', 0, { subtitleStreamIndex: -1, audioStreamIndex: 1 })).resolves.toBeTruthy()
  })

  it('links episodes to their season and series for next-episode lookup', async () => {
    expect(await demoLibrary.item('demo-caminandes-e2')).toMatchObject({ parentId: 'demo-caminandes-s1', seriesId: 'demo-caminandes' })
  })
})
