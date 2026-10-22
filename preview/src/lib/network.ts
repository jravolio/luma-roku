export type NetworkKind = 'home' | 'thisDevice' | 'tailscale' | 'internet'

export interface NetworkInfo {
  kind: NetworkKind
  label: string
  address: string
}

const LABELS: Record<NetworkKind, string> = {
  home: 'Rede doméstica',
  thisDevice: 'Este computador',
  tailscale: 'Tailscale',
  internet: 'Internet',
}

function ipv4(host: string): number[] | undefined {
  const parts = host.split('.')
  if (parts.length !== 4) return undefined
  const octets = parts.map(Number)
  return octets.every(octet => Number.isInteger(octet) && octet >= 0 && octet <= 255) ? octets : undefined
}

function kindOf(host: string): NetworkKind {
  const name = host.toLowerCase().replace(/^\[|\]$/g, '')
  if (name === 'localhost' || name === '::1') return 'thisDevice'
  if (name.endsWith('.ts.net')) return 'tailscale'
  if (name.endsWith('.local') || name.endsWith('.lan') || name.endsWith('.home.arpa')) return 'home'
  if (/^f[cd][0-9a-f]{2}:|^fe80:/.test(name)) return 'home'
  const ip = ipv4(name)
  if (!ip) return 'internet'
  const [a = 0, b = 0] = ip
  if (a === 127) return 'thisDevice'
  // 100.64.0.0/10 is carrier-grade NAT space; Tailscale hands out its addresses from it.
  if (a === 100 && b >= 64 && b <= 127) return 'tailscale'
  if (a === 10 || (a === 192 && b === 168) || (a === 172 && b >= 16 && b <= 31) || (a === 169 && b === 254)) return 'home'
  return 'internet'
}

export function networkOf(url: string): NetworkInfo {
  try {
    const parsed = new URL(url)
    const kind = kindOf(parsed.hostname)
    return { kind, label: LABELS[kind], address: parsed.host }
  } catch {
    return { kind: 'internet', label: LABELS.internet, address: url }
  }
}
