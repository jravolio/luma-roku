import { describe, expect, it } from 'vitest'
import { networkOf } from './network'

describe('networkOf', () => {
  it('labels a private LAN address as the home network', () => {
    expect(networkOf('http://192.168.1.50:8096')).toEqual({ kind: 'home', label: 'Rede doméstica', address: '192.168.1.50:8096' })
    expect(networkOf('http://10.0.0.5:8096').kind).toBe('home')
    expect(networkOf('http://172.20.1.2:8096').kind).toBe('home')
    expect(networkOf('http://media-pc.local:8096').kind).toBe('home')
  })

  it('tells a Tailscale address apart from the home network', () => {
    expect(networkOf('http://100.101.102.103:8096').kind).toBe('tailscale')
    expect(networkOf('https://media-pc.tail1234.ts.net').kind).toBe('tailscale')
  })

  it('recognises this computer and public hosts', () => {
    expect(networkOf('http://127.0.0.1:8096').kind).toBe('thisDevice')
    expect(networkOf('https://jellyfin.example.com').kind).toBe('internet')
    expect(networkOf('http://172.32.0.1:8096').kind).toBe('internet')
  })
})
