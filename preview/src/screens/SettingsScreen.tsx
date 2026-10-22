import { demoCredits } from '../api/demoCatalog'
import { ChevronIcon } from '../components/icons'
import { Link } from '../components/Link'
import { useScreenFocus } from '../nav/useScreenFocus'
import { useSession } from '../session/SessionProvider'

export function SettingsScreen() {
  const { session, demo } = useSession()
  useScreenFocus(session.status !== 'checking', 'settings')
  const accountDetail =
    session.status === 'connected' ? `${session.user.name} · ${session.server.name}` : demo ? 'Demo · sem conexão' : 'Sem conexão'

  return (
    <div className="screen screen--page">
      <header className="page-header">
        <h1 className="page-title">Configurações</h1>
      </header>
      <div className="stack">
        <section aria-labelledby="account-heading">
          <h2 className="section-title" id="account-heading">
            Conta
          </h2>
          <Link to="/account" className="row" data-autofocus data-focus-key="settings:account">
            <span className="row__label">Servidor e acesso</span>
            <span className="row__value">{accountDetail}</span>
            <ChevronIcon className="row__chevron" />
          </Link>
        </section>

        <section aria-labelledby="remote-heading">
          <h2 className="section-title" id="remote-heading">
            Controle remoto
          </h2>
          <div className="panel">
            <dl className="facts facts--keys">
              <dt>
                <kbd>←</kbd> <kbd>↑</kbd> <kbd>→</kbd> <kbd>↓</kbd>
              </dt>
              <dd>Mover</dd>
              <dt>
                <kbd>Enter</kbd>
              </dt>
              <dd>Selecionar</dd>
              <dt>
                <kbd>Esc</kbd> <kbd>Backspace</kbd>
              </dt>
              <dd>Voltar</dd>
              <dt>
                <kbd>Space</kbd>
              </dt>
              <dd>Reproduzir ou pausar na linha do tempo; ativar o botão em foco</dd>
              <dt>
                <kbd>J</kbd> <kbd>L</kbd>
              </dt>
              <dd>Voltar ou avançar 10 segundos</dd>
              <dt>
                <kbd>K</kbd>
              </dt>
              <dd>Reproduzir ou pausar em qualquer lugar do player</dd>
              <dt>
                <kbd>C</kbd>
              </dt>
              <dd>Menu de legendas</dd>
              <dt>
                <kbd>M</kbd> <kbd>F</kbd>
              </dt>
              <dd>Silenciar, tela cheia</dd>
            </dl>
          </div>
        </section>

        {demo ? (
          <section aria-labelledby="credits-heading">
            <h2 className="section-title" id="credits-heading">
              Créditos da demonstração
            </h2>
            <div className="panel">
              <p className="panel__detail">
                As imagens e o vídeo de exemplo vêm dos filmes abertos do Blender Studio, via Wikimedia Commons. As imagens
                foram redimensionadas; alguns pôsteres são recortes de cenas. O progresso é apagado ao sair da demonstração ou recarregar a página.
              </p>
              <ul className="credits" role="list">
                {demoCredits.map(credit => (
                  <li key={`${credit.work}-${credit.file}`}>
                    <span className="credits__work">
                      {credit.work} <span className="credits__file">· {credit.file}</span>
                    </span>
                    <span className="credits__by">
                      {credit.author} ·{' '}
                      <a href={credit.licenseUrl} target="_blank" rel="noreferrer">
                        {credit.license}
                      </a>{' '}
                      ·{' '}
                      <a href={credit.source} target="_blank" rel="noreferrer">
                        Fonte
                      </a>
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          </section>
        ) : null}
      </div>
    </div>
  )
}
