sub Main()
    m.stats = {nodes: 0, fonts: 0, effects: 0, finds: 0, updates: 100}
    m.page = "home"
    m.featuredCards = []
    m.featuredIndex = 0
    for index = 0 to 4
        m.featuredCards.Push({id: index.ToStr(), title: "Title " + index.ToStr(), logo: "logo.png", backdrop: "art.png", description: "Synopsis", meta: "2026"})
    end for
    for each id in ["featuredDots", "featuredDotsBg", "info", "featuredPrevious", "featuredNext", "heroTitle", "heroLogo", "synopsis", "meta", "backdrop", "ctaText"]
        m[id] = PerfNode("Group")
    end for
    m.heroLogo.loadStatus = "ready"
    ShowFeatured()
    ResetCounts()
    for index = 1 to 100
        ChangeFeatured(1)
        OnHeroLogoLoad()
        Check(m.heroTitle.text, "Title " + (index mod 5).ToStr(), "feature title follows remote selection")
        Check(m.featuredDots.GetChildCount(), 5, "same five page dots remain visible")
        for dotIndex = 0 to 4
            color = "0xffffff66"
            if dotIndex = index mod 5 then color = "0xffffffff"
            Check(m.featuredDots.GetChild(dotIndex).color, color, "only active page dot is white")
        end for
    end for
    m.page = "details"
    PaintFeatured()
    Check(m.featuredDots.visible, false, "detail hides dots")
    m.page = "home"
    PaintFeatured()
    Check(m.featuredDots.visible, true, "Home restores dots")
    allCards = m.featuredCards
    m.featuredCards = [allCards[0], allCards[1], allCards[2]]
    PaintFeatured()
    Check(m.featuredDots.GetChild(3).visible, false, "short library hides extra pooled dots")
    Check(m.featuredDots.GetChild(4).visible, false, "short library hides final pooled dot")
    m.featuredCards = [allCards[0]]
    PaintFeatured()
    Check(m.featuredDots.visible, false, "single item needs no pagination")
    Check(m.featuredNext.visible, false, "single item needs no next action")
    m.featuredCards = []
    PaintFeatured()
    Check(m.featuredPrevious.visible, false, "empty library hides previous action")
    m.featuredCards = allCards
    PaintFeatured()
    Check(m.featuredDots.GetChildCount(), 5, "restored library reuses bounded five dots")
    Check(m.featuredDots.GetChild(4).visible, true, "restored library reveals final dot")
    print "MEASURE "; FormatJson(m.stats)
end sub
