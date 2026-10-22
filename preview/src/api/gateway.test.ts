import { afterEach, describe, expect, it, vi } from 'vitest'
import { ApiError, gatewayLibrary, request } from './gateway'

function respond(status: number, body: string) {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(body, { status })))
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('request', () => {
  it('treats a non-JSON 5xx as the gateway being down', async () => {
    respond(500, 'proxy error')
    await expect(request('/api/session')).rejects.toMatchObject({ kind: 'unreachable' })
  })

  it('maps the gateway offline code to a Portuguese unreachable message', async () => {
    respond(503, JSON.stringify({ error: { code: 'offline', message: 'Jellyfin is unreachable. The saved account is preserved.' } }))
    const error = await request('/api/home').catch(e => e as ApiError)
    expect(error).toMatchObject({ kind: 'unreachable', code: 'offline', message: 'O servidor Jellyfin não está respondendo. Sua conta foi mantida.' })
  })

  it('maps 401 to unauthorized', async () => {
    respond(401, JSON.stringify({ error: { code: 'auth_revoked', message: 'Sign in again.' } }))
    await expect(request('/api/home')).rejects.toMatchObject({ kind: 'unauthorized' })
  })

  it('does not show unrecognized English gateway messages to viewers', async () => {
    respond(502, JSON.stringify({ error: { code: 'new_gateway_error', message: 'English internal details.' } }))
    await expect(request('/api/home')).rejects.toMatchObject({
      code: 'new_gateway_error',
      message: 'Não foi possível concluir a solicitação (502).',
    })
  })

  it('reports a network failure as unreachable', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => Promise.reject(new TypeError('Failed to fetch'))))
    await expect(request('/api/session')).rejects.toMatchObject({ kind: 'unreachable' })
  })
})

describe('itemsPage', () => {
  it('sends pagination and normalizes the continuation', async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL) => new Response(JSON.stringify({ items: [], total: 250, startIndex: 100, nextStartIndex: 200 })))
    vi.stubGlobal('fetch', fetchMock)
    const page = await gatewayLibrary.itemsPage({ type: 'Movie' }, 100)
    expect(fetchMock.mock.calls[0]?.[0]).toBe('/api/items?type=Movie&startIndex=100&limit=100')
    expect(page).toEqual({ items: [], total: 250, nextStartIndex: 200 })
  })
})

describe('playback', () => {
  it('keeps the original two-argument request body', async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response('{}'))
    vi.stubGlobal('fetch', fetchMock)
    await gatewayLibrary.playback('item1')
    await gatewayLibrary.playback('item1', 300_000_000)
    expect(fetchMock.mock.calls.map(([, init]) => JSON.parse(String(init?.body)))).toEqual([{}, { startTimeTicks: 300_000_000 }])
  })

  it('sends playback choices, including subtitles Off as -1', async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response('{}'))
    vi.stubGlobal('fetch', fetchMock)
    await gatewayLibrary.playback('item1', 7_660_000_000.4, { mediaSourceId: 'v2', audioStreamIndex: 3, subtitleStreamIndex: -1, quality: '480p' })
    expect(JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body))).toEqual({
      startTimeTicks: 7_660_000_000,
      mediaSourceId: 'v2',
      audioStreamIndex: 3,
      subtitleStreamIndex: -1,
      quality: '480p',
    })
  })
})
