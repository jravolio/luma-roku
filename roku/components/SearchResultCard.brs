sub init()
    for each id in ["outline", "placeholder", "fallback", "poster", "title", "subtitle"]
        m[id] = m.top.FindNode(id)
    end for
    ApplyRounded(m.poster, 12)
    ApplyRounded(m.placeholder, 12)
    ApplyRounded(m.outline, 16)
end sub

sub ShowResult()
    content = m.top.itemContent
    if content = invalid then return
    m.poster.uri = content.HDPosterUrl
    m.fallback.text = content.title
    m.title.text = content.title
    m.subtitle.text = ResultSubtitle(content)
end sub

function ResultSubtitle(content as Object) as String
    kind = TextValue(content.kind)
    if kind = "Episode" then return TextValue(content.meta)
    if kind = "Series" then return "Série"
    if kind = "Movie" then return "Filme"
    return ""
end function

' Grid focus is remote-driven and frequent: the outline paints immediately.
sub ShowResultFocus()
    focused = m.top.gridHasFocus and m.top.focusPercent > 0.5
    m.outline.visible = focused
    m.title.color = "0xd0d0d0ff"
    if focused then m.title.color = "0xffffffff"
end sub
