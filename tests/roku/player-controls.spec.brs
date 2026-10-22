sub Main()
    m.assertions = 0
    ResetControls()
    onKeyEvent("options", true)
    AssertEqual(m.menu.visible, true, "Star opens caption menu")
    AssertEqual(m.menuItems.Count(), 10, "Off plus all nine actual subtitle choices listed")
    AssertEqual(m.menuItems[0].value, -1, "Off is an explicit real option")
    AssertEqual(m.menuIndex, 0, "current Off selection starts focused")
    for index = 1 to 7
        onKeyEvent("down", true)
    end for
    AssertEqual(m.menuIndex, 7, "remote reaches choices beyond first five visible rows")
    onKeyEvent("OK", true)
    AssertEqual(m.top.action.field, "subtitleStreamIndex", "caption menu emits correct field")
    AssertEqual(m.top.action.value, 16, "caption choice emits Jellyfin index, not menu index")
    AssertEqual(m.top.options.selection.subtitleStreamIndex, -1, "UI waits for successful playback before moving checkmark")
    AssertEqual(m.area, "buttons", "selection restores triggering control focus")
    AssertEqual(m.menu.visible, false, "selection closes list")
    onKeyEvent("options", true)
    onKeyEvent("options", true)
    AssertEqual(m.menu.visible, false, "second Star dismisses options")
    onKeyEvent("options", true)
    onKeyEvent("back", true)
    AssertEqual(m.area, "buttons", "Back closes menu to its control")
    AssertEqual(m.top.action.kind, "selection", "menu Back does not stop playback")
    onKeyEvent("back", true)
    AssertEqual(m.hud.visible, false, "next Back hides player HUD")
    AssertEqual(m.controlHint.visible, false, "hidden HUD leaves video completely unobstructed")
    onKeyEvent("up", true)
    AssertEqual(m.hud.visible, true, "arrow reveals hidden controls")
    AssertEqual(m.controlHint.visible, false, "navigation hints remain hidden with controls")
    onKeyEvent("back", true)
    onKeyEvent("back", true)
    AssertEqual(m.top.action.kind, "exit", "Back from hidden controls exits playback")

    ResetControls()
    m.buttonIndex = 1
    OpenOptions()
    AssertEqual(m.menuItems[0].value, 2, "audio tracks retain sparse stream index")
    onKeyEvent("down", true)
    onKeyEvent("OK", true)
    AssertEqual(m.top.action.value, 4, "selected audio uses actual stream index")
    ResetControls()
    m.top.busy = true
    onKeyEvent("options", true)
    AssertEqual(m.menu.visible, false, "in-flight switch prevents another option request")
    AssertEqual(onKeyEvent("right", false), false, "key release does not seek")

    ResetControls()
    m.buttonIndex = 5
    m.top.position = 1400
    OpenOptions()
    AssertEqual(m.menuIndex, 1, "chapter menu highlights current chapter")
    onKeyEvent("OK", true)
    AssertEqual(m.top.action.kind, "seekTo", "chapter choice seeks rather than renegotiates")
    AssertEqual(m.top.action.seconds, 1200, "chapter target uses absolute seconds")
    AssertEqual(ClockLabel(7209), "2:00:09", "long playback time remains readable")
    ResetControls()
    m.hud.visible = false
    m.controlHint.visible = false
    m.menu.visible = true
    m.top.visible = true
    VisibilityChanged()
    AssertEqual(m.hud.visible, true, "opening another video restores visible loading HUD")
    AssertEqual(m.controlHint.visible, false, "opening player keeps navigation hints hidden")
    AssertEqual(m.menu.visible, false, "new playback cannot inherit old open menu")
    AssertEqual(m.area, "timeline", "new playback starts at timeline focus")
    m.top.visible = false
    VisibilityChanged()
    AssertEqual(m.hideTimer.control, "stop", "leaving player stops hidden HUD timer")

    ResetControls()
    m.top.playbackState = "playing"
    m.top.duration = 2700
    m.top.position = 10
    m.top.segments = [{kind: "Intro", startTime: 62, endTime: 152}, {kind: "Outro", startTime: 2600, endTime: 2700}]
    SegmentsChanged()
    AssertEqual(m.skipVisible, false, "skip pill hidden before the intro")
    m.top.position = 63
    UpdateSkip()
    AssertEqual(m.skipVisible, true, "skip pill appears inside the intro")
    AssertEqual(SkipLabel(m.activeSegment.kind), "Pular abertura", "intro label in Portuguese")
    m.hud.visible = false
    AssertEqual(onKeyEvent("OK", true), true, "OK over hidden HUD is consumed by the pill")
    AssertEqual(m.top.action.kind, "seekTo", "skip seeks instead of toggling playback")
    AssertEqual(m.top.action.seconds, 152, "skip lands at intro end")
    AssertEqual(m.hud.visible, false, "skipping does not open the HUD")
    AssertEqual(m.skipVisible, false, "pill hides immediately after skipping while the seek lands")
    m.top.position = 152
    UpdateSkip()
    AssertEqual(m.skipVisible, false, "pill gone past the intro")
    m.top.position = 70
    UpdateSkip()
    AssertEqual(m.skipVisible, true, "rewinding into the intro offers skip again")
    m.top.position = 140
    UpdateSkip()
    AssertEqual(m.skipVisible, true, "pill stays for the whole intro")
    m.top.position = 160
    UpdateSkip()
    m.top.action = {}
    onKeyEvent("OK", true)
    AssertEqual(m.top.action.kind, invalid, "OK outside a segment reveals controls instead of skipping")
    AssertEqual(m.hud.visible, true, "OK outside a segment reveals HUD")
    m.top.position = 100
    UpdateSkip()
    AssertEqual(m.skipVisible, true, "pill shows alongside the HUD inside the intro")
    AssertEqual(m.area, "skip", "a newly offered skip takes focus from the timeline")
    m.area = "timeline"
    onKeyEvent("down", true)
    AssertEqual(m.area, "skip", "Down from the timeline focuses the skip pill")
    onKeyEvent("OK", true)
    AssertEqual(m.top.action.seconds, 152, "focused pill skips from the HUD")
    AssertEqual(m.area, "timeline", "focus returns to timeline after skipping")
    m.top.position = 152
    UpdateSkip()
    m.top.position = 70
    m.hud.visible = false
    UpdateSkip()
    onKeyEvent("down", true)
    AssertEqual(m.hud.visible, true, "Down over an offered skip reveals the controls")
    AssertEqual(m.area, "skip", "revealed controls keep the skip focused so OK still skips")
    m.top.action = {}
    onKeyEvent("play", true)
    AssertEqual(m.top.action.kind, "toggle", "Play/Pause still pauses while the skip is focused")
    onKeyEvent("up", true)
    AssertEqual(m.area, "timeline", "Up leaves the skip for the timeline")
    m.top.action = {}
    onKeyEvent("OK", true)
    AssertEqual(m.top.action.kind, "toggle", "OK on the timeline pauses as usual")
    onKeyEvent("down", true)
    onKeyEvent("OK", true)
    AssertEqual(m.top.action.seconds, 152, "Down then OK skips from the timeline")
    PlayThrough(2585, 2605)
    AssertEqual(m.skipVisible, false, "trailing credits are not offered because skipping would end the file")
    m.top.hasNextEpisode = true
    m.top.position = 2650
    UpdateSkip()
    AssertEqual(m.skipVisible, false, "jumping into the final credits is a search, not the end: no next episode")
    PlayThrough(2585, 2605)
    AssertEqual(m.skipVisible, true, "playing into the final credits offers the next episode")
    AssertEqual(SkipLabel(m.activeSegment.kind), "Próximo episódio", "next episode label in Portuguese")
    m.hud.visible = false
    m.top.action = {}
    onKeyEvent("OK", true)
    AssertEqual(m.top.action.kind, "nextEpisode", "one OK during the credits asks for the next episode")
    AssertEqual(m.hud.visible, false, "asking for the next episode does not open the HUD")
    m.top.position = 2500
    UpdateSkip()
    AssertEqual(m.skipVisible, false, "the next episode is offered only during the final credits")
    m.top.hasNextEpisode = false
    PlayThrough(2585, 2605)
    AssertEqual(m.skipVisible, false, "the last episode of a series offers nothing during its credits")
    m.top.hasNextEpisode = true
    m.scrubbing = true
    m.scrubTarget = 2650
    UpdateSkip()
    AssertEqual(m.skipVisible, false, "scrubbing through the final credits never offers the next episode")
    m.scrubbing = false
    m.top.hasNextEpisode = false
    m.top.segments = []
    SegmentsChanged()
    m.top.position = 100
    UpdateSkip()
    AssertEqual(m.skipVisible, false, "no segments means no pill")
    m.top.segments = [{kind: "Recap", startTime: 0, endTime: 40}, {kind: "Outro", startTime: 600, endTime: 700}]
    SegmentsChanged()
    m.top.position = 5
    UpdateSkip()
    AssertEqual(SkipLabel(m.activeSegment.kind), "Pular recapitulação", "recap label")
    m.top.position = 610
    UpdateSkip()
    AssertEqual(m.skipVisible, true, "mid-file credits are skippable")
    m.top.hasNextEpisode = true
    UpdateSkip()
    AssertEqual(SkipLabel(m.activeSegment.kind), "Pular créditos", "credits before a post-credits scene still skip, not jump episodes")
    m.top.hasNextEpisode = false
    m.scrubbing = true
    m.scrubTarget = 900
    UpdateSkip()
    AssertEqual(m.skipVisible, false, "pill follows a scrub preview out of the segment")
    m.scrubTarget = 620
    UpdateSkip()
    AssertEqual(m.skipVisible, true, "pill follows a scrub preview into the segment")
    AssertEqual(m.area, "timeline", "a skip reached by scrubbing does not steal focus")
    m.scrubbing = false
    m.area = "skip"
    m.hud.visible = true
    m.top.duration = 2700
    onKeyEvent("left", true)
    AssertEqual(m.scrubbing, true, "Left on the skip rewinds like the timeline")
    AssertEqual(m.area, "timeline", "rewinding from the skip moves focus to the timeline")
    onKeyEvent("left", false)
    AssertEqual(m.scrubbing, false, "releasing Left commits the rewind")
    TestLoadingLayer()
    TestUpNextCountdown()
    TestTrickplayPreview()
    print "PASS: "; m.assertions; " player control assertions"
end sub

sub TestLoadingLayer()
    ResetControls()
    m.messageLabel = {visible: true}
    m.loadingLayer = {visible: false, opacity: 1}
    m.loadingArt = {visible: false}
    m.loadingShade = {}
    m.loadingIndicator = {control: ""}
    m.loadingFadeOut = {}
    m.top.artwork = "https://server/backdrop.jpg"
    m.top.visible = true
    VisibilityChanged()
    m.top.message = "Carregando…"
    m.top.busy = true
    BusyChanged()
    AssertEqual(m.loadingLayer.visible, true, "a starting title shows the loading layer")
    AssertEqual(m.loadingArt.visible, true, "the first load shows the title's art")
    AssertEqual(m.loadingIndicator.control, "start", "the indicator spins while loading")
    AssertEqual(m.loadingIndicator.text, "Carregando…", "the status sits under the indicator")
    AssertEqual(m.messageLabel.visible, false, "loading text is not repeated in the HUD")
    m.top.playbackState = "playing"
    m.hasPlayed = true
    UpdateLoading()
    AssertEqual(m.loadingArt.visible, true, "the art stays until the layer fades")
    m.top.busy = false
    BusyChanged()
    AssertEqual(m.loadingIndicator.control, "stop", "the first frame stops the indicator")
    AssertEqual(m.loadingFadeOut.control, "start", "the layer fades out instead of cutting")
    m.loadingFadeOut.state = "stopped"
    OnLoadingFaded()
    AssertEqual(m.loadingLayer.visible, false, "the faded layer is removed")
    m.top.message = ""
    m.top.playbackState = "buffering"
    UpdateLoading()
    AssertEqual(m.loadingLayer.visible, true, "rebuffering shows the indicator over the frame")
    AssertEqual(m.loadingArt.visible, false, "rebuffering does not cover the frame with art")
    m.top.playbackState = "playing"
    UpdateLoading()
    m.top.message = "Could not apply selection"
    MessageChanged()
    AssertEqual(m.messageLabel.visible, true, "errors stay readable in the HUD")
    m.top.visible = false
    m.loadingLayer.visible = true
    VisibilityChanged()
    AssertEqual(m.loadingLayer.visible, false, "leaving the player removes the loading layer")
end sub

sub TestUpNextCountdown()
    ResetControls()
    m.idleEpisodes = 0
    m.top.duration = 1500
    m.top.playbackState = "playing"
    m.top.hasNextEpisode = true
    m.top.segments = []
    SegmentsChanged()
    m.hud.visible = false
    PlayThrough(1470, 1479)
    AssertEqual(m.skipVisible, false, "without a credits marker nothing is offered before the last 20 s")
    PlayThrough(1480, 1481)
    AssertEqual(OfferingNext(), true, "without a credits marker the next episode is offered for the last 20 s")
    AssertEqual(m.top.upNextArmed, true, "the offer counts down")
    m.top.action = {}
    PlayThrough(1482, 1486)
    AssertEqual(m.top.action.kind, invalid, "nothing starts before the countdown ends")
    PlayThrough(1487, 1491)
    AssertEqual(m.top.action.kind, "nextEpisode", "the next episode starts by itself after 10 s")
    m.top.action = {}
    PlayThrough(1492, 1492)
    AssertEqual(m.top.action.kind, invalid, "it is asked for only once")
    m.top.segments = []
    SegmentsChanged()
    m.top.position = 1490
    UpdateSkip()
    AssertEqual(OfferingNext(), false, "a seek into the last seconds offers nothing")
    m.top.position = 1300
    UpdateSkip()
    PlayThrough(1476, 1481)
    AssertEqual(OfferingNext(), false, "a seek just before the end that then plays on is still a seek")
    m.top.position = 1300
    UpdateSkip()
    PlayThrough(1301, 1302)
    m.top.position = 1465
    UpdateSkip()
    PlayThrough(1466, 1481)
    AssertEqual(OfferingNext(), true, "landing well before the last 20 s and watching into them offers the next episode")
    m.top.action = {}
    onKeyEvent("back", true)
    AssertEqual(m.skipVisible, false, "Back withdraws the offer")
    AssertEqual(m.top.action.kind, invalid, "Back over the offer keeps the credits playing")
    PlayThrough(1482, 1495)
    AssertEqual(m.top.action.kind, invalid, "a withdrawn offer never starts the next episode")
    m.idleEpisodes = 0
    for episode = 1 to 3
        m.top.segments = []
        SegmentsChanged()
        PlayThrough(1468, 1481)
        AssertEqual(m.top.upNextArmed, true, "unattended episodes continue by themselves up to three times")
    end for
    m.top.segments = []
    SegmentsChanged()
    PlayThrough(1468, 1481)
    AssertEqual(m.top.upNextArmed, false, "after three unattended episodes the fourth waits for the viewer")
    m.top.action = {}
    PlayThrough(1482, 1495)
    AssertEqual(m.top.action.kind, invalid, "a waiting offer never starts by itself")
    onKeyEvent("OK", true)
    AssertEqual(m.top.action.kind, "nextEpisode", "OK still plays the next episode")
    m.top.segments = []
    SegmentsChanged()
    PlayThrough(1468, 1481)
    AssertEqual(m.top.upNextArmed, true, "any key press re-arms the countdown")
end sub

sub TestTrickplayPreview()
    ResetControls()
    for each id in ["trickFrame", "trickEdge", "trickBack", "trickClip", "trickSheet"]
        m[id] = {}
    end for
    m.top.duration = 7200
    m.top.trickplay = {prefix: "http://pc/Videos/film/Trickplay/320/", suffix: ".jpg?MediaSourceId=src", width: 320, height: 134, tileWidth: 5, tileHeight: 5, frames: 720, interval: 10000}
    PaintTrickplay(1000, 500)
    AssertEqual(m.trickFrame.visible, false, "no preview while simply playing")
    m.scrubbing = true
    PaintTrickplay(1000, 500)
    AssertEqual(m.trickFrame.visible, false, "a tap is a jump, not a preview")
    m.scrubHeld = true
    PaintTrickplay(1000, 500)
    AssertEqual(m.trickFrame.visible, true, "holding shows the frame at the target")
    AssertEqual(m.trickSheet.uri, "http://pc/Videos/film/Trickplay/320/4.jpg?MediaSourceId=src", "100th frame is on the fifth sheet of 25")
    AssertEqual(m.trickSheet.translation[0], 0, "its column within the sheet")
    AssertEqual(m.trickSheet.translation[1], 0, "its row within the sheet")
    PaintTrickplay(1080, 500)
    AssertEqual(m.trickSheet.translation[0], -960, "the fourth column is three widths in")
    AssertEqual(m.trickSheet.translation[1], -134, "the second row is one height down")
    AssertEqual(m.trickClip.clippingRect[3], 134, "the clip follows the film's shape")
    AssertEqual(m.trickFrame.translation[0], 340, "the preview is centred on the playhead")
    PaintTrickplay(7199, 1836)
    AssertEqual(m.trickFrame.translation[0], 1520, "the preview stays on screen at the end")
    AssertEqual(m.trickSheet.uri, "http://pc/Videos/film/Trickplay/320/28.jpg?MediaSourceId=src", "the target past the last frame shows the last one")
    m.scrubStatus = {}
    PlaceScrubStatus(1836)
    AssertEqual(m.scrubStatus.translation[1], 870 - 134 - 48, "the speed sits above the preview, clear of the times")
    m.scrubbing = true
    ClearScrub()
    AssertEqual(m.trickFrame.visible, false, "releasing hides the preview")
    m.top.trickplay = {}
    m.scrubbing = true
    m.scrubHeld = true
    PaintTrickplay(10, 100)
    AssertEqual(m.trickFrame.visible, false, "items without sheets show no preview")
    m.scrubbing = false
end sub

' Playback moving on its own, one position report a second.
sub PlayThrough(first as Integer, last as Integer)
    for second = first to last
        m.top.position = second
        UpdateSkip()
    end for
end sub

sub ResetControls()
    m.area = "timeline"
    m.buttonIndex = 2
    m.menuIndex = 0
    m.menuItems = []
    m.buttonNodes = [{group: {}}, {group: {}}, {group: {}}, {group: {}}, {group: {}}, {group: {visible: true}}]
    m.menu = {visible: false}
    m.hud = {visible: true}
    m.controlHint = {visible: true}
    m.menuTitle = {}
    m.hideTimer = {}
    m.scrubTimer = {}
    m.scrubStatus = {}
    m.timelineFill = {}
    m.playhead = {}
    m.elapsed = {}
    m.remaining = {}
    m.names = ["Reproduzir", "Áudio", "Legendas", "Qualidade", "Versão", "Capítulos"]
    m.keys = ["", "audioStreamIndex", "subtitleStreamIndex", "quality", "mediaSourceId", ""]
    subtitles = []
    for index = 10 to 18
        subtitles.Push({index: index, label: "Language " + index.ToStr()})
    end for
    m.top = {busy: false, position: 0, options: {selection: {audioStreamIndex: 2, subtitleStreamIndex: -1}, subtitleTracks: subtitles, audioTracks: [{index: 2, label: "Portuguese"}, {index: 4, label: "English"}], chapters: [{label: "Start", seconds: 0}, {label: "Arrival", seconds: 1200}]}}
end sub

sub PaintMenu()
end sub

sub PaintControls()
end sub

sub PaintSkip()
end sub

sub AssertEqual(actual as Dynamic, expected as Dynamic, description as String)
    if actual <> expected
        print "FAIL: "; description; " expected="; expected; " actual="; actual
        stop
    end if
    m.assertions++
end sub
