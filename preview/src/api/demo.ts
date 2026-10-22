import { DEMO_SAMPLE, demoItems, demoParents, demoSeedProgress } from './demoCatalog'
import { ApiError } from './gateway'
import { TICKS_PER_SECOND, type Item, type ItemQuery, type LibrarySource, type PlaybackInfo } from './types'

const SAMPLE_TICKS = DEMO_SAMPLE.seconds * TICKS_PER_SECOND
const PLAYED_THRESHOLD = 0.92

interface Progress {
  fraction: number
  played: boolean
  updatedAt: number
}

type ProgressMap = Record<string, Progress>

function seed(): ProgressMap {
  return Object.fromEntries(
    Object.entries(demoSeedProgress).map(([id, fraction], index) => [id, { fraction, played: false, updatedAt: index }]),
  )
}

// Demo progress lives in memory on purpose: the demo is opt-in per launch and must leave nothing behind.
let progressMap: ProgressMap = seed()

export function resetDemoProgress() {
  progressMap = seed()
}

// Measured from the bundled file with ffprobe: one VP9 854×480 video stream and one stereo Opus audio stream, no subtitles.
// The demo offers exactly these; quality and subtitle choices stay empty rather than pretending.
const SAMPLE_CHOICES: Pick<PlaybackInfo, 'audioTracks' | 'subtitleTracks' | 'mediaSources' | 'qualityOptions' | 'selection' | 'subtitleDelivery' | 'stream'> = {
  audioTracks: [{ index: 1, label: 'Áudio original · Opus · Estéreo', codec: 'opus', channels: 2, isDefault: true }],
  subtitleTracks: [],
  mediaSources: [{ id: 'demo-sample', label: 'Vídeo de exemplo · 854 × 480 · VP9 · WEBM', width: 854, height: 480 }],
  qualityOptions: [],
  selection: { mediaSourceId: 'demo-sample', audioStreamIndex: 1, subtitleStreamIndex: -1, quality: 'original' },
  subtitleDelivery: 'off',
  stream: { width: 854, height: 480, videoCodec: 'vp9', audioCodec: 'opus' },
}

const byId = new Map(demoItems.map(item => [item.id, item]))

function related(item: Item): Item {
  const parentId = demoParents[item.id]
  if (!parentId) return { ...item }
  const seriesId = item.type === 'Episode' ? (demoParents[parentId] ?? parentId) : parentId
  return { ...item, parentId, seriesId }
}

function withProgress(source: Item, progress: ProgressMap): Item {
  const item = related(source)
  const entry = progress[item.id]
  if (!entry || !item.runtimeTicks) return item
  return {
    ...item,
    played: entry.played,
    positionTicks: entry.played ? 0 : Math.round(entry.fraction * item.runtimeTicks),
  }
}

function find(id: string): Item {
  const item = byId.get(id)
  if (!item) throw new ApiError('notFound', 'Este título não faz parte da biblioteca de demonstração.', 404)
  return item
}

function matches(item: Item, search: string): boolean {
  const needle = search.trim().toLocaleLowerCase()
  if (!needle) return true
  return [item.name, item.seriesName, item.overview, ...(item.genres ?? [])].some(value =>
    value?.toLocaleLowerCase().includes(needle),
  )
}

function findItems(query: ItemQuery): Item[] {
  const progress = progressMap
  return demoItems
    .filter(item => {
      if (query.parentId) return demoParents[item.id] === query.parentId
      if (query.type) return item.type === query.type && matches(item, query.search ?? '')
      return (item.type === 'Movie' || item.type === 'Series' || item.type === 'Episode') && matches(item, query.search ?? '')
    })
    .map(item => withProgress(item, progress))
}

export const demoLibrary: LibrarySource = {
  kind: 'demo',
  async home() {
    const progress = progressMap
    const all = demoItems.map(item => withProgress(item, progress))
    const resume = all
      .filter(item => (item.positionTicks ?? 0) > 0)
      .sort((a, b) => (progress[b.id]?.updatedAt ?? 0) - (progress[a.id]?.updatedAt ?? 0))
    const movies = all.filter(item => item.type === 'Movie')
    const latest = all
      .filter(item => item.type === 'Movie' || item.type === 'Episode')
      .toSorted((a, b) => (b.year ?? 0) - (a.year ?? 0))
      .slice(0, 8)
    return { resume, latest, movies, series: all.filter(item => item.type === 'Series') }
  },
  async itemsPage(query) {
    const items = findItems(query)
    return { items, total: items.length, nextStartIndex: null }
  },
  async item(id) {
    return withProgress(find(id), progressMap)
  },
  async children(id) {
    find(id)
    return findItems({ parentId: id })
  },
  async childrenPage(id) {
    const items = await demoLibrary.children(id)
    return { items, total: items.length, nextStartIndex: null }
  },
  async playback(id, startTimeTicks = 0, options = {}) {
    const item = find(id)
    if (item.type !== 'Movie' && item.type !== 'Episode') {
      throw new ApiError('invalid', 'Escolha um episódio para reproduzir.', 400)
    }
    const { mediaSourceId, audioStreamIndex, subtitleStreamIndex, quality } = options
    if (
      (mediaSourceId !== undefined && mediaSourceId !== 'demo-sample') ||
      (audioStreamIndex !== undefined && audioStreamIndex !== 1) ||
      (subtitleStreamIndex !== undefined && subtitleStreamIndex !== -1) ||
      (quality !== undefined && quality !== 'original')
    ) {
      throw new ApiError('invalid', 'O vídeo de exemplo tem uma versão, uma faixa de áudio e nenhuma legenda.', 400)
    }
    const fraction = item.runtimeTicks ? Math.min(1, startTimeTicks / item.runtimeTicks) : 0
    return {
      url: DEMO_SAMPLE.url,
      playSessionId: `demo-${Date.now().toString(36)}`,
      mediaSourceId: 'demo-sample',
      itemId: id,
      startTimeTicks: Math.round(fraction * SAMPLE_TICKS),
      playMethod: 'DirectPlay',
      sample: { title: DEMO_SAMPLE.title, credit: DEMO_SAMPLE.credit },
      ...structuredClone(SAMPLE_CHOICES),
    }
  },
  async report(report) {
    if (report.event === 'start') return
    const fraction = Math.min(1, Math.max(0, report.positionTicks / SAMPLE_TICKS))
    const played = fraction >= PLAYED_THRESHOLD
    if (fraction === 0 && !progressMap[report.itemId]) return
    progressMap = { ...progressMap, [report.itemId]: { fraction: played ? 0 : fraction, played, updatedAt: Date.now() } }
  },
}
