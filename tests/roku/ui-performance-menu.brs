sub Main()
    m.stats = {nodes: 0, fonts: 0, effects: 0, finds: 0, updates: 100}
    for each id in ["menu", "menuRows", "menuPage", "menuTitle", "hud", "controlHint", "hideTimer", "timelineTrack"]
        m[id] = PerfNode("Group")
    end for
    m.buttonNodes = []
    for index = 0 to 5
        m.buttonNodes.Push({bg: PerfNode("Rectangle"), label: PerfNode("Label"), icon: PerfNode("Poster"), group: PerfNode("Group")})
    end for
    m.buttonIndex = 2
    m.names = ["Reproduzir", "Áudio", "Legendas", "Qualidade", "Versão", "Capítulos"]
    m.keys = ["", "audioStreamIndex", "subtitleStreamIndex", "quality", "mediaSourceId", ""]
    tracks = []
    for index = 1 to 9
        tracks.Push({index: index * 2, label: "Track " + index.ToStr()})
    end for
    m.top = {busy: false, options: {selection: {subtitleStreamIndex: -1}, subtitleTracks: tracks}}
    OpenOptions()
    ResetCounts()
    direction = "down"
    for index = 1 to 100
        if m.menuIndex = 9 then direction = "up"
        if m.menuIndex = 0 then direction = "down"
        onKeyEvent(direction, true)
        Check(m.menuRows.GetChildCount(), 5, "same visible menu row count")
        first = Int(m.menuIndex / 5) * 5
        for slot = 0 to 4
            group = m.menuRows.GetChild(slot)
            bg = group.GetChild(0)
            label = group.GetChild(1)
            expected = "Track " + (first + slot).ToStr()
            if first + slot = 0 then expected = "Desativadas"
            Check(label.text, expected, "track label remains correct")
            Check(group.GetChild(2).visible, first + slot = 0, "selected icon tracks item across recycled pages")
            tint = "0xffffffff"
            if first + slot = m.menuIndex then tint = "0x111111ff"
            Check(group.GetChild(2).blendColor, tint, "check icon readable on focused and unfocused rows")
            color = "0x00000000"
            if first + slot = m.menuIndex then color = "0xffffffff"
            Check(bg.color, color, "focus remains immediate white fill")
        end for
    end for
    ' Reusing the same pool across versions/menus must never leave stale rows.
    m.menuItems = [{value: 44, label: "New version track"}]
    m.menuIndex = 0
    m.menuSelected = 44
    PaintMenu()
    Check(m.menuRows.GetChild(0).GetChild(1).text, "New version track", "new menu replaces old text and check")
    for slot = 1 to 4
        Check(m.menuRows.GetChild(slot).visible, false, "short menu hides recycled rows")
    end for
    m.menuItems = []
    PaintMenu()
    for slot = 0 to 4
        Check(m.menuRows.GetChild(slot).visible, false, "empty menu hides every row")
    end for
    Check(m.menuPage.text, "Nenhuma faixa disponível nesta versão", "empty menu explanation survives pooling")
    m.top.options.subtitleTracks = tracks
    OpenOptions()
    for slot = 0 to 4
        Check(m.menuRows.GetChild(slot).visible, true, "long menu reveals reused rows")
    end for
    Check(m.menuRows.GetChild(0).GetChild(1).text, "Desativadas", "reopened subtitle menu restores current selection")
    print "MEASURE "; FormatJson(m.stats)
end sub
