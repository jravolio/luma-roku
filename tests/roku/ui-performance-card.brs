sub Main()
    m.stats = {nodes: 0, fonts: 0, effects: 0, finds: 0, updates: 100}
    m.top = PerfNode("Group")
    for each id in ["card", "shadow", "title", "poster", "placeholder", "fallback", "track", "progress", "focusMotion", "focusScale", "titleShade", "titleArt", "titleName", "badge", "badgeBg", "badgeCheck", "badgeCount", "initials", "role"]
        m.top.nodes[id] = PerfNode("Group")
    end for
    m.top.nodes.titleArt.ObserveField = IgnoreCardObservation
    m.top.focusPercent = 0
    m.top.rowFocusPercent = 0
    m.top.rowListHasFocus = false
    m.top.nodes.card.scale = [1.0, 1.0]
    init()
    m.top.itemContent = {title: "First", HDPosterUrl: "first.png", progress: 0.5}
    ShowCard()
    ResetCounts()
    for index = 1 to 100
        portrait = index mod 2 = 0
        m.top.itemContent = {title: "Title " + index.ToStr(), HDPosterUrl: "art.png", progress: 0.5, portrait: portrait}
        ShowCard()
        m.top.rowListHasFocus = true
        m.top.focusPercent = 1
        m.top.rowFocusPercent = 1
        ShowFocus()
        width = 340
        if portrait then width = 200
        Check(m.top.nodes.poster.width, width, "recycled card changes aspect geometry")
        Check(m.top.nodes.progress.width, width / 2, "resume bar retains exact fraction")
        Check(m.top.nodes.shadow.visible, true, "focused card shadow remains visible")
        Check(m.top.nodes.title.text, "Title " + index.ToStr(), "recycled card updates title")
    end for
    m.top.rowListHasFocus = false
    ShowFocus()
    ShowFocus()
    Check(m.shadow.visible, false, "shelf blur clears cached focus shadow")
    Check(m.title.color, "0xb8b8b8ff", "unfocused title restores subdued color")
    m.top.rowListHasFocus = true
    ShowFocus()
    Check(m.shadow.visible, true, "returning shelf focus restores shadow immediately")
    m.top.itemContent.progress = 0
    ShowCard()
    Check(m.track.visible, false, "new title without resume hides track")
    Check(m.progress.visible, false, "new title without resume hides fill")
    ' Exercise the real focus handler at a mid-animation presentation scale.
    ' Render interpolation itself is a hardware/simulator check, not emulated.
    m.card.scale = [1.02, 1.02]
    m.top.focusPercent = 0
    ShowFocus()
    Check(m.shadow.visible, false, "departing card clears selection before shrinking")
    Check(m.focusScale.keyValue[0][0], 1.02, "focus loss retargets current scale")
    Check(m.focusScale.keyValue[1][0], 1.0, "focus loss shrinks to original artwork size")
    Check(m.focusMotion.control, "start", "focus change starts reusable animation")
    m.card.scale = [1.01, 1.01]
    m.top.focusPercent = 1
    ShowFocus()
    Check(m.shadow.visible, true, "rapid reversal restores lift immediately")
    Check(m.focusScale.keyValue[0][0], 1.01, "rapid reversal starts at presentation scale")
    Check(m.focusScale.keyValue[1][0], 1.07, "focused card lifts seven percent within the item gutter")
    TestTitleArt()
    m.top.rowListHasFocus = false
    ShowFocus()
    Check(m.focusMotion.control, "stop", "leaving shelf stops off-focus animation")
    Check(m.card.scale[0], 1.0, "sidebar focus clears leftover card transform")
    m.top.itemContent.portrait = true
    ShowCard()
    Check(m.card.scaleRotateCenter[0], 100, "portrait pivot follows recycled artwork width")
    Check(m.card.scaleRotateCenter[1], 150, "portrait pivot follows recycled artwork height")
    m.top.itemContent.portrait = false
    ShowCard()
    Check(m.card.scaleRotateCenter[0], 170, "landscape pivot restores after reuse")
    Check(m.card.scaleRotateCenter[1], 95.5, "landscape pivot stays centered on image")
    TestPersonCard()
    print "MEASURE "; FormatJson(m.stats)
end sub

sub TestPersonCard()
    m.top.itemContent = {title: "Russell Crowe", caption: "Hermann Göring", HDPosterUrl: "", person: true, kind: "Person", progress: 0}
    ShowCard()
    Check(m.poster.width, 176, "cast portraits are square before rounding")
    Check(m.title.text, "Russell Crowe", "a portrait is captioned with the person's name")
    Check(m.role.text, "Hermann Göring", "the role sits under the name")
    Check(m.role.visible, true, "the role line shows on portraits")
    Check(m.initials.text, "RC", "a person without a photo shows initials")
    Check(m.titleShade.visible, false, "portraits carry no title art shade")
    m.top.rowListHasFocus = true
    m.top.focusPercent = 1
    m.top.rowFocusPercent = 1
    ShowFocus()
    Check(m.shadow.visible, false, "the rectangular shadow never frames a round portrait")
    m.top.itemContent = {title: "Film", HDPosterUrl: "art.png", progress: 0}
    ShowCard()
    Check(m.role.visible, false, "a recycled title tile drops the role line")
    Check(m.initials.visible, false, "a recycled title tile drops the initials")
    Check(m.poster.width, 340, "a recycled title tile restores its 16:9 size")
end sub

sub IgnoreCardObservation(field as String, handler as String)
end sub

sub TestTitleArt()
    m.top.itemContent = {title: "Eternidade", HDPosterUrl: "art.png", progress: 0, tileLogo: "logo.png", caption: "Eternidade"}
    ShowCard()
    Check(m.titleShade.visible, true, "landscape tiles get the title shade")
    Check(m.titleArt.uri, "logo.png", "the small title logo loads on the tile")
    Check(m.titleArt.visible, false, "the logo stays hidden until it has loaded")
    m.titleArt.loadStatus = "ready"
    m.titleArt.bitmapWidth = 360
    m.titleArt.bitmapHeight = 90
    OnTitleArt()
    Check(m.titleArt.width, 190, "a wide wordmark fills the logo width")
    Check(m.titleArt.height, 47, "the logo keeps its proportions")
    Check(m.titleArt.translation[1] + m.titleArt.height, 177, "the logo sits on the tile baseline")
    m.titleArt.bitmapWidth = 200
    m.titleArt.bitmapHeight = 200
    FitTitleArt()
    Check(m.titleArt.height, 64, "a stacked logo is limited by height")
    m.top.itemContent = {title: "Última chance", kind: "Episode", raw: {SeriesName: "Cyberpunk: Mercenários"}, HDPosterUrl: "still.png", progress: 0.4, tileLogo: "", caption: "T2, E1 · Última chance"}
    ShowCard()
    Check(m.titleName.visible, true, "without a logo the name stands in")
    Check(m.titleName.text, "Cyberpunk: Mercenários", "an episode tile names its show")
    Check(m.title.text, "T2, E1 · Última chance", "the caption names the episode")
    Check(m.titleName.translation[1] + 64, 169, "the name clears the progress bar")
    m.top.itemContent = {title: "1. Episode", HDPosterUrl: "still.png", progress: 0, tileLogo: "logo.png", plainTile: true}
    ShowCard()
    Check(m.titleShade.visible, false, "a show's episode rail stays plain")
    Check(m.titleName.visible, false, "a plain tile shows no name overlay")
    m.top.itemContent = {title: "Poster", HDPosterUrl: "poster.png", progress: 0, portrait: true, tileLogo: "logo.png"}
    ShowCard()
    Check(m.titleShade.visible, false, "posters already carry their title")
    m.top.itemContent = {title: "Show", kind: "Series", HDPosterUrl: "poster.png", progress: 0, portrait: true, unplayed: 3, played: false}
    ShowCard()
    Check(m.badge.visible, true, "a show with new episodes is marked")
    Check(m.badgeCount.text, "3", "the mark counts unwatched episodes")
    Check(m.badgeCheck.visible, false, "a count is not also a check")
    Check(m.badge.translation[0], 200 - 34 - 10, "the badge sits in the top-right corner")
    m.top.itemContent = {title: "Film", kind: "Movie", HDPosterUrl: "art.png", progress: 0, played: true}
    ShowCard()
    Check(m.badgeCheck.visible, true, "a watched film gets a check")
    Check(m.badgeCount.visible, false, "a watched film shows no count")
    m.top.itemContent = {title: "Film", kind: "Movie", HDPosterUrl: "art.png", progress: 0.4, played: true}
    ShowCard()
    Check(m.badge.visible, false, "a title in progress shows its bar, not a check")
    m.top.itemContent = {title: "Show", kind: "Series", HDPosterUrl: "poster.png", progress: 0, portrait: true, unplayed: 140, played: false}
    ShowCard()
    Check(m.badgeCount.text, "99+", "large counts stay compact")
end sub
