import { act, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { StrictMode } from 'react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { App } from './App'
import type { Item, PlaybackInfo, PlaybackReport } from './api/types'
import { invalidateResources } from './data/useResource'

type Handler = (url: URL, init?: RequestInit) => unknown

function serve(routes: Record<string, Handler | unknown>) {
  const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input), 'http://127.0.0.1:5173')
    const key = `${init?.method ?? 'GET'} ${url.pathname}`
    if (!(key in routes)) return new Response(JSON.stringify({ error: { code: 'not_found', message: key } }), { status: 404 })
    const route = routes[key]
    const body = typeof route === 'function' ? (route as Handler)(url, init) : route
    if (body instanceof Response) return body
    return new Response(JSON.stringify(body), { status: 200 })
  })
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

afterEach(() => {
  vi.unstubAllGlobals()
})

const server = { id: 'f1c2a3b4d5e6', name: 'media-pc', url: 'http://192.168.1.50:8096' }
const user = { id: 'u1', name: 'Julio' }
const emptyHome = { resume: [], latest: [], movies: [], series: [] }
const movie = (n: number): Item => ({ id: `m${n}`, name: `Movie ${n}`, type: 'Movie', year: 2000 + (n % 20) })

function seriesServer() {
  const series: Item = { id: 'show1', name: 'Test Series', type: 'Series' }
  const episode = (season: number): Item => ({ id: `e${season}`, name: `Season ${season} premiere`, type: 'Episode', seriesId: series.id, seriesName: series.name, parentId: `s${season}`, parentIndexNumber: season, indexNumber: 1 })
  const page = (items: Item[]) => ({ items, total: items.length, startIndex: 0, nextStartIndex: null })
  return serve({
    'GET /api/session': { connected: true, server, user },
    'GET /api/home': { ...emptyHome, series: [series] },
    'GET /api/items/show1': { item: series },
    'GET /api/items/e2': { item: episode(2) },
    'GET /api/items/show1/children': page([1, 2].map(n => ({ id: `s${n}`, name: `Season ${n}`, type: 'Season' }))),
    'GET /api/items/s1/children': page([episode(1)]),
    'GET /api/items/s2/children': page([episode(2)]),
  })
}

function playbackServer() {
  vi.spyOn(HTMLMediaElement.prototype, 'load').mockImplementation(() => undefined)
  vi.spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(() => undefined)
  vi.spyOn(HTMLMediaElement.prototype, 'play').mockImplementation(() => Promise.resolve())
  const bodies: { startTimeTicks?: number; audioStreamIndex?: number; subtitleStreamIndex?: number; quality?: string }[] = []
  const reports: PlaybackReport[] = []
  const fetchMock = serve({
    'GET /api/session': { connected: true, server, user },
    'GET /api/home': { ...emptyHome, movies: [movie(1)] },
    'GET /api/items/m1': { item: { id: 'm1', name: 'Movie 1', type: 'Movie', runtimeTicks: 60_000_000_000 } },
    'POST /api/playback/report': (_url: URL, init?: RequestInit) => {
      reports.push(JSON.parse(String(init?.body)) as PlaybackReport)
      return { ok: true }
    },
    'POST /api/playback/m1': (_url: URL, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body)) as (typeof bodies)[number]
      bodies.push(body)
      const n = bodies.length
      return {
        url: `/api/media/s${n}/stream.mp4`,
        playSessionId: `play${n}`,
        mediaSourceId: 'src1',
        itemId: 'm1',
        startTimeTicks: body.startTimeTicks ?? 0,
        seekTimeTicks: body.startTimeTicks ?? 0,
        positionOffsetTicks: 0,
        playMethod: 'Transcode',
        audioTracks: [
          { index: 2, label: 'English · AAC · Stereo' },
          { index: 4, label: 'Japanese · AC3 · 5.1' },
        ],
        subtitleTracks: [{ index: 0, label: 'Portuguese · SUBRIP' }],
        mediaSources: [{ id: 'src1', label: 'Version 1 · 1920 × 1080 · H264 · MKV' }],
        qualityOptions: [
          { id: 'auto', label: 'Auto · up to 20 Mbps' },
          { id: '720p', label: 'Até 720p · 4 Mbps', maxHeight: 720 },
        ],
        selection: {
          mediaSourceId: 'src1',
          audioStreamIndex: body.audioStreamIndex ?? 2,
          subtitleStreamIndex: body.subtitleStreamIndex ?? 0,
          quality: body.quality ?? 'auto',
        },
        subtitleDelivery: (body.subtitleStreamIndex ?? 0) === -1 ? 'off' : 'encoded',
      } satisfies PlaybackInfo
    },
  })
  return { bodies, reports, fetchMock }
}

const videoSrc = () => document.querySelector('video')?.getAttribute('src')
const settle = () => act(() => new Promise(resolve => setTimeout(resolve, 60)))

describe('Luma preview', () => {
  it('keeps Home reachable from series details through the menu', async () => {
    seriesServer()
    window.history.replaceState(null, '', '#/item/show1')
    render(<App />)
    await screen.findByRole('tab', { name: 'Season 1' })
    await userEvent.click(screen.getByRole('button', { name: /Abrir menu/ }))
    await userEvent.click(screen.getByRole('link', { name: 'Início' }))
    await waitFor(() => expect(window.location.hash).toBe('#/'))
    expect(await screen.findByRole('heading', { level: 1, name: 'Test Series' })).toBeInTheDocument()
  })

  it('opens the season browser from an episode, changes seasons, and returns Home with Back', async () => {
    seriesServer()
    window.history.replaceState(null, '', '#/item/e2')
    render(<App />)
    await userEvent.click(await screen.findByRole('link', { name: 'Temporadas e episódios' }))
    await userEvent.click(await screen.findByRole('tab', { name: 'Season 2' }))
    expect(await screen.findByRole('link', { name: /Reproduzir Season 2 premiere/ })).toBeInTheDocument()
    expect(screen.getByRole('tab', { name: 'Season 2' })).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByRole('tab', { name: 'Season 2' })).toHaveFocus()
    expect(screen.queryByRole('link', { name: /Reproduzir Season 1 premiere/ })).not.toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Voltar' }))
    await screen.findByRole('link', { name: 'Temporadas e episódios' })
    await userEvent.click(screen.getByRole('button', { name: 'Voltar' }))
    await waitFor(() => expect(window.location.hash).toBe('#/'))
  })

  it('opens on connection onboarding and looks for servers when nothing is saved', async () => {
    const fetchMock = serve({
      'GET /api/session': { connected: false, reason: 'login_required' },
      'POST /api/discover': { servers: [server], diagnostics: [] },
    })
    window.history.replaceState(null, '', '#/')
    render(<App />)

    expect(await screen.findByRole('heading', { level: 1, name: 'Conectar ao Jellyfin' })).toBeInTheDocument()
    await waitFor(() => expect(window.location.hash).toBe('#/connect'))
    const row = await screen.findByRole('button', { name: /media-pc/ })
    expect(row).toHaveTextContent('192.168.1.50:8096')
    expect(row).toHaveTextContent('Rede doméstica')
    expect(fetchMock.mock.calls.some(([url, init]) => String(url) === '/api/discover' && init?.method === 'POST')).toBe(true)

    expect(screen.queryByRole('navigation', { name: 'Menu principal' })).not.toBeInTheDocument()
    expect(screen.queryByText(/\bconnected\b/i)).not.toBeInTheDocument()
    expect(screen.queryByText('Demo', { selector: '.demo-banner__label' })).not.toBeInTheDocument()
    expect(document.querySelector('video')).toBeNull()
  })

  it('routes every library page to onboarding while no server is signed in', async () => {
    const fetchMock = serve({
      'GET /api/session': { connected: false, reason: 'login_required' },
      'POST /api/discover': { servers: [], diagnostics: [] },
    })
    window.history.replaceState(null, '', '#/movies')
    render(<App />)

    expect(await screen.findByRole('heading', { level: 1, name: 'Conectar ao Jellyfin' })).toBeInTheDocument()
    await waitFor(() => expect(window.location.hash).toBe('#/connect'))
    expect(fetchMock.mock.calls.some(([url]) => String(url).startsWith('/api/items'))).toBe(false)
  })

  it('asks a saved but signed-out server for a concise sign-in, without claiming a connection', async () => {
    let signedIn = false
    const fetchMock = serve({
      'GET /api/session': () => (signedIn ? { connected: true, server, user } : { connected: false, server, reason: 'login_required' }),
      'POST /api/login': () => {
        signedIn = true
        return { connected: true, server, user }
      },
      'GET /api/home': { ...emptyHome, movies: [movie(1)] },
    })
    window.history.replaceState(null, '', '#/')
    render(<App />)

    expect(await screen.findByRole('heading', { name: 'Entrar em media-pc' })).toBeInTheDocument()
    expect(screen.getByText('192.168.1.50:8096')).toBeInTheDocument()
    expect(screen.getByText('Rede doméstica')).toBeInTheDocument()
    expect(screen.queryByText(/\bconnected\b/i)).not.toBeInTheDocument()
    expect(fetchMock.mock.calls.some(([url]) => String(url) === '/api/discover')).toBe(false)

    await userEvent.type(screen.getByLabelText('Nome de usuário'), 'Julio')
    await userEvent.type(screen.getByLabelText('Senha'), 'secret')
    await userEvent.click(screen.getByRole('button', { name: 'Entrar' }))

    expect(await screen.findByRole('heading', { level: 1, name: 'Movie 1' })).toBeInTheDocument()
    const loginCall = fetchMock.mock.calls.find(([url]) => String(url) === '/api/login')
    expect(JSON.parse(String(loginCall?.[1]?.body))).toEqual({ serverId: server.id, username: 'Julio', password: 'secret' })
    expect(screen.getByRole('link', { name: 'Conta: Julio em media-pc' })).toBeInTheDocument()
  })

  it('connects by address and signs in, then shows the server library', async () => {
    let signedIn = false
    const fetchMock = serve({
      'GET /api/session': () => (signedIn ? { connected: true, server, user } : { connected: false, reason: 'login_required' }),
      'POST /api/discover': { servers: [], diagnostics: [{ code: 'udp_error', message: 'EPERM' }] },
      'POST /api/connect': { server },
      'POST /api/login': () => {
        signedIn = true
        return { connected: true, server, user }
      },
      'GET /api/home': { ...emptyHome, movies: [movie(1)] },
    })
    window.history.replaceState(null, '', '#/connect')
    render(<App />)

    expect(await screen.findByText(/Nenhum servidor Jellyfin respondeu/)).toBeInTheDocument()
    await userEvent.type(screen.getByLabelText('Endereço do servidor'), '192.168.1.50:8096')
    await userEvent.click(screen.getByRole('button', { name: 'Conectar' }))

    expect(await screen.findByRole('heading', { name: 'Entrar em media-pc' })).toBeInTheDocument()
    expect(screen.getByText('Acessível')).toBeInTheDocument()
    const connectCall = fetchMock.mock.calls.find(([url]) => String(url) === '/api/connect')
    expect(JSON.parse(String(connectCall?.[1]?.body))).toEqual({ url: 'http://192.168.1.50:8096' })

    await userEvent.type(screen.getByLabelText('Nome de usuário'), 'Julio')
    await userEvent.type(screen.getByLabelText('Senha'), 'secret')
    await userEvent.click(screen.getByRole('button', { name: 'Entrar' }))

    expect(await screen.findByRole('heading', { level: 1, name: 'Movie 1' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Conta: Julio em media-pc' })).toBeInTheDocument()
    expect(screen.queryByText('Demo', { selector: '.demo-banner__label' })).not.toBeInTheDocument()
    expect(localStorage.getItem('luma.rememberedAccount.v1')).not.toContain('secret')
  })

  it('opens the demo only on request, labels it everywhere, and forgets it on relaunch', async () => {
    serve({
      'GET /api/session': { connected: false, reason: 'login_required' },
      'POST /api/discover': { servers: [], diagnostics: [] },
    })
    window.history.replaceState(null, '', '#/')
    const view = render(<App />)

    await userEvent.click(await screen.findByRole('button', { name: 'Experimentar a demonstração' }))
    expect(await screen.findByRole('heading', { level: 1, name: 'Caminandes' })).toBeInTheDocument()
    expect(screen.getByText('Demo', { selector: '.demo-banner__label' })).toBeInTheDocument()
    expect(screen.getByText(/não é sua biblioteca do Jellyfin/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /Conta: biblioteca de demonstração, sem conexão com um servidor/ })).toBeInTheDocument()
    expect(screen.queryByText(/\bconnected\b/i)).not.toBeInTheDocument()
    expect(Object.keys(localStorage).filter(key => key.toLowerCase().includes('demo'))).toEqual([])

    await userEvent.click(screen.getByRole('button', { name: 'Sair da demonstração' }))
    expect(await screen.findByRole('heading', { level: 1, name: 'Conectar ao Jellyfin' })).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Experimentar a demonstração' }))
    expect(await screen.findByRole('heading', { level: 1, name: 'Caminandes' })).toBeInTheDocument()
    view.unmount()
    window.history.replaceState(null, '', '#/')
    render(<App />)
    expect(await screen.findByRole('heading', { level: 1, name: 'Conectar ao Jellyfin' })).toBeInTheDocument()
  })

  it('keeps the account and explains itself when the server is offline', async () => {
    serve({ 'GET /api/session': { connected: false, server, user, reason: 'offline' } })
    window.history.replaceState(null, '', '#/account')
    render(<App />)

    const panel = (await screen.findByText('Servidor indisponível')).closest('.panel') as HTMLElement
    expect(within(panel).getByText(/media-pc não está respondendo\. O Luma manteve seus dados de acesso/)).toBeInTheDocument()
    expect(within(panel).getByText('Julio (mantido)')).toBeInTheDocument()
    expect(within(panel).getByRole('button', { name: 'Tentar novamente' })).toBeInTheDocument()
    expect(within(panel).getByRole('link', { name: 'Buscar na rede' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Conta: Julio, media-pc indisponível' })).toBeInTheDocument()
  })

  it('keeps the sidebar and offers recovery, not the demo, on library pages while offline', async () => {
    serve({ 'GET /api/session': { connected: false, server, user, reason: 'offline' } })
    window.history.replaceState(null, '', '#/')
    render(<App />)

    expect(await screen.findByRole('heading', { level: 1, name: 'Sua biblioteca está indisponível' })).toBeInTheDocument()
    expect(screen.getByRole('navigation', { name: 'Menu principal' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Experimentar a demonstração' })).toBeInTheDocument()
    expect(screen.queryByText('Demo', { selector: '.demo-banner__label' })).not.toBeInTheDocument()
    expect(window.location.hash).toBe('#/')
  })

  it('pages a large library with Show more instead of truncating it', async () => {
    serve({
      'GET /api/session': { connected: true, server, user },
      'GET /api/items': (url: URL) => {
        const start = Number(url.searchParams.get('startIndex'))
        return start === 0
          ? { items: Array.from({ length: 100 }, (_, i) => movie(i)), total: 101, startIndex: 0, nextStartIndex: 100 }
          : { items: [movie(100)], total: 101, startIndex: 100, nextStartIndex: null }
      },
    })
    window.history.replaceState(null, '', '#/movies')
    render(<App />)

    expect(await screen.findByText(/^101 filmes/)).toBeInTheDocument()
    const grid = screen.getByRole('list', { name: 'Filmes' })
    expect(within(grid).getAllByRole('listitem')).toHaveLength(100)
    await userEvent.click(screen.getByRole('button', { name: 'Mostrar mais · 100 de 101' }))
    await waitFor(() => expect(within(grid).getAllByRole('listitem')).toHaveLength(101))
    expect(screen.queryByRole('button', { name: /Mostrar mais/ })).not.toBeInTheDocument()
  })

  it('loads episodes beyond the first page when a series has no season folders', async () => {
    const episode = (n: number): Item => ({ id: `e${n}`, name: `Episode ${n}`, type: 'Episode', parentIndexNumber: 1, indexNumber: n })
    serve({
      'GET /api/session': { connected: true, server, user },
      'GET /api/items/show1': { item: { id: 'show1', name: 'Long Series', type: 'Series' } },
      'GET /api/items/show1/children': (url: URL) => Number(url.searchParams.get('startIndex')) === 100
        ? { items: [episode(101)], total: 101, startIndex: 100, nextStartIndex: null }
        : { items: Array.from({ length: 100 }, (_, i) => episode(i + 1)), total: 101, startIndex: 0, nextStartIndex: 100 },
    })
    window.history.replaceState(null, '', '#/item/show1')
    render(<App />)
    expect(await screen.findByRole('heading', { name: 'Temporada 1' })).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Mostrar mais · 100 de 101' }))
    expect(await screen.findByRole('link', { name: /Reproduzir Episode 101,/ })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /Mostrar mais/ })).not.toBeInTheDocument()
  })

  it('sends each player choice through the session provider to the gateway, keeping the others', async () => {
    const { bodies } = playbackServer()
    window.history.replaceState(null, '', '#/play/m1')
    render(<App />)

    await userEvent.click(await screen.findByRole('button', { name: 'Áudio' }))
    await userEvent.click(screen.getByRole('menuitemradio', { name: 'Japanese · AC3 · 5.1' }))
    await waitFor(() => expect(bodies).toHaveLength(2))
    expect(bodies[1]).toEqual({ mediaSourceId: 'src1', audioStreamIndex: 4, subtitleStreamIndex: 0, quality: 'auto' })

    await waitFor(() => expect(document.querySelector('video')?.getAttribute('src')).toBe('/api/media/s2/stream.mp4'))
    await userEvent.click(screen.getByRole('button', { name: 'Qualidade e versão' }))
    await userEvent.click(screen.getByRole('menuitemradio', { name: 'Até 720p · 4 Mbps' }))
    await waitFor(() => expect(bodies).toHaveLength(3))
    expect(bodies[2]).toEqual({ mediaSourceId: 'src1', audioStreamIndex: 4, subtitleStreamIndex: 0, quality: '720p' })

    await waitFor(() => expect(document.querySelector('video')?.getAttribute('src')).toBe('/api/media/s3/stream.mp4'))
    await userEvent.click(screen.getByRole('button', { name: /^Legendas/ }))
    await userEvent.click(screen.getByRole('menuitemradio', { name: 'Desativadas' }))
    await waitFor(() => expect(bodies).toHaveLength(4))
    expect(bodies[3]).toEqual({ mediaSourceId: 'src1', audioStreamIndex: 4, subtitleStreamIndex: -1, quality: '720p' })
  })

  it('keeps one playback session when library caches are invalidated during playback', async () => {
    const { bodies, reports } = playbackServer()
    window.history.replaceState(null, '', '#/play/m1')
    render(<App />)
    await screen.findByRole('button', { name: 'Áudio' })
    expect(videoSrc()).toBe('/api/media/s1/stream.mp4')

    for (let i = 0; i < 3; i += 1) act(() => invalidateResources())
    await settle()
    expect(bodies).toHaveLength(1)
    expect(videoSrc()).toBe('/api/media/s1/stream.mp4')

    await userEvent.click(screen.getByRole('button', { name: 'Áudio' }))
    await userEvent.click(screen.getByRole('menuitemradio', { name: 'Japanese · AC3 · 5.1' }))
    await waitFor(() => expect(videoSrc()).toBe('/api/media/s2/stream.mp4'))
    act(() => invalidateResources())
    await settle()
    expect(bodies).toHaveLength(2)
    expect(videoSrc()).toBe('/api/media/s2/stream.mp4')
    expect(reports.filter(report => report.event === 'stop').map(report => report.playSessionId)).toEqual(['play1'])
  })

  it('negotiates a bounded number of sessions under StrictMode and stops the discarded one', async () => {
    const { bodies, reports } = playbackServer()
    window.history.replaceState(null, '', '#/play/m1')
    render(
      <StrictMode>
        <App />
      </StrictMode>,
    )
    await screen.findByRole('button', { name: 'Áudio' })
    await settle()
    act(() => invalidateResources())
    await settle()
    expect(bodies.length).toBeLessThanOrEqual(2)
    const attached = videoSrc()?.match(/s(\d+)/)?.[1]
    const stopped = reports.filter(report => report.event === 'stop').map(report => report.playSessionId)
    expect(stopped).toEqual(bodies.length === 2 ? [attached === '1' ? 'play2' : 'play1'] : [])
  })

  it('refreshes library data once after leaving the player', async () => {
    const { fetchMock } = playbackServer()
    window.history.replaceState(null, '', '#/')
    render(<App />)
    await userEvent.click(await screen.findByRole('link', { name: 'Reproduzir' }))
    await screen.findByRole('button', { name: 'Áudio' })
    const homeLoads = () => fetchMock.mock.calls.filter(([url]) => String(url) === '/api/home').length
    const before = homeLoads()
    await userEvent.keyboard('{Escape}')
    await screen.findByRole('heading', { level: 1, name: 'Movie 1' })
    await settle()
    expect(homeLoads()).toBe(before + 1)
  })

  it('leaves playback with the visible Back button and retires its stream once', async () => {
    const { reports, bodies } = playbackServer()
    window.history.replaceState(null, '', '#/')
    render(<App />)
    await userEvent.click(await screen.findByRole('link', { name: 'Reproduzir' }))
    const nav = await screen.findByRole('navigation', { name: 'Navegação do player' })
    await userEvent.click(within(nav).getByRole('button', { name: 'Voltar' }))
    await screen.findByRole('heading', { level: 1, name: 'Movie 1' })
    await waitFor(() => expect(reports.filter(report => report.event === 'stop')).toHaveLength(1))
    expect(bodies).toHaveLength(1)
    expect(window.location.hash).toBe('#/')
  })

  it('can leave a directly opened player through its top Home shortcut', async () => {
    const { reports } = playbackServer()
    window.history.replaceState(null, '', '#/play/m1')
    render(<App />)
    const nav = await screen.findByRole('navigation', { name: 'Navegação do player' })
    act(() => within(nav).getByRole('button', { name: 'Voltar' }).focus())
    await userEvent.click(within(nav).getByRole('link', { name: 'Início' }))
    await screen.findByRole('heading', { level: 1, name: 'Movie 1' })
    await waitFor(() => expect(reports.filter(report => report.event === 'stop')).toHaveLength(1))
    expect(window.location.hash).toBe('#/')
  })

  it('expands the collapsed tab into the menu on focus and returns to the content on Right', async () => {
    serve({ 'GET /api/session': { connected: true, server, user }, 'GET /api/home': { ...emptyHome, movies: [movie(1)] } })
    window.history.replaceState(null, '', '#/')
    render(<App />)
    const play = await screen.findByRole('link', { name: 'Reproduzir' })
    await waitFor(() => expect(play).toHaveFocus())
    const nav = screen.getByRole('navigation', { name: 'Menu principal' })
    expect(nav).toHaveAttribute('data-expanded', 'false')

    act(() => screen.getByRole('button', { name: 'Abrir menu. Página atual: Início' }).focus())
    expect(nav).toHaveAttribute('data-expanded', 'true')
    expect(within(nav).getByRole('link', { name: 'Início' })).toHaveFocus()
    expect(within(nav).getByRole('link', { name: 'Conta: Julio em media-pc' })).toBeInTheDocument()

    await userEvent.keyboard('{ArrowRight}')
    expect(play).toHaveFocus()
    expect(nav).toHaveAttribute('data-expanded', 'false')

    act(() => screen.getByRole('button', { name: 'Abrir menu. Página atual: Início' }).focus())
    await userEvent.keyboard('{Escape}')
    expect(play).toHaveFocus()
    expect(window.location.hash).toBe('#/')
  })

  it('shows real title logos with a text fallback and pages through featured titles', async () => {
    const logo = { ...movie(1), backdrop: '/art/b1.jpg', logo: '/art/logo1.png' }
    const plain = { ...movie(2), backdrop: '/art/b2.jpg' }
    serve({ 'GET /api/session': { connected: true, server, user }, 'GET /api/home': { ...emptyHome, latest: [logo, plain] } })
    window.history.replaceState(null, '', '#/')
    render(<App />)

    const heading = await screen.findByRole('heading', { level: 1, name: 'Movie 1' })
    expect(within(heading).getByRole('img', { name: 'Movie 1' })).toHaveAttribute('src', '/art/logo1.png')
    expect(screen.getByText('Novo em media-pc')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Próximo destaque (2 de 2)' }))
    const next = screen.getByRole('heading', { level: 1, name: 'Movie 2' })
    expect(within(next).queryByRole('img')).not.toBeInTheDocument()
    expect(next).toHaveTextContent('Movie 2')
  })
})
