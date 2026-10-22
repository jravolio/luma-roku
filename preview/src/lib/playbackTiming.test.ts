import { describe, expect, it } from 'vitest'
import { itemPositionTicks, streamTiming } from './playbackTiming'

describe('streamTiming', () => {
  it('seeks client-side for direct play', () => {
    const timing = streamTiming({ startTimeTicks: 300_000_000, seekTimeTicks: 300_000_000, positionOffsetTicks: 0 })
    expect(timing).toEqual({ offsetTicks: 0, initialSeekSeconds: 30 })
    expect(itemPositionTicks(timing, 45)).toBe(450_000_000)
  })

  it('does not seek again when a transcode already starts at the resume point', () => {
    const timing = streamTiming({ startTimeTicks: 300_000_000, seekTimeTicks: 0, positionOffsetTicks: 300_000_000 })
    expect(timing.initialSeekSeconds).toBe(0)
    expect(itemPositionTicks(timing, 10)).toBe(400_000_000)
  })

  it('falls back to startTimeTicks when the server omits seek fields', () => {
    expect(streamTiming({ startTimeTicks: 120_000_000 }).initialSeekSeconds).toBe(12)
  })
})
