sub Main()
    m.stats = {nodes: 0, fonts: 0, effects: 0, finds: 0, updates: 100}
    for each id in ["meta", "shelfSurface", "heroCopy", "heroExtras", "backdrop", "homeLayoutMotion", "homeShelfPosition", "homeHeroScale", "homeHeroPosition", "homeExtrasOpacity", "homeBackdropOpacity"]
        m[id] = PerfNode("Group")
    end for
    m.page = "home"
    m.focusArea = "cta"
    UpdateHomeLayout(false)
    ResetCounts()
    for index = 1 to 100
        m.focusArea = "rows"
        UpdateHomeLayout(true)
        Check(m.homeShelfPosition.keyValue[1][1], -372, "shelf moves above lower screen edge")
        Check(m.homeExtrasOpacity.keyValue[1], 0.0, "hero copy fades out over the shelves")
        Check(m.homeBackdropOpacity.keyValue[1], 0.45, "artwork dims behind the shelves")
        ' Renderer is mid-frame when the user reverses the remote input.
        m.shelfSurface.translation = [0, -180]
        m.heroCopy.scale = [0.8, 0.8]
        m.focusArea = "cta"
        UpdateHomeLayout(true)
        Check(m.homeShelfPosition.keyValue[0][1], -180, "reversal begins at rendered shelf position")
        Check(m.homeHeroScale.keyValue[0][0], 0.8, "reversal begins at rendered hero scale")
        Check(m.homeShelfPosition.keyValue[1][1], 196, "Up restores the hero with the shelf peeking")
        Check(m.homeExtrasOpacity.keyValue[1], 1.0, "Up restores the hero copy")
        ' Leaving Home mid-expansion must restore normal detail geometry even
        ' though the target compact flag is already false.
        m.page = "details"
        UpdateHomeLayout(false)
        Check(m.shelfSurface.translation[1], 0, "details clears in-flight shelf transform")
        Check(m.heroCopy.scale[0], 1, "details clears in-flight hero scale")
        Check(m.heroCopy.opacity, 1, "detail actions readable")
        m.page = "home"
        m.focusArea = "rows"
        UpdateHomeLayout(false)
        m.focusArea = "nav"
        m.contentFocusArea = "rows"
        UpdateHomeLayout(false)
        Check(m.homeCompact, true, "sidebar preserves compact shelf context")
        m.focusArea = "cta"
        UpdateHomeLayout(false)
    end for
    print "MEASURE "; FormatJson(m.stats)
end sub
