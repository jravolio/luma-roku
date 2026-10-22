import { TICKS_PER_SECOND, type PlaybackInfo } from '../api/types'

export interface StreamTiming {
  offsetTicks: number
  initialSeekSeconds: number
}

export function streamTiming(info: Pick<PlaybackInfo, 'startTimeTicks' | 'positionOffsetTicks' | 'seekTimeTicks'>): StreamTiming {
  const offsetTicks = info.positionOffsetTicks ?? 0
  const seekTicks = info.seekTimeTicks ?? info.startTimeTicks - offsetTicks
  const initialSeekSeconds = Math.max(0, seekTicks / TICKS_PER_SECOND)
  return { offsetTicks, initialSeekSeconds }
}

export function itemPositionTicks(timing: StreamTiming, streamSeconds: number): number {
  return timing.offsetTicks + Math.max(0, Math.round(streamSeconds * TICKS_PER_SECOND))
}
