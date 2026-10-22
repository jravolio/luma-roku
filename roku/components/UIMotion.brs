sub InitUIMotion()
    for each id in ["sidebarMotion", "sidebarPosition", "sidebarOpacity", "pageMotion", "contentSurface", "heroCopy", "heroExtras", "shelfSurface", "homeLayoutMotion", "homeShelfPosition", "homeHeroScale", "homeHeroPosition", "homeExtrasOpacity", "homeBackdropOpacity"]
        m[id] = m.top.FindNode(id)
    end for
    m.sidebarOpen = false
    m.sidebar.opacity = 0
    m.sidebarMotion.ObserveField("state", "OnSidebarMotionState")
    m.uiMotionReady = true
end sub

sub PaintSidebarMotion(open as Boolean)
    if m.sidebarOpen = open then return
    m.sidebarOpen = open
    ' Stop preserves the current rendered values, including mid-reversal.
    m.sidebarMotion.control = "stop"
    targetOpacity = 0
    targetPosition = [10, 34]
    m.sidebarMotion.duration = 0.12
    if open
        targetOpacity = 1
        targetPosition = [34, 34]
        m.sidebarMotion.duration = 0.18
        m.sidebar.visible = true
        PaintSidebarClock()
    end if
    m.sidebarPosition.keyValue = [m.sidebar.translation, targetPosition]
    m.sidebarOpacity.keyValue = [m.sidebar.opacity, targetOpacity]
    m.sidebarMotion.control = "start"
end sub

sub OnSidebarMotionState()
    ' An interrupted close must never hide a newly reopened drawer.
    if m.sidebarMotion.state = "stopped" and not m.sidebarOpen and m.sidebar.opacity < 0.01
        m.sidebar.visible = false
    end if
end sub

sub AnimatePageIn()
    ' SceneGraph owns the frames. Focus changes immediately and never waits.
    m.pageMotion.control = "stop"
    m.pageMotion.control = "start"
end sub


' Apple TV Home and show pages: the hero owns the screen with the first shelf
' peeking at the bottom. Moving into the shelves fades the hero copy and lifts
' two rows into view.
sub UpdateHomeLayout(animate as Boolean)
    shelvesShown = false
    if m.shelves <> invalid then shelvesShown = m.shelves.visible = true
    layered = m.page = "home" or (m.page = "details" and shelvesShown)
    compact = false
    if layered
        compact = m.focusArea = "rows"
        if m.focusArea = "nav" then compact = m.contentFocusArea = "rows"
    end if
    layoutKey = m.page + shelvesShown.ToStr()
    if m.homeCompact <> invalid and m.homeCompact = compact and m.homeLayoutPage = layoutKey then return
    m.homeLayoutPage = layoutKey
    m.homeCompact = compact
    m.homeLayoutMotion.control = "stop"
    shelfPosition = [0, 0]
    if m.page = "home" then shelfPosition = [0, 196]
    if m.page = "details" and shelvesShown then shelfPosition = [0, 312]
    heroScale = [1, 1]
    heroPosition = [0, 0]
    copyOpacity = 1.0
    backdropOpacity = 1.0
    if compact
        shelfPosition = [0, -372]
        copyOpacity = 0.0
        backdropOpacity = 0.45
    end if
    if not animate or not layered
        m.shelfSurface.translation = shelfPosition
        m.heroCopy.scale = heroScale
        m.heroCopy.translation = heroPosition
        m.heroCopy.opacity = copyOpacity
        m.backdrop.opacity = backdropOpacity
        return
    end if
    ' Retarget presentation values; repeated Up/Down never queues transitions.
    ' RowList geometry/content is unchanged, so its selected row/item survives.
    m.homeShelfPosition.keyValue = [m.shelfSurface.translation, shelfPosition]
    m.homeHeroScale.keyValue = [m.heroCopy.scale, heroScale]
    m.homeHeroPosition.keyValue = [m.heroCopy.translation, heroPosition]
    m.homeExtrasOpacity.keyValue = [m.heroCopy.opacity, copyOpacity]
    m.homeBackdropOpacity.keyValue = [m.backdrop.opacity, backdropOpacity]
    m.homeLayoutMotion.control = "start"
end sub
