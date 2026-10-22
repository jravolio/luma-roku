import { describe, expect, it } from 'vitest'
import { pickNext, type Box } from './spatial'

const box = (left: number, top: number, width = 100, height = 100): Box => ({ left, top, right: left + width, bottom: top + height })

describe('pickNext', () => {
  const row = [box(0, 0), box(120, 0), box(240, 0)]

  it('moves to the adjacent card in a row', () => {
    expect(pickNext(row[0]!, row.slice(1), 'right')).toBe(0)
    expect(pickNext(row[2]!, row.slice(0, 2), 'left')).toBe(1)
  })

  it('returns -1 at the edge', () => {
    expect(pickNext(row[2]!, row.slice(0, 2), 'right')).toBe(-1)
  })

  it('prefers the item in the same column over a closer diagonal one', () => {
    const from = box(400, 0)
    const candidates = [box(0, 140), box(390, 400)]
    expect(pickNext(from, candidates, 'down')).toBe(1)
  })

  it('moves up from a shelf to the nearest button above', () => {
    const from = box(300, 500)
    const candidates = [box(0, 300, 200, 60), box(260, 300, 200, 60), box(0, 0, 200, 60)]
    expect(pickNext(from, candidates, 'up')).toBe(1)
  })
})
