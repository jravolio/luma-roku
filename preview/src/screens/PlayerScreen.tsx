import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type KeyboardEvent as ReactKeyboardEvent,
  type ReactNode,
  type RefObject,
} from 'react'
import { TICKS_PER_SECOND, type Item, type LibrarySource, type PlaybackInfo, type PlaybackOptions, type PlaybackReport } from '../api/types'
import {
  AudioIcon,
  BackIcon,
  ExitFullscreenIcon,
  FullscreenIcon,
  GearIcon,
  HomeIcon,
  ListIcon,
  NextIcon,
  PauseIcon,
  PlayIcon,
  SkipBackIcon,
  SkipForwardIcon,
  SpeakerIcon,
  SpeakerMutedIcon,
  SubtitlesIcon,
} from '../components/icons'
import { PlayerMenu, type MenuSection } from '../components/PlayerMenu'
import { Link } from '../components/Link'
import { errorCopy } from '../components/States'
import { invalidateResources } from '../data/useResource'
import { displayTitle, episodeCode, formatPlayerClock, itemTitle, playPath } from '../lib/format'
import { loadHls } from '../lib/loadHls'
import { findNextEpisode } from '../lib/nextEpisode'
import {
  applyChange,
  changeLabel,
  chosen,
  qualityLabel,
  renderedSubtitle,
  selectionOptions,
  streamSummary,
  SUBTITLES_OFF,
  supportsChoices,
  type PlaybackChange,
} from '../lib/playbackOptions'
import { itemPositionTicks, streamTiming } from '../lib/playbackTiming'
import { BACK_EVENT, focusElement, moveFocus } from '../nav/remote'
import { goBack, navigate, useRoute } from '../nav/router'
import { useSession } from '../session/SessionProvider'

const SKIP_SECONDS = 10
const HIDE_AFTER_MS = 4000
const PROGRESS_EVERY_MS = 10_000
const NOTICE_MS = 8000

type HlsInstance = { destroy(): void }
type MenuName = 'subtitles' | 'audio' | 'settings' | 'chapters'

function mediaErrorMessage(error: MediaError | null): string {
  switch (error?.code) {
    case MediaError.MEDIA_ERR_NETWORK:
      return 'A conexão com o servidor caiu ao carregar este vídeo.'
    case MediaError.MEDIA_ERR_DECODE:
      return 'Este navegador não conseguiu decodificar o vídeo. O aplicativo para Roku ainda pode reproduzi-lo.'
    case MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED:
      return 'Este navegador não reproduz este formato de vídeo. O aplicativo para Roku ainda pode reproduzi-lo.'
    default:
      return 'O vídeo parou inesperadamente.'
  }
}

async function attachSource(
  video: HTMLVideoElement,
  url: string,
  startSeconds: number,
  signal: AbortSignal,
  onFatal: (message: string) => void,
): Promise<HlsInstance | null> {
  const isHls = /\.m3u8(\?|$)/i.test(url)
  if (!isHls || video.canPlayType('application/vnd.apple.mpegurl')) {
    video.src = url
    return null
  }
  let Hls: Awaited<ReturnType<typeof loadHls>>
  try {
    Hls = await loadHls()
  } catch {
    if (!signal.aborted) onFatal('O Luma não conseguiu carregar o player. Verifique a conexão e tente novamente.')
    return null
  }
  // StrictMode and fast route changes dispose the first attempt while the import is pending; it must not touch the element.
  if (signal.aborted) return null
  if (!Hls.isSupported()) {
    onFatal('Este navegador não reproduz transmissões HLS. Tente Safari ou Chrome, ou assista no Roku.')
    return null
  }
  // Jellyfin playlists cover the whole item, so loading starts at the resume point instead of segment zero.
  const hls = new Hls(startSeconds > 0 ? { startPosition: startSeconds } : {})
  let recoveredAt = 0
  hls.on(Hls.Events.ERROR, (_event, data) => {
    if (signal.aborted || !data.fatal) return
    if (data.type === Hls.ErrorTypes.MEDIA_ERROR && Date.now() - recoveredAt > 5000) {
      recoveredAt = Date.now()
      hls.recoverMediaError()
      return
    }
    onFatal(
      data.type === Hls.ErrorTypes.NETWORK_ERROR
        ? 'A conexão com o servidor caiu durante a reprodução.'
        : 'A transmissão falhou e não pôde ser recuperada.',
    )
  })
  hls.loadSource(url)
  hls.attachMedia(video)
  return hls
}

type Snapshot = Pick<PlaybackReport, 'positionTicks' | 'isPaused'>

function requestedPosition(info: PlaybackInfo): number {
  const timing = streamTiming(info)
  return itemPositionTicks(timing, timing.initialSeekSeconds)
}

// A remounted player (hot reload) can be handed a session an earlier instance already ended; it must not attach it.
const endedSessions = new WeakSet<PlaybackInfo>()

/** Ends a server session the player never attached, so its transcode job doesn't linger. */
function stopUnused(library: LibrarySource, info: PlaybackInfo) {
  endedSessions.add(info)
  void library
    .report({
      event: 'stop',
      itemId: info.itemId,
      playSessionId: info.playSessionId,
      mediaSourceId: info.mediaSourceId,
      positionTicks: requestedPosition(info),
      isPaused: true,
    })
    .catch(() => undefined)
}

interface Session {
  info: PlaybackInfo
  resumePaused: boolean
  generation: number
}

interface SwitchIntent {
  positionTicks: number
  paused: boolean
}

function OptionButton({
  label,
  name,
  open,
  onToggle,
  buttonRef,
  children,
  menu,
}: {
  label: string
  name: MenuName
  open: boolean
  onToggle: (name: MenuName) => void
  buttonRef: RefObject<HTMLButtonElement | null>
  children: ReactNode
  menu: ReactNode
}) {
  return (
    <span className="player__option">
      <button
        ref={buttonRef}
        type="button"
        className="glass-circle"
        aria-label={label}
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => onToggle(name)}
        data-focus-key={`player:${name}`}
      >
        {children}
      </button>
      {open ? menu : null}
    </span>
  )
}

interface PlayerProps {
  item: Item
  initial: PlaybackInfo
}

function Player({ item, initial }: PlayerProps) {
  const { library } = useSession()
  const rootRef = useRef<HTMLDivElement>(null)
  const videoRef = useRef<HTMLVideoElement>(null)
  const trackRef = useRef<HTMLTrackElement>(null)
  const timelineRef = useRef<HTMLInputElement>(null)
  const elapsedRef = useRef<HTMLSpanElement>(null)
  const subtitlesButton = useRef<HTMLButtonElement>(null)
  const audioButton = useRef<HTMLButtonElement>(null)
  const settingsButton = useRef<HTMLButtonElement>(null)
  const chaptersButton = useRef<HTMLButtonElement>(null)

  const [session, setSession] = useState<Session>({ info: initial, resumePaused: false, generation: 0 })
  const info = session.info
  const timing = useMemo(() => streamTiming(info), [info])
  const offsetSeconds = timing.offsetTicks / TICKS_PER_SECOND
  // Media events and reports outlive renders; they read the attached session from here.
  const live = useRef({ info, timing })
  // A new source reports 0 until the resume seek lands; nothing is captured before then.
  const positioned = useRef(false)
  const started = useRef(false)
  const snapshot = useRef<Snapshot>({ positionTicks: requestedPosition(initial), isPaused: true })
  const hideTimer = useRef<number | undefined>(undefined)
  const requestId = useRef(0)
  const intent = useRef<SwitchIntent | null>(null)
  const alive = useRef(true)
  const stopped = useRef(new Set<string>())

  const [paused, setPaused] = useState(true)
  const [buffering, setBuffering] = useState(true)
  const [time, setTime] = useState(timing.initialSeekSeconds)
  const [duration, setDuration] = useState(0)
  const [chrome, setChrome] = useState(true)
  const [failure, setFailure] = useState<string>()
  const [menu, setMenu] = useState<MenuName | null>(null)
  const [desired, setDesired] = useState<PlaybackOptions | null>(null)
  const [pending, setPending] = useState<PlaybackChange | null>(null)
  const [notice, setNotice] = useState<string>()
  const [legacyCaption, setLegacyCaption] = useState(-1)
  const [muted, setMuted] = useState(false)
  const [fullscreen, setFullscreen] = useState(false)
  const [scrub, setScrub] = useState<number | null>(null)
  const [next, setNext] = useState<Item | null>(null)
  const [decoded, setDecoded] = useState<{ width: number; height: number } | null>(null)
  const menuOpen = useRef(false)

  useLayoutEffect(() => {
    live.current = { info, timing }
    positioned.current = false
    setDecoded(null)
  }, [info, timing])

  useLayoutEffect(() => {
    menuOpen.current = menu !== null
  }, [menu])

  const capture = useCallback((video: HTMLVideoElement) => {
    if (!positioned.current) return
    snapshot.current = { positionTicks: itemPositionTicks(live.current.timing, video.currentTime), isPaused: video.paused }
  }, [])

  const send = useCallback(
    (event: PlaybackReport['event'], target: PlaybackInfo, position: Snapshot = snapshot.current, keepalive = false) => {
      void library
        .report(
          {
            event,
            itemId: target.itemId,
            playSessionId: target.playSessionId,
            mediaSourceId: target.mediaSourceId,
            ...position,
          },
          { keepalive },
        )
        .catch(() => undefined)
    },
    [library],
  )

  // Every negotiated session is stopped exactly once, whether or not it ever played.
  const retire = useCallback(
    (target: PlaybackInfo, position: Snapshot, keepalive = false) => {
      if (stopped.current.has(target.playSessionId)) return
      stopped.current.add(target.playSessionId)
      endedSessions.add(target)
      send('stop', target, position, keepalive)
    },
    [send],
  )

  const showChrome = useCallback(() => {
    setChrome(true)
    window.clearTimeout(hideTimer.current)
    hideTimer.current = window.setTimeout(() => {
      if (videoRef.current && !videoRef.current.paused && !menuOpen.current) setChrome(false)
    }, HIDE_AFTER_MS)
  }, [])

  useEffect(() => {
    const video = videoRef.current
    if (!video || endedSessions.has(info)) return
    const controller = new AbortController()
    let hls: HlsInstance | null = null
    video.autoplay = !session.resumePaused
    void attachSource(video, info.url, timing.initialSeekSeconds, controller.signal, message => {
      if (!controller.signal.aborted) setFailure(message)
    }).then(instance => {
      if (controller.signal.aborted) instance?.destroy()
      else hls = instance
    })
    return () => {
      controller.abort()
      hls?.destroy()
      video.removeAttribute('src')
      video.load()
    }
    // A session is attached exactly once; its timing and pause intent travel with it.
  }, [info.url, session.generation])

  useEffect(() => {
    alive.current = true
    const timer = window.setInterval(() => {
      if (started.current && !snapshot.current.isPaused) send('progress', live.current.info)
    }, PROGRESS_EVERY_MS)
    return () => {
      window.clearInterval(timer)
      window.clearTimeout(hideTimer.current)
      alive.current = false
      // StrictMode disposes and remounts in one commit; only a real unmount is still dead a microtask later.
      queueMicrotask(() => {
        if (alive.current) return
        retire(live.current.info, snapshot.current, true)
        started.current = false
      })
    }
  }, [send, retire])

  const subtitle = renderedSubtitle(info, legacyCaption)
  useEffect(() => {
    const video = videoRef.current
    const tracks = video?.textTracks
    if (!tracks) return
    const own = trackRef.current?.track
    // hls.js can add in-manifest tracks at any time; only the chosen external track may show.
    const sync = () => {
      for (const track of Array.from(tracks)) track.mode = own && track === own ? 'showing' : 'disabled'
    }
    sync()
    tracks.addEventListener?.('addtrack', sync)
    return () => tracks.removeEventListener?.('addtrack', sync)
  }, [subtitle?.url, session.generation])

  useEffect(() => {
    if (timelineRef.current) focusElement(timelineRef.current)
    if (endedSessions.has(initial)) void choose({ kind: 'position' }, { play: true })
    // Mount only: `choose` reads live refs.
  }, [])

  useEffect(() => {
    const controller = new AbortController()
    findNextEpisode(library, item, controller.signal)
      .then(found => {
        if (!controller.signal.aborted) setNext(found)
      })
      .catch(() => undefined)
    return () => controller.abort()
  }, [library, item])

  useEffect(() => {
    if (!notice) return
    const timer = window.setTimeout(() => setNotice(undefined), NOTICE_MS)
    return () => window.clearTimeout(timer)
  }, [notice])

  useEffect(() => {
    const sync = () => setFullscreen(document.fullscreenElement === rootRef.current)
    document.addEventListener('fullscreenchange', sync)
    return () => document.removeEventListener('fullscreenchange', sync)
  }, [])

  const visible = chrome || paused || Boolean(failure)

  useEffect(() => {
    function onBack(event: Event) {
      if (menuOpen.current) {
        event.preventDefault()
        setMenu(null)
      } else if (visible && videoRef.current && !videoRef.current.paused) {
        // As on tvOS, Back first hides the controls; the next Back leaves the player.
        event.preventDefault()
        window.clearTimeout(hideTimer.current)
        setChrome(false)
      }
    }
    window.addEventListener(BACK_EVENT, onBack)
    return () => window.removeEventListener(BACK_EVENT, onBack)
  }, [visible])

  async function choose(change: PlaybackChange, options: { atTicks?: number; play?: boolean } = {}) {
    const current = live.current.info
    if (change.kind !== 'position') {
      if (!supportsChoices(current)) return
      const base = desired ?? selectionOptions(current)
      if (chosen(base, change)) return
    }
    const video = videoRef.current
    if (!intent.current) {
      if (video) capture(video)
      intent.current = { positionTicks: snapshot.current.positionTicks, paused: video ? video.paused : snapshot.current.isPaused }
      if (video && !video.paused) video.pause()
    }
    if (options.atTicks !== undefined) intent.current.positionTicks = Math.max(0, Math.round(options.atTicks))
    if (options.play) intent.current.paused = false
    const requested = change.kind === 'position' ? (desired ?? selectionOptions(current)) : applyChange(desired ?? selectionOptions(current), change)
    const { positionTicks } = intent.current
    const id = ++requestId.current
    setDesired(requested)
    setPending(change)
    setNotice(undefined)
    try {
      // Not aborted when superseded: the server creates a session either way, and only a response names it for cleanup.
      const replacement = await library.playback(item.id, positionTicks, requested)
      if (!alive.current || id !== requestId.current) {
        stopUnused(library, replacement)
        return
      }
      const resumePaused = intent.current?.paused ?? false
      snapshot.current = { positionTicks, isPaused: resumePaused }
      retire(current, snapshot.current)
      started.current = false
      intent.current = null
      setDesired(null)
      setPending(null)
      setFailure(undefined)
      setBuffering(true)
      setTime(streamTiming(replacement).initialSeekSeconds)
      setSession(previous => ({ info: replacement, resumePaused, generation: previous.generation + 1 }))
    } catch (error) {
      if (!alive.current || id !== requestId.current) return
      const resume = intent.current ? !intent.current.paused : false
      intent.current = null
      setDesired(null)
      setPending(null)
      const reason = error instanceof Error ? errorCopy(error).detail : 'O servidor não aceitou a alteração.'
      setNotice(
        change.kind === 'position'
          ? `Não foi possível reiniciar a reprodução. ${reason}`
          : `Não foi possível mudar para ${changeLabel(current, change)}. ${reason}`,
      )
      if (resume && !failure) void videoRef.current?.play().catch(() => undefined)
    }
  }

  function togglePlay() {
    const video = videoRef.current
    if (!video) return
    if (video.paused) void video.play().catch(() => setPaused(true))
    else video.pause()
    showChrome()
  }

  const streamDuration = Number.isFinite(duration) && duration > 0 ? duration : 0
  const total = streamDuration ? offsetSeconds + streamDuration : (item.runtimeTicks ?? 0) / TICKS_PER_SECOND
  const position = offsetSeconds + time

  function refreshTimeline(seconds: number) {
    if (scrub !== null) return
    const timeline = timelineRef.current
    if (!timeline) return
    const shown = offsetSeconds + seconds
    const fill = total > 0 ? Math.min(100, (shown / total) * 100) : 0
    timeline.value = String(Math.min(shown, Math.max(total, 1)))
    timeline.style.setProperty('--fill', `${fill}%`)
    if (elapsedRef.current) elapsedRef.current.style.left = `clamp(2.5rem, ${fill}%, calc(100% - 9rem))`
  }

  function seekTo(seconds: number) {
    const video = videoRef.current
    if (!video) return
    const target = Math.max(0, total > 0 ? Math.min(seconds, total) : seconds)
    showChrome()
    if (target < offsetSeconds - 0.5) {
      // This stream starts after the requested time, so the server negotiates one that starts there.
      void choose({ kind: 'position' }, { atTicks: target * TICKS_PER_SECOND })
      return
    }
    const streamTarget = target - offsetSeconds
    video.currentTime = Number.isFinite(video.duration) ? Math.min(streamTarget, video.duration) : streamTarget
  }

  function skip(delta: number) {
    seekTo(offsetSeconds + (videoRef.current?.currentTime ?? time) + delta)
  }

  function toggleMenu(name: MenuName) {
    setMenu(open => (open === name ? null : name))
    showChrome()
  }

  function closeMenu() {
    setMenu(null)
    showChrome()
  }

  function pick(change: PlaybackChange) {
    closeMenu()
    void choose(change)
  }

  function pickLegacy(index: number) {
    closeMenu()
    setLegacyCaption(index)
  }

  function toggleMute() {
    const video = videoRef.current
    if (!video) return
    video.muted = !video.muted
    showChrome()
  }

  function toggleFullscreen() {
    const root = rootRef.current
    if (!root) return
    if (document.fullscreenElement) void document.exitFullscreen?.().catch(() => undefined)
    else void root.requestFullscreen?.().catch(() => undefined)
    showChrome()
  }

  function onTimelineKey(event: ReactKeyboardEvent<HTMLInputElement>) {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault()
      skip(event.key === 'ArrowLeft' ? -SKIP_SECONDS : SKIP_SECONDS)
    } else if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
      event.preventDefault()
      showChrome()
      moveFocus(event.key === 'ArrowUp' ? 'up' : 'down')
    } else if (event.key === 'Enter') {
      event.preventDefault()
      togglePlay()
    }
  }

  function onPlayerKey(event: ReactKeyboardEvent<HTMLDivElement>) {
    if (menu || event.defaultPrevented) return
    const wasHidden = !visible
    showChrome()
    const target = event.target instanceof HTMLElement ? event.target : null
    const activates = event.key === ' ' && target !== timelineRef.current && target?.closest('button, a[href]')
    if (activates) return
    if (event.key === ' ' || event.key === 'k' || event.key === 'MediaPlayPause') {
      event.preventDefault()
      togglePlay()
    } else if (event.key === 'j' || event.key === 'MediaRewind') {
      skip(-SKIP_SECONDS)
    } else if (event.key === 'l' || event.key === 'MediaFastForward') {
      skip(SKIP_SECONDS)
    } else if (event.key === 'c') {
      toggleMenu('subtitles')
    } else if (event.key === 'm') {
      toggleMute()
    } else if (event.key === 'f') {
      toggleFullscreen()
    } else if (wasHidden && event.key.startsWith('Arrow') && !target?.closest('.player__navigation')) {
      event.preventDefault()
      if (timelineRef.current) focusElement(timelineRef.current)
    }
  }

  const selection = desired ?? selectionOptions(info)
  const isPending = (change: PlaybackChange) => desired !== null && chosen(desired, change) && !chosen(selectionOptions(info), change)
  const legacy = !supportsChoices(info)
  const legacySubtitles = info.subtitles ?? []

  const subtitleSections: MenuSection[] = [
    {
      title: 'Legendas',
      items: legacy
        ? [
            { key: 'off', label: 'Desativadas', checked: legacyCaption < 0, onSelect: () => pickLegacy(-1) },
            ...legacySubtitles.map((track, index) => ({
              key: track.url,
              label: track.label ?? track.language ?? `Legenda ${index + 1}`,
              checked: legacyCaption === index,
              onSelect: () => pickLegacy(index),
            })),
          ]
        : [
            { kind: 'subtitles' as const, index: SUBTITLES_OFF, label: 'Desativadas', detail: undefined as string | undefined },
            ...(info.subtitleTracks ?? []).map(track => ({
              kind: 'subtitles' as const,
              index: track.index,
              label: track.label,
              detail: track.isForced ? 'Forçada' : undefined,
            })),
          ].map(({ label, detail, ...change }) => ({
            key: String(change.index),
            label,
            detail,
            checked: info.selection?.subtitleStreamIndex === change.index,
            pending: isPending(change),
            onSelect: () => pick(change),
          })),
    },
  ]
  const subtitleState = legacy
    ? legacyCaption >= 0
      ? (legacySubtitles[legacyCaption]?.label ?? 'Ativadas')
      : 'Desativadas'
    : selection.subtitleStreamIndex === undefined || selection.subtitleStreamIndex === SUBTITLES_OFF
      ? 'Desativadas'
      : changeLabel(info, { kind: 'subtitles', index: selection.subtitleStreamIndex })
  const noSubtitles = legacy ? legacySubtitles.length === 0 : (info.subtitleTracks ?? []).length === 0

  const audioSections: MenuSection[] = [
    {
      title: 'Áudio',
      empty: legacy ? 'Este servidor não lista as faixas de áudio.' : 'Não há faixas de áudio nesta versão.',
      items: (info.audioTracks ?? []).map(track => {
        const change = { kind: 'audio' as const, index: track.index }
        return {
          key: String(track.index),
          label: track.label,
          checked: info.selection?.audioStreamIndex === track.index,
          pending: isPending(change),
          onSelect: () => pick(change),
        }
      }),
    },
  ]

  const settingsSections: MenuSection[] = [
    {
      title: 'Qualidade',
      empty: info.sample
        ? 'A demonstração reproduz um vídeo de exemplo na resolução original de 480p.'
        : 'Este servidor não oferece opções de qualidade.',
      items: (info.qualityOptions ?? []).map(option => {
        const change = { kind: 'quality' as const, id: option.id }
        return {
          key: option.id,
          label: qualityLabel(option),
          checked: info.selection?.quality === option.id,
          pending: isPending(change),
          onSelect: () => pick(change),
        }
      }),
    },
    {
      title: 'Versão',
      empty: 'Este servidor não lista outras versões.',
      items: (info.mediaSources ?? []).map(source => {
        const change = { kind: 'version' as const, id: source.id }
        return {
          key: source.id,
          label: source.label,
          checked: info.selection?.mediaSourceId === source.id,
          pending: isPending(change),
          onSelect: () => pick(change),
        }
      }),
    },
  ]
  const summary = streamSummary(info)
  const playing = decoded ? [`${decoded.width} × ${decoded.height}`, ...(summary?.split(' · ').filter(part => !part.includes(' × ')) ?? [])].join(' · ') : summary

  const chapters = item.chapters ?? []
  const currentChapter = chapters.reduce((found, chapter, index) => (chapter.startTimeTicks / TICKS_PER_SECOND <= position + 0.5 ? index : found), -1)
  const chapterSections: MenuSection[] = [
    {
      title: 'Capítulos',
      items: chapters.map((chapter, index) => ({
        key: `${index}:${chapter.startTimeTicks}`,
        label: chapter.name || `Capítulo ${index + 1}`,
        detail: formatPlayerClock(chapter.startTimeTicks / TICKS_PER_SECOND),
        checked: index === currentChapter,
        onSelect: () => {
          closeMenu()
          seekTo(chapter.startTimeTicks / TICKS_PER_SECOND)
        },
      })),
    },
  ]

  const shown = scrub ?? position
  const fill = total > 0 ? Math.min(100, (shown / total) * 100) : 0
  const eyebrow = item.type === 'Episode' ? [episodeCode(item), item.name].filter(Boolean).join(' · ') : [item.year, ...(item.genres?.slice(0, 2) ?? [])].filter(Boolean).join(' · ')
  const status = pending ? `Mudando para ${changeLabel(info, pending)}…` : undefined

  return (
    <div
      ref={rootRef}
      className={`player${visible ? ' player--chrome' : ''}`}
      data-focus-scope
      onKeyDown={onPlayerKey}
      onPointerMove={showChrome}
      role="region"
      aria-label={`Reprodução: ${itemTitle(item)}`}
    >
      <video
        ref={videoRef}
        className="player__video"
        playsInline
        onClick={() => (menu ? closeMenu() : togglePlay())}
        onLoadedMetadata={event => {
          const video = event.currentTarget
          setDuration(video.duration)
          const target = live.current.timing.initialSeekSeconds
          if (target > 0 && Math.abs(video.currentTime - target) > 0.5) video.currentTime = target
          positioned.current = true
          capture(video)
        }}
        onLoadedData={event => {
          const { videoWidth, videoHeight } = event.currentTarget
          if (videoWidth && videoHeight) setDecoded({ width: videoWidth, height: videoHeight })
        }}
        onResize={event => {
          const { videoWidth, videoHeight } = event.currentTarget
          if (videoWidth && videoHeight) setDecoded({ width: videoWidth, height: videoHeight })
        }}
        onDurationChange={event => setDuration(event.currentTarget.duration)}
        onTimeUpdate={event => {
          if (!positioned.current) return
          const video = event.currentTarget
          // Clocks display whole seconds. Keep reports exact, but skip the full player render
          // for the several media ticks that arrive within the same displayed second.
          capture(video)
          refreshTimeline(video.currentTime)
          setTime(previous => Math.floor(previous) === Math.floor(video.currentTime) ? previous : video.currentTime)
        }}
        onPlaying={event => {
          positioned.current = true
          capture(event.currentTarget)
          setPaused(false)
          setBuffering(false)
          showChrome()
          if (!started.current) {
            started.current = true
            send('start', live.current.info)
          }
        }}
        onPause={event => {
          capture(event.currentTarget)
          setPaused(true)
          setChrome(true)
          if (started.current) send('progress', live.current.info)
        }}
        onWaiting={() => setBuffering(true)}
        onCanPlay={() => setBuffering(false)}
        onSeeked={event => {
          positioned.current = true
          setTime(event.currentTarget.currentTime)
          capture(event.currentTarget)
          if (started.current) send('progress', live.current.info)
        }}
        onVolumeChange={event => setMuted(event.currentTarget.muted)}
        onEnded={event => {
          capture(event.currentTarget)
          goBack()
        }}
        onError={event => setFailure(mediaErrorMessage(event.currentTarget.error))}
      >
        {subtitle ? (
          <track
            key={subtitle.url}
            ref={trackRef}
            kind="subtitles"
            default
            src={subtitle.url}
            label={subtitle.label ?? subtitle.language ?? 'Legendas'}
            srcLang={subtitle.language && subtitle.language !== 'und' ? subtitle.language : undefined}
          />
        ) : null}
      </video>

      <div className="player__shade" aria-hidden="true" />

      {!failure ? (
        <nav className="player__navigation" aria-label="Navegação do player" data-no-scroll>
          <button type="button" className="glass-circle" aria-label="Voltar" onClick={goBack}>
            <BackIcon />
          </button>
          <Link to="/" className="glass-pill player__home" aria-label="Início">
            <HomeIcon />
            Início
          </Link>
        </nav>
      ) : null}

      {buffering && !failure ? (
        <div className="player__spinner" role="status">
          <span className="visually-hidden">Carregando vídeo</span>
        </div>
      ) : null}

      {status || notice ? (
        <p className={`player__notice${notice ? ' player__notice--error' : ''}`} role={notice ? 'alert' : 'status'}>
          {notice ?? status}
        </p>
      ) : null}

      {failure ? (
        <div className="player__failure" role="alert">
          <h2 className="state__title">Não foi possível reproduzir {item.name}</h2>
          <p className="state__detail">{failure}</p>
          <div className="state__actions">
            <button type="button" className="btn btn--primary" onClick={() => void choose({ kind: 'position' }, { play: true })} autoFocus>
              Tentar novamente
            </button>
            <button type="button" className="btn" onClick={() => goBack()}>
              Voltar
            </button>
          </div>
        </div>
      ) : (
        <div className="player__chrome">
          <div className="player__head">
            <div className="player__titles">
              {info.sample ? (
                <p className="player__sample">
                  Vídeo de exemplo · Todos os títulos da demonstração reproduzem “{info.sample.title}” ({info.sample.credit})
                </p>
              ) : null}
              {eyebrow ? <p className="player__eyebrow">{eyebrow}</p> : null}
              <h1 className="player__title">{displayTitle(item)}</h1>
            </div>
            <div className="player__options" role="toolbar" aria-label="Opções de reprodução">
              <OptionButton
                label={`Legendas: ${subtitleState}`}
                name="subtitles"
                open={menu === 'subtitles'}
                onToggle={toggleMenu}
                buttonRef={subtitlesButton}
                menu={
                  <PlayerMenu
                    label="Legendas"
                    sections={subtitleSections}
                    footer={noSubtitles ? 'Não há legendas nesta versão.' : undefined}
                    trigger={subtitlesButton}
                    onClose={closeMenu}
                  />
                }
              >
                <SubtitlesIcon />
              </OptionButton>
              <OptionButton
                label="Áudio"
                name="audio"
                open={menu === 'audio'}
                onToggle={toggleMenu}
                buttonRef={audioButton}
                menu={<PlayerMenu label="Áudio" sections={audioSections} trigger={audioButton} onClose={closeMenu} />}
              >
                <AudioIcon />
              </OptionButton>
              <OptionButton
                label="Qualidade e versão"
                name="settings"
                open={menu === 'settings'}
                onToggle={toggleMenu}
                buttonRef={settingsButton}
                menu={
                  <PlayerMenu
                    label="Qualidade e versão"
                    sections={settingsSections}
                    footer={playing ? `Reproduzindo agora · ${playing}` : undefined}
                    trigger={settingsButton}
                    onClose={closeMenu}
                  />
                }
              >
                <GearIcon />
              </OptionButton>
              <span className="player__option">
                <button type="button" className="glass-circle" aria-label={muted ? 'Ativar som' : 'Silenciar'} aria-pressed={muted} onClick={toggleMute}>
                  {muted ? <SpeakerMutedIcon /> : <SpeakerIcon />}
                </button>
              </span>
              {document.fullscreenEnabled ? (
                <span className="player__option">
                  <button
                    type="button"
                    className="glass-circle"
                    aria-label={fullscreen ? 'Sair da tela cheia' : 'Tela cheia'}
                    onClick={toggleFullscreen}
                  >
                    {fullscreen ? <ExitFullscreenIcon /> : <FullscreenIcon />}
                  </button>
                </span>
              ) : null}
            </div>
          </div>

          <div className="timeline">
            <input
              ref={timelineRef}
              type="range"
              className="timeline__input"
              min={0}
              max={Math.max(total, 1)}
              step="any"
              value={Math.min(shown, Math.max(total, 1))}
              onPointerDown={() => setScrub(position)}
              onPointerCancel={() => setScrub(null)}
              onChange={event => {
                const value = Number(event.target.value)
                if (scrub !== null) setScrub(value)
                else seekTo(value)
              }}
              onPointerUp={event => {
                if (scrub === null) return
                const value = Number(event.currentTarget.value)
                setScrub(null)
                seekTo(value)
              }}
              onKeyDown={onTimelineKey}
              aria-label="Posição da reprodução"
              aria-valuetext={`${formatPlayerClock(shown)} de ${formatPlayerClock(total)}`}
              style={{ '--fill': `${fill}%` } as CSSProperties}
              data-focus-key="player:timeline"
            />
            <div className="timeline__times" aria-hidden="true">
              <span ref={elapsedRef} className="timeline__elapsed" style={{ left: `clamp(2.5rem, ${fill}%, calc(100% - 9rem))` }}>
                {formatPlayerClock(shown)}
                <span className="timeline__state">{paused ? <PauseIcon /> : <PlayIcon />}</span>
              </span>
              <span className="timeline__remaining">−{formatPlayerClock(Math.max(0, total - shown))}</span>
            </div>
          </div>

          <div className="player__actions">
            <div className="player__transport">
              <button type="button" className="glass-circle" onClick={() => skip(-SKIP_SECONDS)} aria-label={`Voltar ${SKIP_SECONDS} segundos`}>
                <SkipBackIcon />
              </button>
              <button type="button" className="glass-circle" onClick={togglePlay} aria-label={paused ? 'Reproduzir' : 'Pausar'}>
                {paused ? <PlayIcon /> : <PauseIcon />}
              </button>
              <button type="button" className="glass-circle" onClick={() => skip(SKIP_SECONDS)} aria-label={`Avançar ${SKIP_SECONDS} segundos`}>
                <SkipForwardIcon />
              </button>
            </div>
            {chapters.length ? (
              <span className="player__option player__option--start">
                <button
                  ref={chaptersButton}
                  type="button"
                  className="glass-pill"
                  aria-haspopup="menu"
                  aria-expanded={menu === 'chapters'}
                  onClick={() => toggleMenu('chapters')}
                >
                  <ListIcon />
                  Capítulos
                </button>
                {menu === 'chapters' ? (
                  <PlayerMenu label="Capítulos" sections={chapterSections} trigger={chaptersButton} onClose={closeMenu} />
                ) : null}
              </span>
            ) : null}
            {next ? (
              <button
                type="button"
                className="glass-pill"
                onClick={() => navigate(playPath(next), { replace: true })}
                aria-label={`Próximo episódio: ${[episodeCode(next), next.name].filter(Boolean).join(' ')}`}
              >
                <NextIcon />
                Próximo episódio
              </button>
            ) : null}
          </div>
        </div>
      )}
    </div>
  )
}

interface Negotiated {
  attempt: number
  item?: Item
  info?: PlaybackInfo
  error?: Error
}

export function PlayerScreen({ id }: { id: string }) {
  const route = useRoute()
  const { library } = useSession()
  const startTicks = Number(route.params.get('t') ?? 0) || 0
  const [attempt, setAttempt] = useState(0)
  const [negotiated, setNegotiated] = useState<Negotiated>({ attempt: -1 })

  // A session is negotiated here, never through the shared resource cache: cache invalidation must not start playback again.
  useEffect(() => {
    const controller = new AbortController()
    const negotiation = library.playback(id, startTicks || undefined)
    Promise.all([library.item(id, controller.signal), negotiation]).then(
      ([item, info]) => {
        if (controller.signal.aborted) stopUnused(library, info)
        else setNegotiated({ attempt, item, info })
      },
      (error: unknown) => {
        negotiation.then(info => stopUnused(library, info), () => undefined)
        if (!controller.signal.aborted) setNegotiated({ attempt, error: error instanceof Error ? error : new Error(String(error)) })
      },
    )
    return () => controller.abort()
  }, [library, id, startTicks, attempt])

  const alive = useRef(true)
  useEffect(() => {
    alive.current = true
    return () => {
      alive.current = false
      // Watch progress changed; library screens refetch once the viewer actually leaves (not on a StrictMode remount).
      queueMicrotask(() => {
        if (!alive.current) invalidateResources()
      })
    }
  }, [])

  const retry = useCallback(() => setAttempt(value => value + 1), [])
  const playback = negotiated.attempt === attempt ? negotiated : { attempt }

  if (playback.item && playback.info) {
    return <Player key={`${attempt}:${playback.info.playSessionId}`} item={playback.item} initial={playback.info} />
  }
  if (playback.error) {
    const { title, detail } = errorCopy(playback.error)
    return (
      <div className="player player--chrome" data-focus-scope>
        <div className="player__failure" role="alert">
          <h2 className="state__title">{title}</h2>
          <p className="state__detail">{detail}</p>
          <div className="state__actions">
            <button type="button" className="btn btn--primary" onClick={retry} autoFocus>
              Tentar novamente
            </button>
            <button type="button" className="btn" onClick={() => goBack()}>
              Voltar
            </button>
          </div>
        </div>
      </div>
    )
  }
  return (
    <div className="player player--chrome" data-focus-scope>
      <div className="player__spinner" role="status">
        <span className="visually-hidden">Preparando reprodução</span>
      </div>
      <div className="player__loading-actions">
        <button type="button" className="glass-pill" onClick={() => goBack()} autoFocus>
          Cancelar
        </button>
      </div>
    </div>
  )
}
