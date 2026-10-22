import { useEffect, useRef, useState, type FormEvent } from 'react'
import { gateway } from '../api/gateway'
import type { Diagnostic, ServerInfo } from '../api/types'
import { ChevronIcon, ServerIcon } from '../components/icons'
import { NetworkTag } from '../components/NetworkTag'
import { networkOf } from '../lib/network'
import { focusElement } from '../nav/remote'
import { goBack, navigate } from '../nav/router'
import { useScreenFocus } from '../nav/useScreenFocus'
import { useSession } from '../session/SessionProvider'
import { appMode, readRemembered } from '../session/sessionState'

type Discovery =
  | { status: 'running'; startedAt: number }
  | { status: 'done'; servers: ServerInfo[]; diagnostics: Diagnostic[] }
  | { status: 'error'; message: string }

const DIAGNOSTIC_COPY: Record<string, string> = {
  udp_error: 'Não foi possível iniciar a busca na rede neste computador',
  send_failed: 'Não foi possível enviar a busca pela rede',
  verification_failed: 'Um dispositivo respondeu, mas não confirmou ser um servidor Jellyfin',
}

function describeDiagnostic(diagnostic: Diagnostic): string {
  if (typeof diagnostic === 'string') return 'Resultado da busca indisponível'
  const base = (diagnostic.code && DIAGNOSTIC_COPY[diagnostic.code]) ?? 'Resultado da busca indisponível'
  const where = [diagnostic.url, diagnostic.host, diagnostic.interface].find(value => typeof value === 'string')
  return [base, where ? `(${String(where)})` : ''].filter(Boolean).join(' ')
}

function normalizeAddress(input: string): string {
  const trimmed = input.trim()
  return /^https?:\/\//i.test(trimmed) ? trimmed : `http://${trimmed}`
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Algo deu errado.'
}

function ElapsedSeconds({ since }: { since: number }) {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(timer)
  }, [])
  return <>{Math.max(0, Math.round((now - since) / 1000))}s</>
}

function ServerSummary({ server, reachable }: { server: ServerInfo; reachable: boolean }) {
  return (
    <div className="server-summary">
      <ServerIcon className="server-summary__icon" />
      <span className="server-summary__address">{networkOf(server.url).address}</span>
      <NetworkTag url={server.url} />
      {reachable ? <span className="status-line status-line--ok">Acessível</span> : null}
    </div>
  )
}

function SignInForm({ server, reachable, onBack }: { server: ServerInfo; reachable: boolean; onBack: () => void }) {
  const { login } = useSession()
  const [username, setUsername] = useState(() => {
    const remembered = readRemembered()
    return remembered?.server.id === server.id ? (remembered.user?.name ?? '') : ''
  })
  const [password, setPassword] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string>()
  const knownUser = useRef(Boolean(username)).current

  async function submit(event: FormEvent) {
    event.preventDefault()
    if (!username.trim()) {
      setError('Digite seu nome de usuário do Jellyfin.')
      return
    }
    setSubmitting(true)
    setError(undefined)
    try {
      const next = await login(server.id, username.trim(), password)
      if (next.status === 'connected') navigate('/', { replace: true })
      else setError('A conexão foi feita, mas o Luma ainda não conseguiu abrir a biblioteca. Tente novamente em instantes.')
    } catch (failure) {
      setError(errorMessage(failure))
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <form className="onboarding__step" onSubmit={submit} aria-labelledby="signin-title" noValidate>
      <h1 className="onboarding__title" id="signin-title">
        Entrar em {server.name}
      </h1>
      <ServerSummary server={server} reachable={reachable} />
      <div className="fields">
        <label className="field">
          <span className="field__label">Nome de usuário</span>
          <input
            className="field__input"
            value={username}
            onChange={event => setUsername(event.target.value)}
            autoComplete="username"
            autoCapitalize="off"
            spellCheck={false}
            data-autofocus={knownUser ? undefined : true}
            required
          />
        </label>
        <label className="field">
          <span className="field__label">Senha</span>
          <input
            className="field__input"
            type="password"
            value={password}
            onChange={event => setPassword(event.target.value)}
            autoComplete="current-password"
            data-autofocus={knownUser ? true : undefined}
          />
        </label>
      </div>
      {error ? (
        <p className="form-error" role="alert">
          {error}
        </p>
      ) : null}
      <div className="actions">
        <button type="submit" className="btn btn--primary" disabled={submitting}>
          {submitting ? 'Entrando…' : 'Entrar'}
        </button>
        <button type="button" className="btn" onClick={onBack} disabled={submitting}>
          Escolher outro servidor
        </button>
      </div>
      <p className="fineprint">
        Sua senha é enviada a {server.name} uma vez e não é salva. O serviço local do Luma guarda o token de acesso;
        este navegador não recebe esse token.
      </p>
    </form>
  )
}

function FindServer({ onChosen }: { onChosen: (server: ServerInfo) => void }) {
  const { connect } = useSession()
  const [discovery, setDiscovery] = useState<Discovery>()
  const [address, setAddress] = useState('')
  const [connecting, setConnecting] = useState<string>()
  const [connectError, setConnectError] = useState<string>()
  const runId = useRef(0)
  const remembered = readRemembered()

  async function discover() {
    const id = ++runId.current
    setDiscovery({ status: 'running', startedAt: Date.now() })
    try {
      const result = await gateway.discover()
      if (id === runId.current) setDiscovery({ status: 'done', servers: result.servers, diagnostics: result.diagnostics ?? [] })
    } catch (error) {
      if (id === runId.current) setDiscovery({ status: 'error', message: errorMessage(error) })
    }
  }

  useEffect(() => {
    void discover()
    return () => {
      runId.current += 1
    }
  }, [])

  const found = discovery?.status === 'done' ? discovery.servers.length : 0
  useEffect(() => {
    if (!found) return
    const active = document.activeElement
    const untouched = !active || active === document.body || (active instanceof HTMLInputElement && !active.value)
    const first = document.querySelector<HTMLElement>('[data-focus-key^="server:"]')
    if (untouched && first) focusElement(first)
  }, [found])

  async function choose(url: string) {
    setConnecting(url)
    setConnectError(undefined)
    try {
      onChosen(await connect(url))
    } catch (error) {
      setConnectError(errorMessage(error))
    } finally {
      setConnecting(undefined)
    }
  }

  function submitAddress(event: FormEvent) {
    event.preventDefault()
    if (!address.trim()) {
      setConnectError('Digite o endereço mostrado no painel do Jellyfin, como 192.168.1.20:8096.')
      return
    }
    void choose(normalizeAddress(address))
  }

  const running = !discovery || discovery.status === 'running'

  return (
    <div className="onboarding__step">
      <h1 className="onboarding__title">Conectar ao Jellyfin</h1>
      <p className="onboarding__lede">O Luma reproduz a biblioteca do seu servidor Jellyfin. Escolha-o abaixo ou digite o endereço.</p>

      <section className="onboarding__section" aria-labelledby="found-title" aria-busy={running}>
        <div className="onboarding__section-head">
          <h2 className="section-title" id="found-title">
            Na sua rede
          </h2>
          {running ? (
            <span className="searching" role="status">
              <span className="searching__spinner" aria-hidden="true" />
              Buscando servidores Jellyfin… {discovery?.status === 'running' ? <ElapsedSeconds since={discovery.startedAt} /> : null}
            </span>
          ) : (
            <button type="button" className="btn btn--small" onClick={() => void discover()} disabled={Boolean(connecting)}>
              Buscar novamente
            </button>
          )}
        </div>

        {running ? (
          <p className="onboarding__hint">Isso pode levar até 25 segundos. Se sua rede bloquear a busca, digite o endereço.</p>
        ) : discovery.status === 'error' ? (
          <p className="form-error" role="alert">
            A busca falhou: {discovery.message}
          </p>
        ) : discovery.servers.length ? (
          <ul className="server-list" role="list">
            {discovery.servers.map((server, index) => (
              <li key={server.id}>
                <button
                  type="button"
                  className="server"
                  onClick={() => void choose(server.url)}
                  disabled={Boolean(connecting)}
                  data-autofocus={index === 0 || undefined}
                  data-focus-key={`server:${server.id}`}
                >
                  <ServerIcon className="server__icon" />
                  <span className="server__text">
                    <span className="server__name">
                      {server.name}
                      {remembered?.server.id === server.id ? <span className="tag">Usado antes</span> : null}
                    </span>
                    <span className="server__meta">
                      <span>{networkOf(server.url).address}</span>
                      <NetworkTag url={server.url} />
                    </span>
                  </span>
                  <span className="server__cta">
                    {connecting === server.url ? 'Conectando…' : <ChevronIcon aria-hidden="true" />}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <p className="onboarding__hint">
            Nenhum servidor Jellyfin respondeu. Alguns roteadores bloqueiam a busca; você também pode digitar o endereço.
          </p>
        )}

        {discovery?.status === 'done' && discovery.diagnostics.length ? (
          <details className="diagnostics">
            <summary>Tentativas do Luma ({discovery.diagnostics.length})</summary>
            <ul>
              {discovery.diagnostics.map((diagnostic, index) => (
                <li key={index}>{describeDiagnostic(diagnostic)}</li>
              ))}
            </ul>
          </details>
        ) : null}
      </section>

      <form className="onboarding__section" onSubmit={submitAddress} aria-labelledby="manual-title" noValidate>
        <h2 className="section-title" id="manual-title">
          Digitar um endereço
        </h2>
        <div className="address-form">
          <label className="field address-form__field">
            <span className="field__label">Endereço do servidor</span>
            <input
              className="field__input"
              value={address}
              onChange={event => setAddress(event.target.value)}
              placeholder="192.168.1.20:8096"
              inputMode="url"
              autoCapitalize="off"
              autoComplete="url"
              spellCheck={false}
            />
          </label>
          <button type="submit" className="btn btn--primary" disabled={Boolean(connecting)}>
            {connecting && connecting === normalizeAddress(address) ? 'Conectando…' : 'Conectar'}
          </button>
        </div>
        <p className="onboarding__hint">Encontre o endereço no Jellyfin em Painel → Rede.</p>
        {connectError ? (
          <p className="form-error" role="alert">
            {connectError}
          </p>
        ) : null}
      </form>
    </div>
  )
}

function ServiceDown() {
  const { session, refresh } = useSession()
  const [checking, setChecking] = useState(false)
  return (
    <div className="onboarding__step">
      <h1 className="onboarding__title">O serviço local do Luma não está em execução</h1>
      <p className="onboarding__lede">
        A prévia no navegador encontra o Jellyfin e acessa sua conta por um serviço neste computador. Inicie-o com{' '}
        <code>npm run dev</code> na pasta do projeto e tente novamente.
      </p>
      {session.status === 'gatewayDown' ? <p className="onboarding__hint">{session.message}</p> : null}
      <div className="actions">
        <button
          type="button"
          className="btn btn--primary"
          data-autofocus
          disabled={checking}
          onClick={async () => {
            setChecking(true)
            try {
              await refresh()
            } finally {
              setChecking(false)
            }
          }}
        >
          {checking ? 'Verificando…' : 'Tentar novamente'}
        </button>
      </div>
    </div>
  )
}

function DemoOffer() {
  const { startDemo } = useSession()
  return (
    <aside className="demo-offer" aria-labelledby="demo-offer-title">
      <div>
        <h2 className="demo-offer__title" id="demo-offer-title">
          Quer explorar primeiro?
        </h2>
        <p className="demo-offer__detail">
          A demonstração reproduz filmes de exemplo do Blender Studio. Ela não usa sua biblioteca e o progresso é apagado ao sair.
        </p>
      </div>
      <button
        type="button"
        className="btn btn--small"
        data-focus-key="connect:demo"
        onClick={() => {
          startDemo()
          navigate('/', { replace: true })
        }}
      >
        Experimentar a demonstração
      </button>
    </aside>
  )
}

export function ConnectScreen() {
  const { session, demo } = useSession()
  // undefined follows the session (a signed-out server goes straight to sign-in); null means the user asked to look around.
  const [chosen, setChosen] = useState<{ server: ServerInfo; reachable: boolean } | null>()
  const sessionServer = session.status === 'signedOut' ? session.server : undefined
  const selected = chosen === undefined ? (sessionServer ? { server: sessionServer, reachable: false } : undefined) : (chosen ?? undefined)
  const canLeave = appMode(session, demo) !== 'setup'
  const step = session.status === 'gatewayDown' && !canLeave ? 'down' : selected ? `signin:${selected.server.id}` : 'find'
  useScreenFocus(true, `connect:${step}`)

  return (
    <div className="onboarding">
      <header className="onboarding__top">
        <span className="wordmark">Luma</span>
        {canLeave ? (
          <button type="button" className="btn btn--small" onClick={() => goBack()}>
            Cancelar
          </button>
        ) : null}
      </header>
      <div className="onboarding__body">
        {step === 'down' ? (
          <ServiceDown />
        ) : selected ? (
          <SignInForm
            key={selected.server.id}
            server={selected.server}
            reachable={selected.reachable}
            onBack={() => setChosen(null)}
          />
        ) : (
          <FindServer onChosen={server => setChosen({ server, reachable: true })} />
        )}
        {session.status !== 'connected' && !demo ? <DemoOffer /> : null}
      </div>
    </div>
  )
}
