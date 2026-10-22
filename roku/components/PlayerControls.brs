sub init()
    for each id in ["hud", "controlHint", "menu", "menuPanel", "menuTitle", "menuRows", "menuPage", "timelineFill", "timelineTrack", "playhead", "elapsed", "remaining", "hideTimer", "buttons", "scrubTimer", "scrubStatus", "pausedIcon", "skipPill", "skipPillBg", "skipPillLabel", "skipScrim", "skipMotion", "skipRise", "skipFade", "skipScrimFade", "messageLabel", "loadingLayer", "loadingArt", "loadingShade", "loadingIndicator", "loadingFadeOut", "upNextCard", "upNextBox", "upNextArt", "upNextTrack", "upNextFill", "upNextLabel", "upNextMotion", "upNextGrow", "trickFrame", "trickEdge", "trickBack", "trickClip", "trickSheet", "playerTitle", "playerSubtitle"]
        m[id] = m.top.FindNode(id)
    end for
    m.idleEpisodes = 0
    m.scrubbing = false
    m.scrubStarted = false
    m.area = "timeline"
    m.buttonIndex = 2
    m.menuIndex = 0
    m.menuItems = []
    m.names = ["Reproduzir", "Áudio", "Legendas", "Qualidade", "Versão", "Capítulos"]
    m.keys = ["", "audioStreamIndex", "subtitleStreamIndex", "quality", "mediaSourceId", ""]
    ' Apple TV player: icon-only round controls above the timeline on the right,
    ' text pills below it on the left. Play/pause is the OK key, not a button.
    m.buttonNodes = []
    iconNames = ["play", "audio", "subtitles", "gear", "film", "list"]
    for index = 0 to 5
        group = m.buttons.CreateChild("Group")
        bg = group.CreateChild("Rectangle")
        label = group.CreateChild("Label")
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.text = m.names[index]
        if index = 5
            group.translation = [80, 972]
            bg.width = 200
            bg.height = 56
            ApplyRounded(bg, 28)
            label.width = 200
            label.height = 56
            SetControlFont(label, 23, "SemiBold")
            icon = CreateAppIcon(group, iconNames[index], 0, 0, 1)
            icon.visible = false
        else
            bg.width = 66
            bg.height = 66
            ApplyRounded(bg, 33)
            label.visible = false
            icon = CreateAppIcon(group, iconNames[index], 18, 18, 30)
        end if
        if index = 0 or index = 5 then group.visible = false
        m.buttonNodes.Push({group: group, bg: bg, label: label, icon: icon})
    end for
    LayoutCircles()
    ' Outside the HUD so the pill can appear over unobstructed video.
    m.segments = []
    m.activeSegment = invalid
    m.skipVisible = false
    m.skipShown = false
    ApplyRounded(m.skipPillBg, 32)
    ApplyRounded(m.upNextBox, 12)
    ApplyRounded(m.upNextArt, 12)
    ApplyRounded(m.upNextTrack, 3)
    ApplyRounded(m.upNextFill, 3)
    m.skipMotion.ObserveField("state", "OnSkipMotion")
    m.loadingFadeOut.ObserveField("state", "OnLoadingFaded")
    shade = m.top.FindNode("shade")
    if shade.HasField("effect")
        effectType = "Effect"
        fade = CreateObject("roSGNode", effectType)
        if fade <> invalid
            if fade.supported
                fade.gradientStyle = "linear"
                fade.gradientAngle = 180
                fade.gradientColors = ["0x00000000", "0x000000a6", "0x000000eb"]
                fade.gradientStops = [0.0, 0.4, 1.0]
                shade.color = "0x00000000"
                shade.effect = fade
            end if
        end if
    end if
    ApplyRounded(m.menuPanel, 30)
    ApplyRounded(m.timelineTrack, 4)
    ApplyRounded(m.timelineFill, 4)
    m.hideTimer.ObserveField("fire", "HideHud")
    m.scrubTimer.ObserveField("fire", "OnScrubTick")
    m.top.ObserveField("visible", "VisibilityChanged")
    PaintControls()
end sub

sub SetControlFont(label as Object, size as Integer, weight = "Regular" as String)
    if m.controlFonts = invalid then m.controlFonts = {}
    key = weight + size.ToStr()
    font = m.controlFonts[key]
    if font = invalid
        font = CreateObject("roSGNode", "Font")
        font.uri = "pkg:/fonts/Inter-" + weight + ".ttf"
        font.size = size
        m.controlFonts[key] = font
    end if
    label.font = font
end sub

sub OptionsChanged()
    CancelScrub(false)
    m.menu.visible = false
    m.area = "timeline"
    m.menuItems = []
    m.buttonNodes[5].group.visible = false
    m.buttonNodes[4].group.visible = false
    if IsMap(m.top.options)
        if IsList(m.top.options.chapters) then m.buttonNodes[5].group.visible = m.top.options.chapters.Count() > 0
        ' Apple shows no control for a choice that does not exist.
        if IsList(m.top.options.mediaSources) then m.buttonNodes[4].group.visible = m.top.options.mediaSources.Count() > 1
    end if
    if not CircleVisible(m.buttonIndex) then m.buttonIndex = 2
    LayoutCircles()
    PaintControls()
end sub

sub StateChanged()
    if m.top.playbackState = "error" or m.top.playbackState = "stopped" or m.top.playbackState = "finished" then CancelScrub(false)
    NoteDecoderState()
    if m.top.playbackState = "playing" then m.hasPlayed = true
    m.buttonNodes[0].label.text = "Pausar"
    iconName = "pause"
    if m.top.playbackState = "paused"
        m.buttonNodes[0].label.text = "Reproduzir"
        iconName = "play"
    end if
    m.buttonNodes[0].icon.uri = AppIconUri(iconName)
    if m.pausedIcon <> invalid then m.pausedIcon.visible = m.top.playbackState = "paused"
    if m.top.playbackState = "paused"
        ShowHud()
        m.hideTimer.control = "stop"
    else if m.top.playbackState = "playing" and m.scrubbing <> true
        m.hideTimer.control = "start"
    end if
    UpdateSkip()
    UpdateLoading()
end sub

' The pause a hold asks for is not the viewer pausing; anything else the
' decoder reports after a seek replaces that seek's intent.
sub NoteDecoderState()
    if m.top.playbackState = "paused" and m.awaitingScrubPause = true
        m.awaitingScrubPause = false
    else if m.top.playbackState = "playing" or m.top.playbackState = "paused"
        m.stateSinceSeek = true
    end if
end sub

function ClockLabel(seconds as Float) as String
    seconds = Int(seconds)
    if seconds < 0 then seconds = 0
    minutes = Int(seconds / 60)
    remainder = seconds mod 60
    suffix = remainder.ToStr()
    if remainder < 10 then suffix = "0" + suffix
    if minutes < 60 then return minutes.ToStr() + ":" + suffix
    minutePart = (minutes mod 60).ToStr()
    if minutes mod 60 < 10 then minutePart = "0" + minutePart
    return Int(minutes / 60).ToStr() + ":" + minutePart + ":" + suffix
end function

sub UpdateTimeline()
    position = DisplayedPosition()
    if m.scrubbing = true then position = m.scrubTarget
    progress = 0.0
    if m.top.duration > 0 then progress = position / m.top.duration
    if progress < 0 then progress = 0
    if progress > 1 then progress = 1
    m.timelineFill.width = 1760 * progress
    x = 80 + 1756 * progress
    m.playhead.translation = [x, 892]
    ' Apple's elapsed time rides under the playhead.
    labelX = x - 20
    if labelX < 80 then labelX = 80
    if labelX > 1560 then labelX = 1560
    m.elapsed.translation = [labelX, 920]
    if m.pausedIcon <> invalid then m.pausedIcon.translation = [labelX + Len(ClockLabel(position)) * 14 + 8, 925]
    m.elapsed.text = ClockLabel(position)
    m.remaining.text = "-" + ClockLabel(m.top.duration - position)
    PaintTrickplay(position, x)
    PlaceScrubStatus(x)
    UpdateSkip()
end sub

' The speed rides above the preview (or the playhead), clear of the times.
sub PlaceScrubStatus(playheadX as Float)
    if m.scrubHeld <> true then return
    top = 836
    if m.trickFrame <> invalid
        if m.trickFrame.visible then top = m.trickFrame.translation[1] - 48
    end if
    left = Int(playheadX - 270)
    if left < 80 then left = 80
    if left > 1300 then left = 1300
    m.scrubStatus.translation = [left, top]
end sub

' Apple TV's scrubbing preview: the frame at the target, above the playhead.
' Jellyfin packs the frames into sheets; the clip shows one cell.
sub PaintTrickplay(position as Float, playheadX as Float)
    if m.trickFrame = invalid then return
    info = m.top.trickplay
    show = m.scrubbing = true and m.scrubHeld = true and IsMap(info)
    if show then show = info.frames <> invalid and info.frames > 0
    m.trickFrame.visible = show
    if not show then return
    width = info.width
    height = info.height
    size = width.ToStr() + "x" + height.ToStr()
    if m.trickSize <> size
        m.trickSize = size
        m.trickEdge.width = width + 6
        m.trickEdge.height = height + 6
        m.trickBack.width = width
        m.trickBack.height = height
        m.trickClip.clippingRect = [0, 0, width, height]
        m.trickSheet.width = width * info.tileWidth
        m.trickSheet.height = height * info.tileHeight
    end if
    index = Int(position * 1000 / info.interval)
    if index >= info.frames then index = info.frames - 1
    if index < 0 then index = 0
    perSheet = info.tileWidth * info.tileHeight
    cell = index mod perSheet
    uri = info.prefix + Int(index / perSheet).ToStr() + info.suffix
    if m.trickSheet.uri <> uri then m.trickSheet.uri = uri
    m.trickSheet.translation = [-(cell mod info.tileWidth) * width, -Int(cell / info.tileWidth) * height]
    x = Int(playheadX - width / 2)
    if x < 80 then x = 80
    if x > 1840 - width then x = 1840 - width
    m.trickFrame.translation = [x, 870 - height]
end sub

sub ShowHud()
    SetHudVisible(true)
    if m.scrubbing <> true then m.hideTimer.control = "start"
end sub

sub HideHud()
    if m.scrubbing = true or m.menu.visible or m.top.busy or m.top.playbackState <> "playing" then return
    SetHudVisible(false)
    m.area = "timeline"
end sub

sub PaintControls()
    for index = 0 to m.buttonNodes.Count() - 1
        node = m.buttonNodes[index]
        focused = m.area = "buttons" and index = m.buttonIndex
        if index = 5 then focused = m.area = "pills"
        node.bg.color = "0xffffff2e"
        node.label.color = "0xffffffff"
        node.icon.blendColor = "0xffffffff"
        if focused
            node.bg.color = "0xffffffff"
            node.label.color = "0x111111ff"
            node.icon.blendColor = "0x111111ff"
        end if
    end for
    m.timelineTrack.height = 8
    if m.area = "timeline" then m.timelineTrack.height = 10
end sub

' Round controls are right-aligned; hidden ones close the gap.
sub LayoutCircles()
    visible = []
    for index = 1 to 4
        if CircleVisible(index) then visible.Push(index)
    end for
    for slot = 0 to visible.Count() - 1
        node = m.buttonNodes[visible[slot]]
        if IsMap(node) and node.group <> invalid then node.group.translation = [1840 - 66 - (visible.Count() - 1 - slot) * 94, 802]
    end for
end sub

function CircleVisible(index as Integer) as Boolean
    if index < 1 or index > 4 then return false
    node = m.buttonNodes[index]
    if not IsMap(node) then return false
    if node.group = invalid then return true
    return node.group.visible <> false
end function

function ChaptersVisible() as Boolean
    node = m.buttonNodes[5]
    if not IsMap(node) then return false
    if node.group = invalid then return false
    return node.group.visible = true
end function

sub OpenOptions()
    options = m.top.options
    if not IsMap(options) then return
    if not IsMap(options.selection) then return
    m.menuItems = []
    if m.buttonIndex = 0
        m.top.action = {kind: "toggle"}
        return
    else if m.buttonIndex = 1
        for each track in options.audioTracks
            m.menuItems.Push({value: track.index, label: track.label})
        end for
    else if m.buttonIndex = 2
        m.menuItems.Push({value: -1, label: "Desativadas"})
        for each track in options.subtitleTracks
            m.menuItems.Push({value: track.index, label: track.label})
        end for
    else if m.buttonIndex = 3
        for each quality in options.qualityOptions
            m.menuItems.Push({value: quality.id, label: quality.label})
        end for
    else if m.buttonIndex = 4
        for each version in options.mediaSources
            m.menuItems.Push({value: version.id, label: version.label})
        end for
    else
        for each chapter in options.chapters
            m.menuItems.Push({value: chapter.seconds, label: chapter.label + " · " + ClockLabel(chapter.seconds)})
        end for
    end if
    m.menuIndex = 0
    selected = options.selection[m.keys[m.buttonIndex]]
    if m.buttonIndex = 5
        for each chapter in options.chapters
            if chapter.seconds <= m.top.position then selected = chapter.seconds
        end for
    end if
    m.menuSelected = selected
    for index = 0 to m.menuItems.Count() - 1
        if m.menuItems[index].value = selected then m.menuIndex = index
    end for
    m.menuTitle.text = m.names[m.buttonIndex]
    ' Menus grow upward from the control that opened them.
    trigger = m.buttonNodes[m.buttonIndex].group
    if m.buttonIndex = 5
        m.menu.translation = [80, 462]
    else if trigger <> invalid
        if trigger.translation <> invalid
            x = trigger.translation[0] + 66 - 660
            if x < 80 then x = 80
            m.menu.translation = [x, 290]
        end if
    end if
    m.menu.visible = true
    m.area = "menu"
    PaintMenu()
    PaintControls()
end sub

sub PaintMenu()
    ' Five stable viewport rows: moving focus changes fields, not the SG tree.
    if m.menuRowNodes = invalid
        m.menuRowNodes = []
        for slot = 0 to 4
            group = m.menuRows.CreateChild("Group")
            group.translation = [0, slot * 70]
            bg = group.CreateChild("Rectangle")
            bg.width = 628
            bg.height = 62
            ApplyRounded(bg, 14)
            label = group.CreateChild("Label")
            label.translation = [22, 0]
            label.width = 530
            label.height = 62
            label.vertAlign = "center"
            SetControlFont(label, 25)
            check = CreateAppIcon(group, "check", 576, 17, 28)
            m.menuRowNodes.Push({group: group, bg: bg, label: label, check: check})
        end for
    end if
    first = Int(m.menuIndex / 5) * 5
    for slot = 0 to 4
        row = m.menuRowNodes[slot]
        index = first + slot
        row.group.visible = index < m.menuItems.Count()
        if row.group.visible
            option = m.menuItems[index]
            row.label.text = option.label
            row.check.visible = option.value = m.menuSelected
            row.check.blendColor = "0xffffffff"
            row.bg.color = "0x00000000"
            row.label.color = "0xffffffff"
            if index = m.menuIndex
                row.bg.color = "0xffffffff"
                row.label.color = "0x111111ff"
                row.check.blendColor = "0x111111ff"
            end if
        end if
    end for
    m.menuPage.text = ""
    if m.menuItems.Count() = 0 then m.menuPage.text = "Nenhuma faixa disponível nesta versão"
    if m.menuItems.Count() > 5 then m.menuPage.text = (m.menuIndex + 1).ToStr() + " de " + m.menuItems.Count().ToStr()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press then m.idleEpisodes = 0
    if not press
        if m.scrubbing = true and key = m.scrubKey
            CommitScrub()
            return true
        end if
        return false
    end if
    if m.scrubbing = true
        if key = m.scrubKey then return true
        if key = "left" or key = "right" or key = "rewind" or key = "fastforward"
            BeginScrub(key, false)
        else if key = "OK" or key = "play"
            CommitScrub()
        else
            CancelScrub(true)
        end if
        return true
    end if
    if key = "back" or (key = "options" and m.menu.visible)
        if key = "back" and OfferingNext() and not m.hud.visible
            ' Back keeps watching the credits; it never starts the next one.
            m.nextDismissed = true
            UpdateSkip()
        else if m.menu.visible
            m.menu.visible = false
            m.area = TriggerArea()
            PaintControls()
        else if m.hud.visible
            SetHudVisible(false)
        else
            m.top.action = {kind: "exit"}
        end if
        return true
    end if
    ' Like Plex and Apple TV, one OK press skips while the pill floats over video.
    if key = "OK" and m.skipVisible = true and not m.hud.visible and m.top.busy <> true
        SkipSegment()
        return true
    end if
    wasHidden = not m.hud.visible
    ShowHud()
    if wasHidden and (key = "up" or key = "down" or key = "left" or key = "right" or key = "OK")
        m.area = "timeline"
        ' An offered skip keeps focus when the controls appear, so OK still skips.
        if m.skipVisible = true and (key = "up" or key = "down") then m.area = "skip"
        if (key = "left" or key = "right") and not m.top.busy then BeginScrub(key, true)
        PaintControls()
        return true
    end if
    if m.top.busy then return true
    if key = "options"
        if m.buttonIndex = 0 then m.buttonIndex = 2
        OpenOptions()
    else if m.area = "menu"
        if key = "up" and m.menuIndex > 0
            m.menuIndex--
        else if key = "down" and m.menuIndex < m.menuItems.Count() - 1
            m.menuIndex++
        else if key = "OK" and m.menuItems.Count() > 0
            option = m.menuItems[m.menuIndex]
            field = m.keys[m.buttonIndex]
            m.menu.visible = false
            m.area = TriggerArea()
            if m.buttonIndex = 5
                RequestSeek(option.value, PlayIntent())
            else if option.value <> m.top.options.selection[field]
                m.top.action = {kind: "selection", field: field, value: option.value}
            end if
        end if
        if m.menu.visible then PaintMenu()
    else if key = "play"
        m.top.action = {kind: "toggle"}
    else if key = "replay"
        target = DisplayedPosition() - 10
        if target < 0 then target = 0
        RequestSeek(target, PlayIntent())
    else if key = "rewind" or key = "fastforward"
        BeginScrub(key, false)
    else if m.area = "timeline"
        if key = "up"
            if not CircleVisible(m.buttonIndex) then m.buttonIndex = 2
            m.area = "buttons"
        else if key = "left" or key = "right"
            BeginScrub(key, false)
        else if key = "OK"
            m.top.action = {kind: "toggle"}
        else if key = "down" and m.skipVisible = true
            m.area = "skip"
        else if key = "down" and ChaptersVisible()
            m.area = "pills"
        else if key = "down"
            SetHudVisible(false)
        end if
    else if m.area = "skip"
        if key = "OK"
            SkipSegment()
        else if key = "up"
            m.area = "timeline"
        else if key = "left" or key = "right"
            ' Skip sits in for the timeline, so arrows still rewind and advance.
            BeginScrub(key, false)
        else if key = "down" and ChaptersVisible()
            m.area = "pills"
        end if
    else if m.area = "pills"
        if key = "OK"
            m.buttonIndex = 5
            OpenOptions()
        else if key = "up"
            m.area = "timeline"
        else if key = "right" and m.skipVisible = true
            m.area = "skip"
        end if
    else
        if key = "left"
            for index = m.buttonIndex - 1 to 1 step -1
                if CircleVisible(index)
                    m.buttonIndex = index
                    exit for
                end if
            end for
        else if key = "right"
            for index = m.buttonIndex + 1 to 4
                if CircleVisible(index)
                    m.buttonIndex = index
                    exit for
                end if
            end for
        else if key = "down"
            m.area = "timeline"
        else if key = "OK" or key = "up"
            OpenOptions()
        end if
    end if
    PaintControls()
    PaintSkip()
    return true
end function

sub SetHudVisible(visible as Boolean)
    m.hud.visible = visible
    if m.controlHint <> invalid then m.controlHint.visible = false
    UpdateSkip()
end sub

sub SegmentsChanged()
    m.segments = []
    m.activeSegment = invalid
    m.skipTarget = invalid
    ' A new episode gets its own offer and countdown.
    m.seekTarget = invalid
    m.stateSinceSeek = invalid
    m.landedAt = invalid
    m.lastPlayed = invalid
    m.nextDismissed = false
    m.nextShownAt = invalid
    m.nextCounted = false
    m.nextFired = false
    if IsList(m.top.segments)
        for each segment in m.top.segments
            if IsMap(segment)
                if segment.startTime <> invalid and segment.endTime <> invalid then m.segments.Push(segment)
            end if
        end for
    end if
    UpdateSkip()
end sub

function SkipSegmentAt(position as Float) as Dynamic
    duration = 0
    if m.top.duration <> invalid then duration = m.top.duration
    offerNext = m.top.hasNextEpisode = true and m.nextDismissed <> true and m.scrubbing <> true
    for each segment in m.segments
        if position >= segment.startTime and position < segment.endTime - 1
            kind = TextValue(segment.kind)
            credits = (kind = "Outro" or kind = "Preview") and duration > 0
            if credits and segment.endTime >= duration - 5
                ' Skipping credits that run to the end would only end the file;
                ' like Netflix, they lead to the next episode instead.
                if offerNext and PlayedInto(segment.startTime) then return {kind: "Next", startTime: segment.startTime, endTime: segment.endTime}
            else if m.skipTarget = invalid or segment.endTime <> m.skipTarget
                if kind = "Intro" or kind = "Recap" or credits then return segment
            end if
        end if
    end for
    ' Without a credits marker the next episode is offered for the last 20 s.
    if offerNext and duration > 20 and position >= duration - 20 and PlayedInto(duration - 20) then return {kind: "Next", startTime: duration - 20, endTime: duration}
    return invalid
end function

' Someone who seeks or scrubs to the end is looking for something, not
' finishing: the next episode is offered only after at least 10 s of watching
' carried playback into the credits.
function PlayedInto(start as Float) as Boolean
    if m.landedAt = invalid then return false
    return m.landedAt <= start - 10
end function

' Positions arrive about once a second. Anything else is a seek, and where it
' landed decides whether the credits are reached by watching.
sub NotePlayback(position as Float)
    if m.lastPlayed = invalid or position < m.lastPlayed - 1 or position > m.lastPlayed + 5 then m.landedAt = position
    m.lastPlayed = position
end sub

function OfferingNext() as Boolean
    if m.skipVisible <> true or m.activeSegment = invalid then return false
    return TextValue(m.activeSegment.kind) = "Next"
end function

' Like Netflix, the next episode starts 10 s after it is offered, unless three
' have already started that way without anyone touching the remote. Returns
' true when it is time to start it.
function UpdateCountdown(offered as Boolean, position as Float, state as String) as Boolean
    if not offered
        m.nextShownAt = invalid
        m.nextLeft = invalid
        m.top.upNextArmed = false
        return false
    end if
    if m.nextShownAt = invalid or position < m.nextShownAt
        m.nextShownAt = position
        if m.nextCounted <> true
            m.nextCounted = true
            m.nextAuto = m.idleEpisodes < 3
            m.idleEpisodes++
        end if
    end if
    m.nextLeft = 10 - (position - m.nextShownAt)
    m.top.upNextArmed = m.nextAuto = true
    if m.nextAuto <> true or m.nextFired = true or m.nextLeft > 0 then return false
    if state <> "playing" or m.scrubbing = true or m.menu.visible then return false
    m.nextFired = true
    return true
end function

' Like Netflix and Apple TV, the pill stays for the whole segment so Skip is
' always one OK away.
sub UpdateSkip()
    if m.segments = invalid then return
    position = DisplayedPosition()
    if m.skipTarget <> invalid
        if position >= m.skipTarget - 1 then m.skipTarget = invalid
    end if
    state = TextValue(m.top.playbackState)
    if m.scrubbing <> true and (state = "playing" or state = "paused") then NotePlayback(position)
    ' While scrubbing the pill follows the preview, so taps do not make it bob.
    if m.scrubbing = true then position = m.scrubTarget
    segment = invalid
    if m.top.busy <> true and (state = "playing" or state = "paused") then segment = SkipSegmentAt(position)
    offered = false
    if segment <> invalid then offered = TextValue(segment.kind) = "Next"
    startNext = UpdateCountdown(offered, position, state)
    m.activeSegment = segment
    visible = segment <> invalid
    area = m.area
    if not visible and m.area = "skip" then m.area = "timeline"
    ' Like Netflix, a skip offered during playback takes focus from the timeline.
    if visible and m.skipVisible <> true and m.area = "timeline" and m.scrubbing <> true then m.area = "skip"
    m.skipVisible = visible
    if m.area <> area then PaintControls()
    PaintSkip()
    ' Last, because starting the next episode updates these controls again.
    if startNext then m.top.action = {kind: "nextEpisode"}
end sub

sub SkipSegment()
    if m.activeSegment = invalid then return
    if TextValue(m.activeSegment.kind) = "Next"
        m.top.action = {kind: "nextEpisode"}
        return
    end if
    m.skipTarget = m.activeSegment.endTime
    m.activeSegment = invalid
    if m.area = "skip" then m.area = "timeline"
    RequestSeek(m.skipTarget, PlayIntent())
    UpdateSkip()
end sub

' A seek takes a moment to land, and until it does the decoder keeps reporting
' where it was. Until a report arrives nearer the target than that (or 10 s
' pass), the target is what the timeline shows and where the next press
' starts, so the playhead never snaps back and quick presses add up.
sub RequestSeek(target as Float, resume as Boolean)
    reported = 0
    if m.top.position <> invalid then reported = m.top.position
    m.seekTarget = invalid
    m.seekIntent = resume
    m.stateSinceSeek = false
    if Abs(target - reported) >= 1
        m.seekTarget = target
        m.seekFrom = reported
        m.seekResume = resume
        if m.seekClock = invalid then m.seekClock = CreateObject("roTimespan")
        m.seekClock.Mark()
    end if
    m.top.action = {kind: "seekTo", seconds: target, resumeAfterSeek: resume}
end sub

function DisplayedPosition() as Dynamic
    position = 0
    if m.top.position <> invalid then position = m.top.position
    if m.seekTarget = invalid then return position
    if Abs(position - m.seekTarget) < Abs(position - m.seekFrom) or m.seekClock.TotalMilliseconds() > 10000
        m.seekTarget = invalid
        return position
    end if
    return m.seekTarget
end function

' Whether playback should run after a seek: while one is still landing the
' decoder reads "buffering" or "paused", and some players never report
' "playing" again after resuming from one, so the last seek's intent stands
' until the decoder reports a state of its own.
function PlayIntent() as Boolean
    if m.seekTarget <> invalid then return m.seekResume = true
    if m.stateSinceSeek = false then return m.seekIntent = true
    return m.top.playbackState <> "paused"
end function

function TriggerArea() as String
    if m.buttonIndex = 5 then return "pills"
    return "buttons"
end function

function SkipLabel(kind as String) as String
    if kind = "Next" then return "Próximo episódio"
    if kind = "Recap" then return "Pular recapitulação"
    if kind = "Outro" then return "Pular créditos"
    if kind = "Preview" then return "Pular prévia"
    return "Pular abertura"
end function

sub PaintSkip()
    if m.skipPill = invalid then return
    if m.skipVisible <> m.skipShown then AnimateSkip(m.skipVisible)
    ' Over bare video the scrim lifts the pill; the HUD brings its own shade.
    m.skipScrim.visible = m.skipShown and not m.hud.visible
    if not m.skipVisible then return
    kind = TextValue(m.activeSegment.kind)
    m.skipPillLabel.text = SkipLabel(kind)
    if kind = "Next" and m.nextAuto = true and m.nextLeft <> invalid
        left = Int(m.nextLeft + 0.999)
        if left < 1 then left = 1
        m.skipPillLabel.text = "Próximo episódio em " + left.ToStr()
    end if
    PaintUpNext(kind = "Next")
    ' Floating over video it is the only control, so it carries focus.
    focused = not m.hud.visible or m.area = "skip"
    m.skipPillBg.color = "0xffffff2e"
    m.skipPillLabel.color = "0xffffffff"
    if focused
        m.skipPillBg.color = "0xffffffff"
        m.skipPillLabel.color = "0x111111ff"
    end if
end sub

' Over the HUD only the pill shows; the card would cover the timeline.
sub PaintUpNext(offered as Boolean)
    info = m.top.upNext
    card = offered and IsMap(info) and not m.hud.visible
    m.upNextCard.visible = card
    if not card then return
    image = TextValue(info.image)
    if m.upNextArt.uri <> image then m.upNextArt.uri = image
    m.upNextLabel.text = TextValue(info.label)
    counting = m.nextAuto = true and m.nextLeft <> invalid
    m.upNextTrack.visible = counting
    m.upNextFill.visible = counting
    if not counting then return
    fraction = (10 - m.nextLeft) / 10
    if fraction < 0 then fraction = 0
    if fraction > 1 then fraction = 1
    if fraction = 0
        m.upNextMotion.control = "stop"
        m.upNextFill.width = 0
        m.upNextTarget = 0
        return
    end if
    ' Position arrives once a second; the bar glides between those steps.
    target = 316 * fraction
    if m.upNextTarget = target then return
    m.upNextTarget = target
    m.upNextMotion.control = "stop"
    m.upNextGrow.keyValue = [m.upNextFill.width, target]
    m.upNextMotion.control = "start"
end sub

' The pill rises from below the frame and sinks back when the segment ends.
sub AnimateSkip(show as Boolean)
    m.skipShown = show
    m.skipMotion.control = "stop"
    target = [1500, 1080]
    opacity = 0.0
    m.skipMotion.duration = 0.25
    m.skipMotion.easeFunction = "inCubic"
    if show
        target = [1500, 968]
        opacity = 1.0
        m.skipMotion.duration = 0.5
        m.skipMotion.easeFunction = "outQuintic"
        m.skipPill.visible = true
    end if
    m.skipRise.keyValue = [m.skipPill.translation, target]
    m.skipFade.keyValue = [m.skipPill.opacity, opacity]
    m.skipScrimFade.keyValue = [m.skipScrim.opacity, opacity]
    m.skipMotion.control = "start"
end sub

sub OnSkipMotion()
    if m.skipMotion.state = "stopped" and not m.skipShown then m.skipPill.visible = false
end sub

sub VisibilityChanged()
    CancelScrub(false)
    m.hasPlayed = false
    if m.loadingLayer <> invalid
        if m.top.visible
            PaintLoadingArt()
        else
            m.loadingIndicator.control = "stop"
            m.loadingLayer.visible = false
        end if
    end if
    if m.top.visible
        m.menu.visible = false
        m.area = "timeline"
        ShowHud()
        PaintControls()
    else
        m.hideTimer.control = "stop"
        m.idleEpisodes = 0
        m.seekTarget = invalid
        m.stateSinceSeek = invalid
    end if
end sub

' Hold movement only paints a target. The decoder receives one absolute seek
' when released, so long holds do not repeatedly flush buffers/transcode jobs.
sub BeginScrub(key as String, revealOnly as Boolean)
    if m.top.duration <= 0 then return
    ' Buffering follows every seek, so a quick second press must still count.
    state = m.top.playbackState
    if state <> "playing" and state <> "paused" and state <> "buffering" then return
    if m.scrubbing <> true
        m.scrubTarget = DisplayedPosition()
        m.scrubResume = PlayIntent()
        m.scrubStarted = false
        m.scrubHeld = false
        m.scrubPaused = false
    end if
    m.scrubbing = true
    m.scrubKey = key
    m.scrubDirection = 1
    if key = "left" or key = "rewind" then m.scrubDirection = -1
    if m.scrubClock = invalid then m.scrubClock = CreateObject("roTimespan")
    m.scrubClock.Mark()
    m.scrubLastStep = 0
    m.area = "timeline"
    m.hideTimer.control = "stop"
    m.scrubTimer.control = "start"
    if not revealOnly then MoveScrubTarget(10)
end sub

function ScrubElapsedMs() as Integer
    return m.scrubClock.TotalMilliseconds()
end function

sub OnScrubTick()
    if m.scrubbing <> true then return
    if not m.top.visible or m.top.busy
        CancelScrub(false)
        return
    end if
    elapsed = ScrubElapsedMs()
    if elapsed < 450 or elapsed - m.scrubLastStep < 180 then return
    m.scrubLastStep = elapsed
    if m.scrubHeld <> true
        m.scrubHeld = true
        ShowScrubChrome(true)
    end if
    MoveScrubTarget(ScrubIncrement(elapsed))
end sub

' A held scrub swaps the title and buttons for the preview and its speed, as
' on Apple TV; a tap is just a 10 s jump.
sub ShowScrubChrome(held as Boolean)
    if m.playerTitle = invalid then return
    m.playerTitle.visible = not held
    m.playerSubtitle.visible = not held
    m.buttons.visible = not held
end sub

' Holding keeps speeding up, doubling every 1.2 s after the first 1.5 s. A long
' video gets a higher top speed: about 36 steps cross the whole file, never
' less than a minute per step, so a film takes no longer than an episode.
function ScrubIncrement(elapsed as Integer) as Integer
    if elapsed < 1500 then return 10
    increment = 10 * 2 ^ ((elapsed - 1500) / 1200)
    limit = m.top.duration / 36
    if limit < 60 then limit = 60
    if increment > limit then increment = limit
    return Int(increment / 10 + 0.5) * 10
end function

function StepLabel(seconds as Integer) as String
    if seconds < 60 then return seconds.ToStr() + " s"
    label = Int(seconds / 60).ToStr() + " min"
    if seconds mod 60 > 0 then label += " " + (seconds mod 60).ToStr() + " s"
    return label
end function

sub MoveScrubTarget(increment as Integer)
    m.scrubStarted = true
    ' Only a hold pauses, so the preview holds still; a tap just seeks.
    if m.scrubHeld = true and m.scrubPaused <> true
        m.scrubPaused = true
        m.awaitingScrubPause = true
        m.top.action = {kind: "scrubStart"}
    end if
    m.scrubTarget += increment * m.scrubDirection
    if m.scrubTarget < 0 then m.scrubTarget = 0
    maximum = m.top.duration - 1
    if maximum < 0 then maximum = 0
    if m.scrubTarget > maximum then m.scrubTarget = maximum
    direction = "Avançando"
    if m.scrubDirection < 0 then direction = "Voltando"
    m.scrubStatus.text = direction + " · " + StepLabel(increment) + " por passo"
    m.scrubStatus.visible = m.scrubHeld = true
    UpdateTimeline()
end sub

sub ClearScrub()
    m.scrubbing = false
    m.scrubStarted = false
    if m.scrubHeld = true then ShowScrubChrome(false)
    m.scrubHeld = false
    if m.trickFrame <> invalid then m.trickFrame.visible = false
    if m.scrubTimer <> invalid then m.scrubTimer.control = "stop"
    if m.scrubStatus <> invalid then m.scrubStatus.visible = false
end sub

sub CommitScrub()
    if m.scrubbing <> true then return
    started = m.scrubStarted
    target = m.scrubTarget
    resume = m.scrubResume
    ClearScrub()
    if started then RequestSeek(target, resume)
    ShowHud()
    PaintControls()
end sub

sub CancelScrub(restore as Boolean)
    if m.scrubbing <> true then return
    paused = m.scrubPaused = true
    resume = m.scrubResume
    ClearScrub()
    UpdateTimeline()
    if restore and paused then m.top.action = {kind: "scrubCancel", resume: resume}
end sub

sub BusyChanged()
    if m.top.busy then CancelScrub(false)
    UpdateSkip()
    UpdateLoading()
end sub

sub MessageChanged()
    m.messageLabel.text = m.top.message
    UpdateLoading()
end sub

sub ArtworkChanged()
    m.loadingArt.uri = m.top.artwork
end sub

' Starting, switching tracks and rebuffering show the indicator over the frame;
' only a new title's first load shows its art. Errors stay in the HUD text.
sub UpdateLoading()
    if m.loadingLayer = invalid then return
    loading = m.top.busy = true or TextValue(m.top.playbackState) = "buffering"
    m.messageLabel.visible = not loading
    if loading
        m.loadingIndicator.text = m.top.message
        if m.loadingLayer.visible and m.loadingLayer.opacity = 1 then return
        PaintLoadingArt()
        m.loadingFadeOut.control = "stop"
        m.loadingLayer.opacity = 1
        m.loadingLayer.visible = true
        m.loadingIndicator.control = "start"
    else if m.loadingLayer.visible and m.loadingIndicator.control = "start"
        m.loadingIndicator.control = "stop"
        m.loadingFadeOut.control = "start"
    end if
end sub

' Decided when loading begins, so the art cannot drop out the frame before the
' layer fades on the first "playing".
sub PaintLoadingArt()
    m.loadingArt.visible = TextValue(m.top.artwork) <> "" and m.hasPlayed <> true
    m.loadingShade.opacity = 0.4
    if m.loadingArt.visible then m.loadingShade.opacity = 0.62
end sub

sub OnLoadingFaded()
    if m.loadingFadeOut.state = "stopped" and m.loadingIndicator.control = "stop" then m.loadingLayer.visible = false
end sub
