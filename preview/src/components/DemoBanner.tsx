import { navigate } from '../nav/router'
import { useSession } from '../session/SessionProvider'

export function DemoBanner() {
  const { demo, exitDemo } = useSession()
  if (!demo) return null
  return (
    <aside className="demo-banner" aria-label="Modo demonstração" data-no-scroll>
      <span className="demo-banner__label">Demo</span>
      <span className="demo-banner__text">Filmes de exemplo do Blender Studio. Esta não é sua biblioteca do Jellyfin.</span>
      <button
        type="button"
        className="btn btn--small"
        data-focus-key="demo:exit"
        onClick={() => {
          exitDemo()
          navigate('/connect', { replace: true })
        }}
      >
        Sair da demonstração
      </button>
    </aside>
  )
}
