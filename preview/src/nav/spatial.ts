export type Direction = 'up' | 'down' | 'left' | 'right'

export interface Box {
  left: number
  top: number
  right: number
  bottom: number
}

const ORTHOGONAL_WEIGHT = 3

// Candidates sharing a row or column beat closer diagonal ones, so Down from a poster lands on the shelf below, not a nav pill.
export function pickNext(from: Box, candidates: readonly Box[], direction: Direction): number {
  const horizontal = direction === 'left' || direction === 'right'
  const fromCenterX = (from.left + from.right) / 2
  const fromCenterY = (from.top + from.bottom) / 2
  let best = -1
  let bestScore = Infinity

  candidates.forEach((box, index) => {
    const centerX = (box.left + box.right) / 2
    const centerY = (box.top + box.bottom) / 2
    let gap: number
    switch (direction) {
      case 'right':
        if (centerX <= fromCenterX || box.left < from.left + 1) return
        gap = Math.max(0, box.left - from.right)
        break
      case 'left':
        if (centerX >= fromCenterX || box.right > from.right - 1) return
        gap = Math.max(0, from.left - box.right)
        break
      case 'down':
        if (centerY <= fromCenterY || box.top < from.top + 1) return
        gap = Math.max(0, box.top - from.bottom)
        break
      case 'up':
        if (centerY >= fromCenterY || box.bottom > from.bottom - 1) return
        gap = Math.max(0, from.top - box.bottom)
        break
    }
    const overlap = horizontal
      ? Math.min(from.bottom, box.bottom) - Math.max(from.top, box.top)
      : Math.min(from.right, box.right) - Math.max(from.left, box.left)
    const drift = horizontal ? Math.abs(centerY - fromCenterY) : Math.abs(centerX - fromCenterX)
    const score = gap + (overlap > 0 ? 0 : drift * ORTHOGONAL_WEIGHT) + drift * 0.1
    if (score < bestScore) {
      bestScore = score
      best = index
    }
  })
  return best
}
