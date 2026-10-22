import { fireEvent, render, waitFor } from '@testing-library/react'
import { StrictMode } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { LibrarySource } from '../api/types'

const instances: FakeHls[] = []

class FakeHls {
  static isSupported = () => true
  static Events = { ERROR: 'hlsError' }
  static ErrorTypes = { NETWORK_ERROR: 'networkError', MEDIA_ERROR: 'mediaError' }
  readonly blob = `blob:hls-${instances.length + 1}`
  media: HTMLMediaElement | null = null
  destroyed = false
  constructor(readonly config: { startPosition?: number } = {}) {
    instances.push(this)
  }
  on() {}
  loadSource() {}
  recoverMediaError() {}
  attachMedia(media: HTMLMediaElement) {
    this.media = media
    media.setAttribute('src', this.blob)
  }
  destroy() {
    this.destroyed = true
    // Pessimistic: real detach resets the element, which breaks any other instance attached to it.
    this.media?.removeAttribute('src')
  }
}

// StrictMode mounts, disposes and remounts synchronously, so even an instant import() resolves after the first disposal.
vi.mock('../lib/loadHls', () => ({ loadHls: async () => FakeHls }))

let resumeTicks = 0

const library: LibrarySource = {
  kind: 'server',
  home: vi.fn(),
  itemsPage: vi.fn(),
  children: vi.fn(),
  childrenPage: vi.fn(),
  item: async id => ({ id, name: 'Stream', type: 'Movie' }),
  playback: async id => ({
    url: '/api/media/00000000-0000-0000-0000-000000000000/stream.m3u8',
    playSessionId: 'play1',
    mediaSourceId: 'src1',
    itemId: id,
    startTimeTicks: resumeTicks,
    playMethod: 'Transcode',
    positionOffsetTicks: 0,
    seekTimeTicks: resumeTicks,
  }),
  report: async () => undefined,
}

vi.mock('../session/SessionProvider', () => ({ useSession: () => ({ library }) }))

const { PlayerScreen } = await import('./PlayerScreen')

beforeEach(() => {
  instances.length = 0
  resumeTicks = 0
  window.history.replaceState(null, '', '#/play/stream1')
  vi.spyOn(HTMLMediaElement.prototype, 'load').mockImplementation(() => undefined)
  vi.spyOn(HTMLMediaElement.prototype, 'play').mockImplementation(() => Promise.resolve())
  vi.spyOn(HTMLMediaElement.prototype, 'canPlayType').mockReturnValue('')
})

describe('PlayerScreen HLS', () => {
  it('attaches exactly one hls.js instance when StrictMode disposes the first mount while its import is pending', async () => {
    const view = render(
      <StrictMode>
        <PlayerScreen id="stream1" />
      </StrictMode>,
    )
    await waitFor(() => expect(instances.length).toBeGreaterThan(0))
    await new Promise(resolve => setTimeout(resolve, 60))

    const live = instances.filter(instance => !instance.destroyed)
    expect(live).toHaveLength(1)
    expect(instances).toHaveLength(1)
    expect(view.container.querySelector('video')?.getAttribute('src')).toBe(live[0]!.blob)
  })

  it('starts loading a full-timeline playlist at the absolute resume time and seeks there once', async () => {
    resumeTicks = 7_660_000_000
    window.history.replaceState(null, '', '#/play/stream1?t=7660000000')
    const view = render(<PlayerScreen id="stream1" />)
    await waitFor(() => expect(instances).toHaveLength(1))
    expect(instances[0]!.config).toEqual({ startPosition: 766 })

    const video = view.container.querySelector('video')!
    const seeks: number[] = []
    Object.defineProperty(video, 'currentTime', { configurable: true, get: () => 0, set: (value: number) => seeks.push(value) })
    fireEvent.loadedMetadata(video)
    expect(seeks).toEqual([766])
  })
})

