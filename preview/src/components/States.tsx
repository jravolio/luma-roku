import type { ReactNode } from 'react'
import { ApiError } from '../api/gateway'

export function errorCopy(error: Error): { title: string; detail: string } {
  if (error instanceof ApiError) {
    switch (error.kind) {
      case 'unreachable':
        return { title: 'Não foi possível acessar seu servidor', detail: error.message }
      case 'unauthorized':
        return { title: 'Sessão encerrada', detail: 'Seu servidor pediu que você entre novamente. O servidor escolhido foi mantido.' }
      case 'notFound':
        return { title: 'Não encontrado', detail: 'Este título não está mais disponível. Ele pode ter sido removido da biblioteca.' }
      default:
        return { title: 'Algo deu errado', detail: error.message }
    }
  }
  return { title: 'Algo deu errado', detail: error.message }
}

interface ErrorStateProps {
  error: Error
  onRetry: () => void
  children?: ReactNode
}

export function ErrorState({ error, onRetry, children }: ErrorStateProps) {
  const { title, detail } = errorCopy(error)
  return (
    <div className="state state--error" role="alert">
      <h2 className="state__title">{title}</h2>
      <p className="state__detail">{detail}</p>
      <div className="state__actions">
        <button type="button" className="btn btn--primary" onClick={onRetry} data-autofocus>
          Tentar novamente
        </button>
        {children}
      </div>
    </div>
  )
}

export function EmptyState({ title, detail, children }: { title: string; detail: string; children?: ReactNode }) {
  return (
    <div className="state">
      <h2 className="state__title">{title}</h2>
      <p className="state__detail">{detail}</p>
      {children ? <div className="state__actions">{children}</div> : null}
    </div>
  )
}

export function ShelfSkeleton({ rows = 2 }: { rows?: number }) {
  return (
    <div className="skeleton" aria-hidden="true">
      {Array.from({ length: rows }, (_, row) => (
        <div className="skeleton__row" key={row}>
          <div className="skeleton__title" />
          <div className="skeleton__cards">
            {Array.from({ length: 7 }, (_, card) => (
              <div className="skeleton__card" key={card} />
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}

export function LoadingNotice({ label }: { label: string }) {
  return (
    <p className="loading-notice" role="status">
      <span className="loading-notice__pulse" aria-hidden="true" />
      {label}
    </p>
  )
}

interface LoadMoreProps {
  shown: number
  total: number | undefined
  hasMore: boolean
  loading: boolean
  error: Error | undefined
  onLoad: () => void
}

export function LoadMore({ shown, total, hasMore, loading, error, onLoad }: LoadMoreProps) {
  if (!hasMore) return null
  return (
    <div className="load-more">
      <button type="button" className="btn" onClick={onLoad} disabled={loading} data-focus-key="load-more">
        {loading ? 'Carregando…' : `Mostrar mais · ${shown} de ${total ?? `${shown}+`}`}
      </button>
      {error ? (
        <p className="form-error" role="alert">
          Não foi possível carregar mais: {error.message}
        </p>
      ) : null}
    </div>
  )
}
