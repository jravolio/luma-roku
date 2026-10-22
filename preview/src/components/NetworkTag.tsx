import { networkOf } from '../lib/network'
import { NetworkIcon } from './icons'

export function NetworkTag({ url }: { url: string }) {
  const network = networkOf(url)
  return (
    <span className={`network-tag network-tag--${network.kind}`}>
      <NetworkIcon className="network-tag__icon" aria-hidden="true" />
      {network.label}
    </span>
  )
}
