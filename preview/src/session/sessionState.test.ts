import { describe, expect, it } from 'vitest'
import { appMode, deriveSession } from './sessionState'

const server = { id: 'srv1', name: 'media-pc', url: 'http://192.168.1.50:8096' }
const user = { id: 'u1', name: 'Julio' }

describe('deriveSession', () => {
  it('is connected only with server and user', () => {
    expect(deriveSession({ connected: true, server, user })).toEqual({ status: 'connected', server, user })
  })

  it('keeps the account when the server is unreachable', () => {
    expect(deriveSession({ connected: false, server, user, reason: 'offline' })).toMatchObject({ status: 'offline', server, user })
  })

  it('falls back to the remembered server when the gateway has not re-resolved it yet', () => {
    const state = deriveSession({ connected: false, user, reason: 'offline' }, { server, user })
    expect(state).toMatchObject({ status: 'offline', server, user })
  })

  it('asks to sign in again when the token was revoked', () => {
    expect(deriveSession({ connected: false, server, user, reason: 'auth_revoked' })).toMatchObject({ status: 'signedOut', server })
  })

  it('treats a server with no account as needing sign-in', () => {
    expect(deriveSession({ connected: false, server, reason: 'login_required' })).toMatchObject({ status: 'signedOut', server })
  })

  it('reports no server when nothing is saved', () => {
    expect(deriveSession({ connected: false, reason: 'login_required' })).toEqual({ status: 'noServer' })
  })
})

describe('appMode', () => {
  it('sends a device without a signed-in server to setup, never to the demo', () => {
    expect(appMode({ status: 'noServer' }, false)).toBe('setup')
    expect(appMode({ status: 'signedOut', server, reason: 'login_required' }, false)).toBe('setup')
    expect(appMode({ status: 'gatewayDown', message: 'down' }, false)).toBe('setup')
  })

  it('keeps a saved account in the shell while its server is unreachable', () => {
    expect(appMode({ status: 'offline', server, user, reason: 'offline' }, false)).toBe('unavailable')
    expect(appMode({ status: 'gatewayDown', remembered: { server, user }, message: 'down' }, false)).toBe('unavailable')
  })

  it('opens the library only when signed in or when the demo was chosen', () => {
    expect(appMode({ status: 'connected', server, user }, false)).toBe('library')
    expect(appMode({ status: 'noServer' }, true)).toBe('library')
    expect(appMode({ status: 'checking' }, true)).toBe('checking')
  })
})
