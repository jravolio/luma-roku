import { useCallback, useEffect, useState, useSyncExternalStore } from 'react'

const cache = new Map<string, unknown>()
const listeners = new Set<() => void>()
let generation = 0

export function invalidateResources() {
  cache.clear()
  generation += 1
  listeners.forEach(listener => listener())
}

function subscribe(listener: () => void) {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

const getGeneration = () => generation

interface Settled<T> {
  key: string
  generation: number
  attempt: number
  data?: T
  error?: Error
}

export interface Resource<T> {
  data: T | undefined
  error: Error | undefined
  loading: boolean
  retry: () => void
}

export function useResource<T>(key: string | null, load: (signal: AbortSignal) => Promise<T>): Resource<T> {
  const currentGeneration = useSyncExternalStore(subscribe, getGeneration)
  const [attempt, setAttempt] = useState(0)
  const [settled, setSettled] = useState<Settled<T> | undefined>()

  useEffect(() => {
    if (key === null) return
    if (cache.has(key)) {
      setSettled({ key, generation: currentGeneration, attempt, data: cache.get(key) as T })
      return
    }
    const controller = new AbortController()
    load(controller.signal).then(
      data => {
        // A response that outlived its request (account switch, invalidation) must not repopulate the cache.
        if (controller.signal.aborted || generation !== currentGeneration) return
        cache.set(key, data)
        setSettled({ key, generation: currentGeneration, attempt, data })
      },
      (error: unknown) => {
        if (controller.signal.aborted) return
        setSettled({ key, generation: currentGeneration, attempt, error: error instanceof Error ? error : new Error(String(error)) })
      },
    )
    return () => controller.abort()
    // `load` is intentionally excluded: callers pass inline closures and the key captures their inputs.
  }, [key, attempt, currentGeneration])

  const retry = useCallback(() => {
    if (key !== null) cache.delete(key)
    setAttempt(value => value + 1)
  }, [key])

  const current = settled && settled.key === key && settled.generation === currentGeneration && settled.attempt === attempt ? settled : undefined
  const stale = !current && settled?.key === key ? settled : undefined
  return {
    data: current?.data ?? stale?.data,
    error: current?.error,
    loading: key !== null && !current,
    retry,
  }
}
