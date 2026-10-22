sub init()
    for each id in ["card", "shadow", "title", "poster", "placeholder", "fallback", "track", "progress", "focusMotion", "focusScale", "titleShade", "titleArt", "titleName", "badge", "badgeBg", "badgeCheck", "badgeCount", "initials", "role"]
        m[id] = m.top.FindNode(id)
    end for
    ' RowList recycles each component across many content nodes. Effects and
    ' node references belong to the component, not to each content binding.
    ApplyRounded(m.poster, 12)
    ApplyRounded(m.placeholder, 12)
    ApplyRounded(m.titleShade, 12)
    ApplyRounded(m.badgeBg, 17)
    m.titleArt.ObserveField("loadStatus", "OnTitleArt")
end sub

sub ShowCard()
    content = m.top.itemContent
    if content = invalid then return
    width = 340
    height = 191
    person = content.person = true
    if content.portrait = true
        width = 200
        height = 300
    else if person
        width = 176
        height = 176
    end if
    if m.cardWidth <> width or m.cardHeight <> height
        m.cardWidth = width
        m.cardHeight = height
        ' Apple TV's cast row: round portraits, the name centred underneath.
        radius = 12
        if person then radius = width / 2
        SetRadius(m.poster, radius)
        SetRadius(m.placeholder, radius)
        m.title.horizAlign = "left"
        m.card.translation = [12, 12]
        if person
            ' The slot is wider than the portrait so the lifted name never
            ' crosses the shelf edge.
            m.title.horizAlign = "center"
            m.card.translation = [24, 12]
        end if
        m.card.scaleRotateCenter = [width / 2, height / 2]
        m.shadow.width = width + 96
        m.shadow.height = height + 96
        m.shadow.uri = "pkg:/images/card-shadow-landscape.png"
        if content.portrait = true then m.shadow.uri = "pkg:/images/card-shadow-portrait.png"
        m.poster.width = width
        m.poster.height = height
        ' Decode at the focused width, not the download's: 4 bytes per pixel of
        ' texture memory on the TV, with no visible difference at 1080p. Width
        ' alone keeps the image's own shape (a 2:3 portrait in a round cast
        ' photo, a 4:3 episode still); the display mode then crops it.
        m.poster.loadWidth = Int(width * 1.07 + 0.5)
        m.poster.loadHeight = 0
        m.placeholder.width = width
        m.placeholder.height = height
        m.fallback.width = width - 48
        m.fallback.translation = [24, (height - 80) / 2]
        m.track.translation = [0, height - 6]
        m.track.width = width
        m.progress.translation = [0, height - 6]
        m.title.translation = [0, height + 16]
        m.title.width = width
        if person
            m.title.translation = [-12, height + 12]
            m.title.width = width + 24
        end if
    end if
    placeholder = TextValue(content.placeholder)
    if placeholder = "" then placeholder = "0x242424ff"
    m.placeholder.color = placeholder
    m.poster.uri = content.HDPosterUrl
    m.fallback.text = content.title
    m.fallback.visible = not person
    m.initials.visible = person and TextValue(content.HDPosterUrl) = ""
    if m.initials.visible then m.initials.text = Initials(TextValue(content.title))
    m.role.visible = person
    if person
        m.title.text = content.title
        m.role.text = TextValue(content.caption)
    else
        m.title.text = TextValue(content.caption, TextValue(content.title))
    end if
    progress = content.progress
    if progress = invalid then progress = 0
    if progress > 1 then progress = 1
    if progress < 0 then progress = 0
    m.track.visible = progress > 0
    m.progress.visible = progress > 0
    m.progress.width = width * progress
    ShowTitleArt(content, progress > 0)
    ShowBadge(content, width, progress > 0)
    ' A recycled card must not inherit an in-flight transform from old content.
    PaintCardFocus(false)
end sub

' Apple TV tiles carry the title art bottom-left over the image; without a logo
' the name stands in. Posters already show their title, and a show's own
' episode rails would repeat one logo on every tile.
sub ShowTitleArt(content as Object, hasProgress as Boolean)
    branded = content.portrait <> true and content.plainTile <> true and content.person <> true
    m.titleShade.visible = branded
    m.titleArt.visible = false
    m.titleName.visible = false
    if not branded
        m.titleArt.uri = ""
        return
    end if
    m.titleBottom = 177
    if hasProgress then m.titleBottom = 169
    name = TextValue(content.title)
    raw = content.raw
    if TextValue(content.kind) = "Episode" and IsMap(raw) then name = TextValue(raw.SeriesName, name)
    m.titleName.text = name
    m.titleName.translation = [16, m.titleBottom - 64]
    uri = TextValue(content.tileLogo)
    if uri = ""
        m.titleArt.uri = ""
        m.titleName.visible = true
    else if m.titleArt.uri = uri and m.titleArt.loadStatus = "ready"
        FitTitleArt()
    else
        m.titleArt.uri = uri
    end if
end sub

' Watched titles get a check; shows with new episodes get their count, the way
' Infuse and Plex mark a library. A title in progress shows its bar instead.
sub ShowBadge(content as Object, width as Integer, inProgress as Boolean)
    count = 0
    if content.unplayed <> invalid then count = content.unplayed
    kind = TextValue(content.kind)
    showCount = (kind = "Series" or kind = "Season") and count > 0
    showCheck = not showCount and content.played = true and not inProgress
    m.badge.visible = showCount or showCheck
    if not m.badge.visible then return
    size = 34
    if showCount
        label = count.ToStr()
        if count > 99 then label = "99+"
        size = 34 + (Len(label) - 1) * 11
        m.badgeCount.text = label
        m.badgeCount.width = size
        m.badgeBg.color = "0xffffffff"
    else
        m.badgeBg.color = "0x000000b8"
    end if
    m.badgeBg.width = size
    m.badgeCount.visible = showCount
    m.badgeCheck.visible = showCheck
    m.badge.translation = [width - size - 10, 10]
end sub

sub SetRadius(node as Object, radius as Float)
    if node.effect <> invalid then node.effect.borderRadius = [radius]
end sub

function Initials(name as String) as String
    words = name.Trim().Split(" ")
    if words.Count() = 0 or words[0] = "" then return ""
    text = UCase(Left(words[0], 1))
    if words.Count() > 1 then text += UCase(Left(words[words.Count() - 1], 1))
    return text
end function

sub OnTitleArt()
    if m.titleArt.uri = "" then return
    status = m.titleArt.loadStatus
    if status = "ready" then FitTitleArt()
    if status = "failed" then m.titleName.visible = true
end sub

' Logos range from wide wordmarks to stacked blocks: fit 190×64, keep the
' baseline, never stretch.
sub FitTitleArt()
    width = m.titleArt.bitmapWidth
    height = m.titleArt.bitmapHeight
    if width <= 0 or height <= 0 then return
    scale = 190 / width
    if height * scale > 64 then scale = 64 / height
    m.titleArt.width = Int(width * scale)
    m.titleArt.height = Int(height * scale)
    m.titleArt.translation = [16, m.titleBottom - m.titleArt.height]
    m.titleArt.visible = true
    m.titleName.visible = false
end sub

sub ShowFocus()
    PaintCardFocus(true)
end sub

sub PaintCardFocus(animate as Boolean)
    focused = m.top.rowListHasFocus and m.top.focusPercent > 0.5 and m.top.rowFocusPercent > 0.5
    if animate and m.focused = focused then return
    m.focused = focused
    ' Apple TV focus: the card lifts on a soft shadow; there is no outline.
    ' Selection feedback never waits for the transform animation to finish.
    m.shadow.visible = focused and m.role.visible = false
    m.title.color = "0xb8b8b8ff"
    target = 1.0
    if focused
        m.title.color = "0xffffffff"
        target = 1.07
    end if
    current = m.card.scale
    m.focusMotion.control = "stop"
    if not animate or not m.top.rowListHasFocus
        m.card.scale = [target, target]
        return
    end if
    ' Retarget from the presentation value: rapid reversal never jumps back to
    ' the beginning, and the two preallocated nodes do all interpolation.
    if current[0] = target then return
    m.focusScale.keyValue = [current, [target, target]]
    m.focusMotion.control = "start"
end sub
