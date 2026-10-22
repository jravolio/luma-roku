import type { AnchorHTMLAttributes, MouseEvent } from 'react'
import { navigate } from '../nav/router'

interface LinkProps extends Omit<AnchorHTMLAttributes<HTMLAnchorElement>, 'href'> {
  to: string
  replace?: boolean
}

export function Link({ to, replace, onClick, ...props }: LinkProps) {
  function handleClick(event: MouseEvent<HTMLAnchorElement>) {
    onClick?.(event)
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    navigate(to, { replace })
  }
  return <a href={`#${to}`} onClick={handleClick} {...props} />
}
