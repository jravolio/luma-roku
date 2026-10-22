import type { SVGProps } from 'react'

type IconProps = SVGProps<SVGSVGElement>

function Icon({ children, ...props }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false" {...props}>
      {children}
    </svg>
  )
}

export const PlayIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M7 4.5v15l12.5-7.5z" fill="currentColor" stroke="none" />
  </Icon>
)
export const PauseIcon = (p: IconProps) => (
  <Icon {...p}>
    <rect x="6" y="4.5" width="4" height="15" rx="1" fill="currentColor" stroke="none" />
    <rect x="14" y="4.5" width="4" height="15" rx="1" fill="currentColor" stroke="none" />
  </Icon>
)
export const RestartIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M4 12a8 8 0 1 0 2.5-5.8" />
    <path d="M4 4v4.5h4.5" />
  </Icon>
)
export const BackIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M15 5l-7 7 7 7" />
  </Icon>
)
export const RewindIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M11 6l-6 6 6 6M19 6l-6 6 6 6" />
  </Icon>
)
export const ForwardIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M13 6l6 6-6 6M5 6l6 6-6 6" />
  </Icon>
)
export const CaptionsIcon = (p: IconProps) => (
  <Icon {...p}>
    <rect x="3" y="5" width="18" height="14" rx="3" />
    <path d="M10 10.5a2 2 0 1 0 0 3M17 10.5a2 2 0 1 0 0 3" />
  </Icon>
)
export const SearchIcon = (p: IconProps) => (
  <Icon {...p}>
    <circle cx="11" cy="11" r="6.5" />
    <path d="M20 20l-4.2-4.2" />
  </Icon>
)
export const CheckIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M5 12.5l4.5 4.5L19 7.5" />
  </Icon>
)
export const ServerIcon = (p: IconProps) => (
  <Icon {...p}>
    <rect x="4" y="4" width="16" height="7" rx="2" />
    <rect x="4" y="13" width="16" height="7" rx="2" />
    <path d="M8 7.5h.01M8 16.5h.01" />
  </Icon>
)
export const InfoIcon = (p: IconProps) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="8.5" />
    <path d="M12 11v5M12 8h.01" />
  </Icon>
)
export const HomeIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M4 10.5L12 4l8 6.5V19a1 1 0 0 1-1 1h-4.5v-5.5h-5V20H5a1 1 0 0 1-1-1z" />
  </Icon>
)
export const FilmIcon = (p: IconProps) => (
  <Icon {...p}>
    <rect x="3.5" y="4.5" width="17" height="15" rx="2.5" />
    <path d="M8 4.5v15M16 4.5v15M3.5 9.5H8M3.5 14.5H8M16 9.5h4.5M16 14.5h4.5" />
  </Icon>
)
export const TvIcon = (p: IconProps) => (
  <Icon {...p}>
    <rect x="3" y="5" width="18" height="12" rx="2.5" />
    <path d="M8.5 20.5h7" />
  </Icon>
)
export const GearIcon = (p: IconProps) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="3" />
    <path d="M19 12a7 7 0 0 0-.1-1.2l2-1.5-2-3.4-2.3.9a7 7 0 0 0-2.1-1.2L14 3h-4l-.5 2.6a7 7 0 0 0-2.1 1.2l-2.3-.9-2 3.4 2 1.5a7 7 0 0 0 0 2.4l-2 1.5 2 3.4 2.3-.9a7 7 0 0 0 2.1 1.2L10 21h4l.5-2.6a7 7 0 0 0 2.1-1.2l2.3.9 2-3.4-2-1.5c.1-.4.1-.8.1-1.2z" />
  </Icon>
)
export const NetworkIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M2.5 9a14 14 0 0 1 19 0M5.5 12.5a9.5 9.5 0 0 1 13 0M8.5 16a5 5 0 0 1 7 0" />
    <path d="M12 19.5h.01" />
  </Icon>
)
export const ChevronIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M9 5l7 7-7 7" />
  </Icon>
)
export const ChevronLeftIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M15 5l-7 7 7 7" />
  </Icon>
)
export const SubtitlesIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M6 4.5h12a3 3 0 0 1 3 3v7a3 3 0 0 1-3 3h-7.5L6 21v-3.5a3 3 0 0 1-3-3v-7a3 3 0 0 1 3-3z" />
    <path d="M7.5 10h3.5M13.5 10h3M7.5 13.5h5M15 13.5h1.5" />
  </Icon>
)
export const AudioIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M4 10.5v3M8 7v10M12 4v16M16 7.5v9M20 10.5v3" />
  </Icon>
)
export const SpeakerIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z" fill="currentColor" />
    <path d="M15.5 9a4.5 4.5 0 0 1 0 6M18 6.5a8 8 0 0 1 0 11" />
  </Icon>
)
export const SpeakerMutedIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z" fill="currentColor" />
    <path d="M16 9.5l5 5M21 9.5l-5 5" />
  </Icon>
)
export const FullscreenIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5" />
  </Icon>
)
export const ExitFullscreenIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M9 4v5H4M15 4v5h5M9 20v-5H4M15 20v-5h5" />
  </Icon>
)
export const SkipBackIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M5.2 8.5A8 8 0 1 1 4 12" />
    <path d="M4.5 4v4.5H9" />
    <text x="12" y="15.6" textAnchor="middle" fontSize="7.5" fontWeight="700" fill="currentColor" stroke="none" fontFamily="inherit">10</text>
  </Icon>
)
export const SkipForwardIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M18.8 8.5A8 8 0 1 0 20 12" />
    <path d="M19.5 4v4.5H15" />
    <text x="12" y="15.6" textAnchor="middle" fontSize="7.5" fontWeight="700" fill="currentColor" stroke="none" fontFamily="inherit">10</text>
  </Icon>
)
export const ListIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M9 6.5h11M9 12h11M9 17.5h11" />
    <path d="M4.5 6.5h.01M4.5 12h.01M4.5 17.5h.01" strokeWidth="3" />
  </Icon>
)
export const NextIcon = (p: IconProps) => (
  <Icon {...p}>
    <path d="M5 5.5v13l10-6.5z" fill="currentColor" stroke="none" />
    <path d="M18.5 5.5v13" strokeWidth="2.4" />
  </Icon>
)
