import type { ServerInfo, SessionResponse, UserInfo } from '../api/types'

export interface RememberedAccount {
  server: ServerInfo
  user?: UserInfo
}

export type SessionState =
  | { status: 'checking' }
  | { status: 'connected'; server: ServerInfo; user: UserInfo }
  | { status: 'offline'; server?: ServerInfo; user: UserInfo; reason: string }
  | { status: 'signedOut'; server: ServerInfo; user?: UserInfo; reason: string }
  | { status: 'noServer' }
  | { status: 'gatewayDown'; remembered?: RememberedAccount; message: string }

const SIGN_IN_REASONS = new Set(['login_required', 'auth_revoked', 'invalid_credentials'])

export function deriveSession(response: SessionResponse, remembered?: RememberedAccount): SessionState {
  const { connected, server, user, reason = 'unknown' } = response
  if (connected && server && user) return { status: 'connected', server, user }
  if (server && (!user || SIGN_IN_REASONS.has(reason))) return { status: 'signedOut', server, user, reason }
  if (user) {
    const knownServer = server ?? (remembered?.user?.id === user.id ? remembered.server : undefined)
    return { status: 'offline', server: knownServer, user, reason }
  }
  return { status: 'noServer' }
}

// The demo is never a fallback: without a signed-in server, the library opens only after the user picks the demo.
export type AppMode = 'checking' | 'setup' | 'unavailable' | 'library'

export function appMode(state: SessionState, demo: boolean): AppMode {
  if (state.status === 'checking') return 'checking'
  if (state.status === 'connected' || demo) return 'library'
  if (state.status === 'offline' || (state.status === 'gatewayDown' && state.remembered)) return 'unavailable'
  return 'setup'
}

export function serverOf(state: SessionState): ServerInfo | undefined {
  switch (state.status) {
    case 'connected':
    case 'signedOut':
    case 'offline':
      return state.server
    case 'gatewayDown':
      return state.remembered?.server
    default:
      return undefined
  }
}

export function describeReason(reason: string, serverName = 'seu servidor'): string {
  switch (reason) {
    case 'offline':
      return `${serverName} não está respondendo. O Luma manteve seus dados de acesso e reconectará quando ele voltar, mesmo em outro endereço.`
    case 'identity_mismatch':
      return `O endereço conhecido agora pertence a outro servidor. O Luma está procurando ${serverName} pelo ID do servidor.`
    case 'auth_revoked':
      return `${serverName} encerrou a sessão deste dispositivo. Entre novamente para continuar assistindo.`
    case 'login_required':
      return `Entre em ${serverName} para explorar a biblioteca.`
    case 'forbidden':
      return `${serverName} recusou esta solicitação. Seus dados de acesso foram mantidos.`
    default:
      return `O Luma não conseguiu confirmar sua sessão com ${serverName}${reason === 'unknown' ? '' : ` (${reason})`}.`
  }
}

const STORAGE_KEY = 'luma.rememberedAccount.v1'

export function readRemembered(): RememberedAccount | undefined {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? (JSON.parse(raw) as RememberedAccount) : undefined
  } catch {
    return undefined
  }
}

export function writeRemembered(account: RememberedAccount | undefined) {
  try {
    if (account) localStorage.setItem(STORAGE_KEY, JSON.stringify(account))
    else localStorage.removeItem(STORAGE_KEY)
  } catch {
    return
  }
}
