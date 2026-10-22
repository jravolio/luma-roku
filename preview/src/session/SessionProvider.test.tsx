import { act, render, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { SessionResponse } from '../api/types'

const sessions: SessionResponse[] = []
const invalidate = vi.fn()

vi.mock('../api/gateway', async importOriginal => {
  const actual = await importOriginal<typeof import('../api/gateway')>()
  return { ...actual, gateway: { ...actual.gateway, session: vi.fn(async () => sessions.shift()!) } }
})
vi.mock('../data/useResource', () => ({ invalidateResources: invalidate }))

const { SessionProvider, useSession } = await import('./SessionProvider')
const { gateway } = await import('../api/gateway')

let api: ReturnType<typeof useSession>
function Probe() {
  api = useSession()
  return <span>{api.session.status}</span>
}

const serverA = { id: 'a', name: 'A', url: 'http://a' }
const serverB = { id: 'b', name: 'B', url: 'http://b' }

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('SessionProvider', () => {
  it('forwards playback choices to the gateway', async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(JSON.stringify({ url: '/x', playSessionId: 'p', mediaSourceId: 's', itemId: 'i', startTimeTicks: 0 })))
    vi.stubGlobal('fetch', fetchMock)
    render(
      <SessionProvider initial={{ status: 'connected', server: serverA, user: { id: 'u1', name: 'One' } }}>
        <Probe />
      </SessionProvider>,
    )
    await api.library.playback('item1', 7_660_000_000, { mediaSourceId: 'src2', audioStreamIndex: 4, subtitleStreamIndex: -1, quality: '720p' })
    const call = fetchMock.mock.calls.find(([url]) => String(url) === '/api/playback/item1')
    expect(JSON.parse(String(call?.[1]?.body))).toEqual({
      startTimeTicks: 7_660_000_000,
      mediaSourceId: 'src2',
      audioStreamIndex: 4,
      subtitleStreamIndex: -1,
      quality: '720p',
    })
  })

  it('invalidates cached library data when a connected session switches account', async () => {
    sessions.push({ connected: true, server: serverA, user: { id: 'u1', name: 'One' } })
    render(
      <SessionProvider>
        <Probe />
      </SessionProvider>,
    )
    await waitFor(() => expect(api.session.status).toBe('connected'))
    invalidate.mockClear()

    sessions.push({ connected: true, server: serverA, user: { id: 'u1', name: 'One' } })
    await act(() => api.refresh())
    expect(invalidate).not.toHaveBeenCalled()

    sessions.push({ connected: true, server: serverB, user: { id: 'u2', name: 'Two' } })
    await act(() => api.refresh())
    expect(invalidate).toHaveBeenCalledTimes(1)
  })

  it('shares one in-flight session request between concurrent refreshes', async () => {
    sessions.push({ connected: false })
    render(
      <SessionProvider initial={{ status: 'noServer' }}>
        <Probe />
      </SessionProvider>,
    )
    const calls = vi.mocked(gateway.session).mock.calls.length
    sessions.push({ connected: false })
    await act(async () => {
      await Promise.all([api.refresh(), api.refresh(), api.refresh()])
    })
    expect(vi.mocked(gateway.session).mock.calls.length - calls).toBe(1)
  })

  it('opens the demo only on request and drops it once a server is signed in', async () => {
    sessions.length = 0
    render(
      <SessionProvider initial={{ status: 'noServer' }}>
        <Probe />
      </SessionProvider>,
    )
    expect(api.demo).toBe(false)
    expect(api.library.kind).toBe('server')

    act(() => api.startDemo())
    expect(api.demo).toBe(true)
    expect(api.library.kind).toBe('demo')

    sessions.push({ connected: true, server: serverA, user: { id: 'u1', name: 'One' } })
    await act(() => api.refresh())
    expect(api.demo).toBe(false)
    expect(api.library.kind).toBe('server')
  })
})
