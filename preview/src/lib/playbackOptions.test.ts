import { describe, expect, it } from 'vitest'
import type { PlaybackInfo } from '../api/types'
import { applyChange, chosen, renderedSubtitle, selectionOptions, streamSummary } from './playbackOptions'

const base: PlaybackInfo = {
  url: '/api/media/a/stream.m3u8',
  playSessionId: 'p',
  mediaSourceId: 'v1',
  itemId: 'i',
  startTimeTicks: 0,
  playMethod: 'Transcode',
  selection: { mediaSourceId: 'v1', audioStreamIndex: 2, subtitleStreamIndex: 6, quality: '720p' },
  subtitleDelivery: 'encoded',
  subtitles: [{ index: 6, url: '/api/media/s6.vtt' }],
}

describe('playback choices', () => {
  it('resends every unchanged choice with a change', () => {
    const current = selectionOptions(base)
    expect(applyChange(current, { kind: 'audio', index: 4 })).toEqual({ mediaSourceId: 'v1', audioStreamIndex: 4, subtitleStreamIndex: 6, quality: '720p' })
    expect(applyChange(current, { kind: 'subtitles', index: -1 })).toEqual({ mediaSourceId: 'v1', audioStreamIndex: 2, subtitleStreamIndex: -1, quality: '720p' })
    expect(applyChange(current, { kind: 'quality', id: '480p' })).toEqual({ mediaSourceId: 'v1', audioStreamIndex: 2, subtitleStreamIndex: 6, quality: '480p' })
  })

  it('drops stream indices when the version changes, keeping Off and the quality ceiling', () => {
    expect(applyChange(selectionOptions(base), { kind: 'version', id: 'v2' })).toEqual({ mediaSourceId: 'v2', quality: '720p' })
    const off = { ...selectionOptions(base), subtitleStreamIndex: -1 }
    expect(applyChange(off, { kind: 'version', id: 'v2' })).toEqual({ mediaSourceId: 'v2', quality: '720p', subtitleStreamIndex: -1 })
  })

  it('omits a missing audio track rather than sending null', () => {
    expect(selectionOptions({ ...base, selection: { ...base.selection!, audioStreamIndex: null } })).not.toHaveProperty('audioStreamIndex')
    expect(selectionOptions({ ...base, selection: undefined })).toEqual({})
  })

  it('recognises the current choice', () => {
    const current = selectionOptions(base)
    expect(chosen(current, { kind: 'subtitles', index: 6 })).toBe(true)
    expect(chosen(current, { kind: 'audio', index: 4 })).toBe(false)
    expect(chosen(current, { kind: 'position' })).toBe(false)
  })

  it('never draws a burned-in or switched-off subtitle in the browser', () => {
    expect(renderedSubtitle(base, -1)).toBeNull()
    expect(renderedSubtitle({ ...base, subtitleDelivery: 'off', selection: { ...base.selection!, subtitleStreamIndex: -1 } }, -1)).toBeNull()
    expect(renderedSubtitle({ ...base, subtitleDelivery: 'external' }, -1)).toEqual(base.subtitles![0])
    expect(renderedSubtitle({ ...base, subtitleDelivery: 'external', selection: { ...base.selection!, subtitleStreamIndex: 7 } }, -1)).toBeNull()
  })

  it('keeps the legacy client-side subtitle choice for gateways without choices', () => {
    const legacy = { ...base, selection: undefined, subtitleDelivery: undefined }
    expect(renderedSubtitle(legacy, 0)).toEqual(base.subtitles![0])
    expect(renderedSubtitle(legacy, -1)).toBeNull()
  })

  it('describes what is actually playing', () => {
    expect(streamSummary({ ...base, stream: { width: 1280, height: 720, bitrate: 3_900_000, videoCodec: 'h264', audioCodec: 'aac' } })).toBe(
      '1280 × 720 · H264 · AAC · 3,9 Mbps · Transcodificação',
    )
    expect(streamSummary({ ...base, playMethod: 'DirectPlay', stream: { bitrate: 24_000_000 } })).toBe('24 Mbps · Reprodução direta')
  })
})
