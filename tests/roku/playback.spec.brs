' Exercise the production scene handlers with inert UI/network boundaries.
sub Main()
    m.assertions = 0
    ResetScene()
    OnVideoState()
    AssertEqual(m.service.request.event, "started", "playing begins a session")
    AssertEqual(m.service.request.body.PositionTicks, 72000000000#, "resume report preserves two-hour timeline")
    for index = 1 to 100
        m.video.position = 7200 + index
        ReportProgress()
    end for
    AssertEqual(m.requestId, 1, "slow task cannot accumulate progress reports")
    AcknowledgeReport()
    ReportProgress()
    AssertEqual(m.requestId, 2, "reporting resumes after acknowledgement")
    AssertEqual(m.service.request.body.PositionTicks, 73000000000#, "next report samples latest position")
    m.video.position = 120
    OnVideoPosition()
    AssertEqual(m.lastPosition, 1200000000#, "backward seek uses native absolute timeline")
    StopPlayback()
    AssertEqual(m.service.request.event, "stopped", "terminal report survives pending progress")
    AssertEqual(m.service.request.body.PositionTicks, 1200000000#, "stop samples current position")
    AssertEqual(m.detail.UserData.PlaybackPositionTicks, 1200000000#, "detail resumes where playback stopped")
    StopPlayback()
    AssertEqual(m.requestId, 3, "repeated stop reports exactly once")
    AssertEqual(m.video.visible, false, "stop restores detail UI")
    AssertEqual(m.reportTimer.control, "stop", "stop halts reporting timer")

    ResetScene()
    m.video.state = "stopped"
    OnVideoState()
    AssertEqual(m.playSession, invalid, "native stopped state closes session")
    AssertEqual(m.service.request.event, "stopped", "native stop sends terminal report")
    OnVideoState()
    AssertEqual(m.requestId, 1, "native stopped callback is idempotent")

    ResetScene()
    m.video.state = "error"
    OnVideoState()
    AssertEqual(m.service.request.body.Failed, true, "decoder failure reported")
    AssertEqual(m.service.request.body.PositionTicks, 72000000000#, "pre-start failure preserves requested resume")
    AssertEqual(m.dialogMode, "playbackError", "decoder failure offers compatible retry")
    AssertEqual(m.detail.UserData.PlaybackPositionTicks, 72000000000#, "retry retains resume point")

    ResetScene()
    m.started = true
    m.lastPosition = 74000000000#
    m.video.state = "finished"
    OnVideoState()
    AssertEqual(m.service.request.body.PositionTicks, 74000000000#, "completion reports final observed timeline")
    AssertEqual(m.detail.UserData.PlaybackPositionTicks, 0, "completed title resets local resume")
    AssertEqual(m.ctaText.text, "Reproduzir novamente", "completed title offers replay")

    ResetScene()
    m.started = true
    m.video.state = "paused"
    OnVideoState()
    AssertEqual(m.service.request.body.IsPaused, true, "pause reports paused state")
    AcknowledgeReport()
    m.video.state = "playing"
    OnVideoState()
    AssertEqual(m.service.request.event, "progress", "unpause does not restart session")
    AssertEqual(m.service.request.body.IsPaused, false, "unpause reports playing state")
    print "PASS: "; m.assertions; " playback assertions"
end sub

sub ResetScene()
    m.requestId = 0
    m.reportsPending = 0
    m.service = {}
    m.video = {state: "playing", position: 7200, visible: true}
    m.reportTimer = {}
    m.playSession = {ItemId: "movie", MediaSourceId: "source", PlaySessionId: "session", PlayMethod: "Transcode", CanSeek: true}
    m.playOffset = 72000000000#
    m.lastPosition = m.playOffset
    m.started = false
    m.detail = {Id: "movie", UserData: {PlaybackPositionTicks: m.playOffset}}
    m.ctaText = {}
    m.secondary = {}
    m.dialogMode = ""
end sub

sub AcknowledgeReport()
    m.service.result = {action: "report", requestId: m.service.request.requestId, ok: true}
    OnResult()
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
