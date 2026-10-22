import { useEffect, useState } from 'react'
import { navigate } from '../nav/router'
import { useSession } from '../session/SessionProvider'
import { describeReason, type SessionState } from '../session/sessionState'
import { Link } from './Link'
import { NetworkTag } from './NetworkTag'

const CONFIRM_WINDOW_MS = 6000

function ForgetButton({ label, confirmLabel }: { label: string; confirmLabel: string }) {
  const { logout } = useSession()
  const [armed, setArmed] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string>()

  useEffect(() => {
    if (!armed) return
    const timer = window.setTimeout(() => setArmed(false), CONFIRM_WINDOW_MS)
    return () => window.clearTimeout(timer)
  }, [armed])

  async function onClick() {
    if (!armed) {
      setArmed(true)
      return
    }
    setBusy(true)
    setError(undefined)
    try {
      await logout()
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'Não foi possível sair.')
    } finally {
      setBusy(false)
      setArmed(false)
    }
  }

  return (
    <>
      <button type="button" className={`btn${armed ? ' btn--danger' : ''}`} onClick={onClick} disabled={busy} data-focus-key="account:forget">
        {busy ? 'Saindo…' : armed ? confirmLabel : label}
      </button>
      {error ? (
        <p className="form-error" role="alert">
          {error}
        </p>
      ) : null}
    </>
  )
}

function RetryButton() {
  const { refresh } = useSession()
  const [busy, setBusy] = useState(false)
  return (
    <button
      type="button"
      className="btn btn--primary"
      data-autofocus
      disabled={busy}
      onClick={async () => {
        setBusy(true)
        try {
          await refresh()
        } finally {
          setBusy(false)
        }
      }}
    >
      {busy ? 'Verificando…' : 'Tentar novamente'}
    </button>
  )
}

function TryDemoButton() {
  const { startDemo } = useSession()
  return (
    <button
      type="button"
      className="btn"
      onClick={() => {
        startDemo()
        navigate('/', { replace: true })
      }}
    >
      Experimentar a demonstração
    </button>
  )
}

function Avatar({ name }: { name: string }) {
  return (
    <span className="avatar avatar--large" aria-hidden="true">
      {name.charAt(0).toLocaleUpperCase()}
    </span>
  )
}

export function ServerCard({ session, offerDemo = false }: { session: SessionState; offerDemo?: boolean }) {
  const { demo } = useSession()
  switch (session.status) {
    case 'checking':
      return (
        <div className="panel">
          <p className="panel__detail">Procurando um servidor salvo…</p>
        </div>
      )
    case 'connected':
      return (
        <div className="panel">
          <div className="panel__head">
            <Avatar name={session.user.name} />
            <div>
              <h2 className="panel__title">{session.user.name}</h2>
              <p className="status-line status-line--ok">Conectado a {session.server.name}</p>
            </div>
          </div>
          <dl className="facts">
            <dt>Servidor</dt>
            <dd>{session.server.name}</dd>
            <dt>Endereço</dt>
            <dd>{session.server.url}</dd>
            <dt>Rede</dt>
            <dd>
              <NetworkTag url={session.server.url} />
            </dd>
            <dt>ID do servidor</dt>
            <dd className="mono">{session.server.id}</dd>
          </dl>
          <p className="panel__fineprint">
            Se o endereço deste servidor mudar, o Luma poderá encontrá-lo pelo ID e manter sua conexão.
          </p>
          <div className="actions">
            <Link to="/connect" className="btn" data-autofocus>
              Trocar servidor
            </Link>
            <ForgetButton label="Sair" confirmLabel="Pressione novamente para sair" />
          </div>
        </div>
      )
    case 'offline':
      return (
        <div className="panel">
          <h2 className="panel__title">{session.server?.name ?? 'Seu servidor'}</h2>
          <p className="status-line status-line--warn">Servidor indisponível</p>
          <p className="panel__detail">{describeReason(session.reason, session.server?.name)}</p>
          <dl className="facts">
            {session.server ? (
              <>
                <dt>Último endereço</dt>
                <dd>{session.server.url}</dd>
                <dt>Rede</dt>
                <dd>
                  <NetworkTag url={session.server.url} />
                </dd>
                <dt>ID do servidor</dt>
                <dd className="mono">{session.server.id}</dd>
              </>
            ) : null}
            <dt>Usuário</dt>
            <dd>{session.user.name} (mantido)</dd>
          </dl>
          <p className="panel__fineprint">O Luma verifica novamente a cada 15 segundos.</p>
          <div className="actions">
            <RetryButton />
            <Link to="/connect" className="btn">
              Buscar na rede
            </Link>
            {offerDemo && !demo ? <TryDemoButton /> : <ForgetButton label="Esquecer este servidor" confirmLabel="Pressione novamente para esquecer" />}
          </div>
        </div>
      )
    case 'signedOut':
      return (
        <div className="panel">
          <h2 className="panel__title">{session.server.name}</h2>
          <p className="status-line status-line--warn">É preciso entrar novamente</p>
          <p className="panel__detail">{describeReason(session.reason, session.server.name)}</p>
          <dl className="facts">
            <dt>Endereço</dt>
            <dd>{session.server.url}</dd>
            <dt>Rede</dt>
            <dd>
              <NetworkTag url={session.server.url} />
            </dd>
          </dl>
          <div className="actions">
            <Link to="/connect" className="btn btn--primary" data-autofocus>
              Entrar
            </Link>
          </div>
        </div>
      )
    case 'gatewayDown':
      return (
        <div className="panel">
          <h2 className="panel__title">{session.remembered ? session.remembered.server.name : 'Nenhum servidor ainda'}</h2>
          <p className="status-line status-line--warn">Serviço local interrompido</p>
          <p className="panel__detail">
            {session.message} A prévia acessa o Jellyfin por um serviço neste computador. Inicie-o com{' '}
            <code>npm run dev</code>.
            {session.remembered ? ' O servidor e os dados de acesso salvos foram mantidos por esse serviço.' : ''}
          </p>
          <div className="actions">
            <RetryButton />
            {offerDemo && !demo ? <TryDemoButton /> : null}
          </div>
        </div>
      )
    case 'noServer':
      return (
        <div className="panel">
          <h2 className="panel__title">Nenhum servidor conectado</h2>
          <p className="panel__detail">Conecte seu servidor Jellyfin para ver sua biblioteca. O Luma pode encontrá-lo na rede ou pelo endereço.</p>
          <div className="actions">
            <Link to="/connect" className="btn btn--primary" data-autofocus>
              Conectar um servidor
            </Link>
          </div>
        </div>
      )
  }
}
