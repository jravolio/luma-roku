sub Main()
    m.assertions = 0
    ResetSeek()
    onKeyEvent("right", true)
    Check(m.top.action, invalid, "a press alone neither pauses nor seeks yet")
    Check(m.scrubStatus.visible, false, "a tap shows no speed")
    Check(m.scrubTarget, 110, "visible timeline tap previews ten seconds")
    m.fakeElapsed = 600
    OnScrubTick()
    Check(m.scrubTarget, 120, "one keydown keeps advancing without repeat events")
    Check(m.top.action.kind, "scrubStart", "holding pauses so the preview holds still, without decoder seeks")
    Check(m.scrubStatus.visible, true, "a hold shows its speed")
    m.fakeElapsed = 2700
    OnScrubTick()
    Check(m.scrubTarget, 140, "a hold doubles its step after 1.2 s more")
    m.fakeElapsed = 3900
    OnScrubTick()
    Check(m.scrubTarget, 180, "and keeps doubling while held")
    m.fakeElapsed = 5200
    OnScrubTick()
    Check(m.scrubTarget, 240, "a short episode tops out at a minute per step")
    Check(m.top.action.kind, "scrubStart", "timer ticks never flood decoder with seeks")
    m.top.position = 101
    UpdateTimeline()
    Check(m.elapsed.text, "4:00", "position callbacks do not overwrite scrub preview")
    onKeyEvent("right", true)
    Check(m.scrubTarget, 240, "OS key repeats do not double count timer movement")
    Check(onKeyEvent("left", false), false, "unrelated keyup cannot finish held right")
    onKeyEvent("right", false)
    Check(m.top.action.kind, "seekTo", "release commits absolute target")
    Check(m.top.action.seconds, 240, "release uses accumulated preview")
    Check(m.top.action.resumeAfterSeek, true, "playing intent retained across scrub pause")
    Check(m.scrubTimer.control, "stop", "release stops hold timer")
    Check(m.scrubbing, false, "release clears held state")
    onKeyEvent("right", false)
    Check(m.top.action.seconds, 240, "duplicate release cannot seek twice")

    ResetSeek()
    m.hud.visible = false
    onKeyEvent("right", true)
    Check(m.scrubTarget, 100, "hidden HUD first press only reveals")
    onKeyEvent("right", false)
    Check(m.top.action, invalid, "hidden HUD tap leaves playback alone")
    m.hud.visible = false
    onKeyEvent("right", true)
    m.fakeElapsed = 600
    OnScrubTick()
    Check(m.scrubTarget, 110, "holding from hidden HUD still starts seeking")
    Check(m.top.action.kind, "scrubStart", "hidden hold pauses only after threshold")
    onKeyEvent("right", false)
    Check(m.top.action.seconds, 110, "hidden hold commits on release")

    ResetSeek()
    m.top.playbackState = "paused"
    onKeyEvent("left", true)
    m.fakeElapsed = 2700
    OnScrubTick()
    Check(m.scrubTarget, 70, "held left rewinds with same acceleration")
    onKeyEvent("left", false)
    Check(m.top.action.resumeAfterSeek, false, "paused playback stays paused after seek")

    ResetSeek()
    onKeyEvent("right", true)
    onKeyEvent("left", true)
    Check(m.scrubTarget, 100, "direction reversal continues from preview, not playing position")
    onKeyEvent("right", false)
    Check(m.scrubbing, true, "old direction release cannot stop reversed hold")
    onKeyEvent("left", false)
    Check(m.top.action.seconds, 100, "reversed hold commits once")

    ResetSeek()
    m.top.position = 998
    onKeyEvent("right", true)
    Check(m.scrubTarget, 999, "forward clamps before end of file")
    m.fakeElapsed = 6000
    OnScrubTick()
    Check(m.scrubTarget, 999, "acceleration cannot overshoot duration")
    onKeyEvent("right", false)
    ResetSeek()
    m.top.position = 3
    onKeyEvent("left", true)
    Check(m.scrubTarget, 0, "rewind clamps at start")
    m.fakeElapsed = 600
    OnScrubTick()
    onKeyEvent("back", true)
    Check(m.top.action.kind, "scrubCancel", "Back cancels preview without seeking")
    Check(m.top.action.resume, true, "cancel restores original playing intent")
    Check(m.scrubTimer.control, "stop", "cancel stops timer")

    ResetSeek()
    m.area = "buttons"
    onKeyEvent("right", true)
    Check(m.scrubbing, false, "right over buttons stays button navigation")
    Check(m.buttonIndex, 3, "button focus advances normally")
    ResetSeek()
    m.top.busy = true
    onKeyEvent("right", true)
    Check(m.scrubbing, false, "busy replacement cannot begin hold")
    ResetSeek()
    onKeyEvent("right", true)
    m.top.visible = false
    VisibilityChanged()
    Check(m.scrubbing, false, "leaving player cancels held preview")
    Check(m.scrubTimer.control, "stop", "no timer survives hidden player")
    onKeyEvent("right", false)
    Check(m.top.action, invalid, "late release cannot reopen hidden playback")
    ResetSeek()
    onKeyEvent("right", true)
    m.top.busy = true
    BusyChanged()
    Check(m.scrubbing, false, "new playback request cancels hold")
    ResetSeek()
    m.top.duration = 0
    onKeyEvent("right", true)
    Check(m.scrubbing, false, "unknown duration never starts uncontrolled seeking")
    ' Quick presses while a seek is still landing: the decoder keeps reporting
    ' the old position and reads buffering for a moment.
    ResetSeek()
    m.seekClock = {TotalMilliseconds: FakeSeekAge, Mark: FakeSeekMark, fakeSeekAge: 0}
    onKeyEvent("right", true)
    onKeyEvent("right", false)
    Check(m.top.action.seconds, 110, "a tap seeks ten seconds")
    m.top.playbackState = "buffering"
    UpdateTimeline()
    Check(m.elapsed.text, "1:50", "the playhead stays on the target while the old position is still reported")
    onKeyEvent("right", true)
    Check(m.scrubTarget, 120, "a second tap adds to the first instead of starting from the stale position")
    onKeyEvent("right", false)
    Check(m.top.action.seconds, 120, "two quick taps land twenty seconds on")
    Check(m.top.action.resumeAfterSeek, true, "a press during buffering keeps playing afterwards")
    m.top.position = 118
    m.top.playbackState = "playing"
    UpdateTimeline()
    Check(m.elapsed.text, "1:58", "once the decoder reports near the target the real position shows")
    Check(m.seekTarget, invalid, "the landed seek is forgotten")
    ResetSeek()
    m.seekClock = {TotalMilliseconds: FakeSeekAge, Mark: FakeSeekMark, fakeSeekAge: 0}
    m.top.playbackState = "paused"
    onKeyEvent("left", true)
    onKeyEvent("left", false)
    m.top.playbackState = "buffering"
    onKeyEvent("left", true)
    onKeyEvent("left", false)
    Check(m.top.action.seconds, 80, "quick rewinds add up too")
    Check(m.top.action.resumeAfterSeek, false, "a paused viewer stays paused through quick presses")
    m.top.playbackState = "playing"
    NoteDecoderState()
    m.top.playbackState = "paused"
    m.seekClock.fakeSeekAge = 0
    onKeyEvent("left", true)
    onKeyEvent("left", false)
    Check(m.top.action.resumeAfterSeek, false, "a pause the decoder reports after the seek is the viewer's")
    ' The fake clock's own m: it reads its fakeSeekAge field.
    m.seekClock.fakeSeekAge = 11000
    UpdateTimeline()
    Check(m.elapsed.text, "1:40", "a seek that never reports back stops being shown after 10 s")
    ' A hold pauses for its preview; after release the seek asks to resume. A
    ' player that never reports "playing" again must not turn the next tap into
    ' a pause.
    ResetSeek()
    m.seekClock = {TotalMilliseconds: FakeSeekAge, Mark: FakeSeekMark, fakeSeekAge: 0}
    onKeyEvent("right", true)
    m.fakeElapsed = 600
    OnScrubTick()
    m.top.playbackState = "paused"
    NoteDecoderState()
    onKeyEvent("right", false)
    Check(m.top.action.resumeAfterSeek, true, "the scrub's own pause does not become the viewer's intent")
    m.top.position = 120
    UpdateTimeline()
    onKeyEvent("right", true)
    onKeyEvent("right", false)
    Check(m.top.action.seconds, 130, "the next tap goes on from the landed position")
    Check(m.top.action.resumeAfterSeek, true, "and keeps playing although the player still reads paused")

    ResetSeek()
    onKeyEvent("replay", true)
    Check(m.top.action.kind, "seekTo", "instant replay is an absolute seek")
    Check(m.top.action.seconds, 90, "instant replay goes back ten seconds from what is shown")

    ResetSeek()
    m.top.duration = 7200
    Check(ScrubIncrement(5100), 80, "a film speeds up like an episode at first")
    Check(ScrubIncrement(9000), 200, "a two-hour film keeps speeding up to about 1/36 of its length per step")
    m.top.duration = 1320
    Check(ScrubIncrement(9000), 60, "a 22-minute episode stays at a minute per step")
    Check(StepLabel(200), "3 min 20 s", "long steps read in minutes")
    print "PASS: ";m.assertions;" held seek assertions"
end sub
sub ResetSeek()
    m.seekTarget = invalid
    m.stateSinceSeek = invalid
    m.awaitingScrubPause = false
    m.scrubbing = false
    m.scrubStarted = false
    m.fakeElapsed = 0
    m.area = "timeline"
    m.buttonIndex = 2
    m.buttonNodes = [{}, {}, {}, {}, {}, {group:{visible:true}}]
    m.top = {visible:true,busy:false,position:100,duration:1000,playbackState:"playing"}
    for each id in ["menu", "hud", "hideTimer", "scrubTimer", "scrubStatus", "timelineFill", "playhead", "elapsed", "remaining"]
        m[id] = {}
    end for
    m.menu.visible = false
    m.hud.visible = true
end sub
function ScrubElapsedMs() as Integer
    return m.fakeElapsed
end function
sub PaintControls()
end sub
sub Check(actual as Dynamic, expected as Dynamic, description as String)
    if actual <> expected
        print "FAIL: ";description;" expected=";expected;" actual=";actual
        stop
    end if
    m.assertions++
end sub

function FakeSeekAge() as Integer
    return m.fakeSeekAge
end function

sub FakeSeekMark()
    m.fakeSeekAge = 0
end sub
