' Idle ambient mode: full-screen library artwork that slowly drifts and
' crossfades, with the title's logo and the time. Any key dismisses it.
sub init()
    ' Node IDs carry an "amb" prefix: Scene.FindNode searches breadth-first and
    ' would otherwise return these nodes for the Scene's own meta/clock/title.
    for each id in ["artA", "artB", "shade", "caption", "logo", "title", "meta", "clock", "date", "slideTimer", "clockTimer", "fade", "fadeIn", "fadeOut", "captionFade", "captionTimer", "drift", "driftPan"]
        m[id] = m.top.FindNode("amb" + UCase(Left(id, 1)) + Mid(id, 2))
    end for
    m.items = []
    m.index = -1
    m.shown = invalid
    m.incoming = invalid
    m.leftDrift = false
    m.logo.ObserveField("loadStatus", "FitLogo")
    m.artA.ObserveField("loadStatus", "OnArtLoad")
    m.artB.ObserveField("loadStatus", "OnArtLoad")
    m.slideTimer.ObserveField("fire", "Advance")
    m.clockTimer.ObserveField("fire", "PaintClock")
    m.captionTimer.ObserveField("fire", "SwapCaption")
    if m.shade.HasField("effect")
        effectType = "Effect"
        shade = CreateObject("roSGNode", effectType)
        if shade <> invalid
            if shade.supported
                shade.gradientStyle = "linear"
                shade.gradientAngle = 180
                shade.gradientColors = ["0x00000066", "0x00000000", "0x000000d9"]
                shade.gradientStops = [0.0, 0.35, 1.0]
                m.shade.color = "0x00000000"
                m.shade.effect = shade
            end if
        end if
    end if
end sub

sub OnActive()
    if m.top.active
        m.index = -1
        m.shown = invalid
        m.artA.opacity = 0
        m.artB.opacity = 0
        m.caption.opacity = 0
        PaintClock()
        m.clockTimer.control = "start"
        m.slideTimer.control = "start"
        Advance()
        m.top.SetFocus(true)
    else
        m.slideTimer.control = "stop"
        m.clockTimer.control = "stop"
        m.fade.control = "stop"
        m.drift.control = "stop"
        m.captionTimer.control = "stop"
        ' Release the full-screen bitmaps while browsing.
        m.artA.uri = ""
        m.artB.uri = ""
        m.logo.uri = ""
    end if
end sub

sub OnItems()
    m.items = []
    if IsList(m.top.items)
        for each item in m.top.items
            if IsMap(item)
                if TextValue(item.backdrop) <> "" then m.items.Push(item)
            end if
        end for
    end if
    if m.top.active and m.shown = invalid then Advance()
end sub

sub Advance()
    if not m.top.active or m.items.Count() = 0 then return
    m.attempts = 0
    LoadNext()
end sub

' Loads into the hidden poster; it is revealed only once the bitmap is ready,
' so a slow or broken image never flashes black.
sub LoadNext()
    if m.attempts >= m.items.Count() then return
    m.attempts++
    m.index = (m.index + 1) mod m.items.Count()
    m.pending = m.items[m.index]
    m.incoming = m.artA
    if m.shown <> invalid
        if m.shown.id = m.artA.id then m.incoming = m.artB
    end if
    if m.incoming.uri = m.pending.backdrop and m.incoming.loadStatus = "ready"
        Reveal()
    else
        m.incoming.uri = m.pending.backdrop
    end if
end sub

sub OnArtLoad(event as Object)
    node = event.GetRoSGNode()
    if m.incoming = invalid or not m.top.active then return
    if node.id <> m.incoming.id then return
    status = node.loadStatus
    if status = "ready"
        Reveal()
    else if status = "failed"
        LoadNext()
    end if
end sub

sub Reveal()
    incoming = m.incoming
    outgoing = m.artB
    if incoming.id = m.artB.id then outgoing = m.artA
    m.fade.control = "stop"
    m.drift.control = "stop"
    m.fadeIn.fieldToInterp = incoming.id + ".opacity"
    m.fadeOut.fieldToInterp = outgoing.id + ".opacity"
    m.fadeIn.keyValue = [incoming.opacity, 1.0]
    m.fadeOut.keyValue = [outgoing.opacity, 0.0]
    ' A slow pan across the oversized art, alternating direction per slide. Its
    ' range stays within [-192, 0] × [-108, 0], so the screen is always covered.
    m.leftDrift = not m.leftDrift
    start = [-176, -90]
    finish = [-16, -18]
    if m.leftDrift
        start = [-16, -18]
        finish = [-176, -90]
    end if
    incoming.translation = start
    m.driftPan.keyValue = [start, finish]
    m.driftPan.fieldToInterp = incoming.id + ".translation"
    ' The caption dips out with the old art and returns with the new one.
    m.captionItem = m.pending
    m.captionFade.keyValue = [m.caption.opacity, 0.0, 0.0, 1.0]
    m.captionTimer.control = "stop"
    m.captionTimer.control = "start"
    m.fade.control = "start"
    m.drift.control = "start"
    m.shown = incoming
end sub

sub SwapCaption()
    if IsMap(m.captionItem) then PaintCaption(m.captionItem)
end sub

sub PaintCaption(item as Object)
    logo = TextValue(item.logo)
    m.logo.uri = logo
    m.logo.visible = logo <> ""
    m.title.visible = logo = ""
    m.title.text = TextValue(item.title)
    m.meta.text = TextValue(item.meta)
end sub

' Left-align the title art on its baseline, as on the Home hero.
sub FitLogo()
    if m.logo.loadStatus <> "ready" or m.logo.bitmapWidth <= 0 or m.logo.bitmapHeight <= 0 then return
    scale = 620 / m.logo.bitmapWidth
    if m.logo.bitmapHeight * scale > 180 then scale = 180 / m.logo.bitmapHeight
    m.logo.width = Int(m.logo.bitmapWidth * scale)
    m.logo.height = Int(m.logo.bitmapHeight * scale)
    m.logo.translation = [96, 880 - m.logo.height]
end sub

sub PaintClock()
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    minutes = now.GetMinutes().ToStr()
    if now.GetMinutes() < 10 then minutes = "0" + minutes
    hours = now.GetHours().ToStr()
    if now.GetHours() < 10 then hours = "0" + hours
    m.clock.text = hours + ":" + minutes
    weekdays = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]
    months = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
    m.date.text = weekdays[now.GetDayOfWeek()] + ", " + now.GetDayOfMonth().ToStr() + " de " + months[now.GetMonth() - 1]
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not m.top.active then return false
    if press then m.top.dismissed = true
    return true
end function
