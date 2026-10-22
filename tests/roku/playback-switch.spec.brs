sub Main()
    m.assertions = 0
    ResetSwitch()
    m.video.state = "playing"
    m.playerControls.action = {kind: "scrubStart"}
    OnPlayerAction()
    AssertEqual(m.video.control, "pause", "scrub starts by pausing existing decoder")
    AssertEqual(m.video.seek, invalid, "scrub start does not flush decoder")
    m.video.state = "paused"
    m.playerControls.action = {kind: "seekTo", seconds: 8100, resumeAfterSeek: true}
    OnPlayerAction()
    AssertEqual(m.video.seek, 8100, "scrub release applies absolute target")
    AssertEqual(m.video.autoplayAfterSeek, true, "release resumes originally playing video")
    m.playerControls.action = {kind: "seekTo", seconds: 8000, resumeAfterSeek: false}
    OnPlayerAction()
    AssertEqual(m.video.autoplayAfterSeek, false, "release preserves originally paused video")
    m.video.state = "playing"
    m.video.control = "none"
    SyncPlayerState()
    AssertEqual(m.video.control, "pause", "firmware autoplay after paused seek is corrected on state acknowledgement")
    m.video.state = "paused"
    m.playerControls.action = {kind: "scrubCancel", resume: true}
    OnPlayerAction()
    AssertEqual(m.video.control, "resume", "cancel restores playing without changing position")
    AssertEqual(m.video.seek, 8000, "cancel does not add another seek")
    ResetSwitch()
    m.playbackOptions = {selection: {audioStreamIndex: 2, subtitleStreamIndex: -1, mediaSourceId: "version-a", quality: "auto"}, subtitleDelivery: "off", nativeSubtitleTracks: [{index: 0, trackName: "https://server/subtitle-0.srt", language: "por", label: "Português"}]}
    m.playerControls.action = {kind: "selection", field: "subtitleStreamIndex", value: 0}
    m.video.content = {SubtitleTracks: [{TrackName: "https://server/subtitle-0.srt"}]}
    m.video.state = "playing"
    oldRequestId = m.requestId
    OnPlayerAction()
    AssertEqual(m.requestId, oldRequestId, "external SRT switch does not renegotiate playback")
    AssertEqual(m.video.control, invalid, "external SRT switch does not pause decoder")
    AssertEqual(m.video.content.SubtitleTracks.Count(), 1, "external switch retains Video content")
    AssertEqual(m.video.subtitleTrack, "https://server/subtitle-0.srt", "external SRT selects registered Roku track")
    AssertEqual(m.video.globalCaptionMode, "On", "external SRT enables Roku captions")
    AssertEqual(m.playbackOptions.selection.subtitleStreamIndex, 0, "in-place selection commits UI choice")
    AssertEqual(m.playSession.SubtitleStreamIndex, 0, "progress report reflects selected SRT")
    AssertEqual(m.playbackOptions.subtitleDelivery, "external", "in-place selection reports external delivery")
    m.playerControls.action.value = -1
    OnPlayerAction()
    AssertEqual(m.requestId, oldRequestId, "Off does not renegotiate external SRT")
    AssertEqual(m.video.globalCaptionMode, "Off", "Off hides native captions")
    AssertEqual(m.playbackOptions.selection.subtitleStreamIndex, -1, "Off commits UI choice")
    AssertEqual(m.playSession.SubtitleStreamIndex, -1, "Off updates session report")
    AssertEqual(m.video.state, "playing", "native toggle keeps playback state")
    AssertEqual(m.video.position, 7200, "native toggle keeps position")

    ResetSwitch()
    m.playbackOptions = {selection: {audioStreamIndex: 2, subtitleStreamIndex: 0, mediaSourceId: "version-a", quality: "auto"}, subtitleDelivery: "external", nativeSubtitleTracks: [{index: 0, trackName: "https://server/subtitle-0.srt"}]}
    m.playerControls.action = {kind: "selection", field: "subtitleStreamIndex", value: -1}
    m.video.content = {SubtitleTracks: [{TrackName: "https://server/subtitle-0.srt"}]}
    oldRequestId = m.requestId
    OnPlayerAction()
    AssertEqual(m.requestId, oldRequestId, "external to Off keeps decoder and session")
    AssertEqual(m.video.control, invalid, "external to Off does not pause")
    AssertEqual(m.video.globalCaptionMode, "Off", "external to Off uses Roku caption mode")

    ResetSwitch()
    m.playbackOptions = {selection: {audioStreamIndex: 2, subtitleStreamIndex: -1, mediaSourceId: "version-a", quality: "auto"}, subtitleDelivery: "off", nativeSubtitleTracks: [{index: 0, trackName: "https://server/subtitle-0.srt"}]}
    m.playerControls.action = {kind: "selection", field: "subtitleStreamIndex", value: 0}
    m.video.content = {SubtitleTracks: [{TrackName: "https://other/subtitle-0.srt"}]}
    OnPlayerAction()
    AssertEqual(m.service.request.subtitleStreamIndex, 0, "unregistered URL cannot be installed in place")

    ResetSwitch()
    m.playbackOptions = {selection: {audioStreamIndex: 2, subtitleStreamIndex: -1, mediaSourceId: "version-b", quality: "auto"}, subtitleDelivery: "off", nativeSubtitleTracks: [{index: 0, trackName: "https://server/subtitle-0.srt"}]}
    m.playerControls.action = {kind: "selection", field: "subtitleStreamIndex", value: 0}
    m.video.content = {SubtitleTracks: [{TrackName: "https://server/subtitle-0.srt"}]}
    OnPlayerAction()
    AssertEqual(m.service.request.subtitleStreamIndex, 0, "other version cannot reuse current source's SRT")

    ResetSwitch()
    m.playbackOptions = {selection: {audioStreamIndex: 2, subtitleStreamIndex: 6, mediaSourceId: "version-a", quality: "auto"}, subtitleDelivery: "encoded", nativeSubtitleTracks: [{index: 0, trackName: "https://server/subtitle-0.srt"}]}
    m.playerControls.action = {kind: "selection", field: "subtitleStreamIndex", value: 0}
    m.video.content = {SubtitleTracks: [{TrackName: "https://server/subtitle-0.srt"}]}
    OnPlayerAction()
    AssertEqual(m.service.request.subtitleStreamIndex, 0, "PGS burn-in to SRT still replaces decoder")

    ResetSwitch()
    m.playRequestId = 1
    m.pendingPlaybackRequest = {paused: false}
    m.pendingPlaybackResult = {requestId: 1, session: {ItemId: "item", MediaSourceId: "version-a", PlaySessionId: "external-session", SubtitleStreamIndex: 0}, content: {title: "Film", SubtitleTracks: [{TrackName: "https://server/subtitle-0.srt"}]}, offsetTicks: 72000000000#, transcoded: false, options: {selection: {mediaSourceId: "version-a", subtitleStreamIndex: 0}, subtitleDelivery: "external", nativeSubtitleTracks: [{index: 0, trackName: "https://server/subtitle-0.srt"}]}}
    CompletePlaybackReplacement()
    AssertEqual(m.video.suppressCaptions, false, "new external stream exposes native captions")
    AssertEqual(m.video.subtitleTrack, "https://server/subtitle-0.srt", "new external stream selects SRT before play")
    AssertEqual(m.video.globalCaptionMode, "On", "new external stream enables Roku captions")
    AssertEqual(m.video.control, "play", "native caption setup does not delay playback")

    ResetSwitch()
    m.playRequestId = 1
    m.pendingPlaybackRequest = {paused: false}
    m.pendingPlaybackResult = {requestId: 1, session: {ItemId: "item", MediaSourceId: "version-a", PlaySessionId: "off-session", SubtitleStreamIndex: -1}, content: {title: "Film", SubtitleTracks: [{TrackName: "https://server/subtitle-0.srt"}]}, offsetTicks: 72000000000#, transcoded: false, options: {selection: {mediaSourceId: "version-a", subtitleStreamIndex: -1}, subtitleDelivery: "off", nativeSubtitleTracks: [{index: 0, trackName: "https://server/subtitle-0.srt"}]}}
    CompletePlaybackReplacement()
    AssertEqual(m.video.suppressCaptions, true, "opening Off hides captions even with tracks present")
    AssertEqual(m.video.globalCaptionMode, invalid, "opening Off leaves device caption preference alone")

    ResetSwitch()
    m.playbackOptions = {selection: {audioStreamIndex: 2, subtitleStreamIndex: -1, mediaSourceId: "version-a", quality: "auto"}, subtitleDelivery: "off", nativeSubtitleTracks: [{index: 0, trackName: "https://server/subtitle-0.srt"}]}
    m.playerControls.action = {kind: "selection", field: "subtitleStreamIndex", value: 7}
    m.video.content = {SubtitleTracks: [{TrackName: "https://server/subtitle-0.srt"}]}
    OnPlayerAction()
    AssertEqual(m.service.request.subtitleStreamIndex, 7, "unregistered subtitle uses validated negotiation")
    AssertEqual(m.playbackOptions.selection.subtitleStreamIndex, -1, "pending fallback does not change selection")

    ResetSwitch()
    OnPlayerAction()
    AssertEqual(m.service.request.audioStreamIndex, 3, "audio choice reaches playback service")
    AssertEqual(m.service.request.subtitleStreamIndex, 6, "audio switch preserves subtitle choice")
    AssertEqual(m.service.request.quality, "720p", "audio switch preserves quality ceiling")
    AssertEqual(m.service.request.mediaSourceId, "version-a", "audio switch preserves version")
    AssertEqual(m.service.request.ticks, 72000000000#, "selection samples absolute current position")
    AssertEqual(m.service.request.paused, true, "paused intent travels with replacement")
    AssertEqual(m.recoveryRequest.audioStreamIndex, 2, "last good selection remains recoverable")
    AssertEqual(m.playbackOptions.selection.audioStreamIndex, 2, "pending selection does not change checkmark")
    AssertEqual(m.playSession.PlaySessionId, "old-session", "negotiation failure can retain current session")
    AssertEqual(m.video.control, "pause", "old stream is paused during negotiation")
    oldRequestId = m.requestId
    OnPlayerAction()
    AssertEqual(m.requestId, oldRequestId, "rapid choices cannot queue stale replacements")

    m.service.result = {action: "play", requestId: m.playRequestId, ok: false, code: 502, message: "Could not apply selection"}
    OnResult()
    AssertEqual(m.playSession.PlaySessionId, "old-session", "failed negotiation keeps previous stream")
    AssertEqual(m.playbackOptions.selection.audioStreamIndex, 2, "failure leaves previous effective selection")
    AssertEqual(m.video.control, "pause", "failed replacement retains paused intent")
    AssertEqual(m.playerControls.busy, false, "failure unlocks controls")
    AssertEqual(m.playerControls.message, "Could not apply selection", "failure provides recoverable explanation")

    ResetSwitch()
    m.video.state = "playing"
    OnPlayerAction()
    m.service.result = {action: "play", requestId: m.playRequestId, ok: false, code: 502, message: "No stream"}
    OnResult()
    AssertEqual(m.video.control, "resume", "failed switch resumes previously playing stream")

    ResetSwitch()
    m.playerControls.action = {kind: "selection", field: "mediaSourceId", value: "version-b"}
    OnPlayerAction()
    AssertEqual(m.service.request.mediaSourceId, "version-b", "version selection reaches service")
    AssertEqual(m.service.request.audioStreamIndex, invalid, "version change does not reuse incompatible audio index")
    AssertEqual(m.service.request.subtitleStreamIndex, invalid, "version change does not reuse incompatible caption index")
    AssertEqual(m.service.request.quality, "720p", "version switch keeps quality policy")

    ResetSwitch()
    OnPlayerAction()
    m.service.result = SuccessfulSwitch(m.playRequestId)
    OnResult()
    AssertEqual(m.video.id, "old-video", "decoder replacement waits for stopped acknowledgement")
    AssertEqual(m.video.control, "stop", "successful negotiation stops old decoder asynchronously")
    AssertEqual(m.busy, true, "decoder handoff remains busy")
    m.video.state = "stopping"
    OnVideoState()
    AssertEqual(m.video.id, "old-video", "stopping state cannot start replacement")
    m.video.state = "stopped"
    OnVideoState()
    AssertEqual(m.service.request.event, "stopped", "successful negotiation retires previous stream")
    AssertEqual(m.service.request.body.PlaySessionId, "old-session", "stop report belongs to old session")
    AssertEqual(m.service.request.body.PositionTicks, 72000000000#, "retired stream reports absolute current position")
    AssertEqual(m.playSession.PlaySessionId, "new-session", "new stream gets independent session")
    AssertEqual(m.video.content.playStart, 7200, "replacement uses native original timeline once")
    AssertEqual(m.playbackOptions.selection.audioStreamIndex, 2, "negotiation alone does not commit visual selection")
    m.video.state = "playing"
    m.video.position = 7200
    OnVideoState()
    AssertEqual(m.video.seek, invalid, "correct native bookmark does not trigger a redundant seek")
    AssertEqual(m.playerControls.options.selection.audioStreamIndex, 3, "playing stream commits effective selection")
    AssertEqual(m.video.control, "pause", "replacement honors previously paused state")
    AssertEqual(m.service.request.event, "started", "replacement reports its own start")
    AssertEqual(m.service.request.body.PlaySessionId, "new-session", "start report belongs to replacement")
    AssertEqual(m.service.request.body.PositionTicks, 72000000000#, "new stream start does not double resume offset")
    event = {GetRoSGNode: StaleVideoNode}
    OnVideoState(event)
    AssertEqual(m.playSession.PlaySessionId, "new-session", "late callbacks from retired node cannot stop replacement")

    ' Decoder may acknowledge playing before honoring the requested bookmark.
    ResetSwitch()
    OnPlayerAction()
    m.service.result = SuccessfulSwitch(m.playRequestId)
    OnResult()
    m.video.state = "stopped"
    OnVideoState()
    m.video.state = "playing"
    m.video.position = 0
    OnVideoState()
    AssertEqual(m.started, false, "wrong start position is not accepted as a successful audio switch")
    AssertEqual(m.video.seek, 7200, "missing bookmark triggers one corrective absolute seek")
    AssertEqual(m.playerControls.busy, true, "switch stays pending until bookmark arrives")
    AssertEqual(m.service.request.event, "stopped", "zero position is never reported as replacement start")
    m.video.seek = invalid
    m.video.position = 1
    OnVideoPosition()
    AssertEqual(m.video.seek, invalid, "early position notifications cannot issue repeated corrective seeks")
    AssertEqual(m.lastPosition, 72000000000#, "transient zero cannot overwrite the saved progress")
    m.video.position = 7200
    OnVideoPosition()
    AssertEqual(m.started, true, "position acknowledgement completes the switch")
    AssertEqual(m.video.control, "pause", "corrective seek retains paused intent")
    AssertEqual(m.service.request.event, "started", "start reports only the restored position")
    AssertEqual(m.service.request.body.PositionTicks, 72000000000#, "replacement reports original position once")
    AssertEqual(m.video.visible, true, "video is revealed only at the restored position")
    AssertEqual(m.resumeCover.visible, false, "resume cover clears when position is acknowledged")

    ResetSwitch()
    m.video.state = "playing"
    OnPlayerAction()
    m.service.result = SuccessfulSwitch(m.playRequestId)
    OnResult()
    m.video.state = "stopped"
    OnVideoState()
    m.video.state = "playing"
    OnVideoState()
    AssertEqual(m.video.autoplayAfterSeek, true, "playing replacement seeks with playback intent")
    AssertEqual(m.resumeTimer.control, "start", "missing bookmark has a bounded acknowledgement wait")
    m.video.position = 7201
    OnVideoPosition()
    AssertEqual(m.video.control, "play", "playing replacement is not paused after landing")
    AssertEqual(m.resumeTimer.control, "stop", "acknowledged bookmark cancels timeout")
    AssertEqual(m.video.mute, false, "acknowledged stream restores audio")
    OnPlaybackResumeTimeout()
    AssertEqual(m.playSession.PlaySessionId, "new-session", "late timeout cannot stop acknowledged playback")

    ResetSwitch()
    OnPlayerAction()
    m.service.result = SuccessfulSwitch(m.playRequestId)
    OnResult()
    m.video.state = "stopped"
    OnVideoState()
    m.video.state = "playing"
    OnVideoState()
    m.video.position = 1
    OnPlaybackResumeTimeout()
    AssertEqual(m.playSession, invalid, "unacknowledged resume closes failed session")
    AssertEqual(m.service.request.body.PositionTicks, 72000000000#, "timeout retains original progress instead of wrong decoder position")
    AssertEqual(m.detail.UserData.PlaybackPositionTicks, 72000000000#, "timeout retains local resume point")
    AssertEqual(m.dialogMode, "switchPlaybackError", "timeout offers previous audio options")
    AssertEqual(m.resumeTimer.control, "stop", "timeout cleanup stops its timer")
    AssertEqual(m.playerControls.visible, false, "timeout returns control to details")
    AssertEqual(m.resumeCover.visible, false, "failed resume cannot cover the recovery dialog")

    ResetSwitch()
    OnPlayerAction()
    requestId = m.playRequestId
    StopPlayback()
    AssertEqual(m.busy, false, "leaving during negotiation unlocks library UI")
    AssertEqual(m.playSession, invalid, "exit retires old session")
    m.service.result = SuccessfulSwitch(requestId)
    OnResult()
    AssertEqual(m.playSession, invalid, "cancelled reply cannot reopen playback")
    AssertEqual(m.service.request.event, "stopped", "unused negotiated session is closed")
    AssertEqual(m.service.request.body.PlaySessionId, "new-session", "cancelled replacement cleanup identifies its session")

    ResetSwitch()
    m.playerControls.action = {kind: "seekTo", seconds: 7190}
    OnPlayerAction()
    AssertEqual(m.video.seek, 7190, "seek uses original absolute timeline")
    AssertEqual(m.video.autoplayAfterSeek, false, "seek preserves paused state")
    m.playerControls.action = {kind: "seekTo", seconds: -3}
    OnPlayerAction()
    AssertEqual(m.video.seek, 0, "seek clamps at item start")
    m.playerControls.action = {kind: "seekTo", seconds: 120, resumeAfterSeek: true}
    OnPlayerAction()
    AssertEqual(m.video.autoplayAfterSeek, true, "the viewer's play intent wins over a decoder still reading paused")
    m.video.control = invalid
    m.video.state = "paused"
    SyncPlayerState()
    AssertEqual(m.video.control, "resume", "a seek meant to keep playing that settles paused is resumed")
    m.video.control = invalid
    SyncPlayerState()
    AssertEqual(m.video.control, invalid, "only once")
    m.playerControls.action = {kind: "seekTo", seconds: 130, resumeAfterSeek: true}
    OnPlayerAction()
    m.playerControls.action = {kind: "toggle"}
    m.video.state = "playing"
    OnPlayerAction()
    m.video.control = invalid
    m.video.state = "paused"
    SyncPlayerState()
    AssertEqual(m.video.control, invalid, "pausing after a seek is the viewer's choice and stands")
    m.playerControls.action = {kind: "seekTo", seconds: 140, resumeAfterSeek: false}
    OnPlayerAction()
    m.video.control = invalid
    SyncPlayerState()
    AssertEqual(m.video.control, invalid, "a paused seek stays paused")
    ResetSwitch()
    m.detail.Chapters = [{Name: "Opening", StartPositionTicks: 0}, {Name: "Arrival", StartPositionTicks: 12000000000#}]
    chapters = PlaybackChapters(m.detail)
    AssertEqual(chapters.Count(), 2, "real chapter metadata exposed")
    AssertEqual(chapters[1].seconds, 1200, "chapter ticks become absolute seconds")
    m.playerControls.action = {kind: "seekTo", seconds: chapters[1].seconds}
    OnPlayerAction()
    AssertEqual(m.video.seek, 1200, "chapter selection seeks to absolute timestamp")
    AssertEqual(m.video.autoplayAfterSeek, false, "chapter selection preserves pause")
    ResetSwitch()
    OnPlayerAction()
    response = SuccessfulSwitch(m.playRequestId)
    m.service.result = {action: "report", ok: true, requestId: m.playRequestId + 1}
    m.reportsPending = 1
    OnResult({data: response, GetData: EventData})
    m.video.state = "stopped"
    OnVideoState()
    AssertEqual(m.playSession.PlaySessionId, "new-session", "queued play event consumes its own response despite newer Task field")
    AssertEqual(m.busy, false, "queued play response releases loading state")
    AssertEqual(m.reportsPending, 2, "play event does not consume the newer report acknowledgement")
    OnResult({data: m.service.result, GetData: EventData})
    AssertEqual(m.reportsPending, 1, "report event acknowledges exactly its own completion")
    ResetSwitch()
    OnPlayerAction()
    m.service.result = SuccessfulSwitch(m.playRequestId)
    OnResult()
    StopPlayback()
    AssertEqual(m.pendingPlaybackResult, invalid, "Back cancels prepared stream while decoder is stopping")
    AssertEqual(m.service.request.body.PlaySessionId, "new-session", "cancelled prepared session receives cleanup report")
    AssertEqual(m.playerControls.visible, false, "cancelling handoff returns to detail")
    AssertEqual(m.detail.UserData.PlaybackPositionTicks, 72000000000#, "cancelled handoff retains latest resume position")
    m.video.state = "stopped"
    OnVideoState()
    AssertEqual(m.video.id, "old-video", "late stop cannot start cancelled replacement")
    AssertEqual(m.playSession, invalid, "cancelled decoder handoff remains stopped")
    TestSeriesTrackChoice()
    TestNextEpisode()
    print "PASS: "; m.assertions; " playback switch assertions"
end sub

sub TestSeriesTrackChoice()
    ResetSwitch()
    m.detail = {Id: "item", Name: "Episode", UserData: {}, SeriesId: "show"}
    m.playbackOptions = {selection: {audioStreamIndex: 2, subtitleStreamIndex: -1, mediaSourceId: "version-a", quality: "auto"}, subtitleDelivery: "off", nativeSubtitleTracks: [{index: 0, trackName: "https://server/subtitle-0.srt"}], subtitleTracks: [{index: 0, label: "Brazilian - Portuguese", title: "Brazilian", language: "por", codec: "srt", isForced: false, isExternal: true}]}
    m.playerControls.action = {kind: "selection", field: "subtitleStreamIndex", value: 0}
    m.video.content = {SubtitleTracks: [{TrackName: "https://server/subtitle-0.srt"}]}
    m.video.state = "playing"
    OnPlayerAction()
    AssertEqual(m.service.request.action, "rememberTracks", "an in-place subtitle choice is remembered for the series")
    AssertEqual(m.service.request.seriesId, "show", "the choice belongs to the episode's series")
    AssertEqual(m.service.request.kind, "subtitle", "subtitle choices are stored as subtitles")
    AssertEqual(m.service.request.track.title, "Brazilian", "the track is remembered by what it is")
    AssertEqual(m.service.request.track.index, invalid, "the shifting index is not remembered")
    m.playerControls.action = {kind: "selection", field: "subtitleStreamIndex", value: -1}
    OnPlayerAction()
    AssertEqual(m.service.request.track.off, true, "turning subtitles off is remembered too")

    ResetSwitch()
    m.detail.SeriesId = "show"
    OnPlayerAction()
    AssertEqual(m.service.request.action, "play", "an audio switch is not remembered before it plays")
    m.service.result = {action: "play", requestId: m.playRequestId, ok: false, code: 502, message: "No stream"}
    OnResult()
    AssertEqual(m.trackChoice, invalid, "a failed audio switch is not remembered")

    ResetSwitch()
    m.detail.SeriesId = "show"
    m.segmentsItemId = "item"
    m.trackChoice = {field: "audioStreamIndex", value: 3}
    m.pendingOptions = {selection: {audioStreamIndex: 3}, audioTracks: [{index: 2, language: "por", label: "Portuguese"}, {index: 3, language: "jpn", label: "Japanese", title: "", codec: "eac3", isForced: false, isExternal: false}]}
    PlaybackStarted()
    AssertEqual(m.service.request.action, "rememberTracks", "an audio switch is remembered once it plays")
    AssertEqual(m.service.request.track.language, "jpn", "the playing audio language is remembered")
    AssertEqual(m.trackChoice, invalid, "the choice is remembered once")

    ResetSwitch()
    m.trackChoice = {field: "audioStreamIndex", value: 3}
    m.playbackOptions.audioTracks = [{index: 3, language: "jpn"}]
    requestId = m.requestId
    RememberTrackChoice()
    AssertEqual(m.requestId, requestId, "movies keep no series choice")
end sub

sub TestNextEpisode()
    ResetSwitch()
    m.playItem = {Id: "item", Name: "Episode 1", Type: "Episode", SeriesId: "show", UserData: {}}
    m.nextEpisode = {Id: "ep2", Name: "Episode 2", Type: "Episode", SeriesId: "show", SeriesName: "Show", ParentIndexNumber: 1, IndexNumber: 2, UserData: {}}
    m.video.state = "playing"
    m.playerControls.action = {kind: "nextEpisode"}
    OnPlayerAction()
    AssertEqual(m.service.request.action, "play", "Next asks for the next episode")
    AssertEqual(m.service.request.itemId, "ep2", "the episode after this one is requested")
    AssertEqual(m.service.request.seriesId, "show", "the series travels so remembered tracks apply")
    AssertEqual(m.service.request.quality, "720p", "the chosen quality carries over")
    AssertEqual(m.service.request.audioStreamIndex, invalid, "this episode's track indices are not reused")
    AssertEqual(m.service.request.ticks, 0, "an unwatched next episode starts at the beginning")
    AssertEqual(m.video.control, "pause", "the credits pause while the next episode loads")
    AssertEqual(PlaybackItem().Id, "item", "the current episode stays until the next one is ready")
    result = SuccessfulSwitch(m.playRequestId)
    result.session.ItemId = "ep2"
    result.offsetTicks = 0
    m.service.result = result
    OnResult()
    m.video.state = "stopped"
    OnVideoState()
    AssertEqual(PlaybackItem().Id, "ep2", "the player now belongs to the next episode")
    AssertEqual(m.playerControls.title, "Show", "the HUD names the series")
    AssertEqual(m.playerControls.subtitle, "T1, E2 · Film", "the HUD shows the new episode number")
    AssertEqual(m.playSession.ItemId, "ep2", "reports now belong to the next episode")

    ResetSwitch()
    m.playItem = {Id: "item", Name: "Episode 1", SeriesId: "show", UserData: {}}
    m.nextEpisode = {Id: "ep2", Name: "Episode 2", SeriesId: "show", UserData: {}}
    m.video.state = "playing"
    m.playerControls.action = {kind: "nextEpisode"}
    OnPlayerAction()
    m.service.result = {action: "play", requestId: m.playRequestId, ok: false, code: 502, message: "No stream"}
    OnResult()
    AssertEqual(PlaybackItem().Id, "item", "a failed next episode keeps the current one")
    AssertEqual(m.video.control, "resume", "the credits resume after a failed next episode")
    AssertEqual(m.pendingPlayItem, invalid, "the failed next episode is dropped")

    ResetSwitch()
    requestId = m.requestId
    m.playerControls.action = {kind: "nextEpisode"}
    OnPlayerAction()
    AssertEqual(m.requestId, requestId, "without a known next episode nothing is requested")

    ResetSwitch()
    m.playItem = {Id: "item", Name: "Episode 1", Type: "Episode", SeriesId: "show", UserData: {}}
    m.nextEpisode = {Id: "ep2", Name: "Episode 2", Type: "Episode", SeriesId: "show", SeriesName: "Show", ParentIndexNumber: 1, IndexNumber: 2, UserData: {}}
    m.playerControls.upNextArmed = true
    m.video.state = "finished"
    OnVideoState()
    AssertEqual(m.service.request.itemId, "ep2", "an episode that ends during the countdown goes on to the next")
    result = SuccessfulSwitch(m.playRequestId)
    result.session.ItemId = "ep2"
    m.service.result = result
    OnResult()
    AssertEqual(m.playSession.ItemId, "ep2", "a finished decoder hands over without waiting for a stop")
end sub

sub ResetSwitch()
    m.playItem = invalid
    m.nextEpisode = invalid
    m.pendingPlayItem = invalid
    m.trackChoice = invalid
    m.segmentsItemId = invalid
    m.seekPausePending = false
    m.resumeTargetSeconds = invalid
    m.resumeSeekIssued = false
    m.resumeTimer = {}
    m.resumeCover = {}
    m.requestId = 0
    m.reportsPending = 0
    m.busy = false
    m.playRequestId = invalid
    m.switchingPlayback = false
    m.pendingPlaybackResult = invalid
    m.pendingPlaybackRequest = invalid
    m.playSession = {ItemId: "item", MediaSourceId: "version-a", PlaySessionId: "old-session", PlayMethod: "Transcode"}
    m.playbackOptions = {selection: {audioStreamIndex: 2, subtitleStreamIndex: 6, mediaSourceId: "version-a", quality: "720p"}}
    m.playerControls = {action: {kind: "selection", field: "audioStreamIndex", value: 3}, SetFocus: NoopFocus}
    m.video = {id: "old-video", state: "paused", position: 7200, duration: 9000, visible: true}
    m.detail = {Id: "item", Name: "Film", UserData: {}}
    m.started = true
    m.lastPosition = 71000000000#
    m.playOffset = 60000000000#
    m.service = {}
    m.spinner = {}
    m.status = {}
    m.reportTimer = {}
    m.secondary = {}
    m.ctaText = {}
end sub

function SuccessfulSwitch(requestId as Integer) as Object
    return {action: "play", requestId: requestId, ok: true, session: {ItemId: "item", MediaSourceId: "version-a", PlaySessionId: "new-session", PlayMethod: "Transcode"}, content: {title: "Film", playStart: 7200}, offsetTicks: 72000000000#, transcoded: true, options: {selection: {audioStreamIndex: 3, subtitleStreamIndex: 6, mediaSourceId: "version-a", quality: "720p"}}}
end function

sub ReplaceVideoNode(result as Object)
    m.video = {id: "new-video", state: "buffering", position: 0, duration: 9000, suppressCaptions: true}
end sub

function StaleVideoNode() as Object
    return {id: "old-video", state: "stopped"}
end function

sub NoopFocus(focused as Boolean)
end sub

sub Focus(area as String)
    m.focusArea = area
end sub

sub ShowMessage(title as String, message as String, buttons as Object, mode as String)
    m.dialogMode = mode
end sub

sub AssertEqual(actual as Dynamic, expected as Dynamic, description as String)
    if actual <> expected
        print "FAIL: "; description; " expected="; expected; " actual="; actual
        stop
    end if
    m.assertions++
end sub

function EventData() as Object
    return m.data
end function
