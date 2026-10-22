import { act, renderHook, waitFor } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { invalidateResources, useResource } from './useResource'

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>(r => (resolve = r))
  return { promise, resolve }
}

describe('useResource', () => {
  it('does not let a response from before an invalidation repopulate the cache', async () => {
    const calls: ReturnType<typeof deferred<string>>[] = []
    const load = () => {
      const next = deferred<string>()
      calls.push(next)
      return next.promise
    }
    const first = renderHook(() => useResource('library', load))
    await waitFor(() => expect(calls).toHaveLength(1))

    act(() => invalidateResources())
    await waitFor(() => expect(calls).toHaveLength(2))
    await act(async () => calls[0]!.resolve('old account'))
    await act(async () => calls[1]!.resolve('new account'))
    await waitFor(() => expect(first.result.current.data).toBe('new account'))

    const second = renderHook(() => useResource('library', load))
    await waitFor(() => expect(second.result.current.data).toBe('new account'))
    expect(calls).toHaveLength(2)
  })

  it('retries after an error', async () => {
    let attempt = 0
    const { result } = renderHook(() =>
      useResource('flaky', async () => {
        attempt += 1
        if (attempt === 1) throw new Error('nope')
        return 'ok'
      }),
    )
    await waitFor(() => expect(result.current.error?.message).toBe('nope'))
    act(() => result.current.retry())
    await waitFor(() => expect(result.current.data).toBe('ok'))
  })
})
