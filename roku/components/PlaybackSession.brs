' Player session changes are negotiated while the old stream is paused. A
' successful response retires it exactly once before attaching a new Video node.
sub OnPlayerAction()
    action = m.playerControls.action
    if not IsMap(action) then return
    if action.kind = "exit"
        StopPlayback()
        return
    end if
    if m.busy then return
    if action.kind = "scrubStart"
        m.seekPausePending = false
        m.seekResumePending = false
        if m.video.state = "playing" then m.video.control = "pause"
    else if action.kind = "scrubCancel"
        if action.resume = true and m.video.state = "paused" then m.video.control = "resume"
    else if action.kind = "toggle"
        m.seekPausePending = false
        m.seekResumePending = false
        if m.video.state = "paused"
            m.video.control = "resume"
        else if m.video.state = "playing"
            m.video.control = "pause"
        end if
    else if action.kind = "seekTo"
        ' Always absolute: the controls know a seek still landing, the decoder
        ' does not.
        position = action.seconds
        if position < 0 then position = 0
        if m.video.duration > 0 and position > m.video.duration then position = m.video.duration
        m.video.autoplayAfterSeek = m.video.state <> "paused"
        if action.resumeAfterSeek <> invalid then m.video.autoplayAfterSeek = action.resumeAfterSeek
        m.seekPausePending = not m.video.autoplayAfterSeek
        m.seekResumePending = m.video.autoplayAfterSeek
        m.video.seek = position
    else if action.kind = "nextEpisode"
        if m.playSession <> invalid and IsMap(m.nextEpisode) then PlayNextEpisode()
    else if action.kind = "selection"
        if m.playSession = invalid or not IsMap(m.playbackOptions) then return
        m.trackChoice = invalid
        if action.field = "audioStreamIndex" or action.field = "subtitleStreamIndex" then m.trackChoice = {field: action.field, value: action.value}
        if action.field = "subtitleStreamIndex"
            if ApplyNativeSubtitleSelection(action.value)
                RememberTrackChoice()
                return
            end if
        end if
        request = PlaybackRequest(m.playbackOptions.selection)
        m.recoveryRequest = PlaybackRequest(m.playbackOptions.selection)
        request[action.field] = action.value
        if action.field = "mediaSourceId"
            request.Delete("audioStreamIndex")
            request.Delete("subtitleStreamIndex")
        end if
        m.switchingPlayback = true
        m.resumePaused = m.video.state = "paused"
        request.paused = m.resumePaused
        m.recoveryRequest.paused = m.resumePaused
        m.seekResumePending = false
        m.video.control = "pause"
        m.playerControls.message = "Aplicando opções de reprodução…"
        m.playerControls.busy = true
        Send("play", request)
        m.playRequestId = m.requestId
    end if
end sub

' Side-loaded SRT tracks belong to the current ContentNode. Selecting one only
' changes Roku's caption renderer; the video decoder and Jellyfin session stay put.
function ApplyNativeSubtitleSelection(index as Dynamic) as Boolean
    options = m.playbackOptions
    if not IsMap(options.selection) then return false
    if options.subtitleDelivery <> "off" and options.subtitleDelivery <> "external" then return false
    if options.selection.mediaSourceId <> m.playSession.MediaSourceId then return false
    if not IsList(options.nativeSubtitleTracks) then return false
    if options.nativeSubtitleTracks.Count() = 0 then return false
    if m.video.content = invalid then return false
    if index = -1
        ' This is an explicit user choice. Roku's caption mode is device-global.
        m.video.globalCaptionMode = "Off"
        m.video.suppressCaptions = true
        options.subtitleDelivery = "off"
    else
        trackName = NativeSubtitleTrackName(options, index, m.video.content)
        if trackName = "" then return false
        m.video.suppressCaptions = false
        m.video.subtitleTrack = trackName
        m.video.globalCaptionMode = "On"
        options.subtitleDelivery = "external"
    end if
    options.selection.subtitleStreamIndex = index
    m.playSession.SubtitleStreamIndex = index
    m.playerControls.options = options
    return true
end function

function NativeSubtitleTrackName(options as Object, index as Dynamic, content as Object) as String
    if not IsList(options.nativeSubtitleTracks) then return ""
    if not IsList(content.SubtitleTracks) then return ""
    for each track in options.nativeSubtitleTracks
        if track.index = index and TextValue(track.trackName) <> ""
            for each registered in content.SubtitleTracks
                if registered.TrackName = track.trackName then return track.trackName
            end for
        end if
    end for
    return ""
end function

function CurrentPlaybackTicks() as Double
    if m.started = true
        if m.video.state = "playing" or m.video.state = "paused" then return CDbl(m.video.position) * 10000000#
    end if
    return m.lastPosition
end function

function PlaybackRequest(selection as Object) as Object
    request = {itemId: m.playSession.ItemId, title: PlaybackItem().Name, ticks: CurrentPlaybackTicks(), seriesId: TextValue(PlaybackItem().SeriesId)}
    for each key in selection
        if selection[key] <> invalid then request[key] = selection[key]
    end for
    return request
end function

' The credits keep playing until the next episode is ready: the same handoff as
' a track switch reports this episode stopped once and restores it on failure.
sub PlayNextEpisode()
    nextItem = m.nextEpisode
    selection = {}
    if IsMap(m.playbackOptions)
        if IsMap(m.playbackOptions.selection) then selection = m.playbackOptions.selection
    end if
    m.recoveryRequest = PlaybackRequest(selection)
    m.recoveryRequest.paused = m.video.state = "paused"
    m.pendingPlayItem = nextItem
    m.trackChoice = invalid
    m.switchingPlayback = true
    m.resumePaused = m.video.state = "paused"
    m.seekResumePending = false
    m.video.control = "pause"
    m.playerControls.message = "Abrindo o próximo episódio…"
    m.playerControls.busy = true
    Send("play", {itemId: nextItem.Id, title: nextItem.Name, ticks: ResumeTicks(nextItem), seriesId: TextValue(nextItem.SeriesId), quality: TextValue(selection.quality, "auto"), paused: false})
end sub

' Saved only once the choice is actually playing, so a failed switch is not
' carried into the next episode.
sub RememberTrackChoice()
    choice = m.trackChoice
    m.trackChoice = invalid
    if not IsMap(choice) or not IsMap(m.playbackOptions) then return
    item = PlaybackItem()
    if not IsMap(item) then return
    seriesId = TextValue(item.SeriesId)
    if seriesId = "" then return
    kind = "audio"
    tracks = m.playbackOptions.audioTracks
    if choice.field = "subtitleStreamIndex"
        kind = "subtitle"
        tracks = m.playbackOptions.subtitleTracks
    end if
    track = invalid
    if kind = "subtitle" and choice.value = -1 then track = {off: true}
    if IsList(tracks)
        for each candidate in tracks
            if candidate.index = choice.value then track = {language: candidate.language, title: candidate.title, label: candidate.label, codec: candidate.codec, forced: candidate.isForced, external: candidate.isExternal}
        end for
    end if
    if track <> invalid then Send("rememberTracks", {seriesId: seriesId, kind: kind, track: track})
end sub

sub AcceptPlayback(result as Object)
    if m.playRequestId <> invalid
        if result.requestId <> m.playRequestId then return
    end if
    if m.playSession <> invalid then SendReport("stopped")
    m.playSession = invalid
    m.reportTimer.control = "stop"
    m.pendingPlaybackResult = result
    m.pendingPlaybackRequest = m.lastRequest
    m.busy = true
    m.playerControls.busy = true
    ' OS 12.5+: release the decoder before creating/playing its replacement.
    ' Keep observing the old node until its stopped acknowledgement arrives.
    state = m.video.state
    if state = "playing" or state = "paused" or state = "buffering" or state = "stopping"
        m.video.asyncStopSemantics = true
        if state <> "stopping" then m.video.control = "stop"
        return
    end if
    CompletePlaybackReplacement()
end sub

sub CompletePlaybackReplacement()
    result = m.pendingPlaybackResult
    if result = invalid then return
    m.pendingPlaybackResult = invalid
    if result.requestId <> m.playRequestId then return
    request = m.pendingPlaybackRequest
    m.pendingPlaybackRequest = invalid
    if m.pendingPlayItem <> invalid
        m.playItem = m.pendingPlayItem
        m.pendingPlayItem = invalid
    end if
    m.busy = false
    ' A separate node also isolates callbacks from the now-retired node.
    ReplaceVideoNode(result)
    m.playSession = result.session
    m.playOffset = result.offsetTicks
    m.transcoded = result.transcoded
    m.lastPosition = result.offsetTicks
    m.started = false
    m.resumeTargetSeconds = result.offsetTicks / 10000000#
    m.resumeSeekIssued = false
    if m.resumeTimer <> invalid then m.resumeTimer.control = "stop"
    m.pendingOptions = result.options
    if IsMap(m.pendingOptions)
        m.pendingOptions.chapters = PlaybackChapters(PlaybackItem())
    end if
    m.pendingPlayRequest = request
    m.resumePaused = request.paused = true
    m.switchingPlayback = false
    m.video.content = result.content
    if IsMap(result.options)
        if IsMap(result.options.selection)
            nativeIndex = result.options.selection.subtitleStreamIndex
            if result.options.subtitleDelivery = "external"
                trackName = NativeSubtitleTrackName(result.options, nativeIndex, result.content)
                if trackName <> ""
                    m.video.suppressCaptions = false
                    m.video.subtitleTrack = trackName
                    m.video.globalCaptionMode = "On"
                end if
            end if
        end if
    end if
    if m.resumeCover <> invalid then m.resumeCover.visible = m.resumeTargetSeconds > 0
    m.video.visible = m.resumeTargetSeconds <= 0
    m.video.mute = m.resumeTargetSeconds > 0
    m.playerControls.visible = true
    m.playerControls.title = result.content.title
    m.playerControls.subtitle = ""
    item = PlaybackItem()
    if item.Type = "Episode"
        m.playerControls.title = TextValue(item.SeriesName, result.content.title)
        m.playerControls.subtitle = "T" + TextValue(item.ParentIndexNumber) + ", E" + TextValue(item.IndexNumber) + " · " + result.content.title
    end if
    m.playerControls.position = result.offsetTicks / 10000000#
    m.playerControls.message = ""
    m.playerControls.busy = true
    m.playerControls.SetFocus(true)
    m.video.control = "play"
end sub

' A new decoder saying "playing" does not prove that its bookmark landed.
' Keep the requested position authoritative until the decoder acknowledges it.
function BeginPlaybackWhenReady() as Boolean
    if m.video.state <> "playing" and m.video.state <> "paused" then return false
    if m.resumeTargetSeconds <> invalid
        if m.resumeTargetSeconds > 0 and Abs(m.video.position - m.resumeTargetSeconds) > 3
            if m.resumeSeekIssued <> true
                m.resumeSeekIssued = true
                m.video.autoplayAfterSeek = m.resumePaused <> true
                m.seekPausePending = m.resumePaused = true
                m.video.seek = m.resumeTargetSeconds
                if m.resumeTimer <> invalid then m.resumeTimer.control = "start"
            end if
            m.playerControls.message = "Retomando de onde parou…"
            return false
        end if
    end if
    m.resumeTargetSeconds = invalid
    if m.resumeTimer <> invalid then m.resumeTimer.control = "stop"
    m.video.mute = false
    if m.resumeCover <> invalid then m.resumeCover.visible = false
    m.video.visible = true
    m.started = true
    if m.playerControls <> invalid then PlaybackStarted()
    SendReport("started")
    m.reportTimer.control = "start"
    return true
end function

sub OnPlaybackResumeTimeout()
    if m.started or m.resumeTargetSeconds = invalid or m.playSession = invalid then return
    StopPlayback(true)
    if IsMap(m.recoveryRequest)
        ShowMessage("Não foi possível retomar nesta opção", "Seu ponto foi preservado. Restaure as opções anteriores para continuar.", ["Restaurar opções anteriores", "Tentar modo compatível", "Fechar"], "switchPlaybackError")
    else
        ShowMessage("Não foi possível retomar o vídeo", "Seu ponto foi preservado. Tente o modo compatível para continuar.", ["Tentar modo compatível", "Reconectar", "Fechar"], "playbackError")
    end if
end sub

sub PlaybackStarted()
    if m.pendingOptions <> invalid
        m.playbackOptions = m.pendingOptions
        m.playerControls.options = m.playbackOptions
        m.pendingOptions = invalid
    end if
    if m.trackChoice <> invalid then RememberTrackChoice()
    ' Stream switches keep the item's segments; only a new item asks again.
    if m.playSession <> invalid
        itemId = TextValue(m.playSession.ItemId)
        if itemId <> "" and itemId <> TextValue(m.segmentsItemId)
            m.segmentsItemId = itemId
            m.playerControls.segments = []
            m.nextEpisode = invalid
            m.playerControls.hasNextEpisode = false
            m.playerControls.trickplay = {}
            Send("segments", {itemId: itemId, seriesId: TextValue(PlaybackItem().SeriesId), mediaSourceId: TextValue(m.playSession.MediaSourceId)})
        end if
    end if
    m.playerControls.busy = false
    m.playerControls.message = ""
    m.playerControls.duration = m.video.duration
    if m.resumePaused = true
        m.resumePaused = false
        m.video.control = "pause"
    end if
end sub

sub SyncPlayerState()
    ' Some HLS firmware paths enter playing even with autoplayAfterSeek=false.
    ' Acknowledge that transition once while retaining explicit paused intent.
    if m.seekPausePending = true and m.video.state = "playing"
        m.seekPausePending = false
        m.video.control = "pause"
    end if
    ' The reverse: a seek meant to keep playing can settle paused, e.g. a tap
    ' right after a held scrub paused the video. Resume it once.
    if m.seekResumePending = true
        if m.video.state = "playing" then m.seekResumePending = false
        if m.video.state = "paused"
            m.seekResumePending = false
            m.video.control = "resume"
        end if
    end if
    if m.playerControls = invalid then return
    m.playerControls.playbackState = m.video.state
    if m.video.state = "playing" or m.video.state = "paused" then m.playerControls.message = ""
end sub

sub SyncPlayerPosition()
    if m.playerControls = invalid then return
    m.playerControls.position = m.lastPosition / 10000000#
    m.playerControls.duration = m.video.duration
end sub

sub ReplaceVideoNode(result as Object)
    m.seekPausePending = false
    m.seekResumePending = false
    oldVideo = m.video
    oldVideo.UnobserveField("state")
    oldVideo.UnobserveField("position")
    m.playbackSurface.RemoveChild(oldVideo)
    m.video = CreateObject("roSGNode", "Video")
    m.video.id = "video-" + result.requestId.ToStr()
    m.video.width = 1920
    m.video.height = 1080
    m.video.asyncStopSemantics = true
    m.video.enableUI = false
    ' Default Off and encoded captions must not expose a stray in-stream track.
    ' External SRT is enabled only after its registered track is selected.
    m.video.suppressCaptions = true
    m.video.notificationInterval = 1
    m.video.ObserveField("state", "OnVideoState")
    m.video.ObserveField("position", "OnVideoPosition")
    m.playbackSurface.InsertChild(m.video, 0)
end sub

function PlaybackChapters(item as Object) as Object
    chapters = []
    if not IsList(item.Chapters) then return chapters
    for each chapter in item.Chapters
        if chapter.StartPositionTicks <> invalid
            chapters.Push({label: TextValue(chapter.Name, "Capítulo " + (chapters.Count() + 1).ToStr()), seconds: chapter.StartPositionTicks / 10000000#})
        end if
    end for
    return chapters
end function
