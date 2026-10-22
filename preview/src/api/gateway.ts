import type {
  DiscoverResponse,
  HomeResponse,
  Item,
  ItemPage,
  ItemQuery,
  LibrarySource,
  PlaybackInfo,
  PlaybackOptions,
  PlaybackReport,
  ServerInfo,
  SessionResponse,
} from './types'

export type ApiErrorKind = 'unreachable' | 'unauthorized' | 'notFound' | 'invalid' | 'server'

export class ApiError extends Error {
  readonly kind: ApiErrorKind
  readonly status: number
  readonly code: string | undefined

  constructor(kind: ApiErrorKind, message: string, status = 0, code?: string) {
    super(message)
    this.name = 'ApiError'
    this.kind = kind
    this.status = status
    this.code = code
  }
}

function kindFor(status: number, code: string | undefined): ApiErrorKind {
  if (code === 'offline' || code === 'identity_mismatch') return 'unreachable'
  if (status === 401) return 'unauthorized'
  if (status === 404) return 'notFound'
  if (status >= 400 && status < 500) return 'invalid'
  return 'server'
}

const ERROR_MESSAGES: Record<string, string> = {
  offline: 'O servidor Jellyfin não está respondendo. Sua conta foi mantida.',
  identity_mismatch: 'Este endereço agora pertence a outro servidor. Sua conta foi mantida.',
  auth_revoked: 'Sua sessão do Jellyfin expirou. Entre novamente.',
  login_required: 'Entre no Jellyfin para continuar.',
  invalid_credentials: 'Nome de usuário ou senha incorretos.',
  invalid_url: 'Digite um endereço HTTP ou HTTPS válido do servidor Jellyfin.',
  invalid_server: 'Este endereço não pertence a um servidor Jellyfin.',
  redirect_rejected: 'Digite o endereço final do servidor Jellyfin.',
  server_not_selected: 'Conecte-se ao servidor antes de entrar.',
  forbidden: 'O Jellyfin recusou esta solicitação.',
  invalid_request: 'Esta solicitação não pôde ser concluída. Confira os dados e tente novamente.',
  unsupported_media: 'O Jellyfin não conseguiu preparar este vídeo para reprodução.',
  not_found: 'O conteúdo solicitado não foi encontrado.',
  upstream_unauthorized: 'O Jellyfin pediu que você entre novamente.',
  upstream_error: 'O servidor Jellyfin não conseguiu concluir a solicitação.',
  internal_error: 'O serviço local não conseguiu concluir a solicitação.',
}

function failureMessage(status: number, code: string | undefined): string {
  return (code && ERROR_MESSAGES[code]) || `Não foi possível concluir a solicitação (${status}).`
}

interface RequestOptions {
  method?: 'GET' | 'POST'
  body?: unknown
  signal?: AbortSignal
  keepalive?: boolean
  timeoutMs?: number
}

export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', body, keepalive, timeoutMs = 20_000 } = options
  const timeout = AbortSignal.timeout(timeoutMs)
  const signal = options.signal ? AbortSignal.any([options.signal, timeout]) : timeout
  let response: Response
  try {
    response = await fetch(path, {
      method,
      signal,
      keepalive,
      headers: method === 'POST' ? { 'Content-Type': 'application/json' } : undefined,
      body: method === 'POST' ? JSON.stringify(body ?? {}) : undefined,
    })
  } catch (error) {
    if (options.signal?.aborted) throw error
    if (timeout.aborted) throw new ApiError('unreachable', 'A solicitação demorou demais. Verifique se o servidor está ligado e tente novamente.')
    throw new ApiError('unreachable', 'O serviço local do Luma não está respondendo.')
  }

  const text = await response.text()
  let data: unknown
  try {
    data = text ? JSON.parse(text) : undefined
  } catch {
    // A non-JSON 5xx comes from the Vite proxy when the gateway process is down.
    if (response.status >= 500) throw new ApiError('unreachable', 'O serviço local do Luma não está em execução.', response.status)
    throw new ApiError('server', 'O serviço enviou uma resposta que o Luma não conseguiu ler.', response.status)
  }

  if (!response.ok) {
    const failure = (data as { error?: { code?: string; message?: string } } | undefined)?.error
    throw new ApiError(
      kindFor(response.status, failure?.code),
      failureMessage(response.status, failure?.code),
      response.status,
      failure?.code,
    )
  }
  return data as T
}

export const PAGE_SIZE = 100

interface PageResponse {
  items: Item[]
  total?: number
  startIndex?: number
  nextStartIndex?: number | null
}

function toPage(response: PageResponse): ItemPage {
  return {
    items: response.items,
    total: response.total ?? response.items.length,
    nextStartIndex: response.nextStartIndex ?? null,
  }
}

function itemQuery(query: ItemQuery, startIndex?: number): string {
  const params = new URLSearchParams()
  if (query.search) params.set('search', query.search)
  if (query.type) params.set('type', query.type)
  if (query.parentId) params.set('parentId', query.parentId)
  if (startIndex !== undefined) {
    params.set('startIndex', String(startIndex))
    params.set('limit', String(PAGE_SIZE))
  }
  const encoded = params.toString()
  return encoded ? `?${encoded}` : ''
}

export function playbackBody(startTimeTicks: number | undefined, options: PlaybackOptions = {}) {
  const { mediaSourceId, audioStreamIndex, subtitleStreamIndex, quality } = options
  return {
    ...(startTimeTicks ? { startTimeTicks: Math.max(0, Math.round(startTimeTicks)) } : {}),
    ...(mediaSourceId !== undefined ? { mediaSourceId } : {}),
    ...(audioStreamIndex !== undefined ? { audioStreamIndex } : {}),
    ...(subtitleStreamIndex !== undefined ? { subtitleStreamIndex } : {}),
    ...(quality !== undefined ? { quality } : {}),
  }
}

export const gateway = {
  // Resolving a moved server can take a cached-URL timeout plus a full discovery pass.
  session: (signal?: AbortSignal) => request<SessionResponse>('/api/session', { signal, timeoutMs: 35_000 }),
  // Discovery may fall back to probing the LAN over HTTP, which the gateway bounds at about 15 seconds.
  discover: () => request<DiscoverResponse>('/api/discover', { method: 'POST', timeoutMs: 30_000 }),
  connect: (url: string) =>
    request<{ server: ServerInfo }>('/api/connect', { method: 'POST', body: { url }, timeoutMs: 30_000 }),
  login: (serverId: string, username: string, password: string) =>
    request<SessionResponse>('/api/login', { method: 'POST', body: { serverId, username, password } }),
  logout: () => request<unknown>('/api/logout', { method: 'POST' }),
}

export const gatewayLibrary: LibrarySource = {
  kind: 'server',
  home: signal => request<HomeResponse>('/api/home', { signal }),
  item: async (id, signal) => (await request<{ item: Item }>(`/api/items/${encodeURIComponent(id)}`, { signal })).item,
  itemsPage: async (query, startIndex, signal) =>
    toPage(await request<PageResponse>(`/api/items${itemQuery(query, startIndex)}`, { signal })),
  children: async (id, signal) =>
    (await request<{ items: Item[] }>(`/api/items/${encodeURIComponent(id)}/children`, { signal })).items,
  childrenPage: async (id, startIndex, signal) =>
    toPage(
      await request<PageResponse>(`/api/items/${encodeURIComponent(id)}/children${itemQuery({}, startIndex)}`, { signal }),
    ),
  playback: (id, startTimeTicks, options) =>
    request<PlaybackInfo>(`/api/playback/${encodeURIComponent(id)}`, {
      method: 'POST',
      body: playbackBody(startTimeTicks, options),
      signal: options?.signal,
    }),
  report: async (report: PlaybackReport, options) => {
    await request<unknown>('/api/playback/report', { method: 'POST', body: report, keepalive: options?.keepalive })
  },
}
