sub Main()
    m.stats = {nodes: 0, fonts: 0, effects: 0, finds: 0, updates: 100}
    m.top = PerfNode("Group")
    m.top.ObserveField = IgnoreObservation
    for each id in ["hud", "controlHint", "menu", "menuPanel", "menuTitle", "menuRows", "menuPage", "timelineFill", "timelineTrack", "playhead", "elapsed", "remaining", "hideTimer", "buttons", "shade", "scrubTimer", "scrubStatus", "pausedIcon", "skipPill", "skipPillBg", "skipPillLabel", "skipScrim", "skipMotion", "skipRise", "skipFade", "skipScrimFade", "messageLabel", "loadingLayer", "loadingArt", "loadingShade", "loadingIndicator", "loadingFadeOut", "upNextCard", "upNextBox", "upNextArt", "upNextTrack", "upNextFill", "upNextLabel", "upNextMotion", "upNextGrow"]
        node = PerfNode("Group")
        node.ObserveField = IgnoreObservation
        m.top.nodes[id] = node
    end for
    init()
    expectedIcons = ["play", "audio", "subtitles", "gear", "film", "list"]
    for index = 0 to 5
        Check(m.buttonNodes[index].icon.uri, AppIconUri(expectedIcons[index]), "player uses matching web icon")
        if index < 5 then Check(m.buttonNodes[index].icon.width, 30, "icons fit inside round controls")
    end for
    Check(m.buttonNodes[5].label.text, "Capítulos", "chapters is a text pill like Apple's lower actions")
    ResetCounts()
    for index = 1 to 100
        m.area = "buttons"
        m.buttonIndex = 1 + index mod 4
        m.top.playbackState = "playing"
        if index mod 2 = 0 then m.top.playbackState = "paused"
        StateChanged()
        PaintControls()
        iconName = "pause"
        label = "Pausar"
        if m.top.playbackState = "paused"
            iconName = "play"
            label = "Reproduzir"
        end if
        Check(m.buttonNodes[0].icon.uri, AppIconUri(iconName), "transport icon follows actual state")
        Check(m.buttonNodes[0].label.text, label, "transport label follows actual state")
        for slot = 0 to 5
            tint = "0xffffffff"
            if slot = m.buttonIndex then tint = "0x111111ff"
            Check(m.buttonNodes[slot].icon.blendColor, tint, "focus tint retains contrast")
            if slot > 0 and slot <> m.buttonIndex then Check(m.buttonNodes[slot].label.color, "0xffffffff", "unfocused labels remain legible")
        end for
    end for
    SetHudVisible(false)
    Check(m.hud.visible, false, "icons are inside hidden HUD")
    Check(m.controlHint.visible, false, "hidden playback remains unobstructed")
    print "MEASURE "; FormatJson(m.stats)
end sub

sub IgnoreObservation(field as String, handler as String)
end sub
