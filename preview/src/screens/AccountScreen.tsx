import { ServerCard } from '../components/ServerCard'
import { useScreenFocus } from '../nav/useScreenFocus'
import { useSession } from '../session/SessionProvider'

export function AccountScreen() {
  const { session } = useSession()
  useScreenFocus(session.status !== 'checking', 'account')
  return (
    <div className="screen screen--page">
      <header className="page-header">
        <h1 className="page-title">Conta</h1>
      </header>
      <div className="stack">
        <ServerCard session={session} />
      </div>
    </div>
  )
}

export function ServerUnavailableScreen() {
  const { session } = useSession()
  useScreenFocus(true, 'unavailable')
  return (
    <div className="screen screen--page">
      <header className="page-header">
        <h1 className="page-title">Sua biblioteca está indisponível</h1>
        <p className="page-subtitle">Sua conta foi mantida. A biblioteca voltará quando o servidor responder.</p>
      </header>
      <div className="stack">
        <ServerCard session={session} offerDemo />
      </div>
    </div>
  )
}
