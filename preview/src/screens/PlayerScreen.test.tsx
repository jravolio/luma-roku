import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Profiler, StrictMode } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ApiError } from '../api/gateway'
import type { Item, LibrarySource, PlaybackInfo, PlaybackOptions, PlaybackReport, PlaybackSelection } from '../api/types'

const reports: PlaybackReport[] = []
const calls: { id: string; start: number | undefined; options: PlaybackOptions | undefined }[] = []
let respond: (start: number | undefined, options: PlaybackOptions | undefined, call: number) => Promise<PlaybackInfo>
let current: Item
let episodes: Item[]

function session(n: number, start = 0, selection: Partial<PlaybackSelection> = {}, extra: Partial<PlaybackInfo> = {}): PlaybackInfo {
  return {
    url: `/api/media/session-${n}/stream.mp4`,
    playSessionId: `play${n}`,
    mediaSourceId: selection.mediaSourceId ?? 'src1',
    itemId: current.id,
    startTimeTicks: start,
    playMethod: 'DirectPlay',
    seekTimeTicks: start,
    positionOffsetTicks: 0,
    audioTracks: [
      { index: 1, label: 'English · AAC · Stereo', isDefault: true },
      { index: 2, label: 'Français · AC3 · 5.1' },
    ],
    subtitleTracks: [
      { index: 3, label: 'English · SUBRIP' },
      { index: 4, label: 'Português · PGSSUB' },
    ],
    mediaSources: [
      { id: 'src1', label: 'Version 1 · 1920 × 1080 · H264 · MKV' },
      { id: 'src2', label: 'Version 2 · 3840 × 2160 · HEVC · MKV' },
    ],
    qualityOptions: [
      { id: 'auto', label: 'Auto · up to 20 Mbps', maxBitrate: 20_000_000 },
      { id: '720p', label: 'Up to 720p · 4 Mbps', maxHeight: 720, maxBitrate: 4_000_000 },
    ],
    selection: { mediaSourceId: 'src1', audioStreamIndex: 1, subtitleStreamIndex: -1, quality: 'auto', ...selection },
    subtitleDelivery: 'off',
    stream: { width: 1920, height: 1080, videoCodec: 'h264', audioCodec: 'aac' },
    ...extra,
  }
}

/** Mirrors the gateway: each negotiation creates a new session reflecting the requested choices. */
function negotiated(start: number | undefined, options: PlaybackOptions | undefined, call: number): PlaybackInfo {
  const subtitleStreamIndex = options?.subtitleStreamIndex ?? -1
  return session(call, start ?? 0, {
    mediaSourceId: options?.mediaSourceId ?? 'src1',
    audioStreamIndex: options?.audioStreamIndex ?? 1,
    subtitleStreamIndex,
    quality: options?.quality ?? 'auto',
  }, { subtitleDelivery: subtitleStreamIndex === -1 ? 'off' : 'encoded' })
}

const library: LibrarySource = {
  kind: 'server',
  home: vi.fn(),
  itemsPage: vi.fn(),
  children: vi.fn(),
  childrenPage: async () => ({ items: episodes, total: episodes.length, nextStartIndex: null }),
  item: async () => current,
  playback: (id, start, options) => {
    calls.push({ id, start, options })
    return respond(start, options, calls.length)
  },
  report: async report => {
    reports.push(report)
  },
}

vi.mock('../session/SessionProvider', () => ({ useSession: () => ({ library }) }))

const { PlayerScreen } = await import('./PlayerScreen')

let seeks: number[]
let play: ReturnType<typeof vi.spyOn>
let pause: ReturnType<typeof vi.spyOn>

beforeEach(() => {
  reports.length = 0
  calls.length = 0
  seeks = []
  current = { id: 'movie1', name: 'Sintel', type: 'Movie', runtimeTicks: 8_880_000_000 }
  episodes = []
  respond = async (start, options, call) => negotiated(start, options, call)
  window.history.replaceState(null, '', '#/play/movie1')
  vi.spyOn(HTMLMediaElement.prototype, 'load').mockImplementation(() => undefined)
  pause = vi.spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(() => undefined)
  play = vi.spyOn(HTMLMediaElement.prototype, 'play').mockImplementation(() => Promise.resolve())
})

afterEach(() => {
  vi.restoreAllMocks()
})

function setMedia(video: HTMLVideoElement, currentTime: number, paused: boolean) {
  Object.defineProperty(video, 'currentTime', {
    configurable: true,
    get: () => currentTime,
    set: (value: number) => {
      seeks.push(value)
    },
  })
  Object.defineProperty(video, 'paused', { configurable: true, get: () => paused })
  Object.defineProperty(video, 'duration', { configurable: true, get: () => 888 })
}

async function mount(ui = <PlayerScreen id={current.id} />) {
  const view = render(ui)
  await waitFor(() => expect(screen.getByLabelText('Posição da reprodução')).toBeInTheDocument())
  return { view, video: view.container.querySelector('video')! }
}

function playingAt(video: HTMLVideoElement, seconds: number) {
  setMedia(video, 0, false)
  fireEvent.playing(video)
  setMedia(video, seconds, false)
  fireEvent.timeUpdate(video)
}

async function chooseFrom(menuButton: string | RegExp, item: string) {
  await userEvent.click(screen.getByRole('button', { name: menuButton }))
  await userEvent.click(within(screen.getByRole('menu')).getByRole('menuitemradio', { name: item }))
}

const stops = () => reports.filter(report => report.event === 'stop')

describe('PlayerScreen', () => {
  it('does not pull focus away from top navigation when playback controls have faded', async () => {
    const { video } = await mount()
    vi.useFakeTimers()
    try {
      playingAt(video, 10)
      act(() => vi.advanceTimersByTime(4100))
      expect(screen.getByRole('region', { name: 'Reprodução: Sintel' })).not.toHaveClass('player--chrome')
      const back = screen.getByRole('button', { name: 'Voltar' })
      act(() => back.focus())
      expect(fireEvent.keyDown(back, { key: 'ArrowRight' })).toBe(true)
      expect(back).toHaveFocus()
    } finally {
      vi.useRealTimers()
    }
  })

  it('avoids rendering the player for subsecond playback ticks while reporting the exact position', async () => {
    let commits = 0
    const { video } = await mount(
      <Profiler id="player" onRender={() => { commits += 1 }}>
        <PlayerScreen id="movie1" />
      </Profiler>,
    )
    setMedia(video, 10, false)
    fireEvent.playing(video)
    fireEvent.timeUpdate(video)
    const beforeTicks = commits

    for (let index = 1; index <= 40; index++) {
      setMedia(video, 10 + index / 100, false)
      fireEvent.timeUpdate(video)
    }

    expect(commits - beforeTicks).toBeLessThanOrEqual(1)
    expect(screen.getByLabelText('Posição da reprodução')).toHaveAttribute('aria-valuetext', '00:10 de 14:48')
    expect((screen.getByLabelText('Posição da reprodução') as HTMLInputElement).value).toBe('10.4')
    expect((screen.getByLabelText('Posição da reprodução') as HTMLInputElement).style.getPropertyValue('--fill')).toBe(`${(10.4 / 888) * 100}%`)
    setMedia(video, 11.01, false)
    fireEvent.timeUpdate(video)
    expect(screen.getByLabelText('Posição da reprodução')).toHaveAttribute('aria-valuetext', '00:11 de 14:48')
    setMedia(video, 10.4, true)
    fireEvent.pause(video)
    expect(reports.at(-1)).toMatchObject({ event: 'progress', positionTicks: 104_000_000 })
  })

  it('reports the last position on stop even though the video element is torn down first', async () => {
    const { view, video } = await mount()
    playingAt(video, 20)

    // Simulate the source cleanup resetting the element before the stop report runs.
    setMedia(video, 0, true)
    act(() => view.unmount())

    await waitFor(() => expect(stops()).toHaveLength(1))
    expect(reports[0]?.event).toBe('start')
    expect(stops()[0]).toMatchObject({ itemId: 'movie1', playSessionId: 'play1', positionTicks: 200_000_000, isPaused: false })
  })

  it('stops a negotiated session exactly once even when it never started playing', async () => {
    window.history.replaceState(null, '', '#/play/movie1?t=300000000')
    const { view } = await mount()
    act(() => view.unmount())
    await waitFor(() => expect(stops()).toHaveLength(1))
    expect(reports.map(report => report.event)).toEqual(['stop'])
    expect(stops()[0]).toMatchObject({ playSessionId: 'play1', positionTicks: 300_000_000 })
  })

  it('renegotiates instead of attaching a session an earlier player already ended', async () => {
    const shared = session(1)
    respond = async (start, options, call) => (call <= 2 ? shared : negotiated(start, options, call))
    const first = await mount()
    act(() => first.view.unmount())
    await waitFor(() => expect(stops()).toHaveLength(1))

    const { video } = await mount()
    await waitFor(() => expect(video.getAttribute('src')).toBe('/api/media/session-3/stream.mp4'))
    expect(calls).toHaveLength(3)
    expect(video.autoplay).toBe(true)
  })

  it('does not stop the session when StrictMode disposes and remounts the player', async () => {
    await mount(
      <StrictMode>
        <PlayerScreen id="movie1" />
      </StrictMode>,
    )
    await new Promise(resolve => setTimeout(resolve, 20))
    const attached = calls.length
    // StrictMode's first, discarded negotiation (if any) is cleaned up; the attached one is left alone.
    expect(stops().map(stop => stop.playSessionId)).not.toContain(`play${attached}`)
  })

  it('switches audio at the absolute position, stops the old session, and keeps playing', async () => {
    const { video } = await mount()
    playingAt(video, 20)

    await chooseFrom('Áudio', 'Français · AC3 · 5.1')

    await waitFor(() => expect(video.getAttribute('src')).toBe('/api/media/session-2/stream.mp4'))
    expect(calls[1]).toMatchObject({
      id: 'movie1',
      start: 200_000_000,
      options: { mediaSourceId: 'src1', audioStreamIndex: 2, subtitleStreamIndex: -1, quality: 'auto' },
    })
    expect(stops()).toEqual([expect.objectContaining({ playSessionId: 'play1', positionTicks: 200_000_000 })])
    expect(video.autoplay).toBe(true)
    expect(screen.getByRole('button', { name: 'Áudio' })).toHaveFocus()

    // Direct play resumes by seeking once, to the absolute time, not twice through an offset.
    setMedia(video, 0, false)
    fireEvent.loadedMetadata(video)
    expect(seeks).toEqual([20])
  })

  it('keeps a paused viewer paused across a subtitle switch and draws burned-in subtitles only once', async () => {
    const { view, video } = await mount()
    setMedia(video, 30, true)
    fireEvent.loadedMetadata(video)

    respond = async (start, options, call) => ({
      ...negotiated(start, options, call),
      subtitleDelivery: 'encoded',
      subtitles: [{ index: 3, url: '/api/media/subtitle-3.vtt', label: 'English' }],
    })
    await chooseFrom(/^Legendas/, 'English · SUBRIP')

    await waitFor(() => expect(video.getAttribute('src')).toBe('/api/media/session-2/stream.mp4'))
    expect(calls[1]?.options).toMatchObject({ subtitleStreamIndex: 3, audioStreamIndex: 1, quality: 'auto' })
    expect(video.autoplay).toBe(false)
    expect(view.container.querySelectorAll('track')).toHaveLength(0)
    expect(screen.getByRole('button', { name: 'Legendas: English · SUBRIP' })).toBeInTheDocument()

    // Leaving before the replacement ever plays still ends both sessions, each once, at the requested time.
    act(() => view.unmount())
    await waitFor(() => expect(stops()).toHaveLength(2))
    expect(stops().map(stop => [stop.playSessionId, stop.positionTicks])).toEqual([
      ['play1', 300_000_000],
      ['play2', 300_000_000],
    ])
    expect(reports.some(report => report.event === 'start')).toBe(false)
  })

  it('renders only the selected external subtitle and removes it for Off', async () => {
    respond = async (start, options, call) =>
      call === 1
        ? session(1, 0, { subtitleStreamIndex: 4 }, {
            subtitleDelivery: 'external',
            subtitles: [
              { index: 3, url: '/api/media/sub-3.vtt', label: 'English' },
              { index: 4, url: '/api/media/sub-4.vtt', label: 'Português', language: 'por' },
            ],
          })
        : negotiated(start, options, call)
    const { view, video } = await mount()
    const tracks = () => Array.from(view.container.querySelectorAll('track')).map(track => track.getAttribute('src'))
    expect(tracks()).toEqual(['/api/media/sub-4.vtt'])

    playingAt(video, 12)
    await chooseFrom(/^Legendas/, 'Desativadas')

    await waitFor(() => expect(video.getAttribute('src')).toBe('/api/media/session-2/stream.mp4'))
    expect(calls[1]?.options).toMatchObject({ subtitleStreamIndex: -1, audioStreamIndex: 1, mediaSourceId: 'src1' })
    expect(tracks()).toEqual([])
  })

  it('attaches only the newest choice and stops sessions from superseded requests', async () => {
    const pending: (() => void)[] = []
    const { view, video } = await mount()
    playingAt(video, 40)
    respond = (start, options, call) => new Promise(resolve => (pending[call] = () => resolve(negotiated(start, options, call))))

    await chooseFrom('Áudio', 'Français · AC3 · 5.1')
    await chooseFrom('Qualidade e versão', 'Até 720p · 4 Mbps')
    // The second request builds on the first, so the audio choice isn't lost.
    expect(calls[2]?.options).toMatchObject({ audioStreamIndex: 2, quality: '720p', subtitleStreamIndex: -1 })

    await act(async () => pending[3]?.())
    await waitFor(() => expect(video.getAttribute('src')).toBe('/api/media/session-3/stream.mp4'))
    await act(async () => pending[2]?.())
    await waitFor(() => expect(stops().map(stop => stop.playSessionId)).toEqual(['play1', 'play2']))
    expect(stops()[1]).toMatchObject({ positionTicks: 400_000_000, isPaused: true })
    expect(video.getAttribute('src')).toBe('/api/media/session-3/stream.mp4')

    act(() => view.unmount())
    await waitFor(() => expect(stops().map(stop => stop.playSessionId)).toEqual(['play1', 'play2', 'play3']))
  })

  it('keeps the last successful selection and resumes when a switch fails', async () => {
    const { video } = await mount()
    playingAt(video, 15)
    respond = async () => {
      throw new ApiError('invalid', 'The selected audio track is not available in this version.', 400)
    }

    await chooseFrom('Áudio', 'Français · AC3 · 5.1')

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Não foi possível mudar para Français · AC3 · 5.1. The selected audio track is not available in this version.',
    )
    expect(video.getAttribute('src')).toBe('/api/media/session-1/stream.mp4')
    expect(play).toHaveBeenCalled()
    expect(stops()).toEqual([])
    await userEvent.click(screen.getByRole('button', { name: 'Áudio' }))
    expect(screen.getByRole('menuitemradio', { name: 'English · AAC · Stereo' })).toHaveAttribute('aria-checked', 'true')
  })

  it('traps focus inside a menu and returns it to the control on Escape', async () => {
    await mount()
    const trigger = screen.getByRole('button', { name: 'Legendas: Desativadas' })
    await userEvent.click(trigger)
    const items = within(screen.getByRole('menu', { name: 'Legendas' })).getAllByRole('menuitemradio')
    expect(items[0]).toHaveFocus()
    expect(items[0]).toHaveAttribute('aria-checked', 'true')

    await userEvent.keyboard('{Shift>}{Tab}{/Shift}')
    expect(items.at(-1)).toHaveFocus()
    await userEvent.keyboard('{Tab}')
    expect(items[0]).toHaveFocus()
    await userEvent.keyboard('{ArrowDown}')
    expect(items[1]).toHaveFocus()

    await userEvent.keyboard('{Escape}')
    expect(screen.queryByRole('menu')).not.toBeInTheDocument()
    expect(trigger).toHaveFocus()
    expect(calls).toHaveLength(1)
  })

  it('lets Space activate a focused control instead of toggling playback', async () => {
    const { video } = await mount()
    playingAt(video, 5)
    screen.getByRole('button', { name: 'Áudio' }).focus()
    await userEvent.keyboard(' ')
    expect(screen.getByRole('menu', { name: 'Áudio' })).toBeInTheDocument()
    expect(pause).not.toHaveBeenCalled()
  })

  it('lists the quality ceilings and versions the server offers, with what is playing', async () => {
    await mount()
    await userEvent.click(screen.getByRole('button', { name: 'Qualidade e versão' }))
    const menu = screen.getByRole('menu', { name: 'Qualidade e versão' })
    expect(within(menu).getAllByRole('menuitemradio').map(item => [item.textContent, item.getAttribute('aria-checked')])).toEqual([
      ['Automática · até 20 Mbps', 'true'],
      ['Até 720p · 4 Mbps', 'false'],
      ['Version 1 · 1920 × 1080 · H264 · MKV', 'true'],
      ['Version 2 · 3840 × 2160 · HEVC · MKV', 'false'],
    ])
    expect(menu).toHaveTextContent('Reproduzindo agora · 1920 × 1080 · H264 · AAC · Reprodução direta')
  })

  it('offers chapters and the next episode only from real metadata', async () => {
    current = {
      id: 'e1',
      name: 'Pilot',
      type: 'Episode',
      seriesName: 'Long Show',
      parentIndexNumber: 1,
      indexNumber: 1,
      parentId: 'season1',
      seriesId: 'show1',
      chapters: [
        { name: 'Opening', startTimeTicks: 0 },
        { name: 'The Heist', startTimeTicks: 600_000_000 },
      ],
    }
    episodes = [current, { id: 'e2', name: 'Second', type: 'Episode', parentIndexNumber: 1, indexNumber: 2, parentId: 'season1' }]
    window.history.replaceState(null, '', '#/play/e1')
    const { video } = await mount()
    playingAt(video, 3)

    await chooseFrom('Capítulos', 'The Heist 01:00')
    expect(seeks.at(-1)).toBe(60)

    await userEvent.click(await screen.findByRole('button', { name: 'Próximo episódio: S1, E2 Second' }))
    expect(window.location.hash).toBe('#/play/e2')
  })

  it('shows neither chapters nor next episode without the metadata', async () => {
    await mount()
    await new Promise(resolve => setTimeout(resolve, 0))
    expect(screen.queryByRole('button', { name: /Capítulos/ })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /Próximo episódio/ })).not.toBeInTheDocument()
  })
})
