sub init()
    m.top.backgroundColor = "0x090909ff"
    m.top.backgroundUri = ""
    for each id in ["backdrop", "heroTitle", "meta", "synopsis", "eyebrow", "cta", "ctaBg", "ctaText", "secondary", "secondaryBg", "secondaryText", "shelves", "hint", "status", "spinner", "service", "video", "reportTimer", "resumeTimer", "resumeCover", "welcome", "account", "playerControls", "playbackSurface", "sidebar", "heroLogo", "heroShade", "libraryRail", "featuredPrevious", "featuredNext", "featuredDots", "detailGenre", "searchScreen", "backButton", "backButtonBg", "backButtonText", "ctaIcon", "info", "infoBg", "infoText", "featuredDotsBg"]
        m[id] = m.top.FindNode(id)
    end for
    ' Apple TV order: Search first, then Home and the libraries, Settings last.
    m.navNames = ["Buscar", "Início", "Filmes", "Séries", "Ajustes"]
    m.navIds = ["search", "home", "movies", "series", "settings"]
    m.navNodes = []
    navIcons = ["search", "home", "film", "tv", "gear"]
    nav = m.top.FindNode("nav")
    navFont = CreateObject("roSGNode", "Font")
    navFont.uri = "pkg:/fonts/Inter-Medium.ttf"
    navFont.size = 25
    for index = 0 to m.navNames.Count() - 1
        group = nav.CreateChild("Group")
        group.translation = [0, index * 76]
        bg = group.CreateChild("Rectangle")
        bg.width = 327
        bg.height = 66
        ApplyRounded(bg, 33)
        bg.color = "0xffffffff"
        chip = group.CreateChild("Rectangle")
        chip.translation = [12, 10]
        chip.width = 46
        chip.height = 46
        chip.color = "0x00000040"
        ApplyRounded(chip, 23)
        label = group.CreateChild("Label")
        label.text = m.navNames[index]
        label.translation = [74, 0]
        label.width = 240
        label.height = 66
        label.horizAlign = "left"
        label.vertAlign = "center"
        label.font = navFont
        icon = CreateAppIcon(group, navIcons[index], 22, 20, 26)
        m.navNodes.Push({bg: bg, chip: chip, label: label, icon: icon})
    end for
    font = CreateObject("roSGNode", "Font")
    font.uri = "pkg:/fonts/Inter-SemiBold.ttf"
    font.size = 30
    m.shelves.rowLabelFont = font
    ' Let the firmware interpolate shelf scrolling; sibling focus remains exclusive.
    if m.shelves.HasField("skipFocusAnimations") then m.shelves.skipFocusAnimations = false
    ApplyRounded(m.top.FindNode("sidebarPanel"), 50)
    ApplyRounded(m.top.FindNode("avatar"), 26)
    m.avatarInitial = m.top.FindNode("avatarInitial")
    m.clock = m.top.FindNode("clock")
    ApplyRounded(m.top.FindNode("featuredPreviousBg"), 32)
    ApplyRounded(m.top.FindNode("featuredNextBg"), 32)
    ApplyRounded(m.ctaBg, 32)
    ApplyRounded(m.secondaryBg, 32)
    ApplyRounded(m.backButtonBg, 29)
    ApplyRounded(m.infoBg, 32)
    ApplyRounded(m.featuredDotsBg, 14)
    ApplyRounded(m.top.FindNode("welcomePanel"), 28)
    m.heroLogo.ObserveField("loadStatus", "OnHeroLogoLoad")
    m.logoBox = {x: 80, bottom: 540, width: 700, height: 190}
    if m.heroShade.HasField("effect")
        effectType = "Effect"
        shade = CreateObject("roSGNode", effectType)
        if shade <> invalid
            if shade.supported
                shade.gradientStyle = "linear"
                shade.gradientAngle = 180
                shade.gradientColors = ["0x09090900", "0x09090944", "0x090909ff"]
                shade.gradientStops = [0.0, 0.55, 0.94]
                ' Gradient alpha must reveal artwork, not an opaque white base.
                m.heroShade.color = "0x00000000"
                m.heroShade.effect = shade
                ' Apple's left scrim keeps copy legible over bright artwork.
                side = CreateObject("roSGNode", effectType)
                side.gradientStyle = "linear"
                side.gradientAngle = 90
                side.gradientColors = ["0x000000b8", "0x00000070", "0x00000000"]
                side.gradientStops = [0.0, 0.45, 1.0]
                m.top.FindNode("heroSideShade").effect = side
            end if
        end if
    end if
    m.navIndex = NavIndex("home")
    m.activeNavIndex = m.navIndex
    m.contentFocusArea = "cta"
    m.focusArea = "cta"
    m.page = "welcome"
    m.stack = []
    m.requestId = 0
    m.reportsPending = 0
    m.busy = false
    m.connected = false
    m.loggedIn = false
    m.currentCard = invalid
    m.featuredCards = []
    m.featuredIndex = 0
    m.playSession = invalid
    m.dialogMode = ""
    m.browseRequest = invalid
    m.shelves.ObserveField("rowItemFocused", "OnCardFocus")
    m.shelves.ObserveField("rowItemSelected", "OnCardSelected")
    m.shelves.ObserveField("content", "ApplyRowSizes")
    m.choiceMenu = m.top.FindNode("choiceMenu")
    m.choiceMenu.ObserveField("chosen", "OnChoiceChosen")
    m.choiceMenu.ObserveField("dismissed", "OnChoiceDismissed")
    m.service.ObserveField("ready", "OnServiceReady")
    m.service.ObserveField("result", "OnResult")
    m.searchScreen.ObserveField("request", "OnSearchRequest")
    m.searchScreen.ObserveField("selected", "OnSearchSelected")
    m.playerControls.ObserveField("action", "OnPlayerAction")
    m.video.ObserveField("state", "OnVideoState")
    m.video.ObserveField("position", "OnVideoPosition")
    m.reportTimer.ObserveField("fire", "ReportProgress")
    m.resumeTimer.ObserveField("fire", "OnPlaybackResumeTimeout")
    m.ambient = m.top.FindNode("ambient")
    m.idleTimer = m.top.FindNode("idleTimer")
    m.ambient.ObserveField("dismissed", "StopAmbient")
    m.idleTimer.ObserveField("fire", "OnIdle")
    NoteActivity()
    InitUIMotion()
    m.prefetchTimer = m.top.FindNode("prefetchTimer")
    m.prefetchTimer.ObserveField("fire", "OnPrefetchTimer")
    ' Instant Resume: a playback report may finish while Luma is suspended.
    if m.top.HasField("allowBackgroundTask") then m.top.allowBackgroundTask = true
    m.top.SetFocus(true)
    PaintFocus()
    ' Nothing is drawn until Luma knows whether it opens on Home or the welcome.
    m.contentSurface.visible = false
    m.service.control = "RUN"
end sub

sub OnServiceReady()
    if not m.service.ready then return
    m.contentSurface.visible = true
    cached = m.service.cachedHome
    if IsMap(cached)
        if cached.content <> invalid
            ' Last session's Home at once; the server check and fresh rows follow
            ' quietly behind it.
            m.connected = true
            m.loggedIn = true
            m.serverName = TextValue(cached.serverName)
            SetAccountName(TextValue(cached.userName, m.serverName))
            ShowListResult("home", {content: cached.content, title: "Para você"})
            m.bootedFromCache = true
            m.lastRequest = {action: "bootstrap"}
            Send("bootstrap", {quiet: true})
            return
        end if
    end if
    m.welcome.visible = true
    m.ctaText.text = "Buscar servidor"
    m.synopsis.text = "Assista aos filmes e séries do seu Jellyfin na TV. Conecte-se ao servidor para começar."
    Send("bootstrap", {})
end sub

sub Send(action as String, data as Object)
    m.requestId++
    data.action = action
    data.requestId = m.requestId
    if action = "play" then m.playRequestId = m.requestId
    if action = "report" then m.reportsPending++
    ' Reports, intro segments, ambient artwork and saved choices never hold the UI.
    if action <> "report" and action <> "segments" and action <> "ambient" and action <> "rememberTracks" and action <> "prefetch" and data.quiet <> true
        m.busy = true
        m.pendingNavigationRequestId = invalid
        if action = "home" or action = "browse" or action = "children" or action = "details" or action = "play"
            m.pendingNavigationRequestId = m.requestId
        end if
        ' RowList consumes remote keys before the Scene's busy guard. Move focus
        ' to a sibling while waiting, retaining focusArea for Back/restoration.
        if not m.video.visible then Focus(m.focusArea)
        m.lastRequest = data
        ' tvOS shows a bare centred indicator; only the network search explains itself.
        m.spinner.translation = [960, 540]
        if m.page = "welcome" then m.spinner.translation = [1380, 540]
        m.spinner.text = ""
        if action = "bootstrap" or action = "discover" then m.spinner.text = "Procurando o Jellyfin na sua rede…"
        m.spinner.visible = true
        m.spinner.control = "start"
    end if
    m.service.request = data
    ' Passwords are never cached in retry state or logged.
    if action = "login" then m.lastRequest = {action: "login"}
    if action = "switchProfile" then m.lastRequest = {action: "profiles"}
end sub

sub OnResult(event = invalid as Dynamic)
    result = m.service.result
    ' Consume the value belonging to this notification, not a later Task write.
    if event <> invalid then result = event.GetData()
    if not IsMap(result) then return
    if result.ok = true and result.canSwitchProfiles <> invalid then m.canSwitchProfiles = result.canSwitchProfiles = true
    if result.action = "report"
        if m.reportsPending > 0 then m.reportsPending--
        return
    end if
    if result.action = "ambient"
        if result.ok = true and m.ambientActive = true and IsList(result.items)
            if result.items.Count() > 0 then m.ambient.items = result.items
        end if
        return
    end if
    if result.action = "rememberTracks" or result.action = "prefetch" then return
    if result.action = "home" and m.quietHomeRequestId <> invalid and result.requestId = m.quietHomeRequestId
        m.quietHomeRequestId = invalid
        if result.ok = true then RefreshHomeInPlace(result.content)
        return
    end if
    if result.action = "segments"
        if result.ok = true and TextValue(result.itemId) = TextValue(m.segmentsItemId)
            if IsList(result.segments) then m.playerControls.segments = result.segments
            if IsMap(result.trickplay) then m.playerControls.trickplay = result.trickplay
            m.nextEpisode = invalid
            if IsMap(result.nextEpisode) then m.nextEpisode = result.nextEpisode
            if m.nextEpisode <> invalid
                label = "T" + TextValue(m.nextEpisode.ParentIndexNumber) + ", E" + TextValue(m.nextEpisode.IndexNumber) + " · " + TextValue(m.nextEpisode.Name)
                m.playerControls.upNext = {label: label, image: TextValue(result.nextImage)}
            end if
            m.playerControls.hasNextEpisode = m.nextEpisode <> invalid
        end if
        return
    end if
    ' Search never holds the busy state, so it cannot release another request's.
    if result.action = "search"
        OnSearchResult(result)
        return
    end if
    ' Back abandons the UI request, not the serial Task or its account state.
    ' A late playback response still owns a server session that must be stopped.
    if m.cancelledThroughRequestId <> invalid and result.requestId <> invalid
        if result.requestId <= m.cancelledThroughRequestId
            if result.action = "play" and result.ok then Send("report", {event: "stopped", body: result.session})
            return
        end if
    end if
    if result.action = "play" and m.playRequestId <> invalid
        if result.requestId <> m.playRequestId
            if result.ok then Send("report", {event: "stopped", body: result.session})
            return
        end if
    end if
    m.busy = false
    m.pendingNavigationRequestId = invalid
    if not m.video.visible then Focus(m.focusArea)
    m.spinner.control = "stop"
    m.spinner.visible = false
    if not result.ok
        m.autoplayItemId = invalid
        m.refreshDetailsId = invalid
        if result.action = "switchProfile" and result.needsPassword = true
            ' A wrong password is not an expired session: just ask again.
            m.pendingProfile = {userId: result.userId, name: result.name}
            title = "Senha de " + TextValue(result.name)
            if result.code = 401 then title = "Senha incorreta. " + title
            OpenKeyboard("profilePassword", title, "", true)
            return
        end if
        if result.action = "play" and m.switchingPlayback = true and result.code <> 401
            m.switchingPlayback = false
            m.pendingPlayItem = invalid
            m.trackChoice = invalid
            m.playerControls.busy = false
            m.playerControls.message = result.message
            if m.resumePaused <> true then m.video.control = "resume"
            m.playerControls.SetFocus(true)
            return
        end if
        if result.code = 401 and result.action <> "login"
            if m.playSession <> invalid then StopPlayback()
            m.loggedIn = false
            ShowLoginLanding()
            ShowMessage("Entre novamente", "O servidor está conectado, mas sua sessão expirou.", ["Entrar", "Cancelar"], "expired")
        else
            ShowMessage("Vamos tentar novamente", result.message, ["Tentar novamente", "Reconectar", "Fechar"], "error")
        end if
        return
    end if
    action = result.action
    if action = "bootstrap" or action = "discover" or action = "select" or action = "manual"
        if result.connected
            m.connected = true
            m.loggedIn = result.loggedIn
            m.serverName = result.serverName
            SetAccountName("Não conectado")
            if m.loggedIn then SetAccountName(TextValue(result.userName, result.serverName))
            if m.loggedIn and m.bootedFromCache = true
                ' Refresh the cached Home in place; if a page was already opened
                ' from it, leave the viewer there.
                if m.page = "home" and m.stack.Count() = 0
                    Send("home", {quiet: true})
                    m.quietHomeRequestId = m.requestId
                end if
            else if m.loggedIn
                m.stack = []
                Send("home", {})
            else
                m.stack = []
                ShowLoginLanding()
                OpenKeyboard("username", "Entrar em " + m.serverName, "", false)
            end if
        else
            m.servers = result.servers
            ShowServerPicker(result.message)
        end if
        m.bootedFromCache = false
    else if action = "login"
        m.loggedIn = true
        SetAccountName(TextValue(result.userName))
        m.username = ""
        Send("home", {})
    else if action = "genres"
        m.genreChoices = result.genres
        options = ["Todos"]
        checked = 0
        for index = 0 to m.genreChoices.Count() - 1
            options.Push(m.genreChoices[index].name)
            if m.genreChoices[index].id = TextValue(m.browseRequest.genreId) then checked = index + 1
        end for
        OpenChoice("genre", "Gênero", options, checked)
    else if action = "profiles"
        m.profileChoices = result.profiles
        options = []
        checked = -1
        for index = 0 to m.profileChoices.Count() - 1
            options.Push(m.profileChoices[index].name)
            if m.profileChoices[index].id = TextValue(result.currentId) then checked = index
        end for
        OpenChoice("profile", "Trocar perfil", options, checked)
    else if action = "switchProfile"
        m.loggedIn = true
        SetAccountName(TextValue(result.userName))
        m.stack = []
        m.navIndex = NavIndex("home")
        m.activeNavIndex = m.navIndex
        Send("home", {})
    else if action = "logout"
        m.loggedIn = false
        m.canSwitchProfiles = false
        m.stack = []
        m.shelves.content = invalid
        m.backdrop.uri = ""
        ShowLoginLanding()
    else if action = "home" or action = "browse" or action = "children"
        ShowListResult(action, result)
    else if action = "details" and m.autoplayItemId <> invalid and TextValue(result.card.id) = TextValue(m.autoplayItemId)
        ' Home's Play goes straight to the video; Home stays underneath.
        m.autoplayItemId = invalid
        StartItemPlayback(result.item, false, TextValue(result.card.backdrop))
    else if action = "details"
        ' After playback a show page reloads in place for fresh progress/next up.
        refreshing = m.refreshDetailsId <> invalid and TextValue(result.card.id) = TextValue(m.refreshDetailsId)
        m.refreshDetailsId = invalid
        if not refreshing then PushPage()
        HideSearchSurface()
        m.page = "details"
        m.detail = result.item
        m.nextUp = result.nextUp
        m.currentCard = result.card
        m.detailCard = result.card
        m.shelves.visible = false
        if result.content <> invalid
            if result.content.GetChildCount() > 0
                m.shelves.content = result.content
                m.shelves.visible = true
                if IsList(result.nextUpLocation) then m.shelves.jumpToRowItem = result.nextUpLocation
            end if
        end if
        m.welcome.visible = false
        ShowHero(result.card)
        m.eyebrow.text = UCase(result.card.kind)
        m.secondary.visible = false
        if result.card.kind = "Series" and IsMap(m.nextUp)
            m.ctaText.text = SeriesActionLabel(m.nextUp)
        else if result.card.kind = "Series"
            m.ctaText.text = "Ver temporadas"
        else if result.card.kind = "Season"
            m.ctaText.text = "Ver episódios"
        else if result.card.kind = "Person" or result.card.kind = "BoxSet"
            m.ctaText.text = "Ver títulos"
        else
            m.ctaText.text = "Reproduzir"
            if ResumeTicks(m.detail) > 0
                m.ctaText.text = "Continuar"
                m.secondary.visible = true
            end if
        end if
        m.hint.text = ""
        if refreshing and m.focusArea = "rows" and m.shelves.visible
            Focus("rows")
        else
            Focus("cta")
        end if
        if m.uiMotionReady = true then AnimatePageIn()
    else if action = "play"
        AcceptPlayback(result)
    end if
end sub

sub ShowListResult(action as String, result as Object)
    HideSearchSurface()
    m.page = action
    if action = "home"
        m.featuredCards = FeaturedCards(result.content)
        m.featuredIndex = 0
    end if
    m.welcome.visible = false
    m.secondary.visible = false
    m.shelves.visible = true
    m.shelves.content = result.content
    m.eyebrow.text = UCase(result.title)
    m.total = 0
    m.offset = 0
    m.count = 0
    if result.total <> invalid then m.total = result.total
    if result.offset <> invalid then m.offset = result.offset
    if result.count <> invalid then m.count = result.count
    m.hint.text = ""
    if action = "browse"
        m.hint.text = ""
    end if
    if result.content.GetChildCount() > 0
        m.currentCard = result.content.GetChild(0).GetChild(0)
        if action = "home" and m.featuredCards.Count() > 0
            ShowFeatured()
            Focus("cta")
        else
            ShowHero(m.currentCard)
            ' Changing a filter in the library column keeps focus there.
            if action = "browse" and m.focusArea = "rail"
                Focus("rail")
            else
                Focus("rows")
            end if
        end if
    else if action = "browse"
        ' An empty category or filter keeps the column, so it can be changed.
        m.currentCard = invalid
        ConfigurePageLayout()
        Focus("rail")
    else
        m.currentCard = invalid
        ConfigurePageLayout()
        m.heroTitle.visible = true
        m.heroLogo.visible = false
        m.heroLogo.uri = ""
        m.cta.visible = true
        m.heroTitle.text = "Sua biblioteca está vazia"
        m.meta.text = ""
        m.synopsis.text = "Nenhum título por aqui. Tente outra busca ou adicione filmes e séries à sua biblioteca do Jellyfin."
        m.backdrop.uri = ""
        m.ctaText.text = "Buscar na biblioteca"
        Focus("cta")
    end if
    if m.uiMotionReady = true then AnimatePageIn()
end sub

sub ShowLoginLanding()
    HideSearchSurface()
    m.page = "welcome"
    ConfigurePageLayout()
    SetAccountName("Não conectado")
    m.currentCard = invalid
    m.backdrop.uri = ""
    if m.heroLogo <> invalid then m.heroLogo.uri = ""
    m.heroTitle.visible = true
    m.hint.text = ""
    m.heroTitle.text = "Entrar no Jellyfin"
    m.eyebrow.text = "CONECTADO A " + UCase(m.serverName)
    m.synopsis.text = "Entre com sua conta do Jellyfin. Seus dados de acesso ficam salvos no Luma."
    m.meta.text = ""
    m.ctaText.text = "Entrar"
    m.welcome.visible = true
    m.shelves.visible = false
    m.secondary.visible = false
    Focus("cta")
end sub

sub ShowHero(card as Object)
    logo = TextValue(card.logo)
    ' The same URI fires no new load event, so a ready logo stays visible.
    sameLogo = logo <> "" and TextValue(m.heroLogo.uri) = logo and TextValue(m.heroLogo.loadStatus) = "ready"
    m.heroTitle.visible = not sameLogo
    m.heroLogo.visible = sameLogo
    m.heroLogo.uri = logo
    m.heroTitle.text = card.title
    m.synopsis.text = card.description
    m.meta.text = card.meta
    if m.page = "home" then m.meta.text = HeroMeta(card)
    m.backdrop.uri = card.backdrop
    m.ctaText.text = "Ver detalhes"
    if m.page = "home" then m.ctaText.text = HomeActionLabel(card)
    ConfigurePageLayout()
end sub

' Apple TV's hero line: kind and genres for titles, season/episode for episodes.
function HeroMeta(card as Object) as String
    item = card.raw
    if not IsMap(item) then return TextValue(card.meta)
    if item.Type = "Episode"
        label = "T" + TextValue(item.ParentIndexNumber) + ", E" + TextValue(item.IndexNumber)
        if TextValue(item.Name) <> "" then label += " · " + item.Name
        return label
    end if
    label = DetailGenre({Type: item.Type, Genres: FirstGenres(item.Genres, 2)})
    if TextValue(item.ProductionYear) <> "" then label += " · " + TextValue(item.ProductionYear)
    if TextValue(item.OfficialRating) <> "" then label += " · " + item.OfficialRating
    return label
end function

function FirstGenres(genres as Dynamic, limit as Integer) as Object
    picked = []
    if not IsList(genres) then return picked
    for each genre in genres
        if picked.Count() < limit then picked.Push(genre)
    end for
    return picked
end function

function HomeActionLabel(card as Object) as String
    kind = TextValue(card.kind)
    if kind <> "Movie" and kind <> "Episode" then return "Ver detalhes"
    if card.progress <> invalid
        if card.progress > 0 then return "Continuar"
    end if
    return "Reproduzir"
end function

function IsPlayLabel(text as String) as Boolean
    return Left(text, 10) = "Reproduzir" or Left(text, 9) = "Continuar"
end function

' Apple's show page plays the next episode: "Continuar T2, E11".
function SeriesActionLabel(episode as Object) as String
    label = "Reproduzir"
    if ResumeTicks(episode) > 0 then label = "Continuar"
    return label + " T" + TextValue(episode.ParentIndexNumber) + ", E" + TextValue(episode.IndexNumber)
end function

function HasDetailActions() as Boolean
    if m.page = "home" or m.page = "browse" or m.page = "search" then return false
    return not IsSeriesPage()
end function

function IsSeriesPage() as Boolean
    if m.page <> "details" or not IsMap(m.detail) then return false
    return m.detail.Type = "Series"
end function

' The page item (a show) and the played item (its episode) can differ.
function PlaybackItem() as Dynamic
    if IsMap(m.playItem) then return m.playItem
    return m.detail
end function

sub OnHeroLogoLoad()
    loaded = m.heroLogo.loadStatus = "ready"
    m.heroLogo.visible = loaded
    m.heroTitle.visible = not loaded
    ConfigurePageLayout()
end sub

' Apple left-aligns title art on its baseline. scaleToFit alone centers it in
' the box, so the box is shrunk to the bitmap's aspect.
sub FitHeroLogo()
    frame = m.logoBox
    width = frame.width
    height = frame.height
    if TextValue(m.heroLogo.loadStatus) = "ready" and m.heroLogo.bitmapWidth <> invalid and m.heroLogo.bitmapHeight <> invalid and m.heroLogo.bitmapWidth > 0 and m.heroLogo.bitmapHeight > 0
        scale = frame.width / m.heroLogo.bitmapWidth
        if m.heroLogo.bitmapHeight * scale > frame.height then scale = frame.height / m.heroLogo.bitmapHeight
        width = Int(m.heroLogo.bitmapWidth * scale)
        height = Int(m.heroLogo.bitmapHeight * scale)
    end if
    m.heroLogo.width = width
    m.heroLogo.height = height
    m.heroLogo.translation = [frame.x, frame.bottom - height]
end sub

sub OnCardFocus()
    NoteActivity()
    if m.busy or m.focusArea <> "rows" or not m.shelves.visible then return
    location = m.shelves.rowItemFocused
    if not IsList(location) then return
    if location.Count() <> 2 then return
    if location[0] < 0 or location[1] < 0 then return
    content = m.shelves.content
    if content = invalid then return
    row = content.GetChild(location[0])
    if row = invalid then return
    card = row.GetChild(location[1])
    if card = invalid then return
    m.currentCard = card
    if m.page <> "details" and m.page <> "home" then ShowHero(card)
    SchedulePrefetch(card, PlaysDirectly(card))
end sub

' A card that stays focused for 0.6 s is fetched ahead, so OK opens it at once.
sub SchedulePrefetch(card as Dynamic, autoplay as Boolean)
    if m.prefetchTimer = invalid then return
    m.prefetchTimer.control = "stop"
    m.prefetchCard = invalid
    if card = invalid then return
    if TextValue(card.id) = "" or TextValue(card.kind) = "" then return
    m.prefetchCard = {itemId: card.id, kind: TextValue(card.kind), autoplay: autoplay}
    m.prefetchTimer.control = "start"
end sub

sub OnPrefetchTimer()
    request = m.prefetchCard
    m.prefetchCard = invalid
    if not IsMap(request) or m.busy or m.video.visible or m.ambientActive = true then return
    if m.page <> "home" and m.page <> "browse" and m.page <> "details" then return
    Send("prefetch", request)
end sub

sub OnCardSelected()
    if m.busy or m.focusArea <> "rows" or not m.shelves.visible then return
    location = m.shelves.rowItemSelected
    if not IsList(location) then return
    if location.Count() <> 2 then return
    if location[0] < 0 or location[1] < 0 then return
    content = m.shelves.content
    if content = invalid then return
    row = content.GetChild(location[0])
    if row = invalid then return
    card = row.GetChild(location[1])
    if card = invalid then return
    if TextValue(card.id) = "" then return
    m.currentCard = card
    ' Apple TV: episodes and in-progress titles play on OK; others open details.
    if PlaysDirectly(card) then m.autoplayItemId = card.id
    Send("details", DetailsRequest(card))
end sub

' The card's type lets a show page arrive with its episodes in one round trip.
function DetailsRequest(card as Object) as Object
    return {itemId: card.id, kind: TextValue(card.kind), autoplay: TextValue(m.autoplayItemId) <> "" and TextValue(m.autoplayItemId) = TextValue(card.id)}
end function

function PlaysDirectly(card as Object) as Boolean
    kind = TextValue(card.kind)
    if kind = "Episode" then return true
    if kind <> "Movie" then return false
    if card.progress = invalid then return false
    return card.progress > 0
end function

sub Focus(area as String)
    NoteActivity()
    if area = "nav" and m.focusArea <> "nav" then m.contentFocusArea = m.focusArea
    m.focusArea = area
    ' Use sibling focus targets; the Scene is only the bubbling event handler.
    target = m.cta
    if area = "rows"
        target = m.shelves
    else if area = "nav"
        target = m.sidebar
    else if area = "secondary"
        target = m.secondary
    else if area = "featuredPrevious"
        target = m.featuredPrevious
    else if area = "featuredNext"
        target = m.featuredNext
    else if area = "search"
        target = m.searchScreen
    else if area = "back"
        target = m.backButton
    else if area = "info"
        target = m.info
    else if area = "rail"
        target = m.libraryRail
    else if area = "choice"
        target = m.choiceMenu
    end if
    if m.busy then target = m.status
    if m.uiMotionReady = true then UpdateHomeLayout(true)
    PaintFocus()
    ' Ambient mode keeps key focus until dismissed; the area is restored after.
    if m.ambientActive = true then return
    target.SetFocus(true)
end sub

sub PaintFocus()
    PaintActionLabel()
    if m.libraryRail.visible then PaintLibraryRail()
    if m.uiMotionReady = true
        PaintSidebarMotion(m.focusArea = "nav")
    else
        m.sidebar.visible = m.focusArea = "nav"
    end if
    for index = 0 to m.navNodes.Count() - 1
        selected = m.focusArea = "nav" and index = m.navIndex
        node = m.navNodes[index]
        node.bg.visible = selected or index = m.activeNavIndex
        node.bg.color = "0xffffff1f"
        node.label.color = "0xf2f2f2ff"
        node.icon.blendColor = "0xf2f2f2ff"
        if node.chip <> invalid then node.chip.color = "0x00000040"
        if selected
            node.bg.color = "0xffffffff"
            node.label.color = "0x111111ff"
            node.icon.blendColor = "0xffffffff"
            if node.chip <> invalid then node.chip.color = "0x111111ff"
        end if
    end for
    ' Apple's glass buttons: translucent at rest, solid white when focused.
    m.ctaBg.color = "0xffffff2e"
    m.ctaText.color = "0xffffffff"
    m.ctaIcon.blendColor = "0xffffffff"
    if m.focusArea = "cta"
        m.ctaBg.color = "0xffffffff"
        m.ctaText.color = "0x090909ff"
        m.ctaIcon.blendColor = "0x090909ff"
    end if
    m.infoBg.color = "0xffffff2e"
    m.infoText.color = "0xffffffff"
    if m.focusArea = "info"
        m.infoBg.color = "0xffffffff"
        m.infoText.color = "0x090909ff"
    end if
    for each direction in ["Previous", "Next"]
        bg = m.top.FindNode("featured" + direction + "Bg")
        label = m.top.FindNode("featured" + direction + "Text")
        bg.color = "0xffffff2e"
        label.color = "0xffffffff"
        if m.focusArea = "featured" + direction
            bg.color = "0xffffffff"
            label.color = "0x090909ff"
        end if
    end for
    m.secondaryBg.color = "0xffffff2e"
    m.secondaryText.color = "0xffffffff"
    if m.focusArea = "secondary"
        m.secondaryBg.color = "0xffffffff"
        m.secondaryText.color = "0x090909ff"
    end if
    ' Translucent at rest so it does not compete with the detail artwork.
    m.backButtonBg.color = "0x29292999"
    m.backButtonText.color = "0xffffffff"
    if m.focusArea = "back"
        m.backButtonBg.color = "0xffffffff"
        m.backButtonText.color = "0x090909ff"
    end if
end sub

sub PushPage()
    m.stack.Push({focusArea: m.focusArea, featuredCards: m.featuredCards, featuredIndex: m.featuredIndex, page: m.page, content: m.shelves.content, card: m.currentCard, detail: m.detail, location: m.shelves.rowItemFocused, eyebrow: m.eyebrow.text, hint: m.hint.text, cta: m.ctaText.text, secondary: m.secondary.visible, shelvesVisible: m.shelves.visible, nextUp: m.nextUp, detailCard: m.detailCard, browseRequest: m.browseRequest, total: m.total, offset: m.offset, count: m.count})
end sub

sub PopPage()
    if m.stack.Count() = 0
        Send("home", {})
        return
    end if
    saved = m.stack.Pop()
    m.page = saved.page
    if IsList(saved.featuredCards) then m.featuredCards = saved.featuredCards
    if saved.featuredIndex <> invalid then m.featuredIndex = saved.featuredIndex
    m.shelves.content = saved.content
    m.currentCard = saved.card
    m.detail = saved.detail
    m.browseRequest = saved.browseRequest
    m.total = saved.total
    m.offset = saved.offset
    m.count = saved.count
    m.nextUp = saved.nextUp
    m.shelves.visible = m.page <> "details"
    if saved.shelvesVisible <> invalid and m.page = "details" then m.shelves.visible = saved.shelvesVisible
    m.secondary.visible = saved.secondary
    m.eyebrow.text = saved.eyebrow
    m.hint.text = saved.hint
    if m.page = "search"
        ' The page node kept its query, results and grid position.
        ShowSearchSurface()
        Focus("search")
        return
    end if
    m.detailCard = saved.detailCard
    if m.page = "home" and HasFeatured()
        ShowFeatured()
    else if m.page = "details" and m.detailCard <> invalid
        ' A show page's focused episode must not replace the show's hero.
        ShowHero(m.detailCard)
    else if m.currentCard <> invalid
        ShowHero(m.currentCard)
    end if
    m.ctaText.text = saved.cta
    if m.shelves.visible
        m.shelves.jumpToRowItem = saved.location
        area = "rows"
        if saved.focusArea <> invalid then area = saved.focusArea
        Focus(area)
    else
        Focus("cta")
    end if
end sub

sub StartDetailPlayback(fromStart as Boolean)
    StartItemPlayback(m.detail, fromStart, DetailArtwork())
end sub

' The open page's art: the title itself, or the show for its next episode.
function DetailArtwork() as String
    if m.detailCard = invalid then return ""
    return TextValue(m.detailCard.backdrop)
end function

sub StartItemPlayback(item as Object, fromStart as Boolean, artwork = "" as String)
    m.playItem = item
    ' Loading early lets the player open on the art instead of black.
    m.playerControls.artwork = artwork
    ticks = ResumeTicks(item)
    if fromStart then ticks = 0
    m.recoveryRequest = invalid
    m.playbackOptions = invalid
    m.playerControls.options = {}
    Send("play", {itemId: item.Id, title: item.Name, ticks: ticks, seriesId: TextValue(item.SeriesId)})
end sub

sub ActivateCTA(fromStart = false as Boolean)
    if m.page = "welcome"
        if m.connected
            OpenKeyboard("username", "Entrar em " + m.serverName, "", false)
        else
            Send("bootstrap", {})
        end if
    else if m.page = "details"
        if m.detail.Type = "Series" and IsMap(m.nextUp)
            StartItemPlayback(m.nextUp, fromStart, DetailArtwork())
        else if m.detail.Type = "Series" or m.detail.Type = "Season"
            PushPage()
            Send("children", {itemId: m.detail.Id, seriesId: TextValue(m.detail.SeriesId), kind: m.detail.Type, title: m.detail.Name})
        else if m.detail.Type = "Person" or m.detail.Type = "BoxSet"
            if m.shelves.visible then Focus("rows")
        else
            StartDetailPlayback(fromStart)
        end if
    else if m.page = "home" and HasFeatured()
        card = m.featuredCards[m.featuredIndex]
        if IsPlayLabel(HomeActionLabel(card)) then m.autoplayItemId = card.id
        Send("details", DetailsRequest(card))
    else if m.currentCard <> invalid
        Send("details", DetailsRequest(m.currentCard))
    else
        OpenSearch()
    end if
end sub

sub ActivateNav()
    navId = m.navIds[m.navIndex]
    if navId = "settings"
        ShowSettings()
        return
    end if
    if not m.loggedIn
        ActivateCTA()
        return
    end if
    if navId = "search"
        OpenSearch()
        return
    end if
    m.stack = []
    m.activeNavIndex = m.navIndex
    if navId = "home"
        Send("home", {})
    else
        kind = "Movie"
        m.railIndex = 0
        if navId = "series"
            kind = "Series"
            m.railIndex = 1
        end if
        m.browseRequest = {kind: kind, offset: 0}
        Send("browse", m.browseRequest)
    end if
end sub

function NavIndex(navId as String) as Integer
    for index = 0 to m.navIds.Count() - 1
        if m.navIds[index] = navId then return index
    end for
    return 0
end function

' The profile row shows the TV's local time, refreshed whenever the menu opens.
sub PaintSidebarClock()
    if m.clock = invalid then return
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    minutes = now.GetMinutes()
    suffix = minutes.ToStr()
    if minutes < 10 then suffix = "0" + suffix
    hours = now.GetHours().ToStr()
    if now.GetHours() < 10 then hours = "0" + hours
    m.clock.text = hours + ":" + suffix
end sub

sub SetAccountName(name as String)
    m.account.text = name
    if m.avatarInitial <> invalid then m.avatarInitial.text = UCase(Left(name, 1))
end sub

' Search is a page of the app, not a system dialog. Reopening it keeps the
' current query and results.
sub OpenSearch()
    m.stack = []
    m.activeNavIndex = NavIndex("search")
    m.navIndex = m.activeNavIndex
    if m.page <> "search"
        m.page = "search"
        ShowSearchSurface()
        m.searchScreen.enter = true
    end if
    Focus("search")
end sub

sub ShowSearchSurface()
    m.top.backgroundColor = "0x1c1c1eff"
    m.searchScreen.visible = true
    m.contentSurface.visible = false
    m.backdrop.visible = false
    m.heroShade.visible = false
    m.welcome.visible = false
end sub

' The next page restores its own artwork through ConfigurePageLayout.
sub HideSearchSurface()
    if m.searchScreen = invalid then return
    if not m.searchScreen.visible then return
    m.searchScreen.visible = false
    m.contentSurface.visible = true
    m.backdrop.visible = true
    m.heroShade.visible = true
end sub

' Typing must never wait: search bypasses the busy state and pending-focus
' parking. The Task serializes requests; the page keeps at most one queued.
sub OnSearchRequest()
    request = m.searchScreen.request
    if not IsMap(request) then return
    m.requestId++
    m.searchRequestId = m.requestId
    m.searchQuery = TextValue(request.query)
    m.searchOffset = 0
    if request.offset <> invalid then m.searchOffset = request.offset
    m.service.request = {action: "search", requestId: m.requestId, query: m.searchQuery, offset: m.searchOffset}
end sub

sub OnSearchResult(result as Object)
    if result.requestId <> m.searchRequestId then return
    if not result.ok and result.code = 401 and m.page = "search" and not m.busy
        m.loggedIn = false
        ShowLoginLanding()
        ShowMessage("Entre novamente", "O servidor está conectado, mas sua sessão expirou.", ["Entrar", "Cancelar"], "expired")
    end if
    m.searchScreen.response = {query: m.searchQuery, offset: m.searchOffset, ok: result.ok, content: result.content, total: result.total, message: result.message}
end sub

sub OnSearchSelected()
    card = m.searchScreen.selected
    if m.busy or m.page <> "search" or card = invalid then return
    if TextValue(card.id) = "" then return
    m.currentCard = card
    ' The details response pushes this page, so Back returns to the same result.
    Send("details", DetailsRequest(card))
end sub

sub ShowMessage(title as String, message as String, buttons as Object, mode as String)
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = title
    dialog.message = message
    dialog.buttons = buttons
    dialog.ObserveField("buttonSelected", "OnDialogButton")
    dialog.ObserveField("wasClosed", "OnDialogClosed")
    m.dialogMode = mode
    m.dialogOpen = true
    m.top.dialog = dialog
end sub

sub ShowServerPicker(message as String)
    buttons = []
    for each server in m.servers
        buttons.Push(server.name + "  ·  " + server.base)
    end for
    buttons.Push("Informar endereço do servidor")
    buttons.Push("Buscar novamente")
    buttons.Push("Fechar")
    ShowMessage("Encontre seu servidor", message, buttons, "servers")
end sub

sub ShowSettings()
    name = TextValue(m.serverName, "Não conectado")
    accountStatus = "Entre na sua conta para acessar a biblioteca."
    if m.loggedIn then accountStatus = "Você está conectado. Sua conta fica salva neste Roku."
    m.settingsActions = ["reconnect", "discover", "manual", "logout", "close"]
    labels = ["Reconectar", "Escolher servidor", "Informar endereço do servidor", "Sair da conta", "Fechar"]
    ' Only the server's administrator sees the other profiles.
    if m.loggedIn and m.canSwitchProfiles = true
        m.settingsActions.Unshift("profiles")
        labels.Unshift("Trocar perfil")
    end if
    ShowMessage("Ajustes do Luma", "Servidor: " + name + Chr(10) + accountStatus + Chr(10) + "A descoberta automática reconecta ao mesmo servidor quando o endereço IP muda.", labels, "settings")
end sub

sub OpenKeyboard(mode as String, title as String, value as String, secure as Boolean)
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    dialog.title = title
    dialog.text = value
    dialog.buttons = ["Continuar", "Cancelar"]
    if secure
        dialog.keyboardDomain = "password"
        dialog.textEditBox.secureMode = true
    end if
    dialog.ObserveField("buttonSelected", "OnKeyboardButton")
    dialog.ObserveField("wasClosed", "OnDialogClosed")
    m.dialogMode = mode
    m.dialogOpen = true
    m.top.dialog = dialog
end sub

sub CloseDialog()
    if m.top.dialog <> invalid then m.top.dialog.close = true
    m.dialogOpen = false
    Focus(m.focusArea)
end sub

sub OnKeyboardButton()
    dialog = m.top.dialog
    if dialog = invalid then return
    index = dialog.buttonSelected
    value = dialog.text
    mode = m.dialogMode
    CloseDialog()
    if index <> 0 then return
    if mode = "manual"
        Send("manual", {base: value})
    else if mode = "username"
        if value.Trim() = ""
            OpenKeyboard("username", "Digite seu usuário do Jellyfin", "", false)
            return
        end if
        m.username = value
        OpenKeyboard("password", "Senha de " + value, "", true)
    else if mode = "password"
        Send("login", {username: m.username, password: value})
        dialog.text = ""
    else if mode = "profilePassword" and IsMap(m.pendingProfile)
        Send("switchProfile", {userId: m.pendingProfile.userId, name: m.pendingProfile.name, hasPassword: true, password: value})
        dialog.text = ""
    end if
end sub

sub OnDialogButton()
    dialog = m.top.dialog
    if dialog = invalid then return
    index = dialog.buttonSelected
    mode = m.dialogMode
    CloseDialog()
    if mode = "servers"
        if index < m.servers.Count()
            server = m.servers[index]
            Send("select", {base: server.base, serverId: server.id})
        else if index = m.servers.Count()
            OpenKeyboard("manual", "Endereço do Jellyfin (inclua o caminho, se houver)", "http://", false)
        else if index = m.servers.Count() + 1
            Send("discover", {})
        end if
    else if mode = "settings"
        action = ""
        if index >= 0 and index < m.settingsActions.Count() then action = m.settingsActions[index]
        if action = "profiles" then Send("profiles", {})
        if action = "reconnect" then Send("bootstrap", {})
        if action = "discover" then Send("discover", {})
        if action = "manual" then OpenKeyboard("manual", "Endereço do Jellyfin (inclua o caminho, se houver)", "http://", false)
        if action = "logout" then ShowMessage("Sair da conta no Luma?", "Isso remove deste Roku os dados de acesso salvos para este servidor e todos os perfis.", ["Sair da conta", "Cancelar"], "logout")
    else if mode = "logout"
        if index = 0 then Send("logout", {})
    else if mode = "expired"
        if index = 0 then OpenKeyboard("username", "Entrar em " + m.serverName, "", false)
    else if mode = "error"
        if index = 0
            if m.lastRequest.action = "login"
                OpenKeyboard("username", "Entrar em " + m.serverName, "", false)
            else
                Send(m.lastRequest.action, m.lastRequest)
            end if
        else if index = 1
            Send("bootstrap", {})
        end if
    else if mode = "switchPlaybackError"
        if index = 0 and IsMap(m.recoveryRequest) then Send("play", m.recoveryRequest)
        if index = 1
            request = m.pendingPlayRequest
            if IsMap(request)
                request.forceTranscode = true
                request.quality = "auto"
                Send("play", request)
            end if
        end if
    else if mode = "playbackError"
        item = PlaybackItem()
        if index = 0 then Send("play", {itemId: item.Id, title: item.Name, ticks: ResumeTicks(item), forceTranscode: true})
        if index = 1 then Send("bootstrap", {})
    end if
end sub

sub OnVideoState(event = invalid as Dynamic)
    if event <> invalid
        if event.GetRoSGNode().id <> m.video.id then return
    end if
    state = m.video.state
    if m.pendingPlaybackResult <> invalid
        if state = "stopped" or state = "error" then CompletePlaybackReplacement()
        return
    end if
    ' Read before the controls see "finished" and withdraw the offer.
    upNextArmed = m.playerControls.upNextArmed = true
    SyncPlayerState()
    if m.playSession = invalid then return
    if state = "playing"
        if not m.started
            if not BeginPlaybackWhenReady() then return
        else
            SendReport("progress")
        end if
    else if state = "paused"
        if not m.started
            if not BeginPlaybackWhenReady() then return
        else
            SendReport("progress")
        end if
    else if state = "finished" and upNextArmed and IsMap(m.nextEpisode) and not m.busy
        ' The credits ran out before the countdown: go on to the next episode.
        PlayNextEpisode()
    else if state = "finished" or state = "error" or state = "stopped"
        failed = state = "error"
        StopPlayback(failed, state = "finished")
        if failed
            if IsMap(m.recoveryRequest)
                ShowMessage("Não foi possível usar esta opção", "Você pode restaurar as opções anteriores e continuar de onde parou.", ["Restaurar opções anteriores", "Tentar modo compatível", "Fechar"], "switchPlaybackError")
            else
                ShowMessage("Não foi possível reproduzir este título", "Verifique se o Jellyfin consegue converter este arquivo e tente novamente.", ["Tentar modo compatível", "Reconectar", "Fechar"], "playbackError")
            end if
        end if
    end if
end sub

sub OnVideoPosition(event = invalid as Dynamic)
    if event <> invalid
        if event.GetRoSGNode().id <> m.video.id then return
    end if
    if m.playSession = invalid then return
    if not m.started
        if not BeginPlaybackWhenReady() then return
    end if
    if m.video.state = "playing" or m.video.state = "paused"
        m.lastPosition = CDbl(m.video.position) * 10000000#
        SyncPlayerPosition()
    end if
end sub

sub ReportProgress()
    if m.playSession <> invalid then SendReport("progress")
end sub

sub SendReport(event as String, failed = false as Boolean)
    if m.playSession = invalid then return
    ' The Task serializes network I/O. Drop intermediate samples while a report
    ' is outstanding so an offline server cannot build an unbounded SG queue.
    ' Lifecycle reports must still arrive in order, especially the final stop.
    if event = "progress" and m.reportsPending > 0 then return
    ticks = m.lastPosition
    if m.video.state = "playing" or m.video.state = "paused" then ticks = CDbl(m.video.position) * 10000000#
    if not m.started then ticks = m.playOffset
    if ticks < 0 then ticks = 0
    m.lastPosition = ticks
    body = {}
    for each key in m.playSession
        body[key] = m.playSession[key]
    end for
    body.PositionTicks = ticks
    body.IsPaused = m.video.state = "paused"
    body.IsMuted = false
    body.Failed = failed
    Send("report", {event: event, body: body})
end sub

sub StopPlayback(failed = false as Boolean, completed = false as Boolean)
    m.segmentsItemId = invalid
    m.nextEpisode = invalid
    m.pendingPlayItem = invalid
    m.trackChoice = invalid
    if m.playerControls <> invalid
        m.playerControls.segments = []
        m.playerControls.hasNextEpisode = false
    end if
    m.resumeTargetSeconds = invalid
    if m.resumeCover <> invalid then m.resumeCover.visible = false
    m.seekPausePending = false
    if m.resumeTimer <> invalid then m.resumeTimer.control = "stop"
    m.playRequestId = -1
    if m.pendingPlaybackResult <> invalid
        Send("report", {event: "stopped", body: m.pendingPlaybackResult.session})
        m.pendingPlaybackResult = invalid
        m.pendingPlaybackRequest = invalid
        m.busy = false
        m.playerControls.busy = false
        m.playerControls.visible = false
        m.video.visible = false
        m.switchingPlayback = false
        item = PlaybackItem()
        if IsMap(item)
            if not IsMap(item.UserData) then item.UserData = {}
            item.UserData.PlaybackPositionTicks = m.lastPosition
            ' Only a title's own details page shows the resume/restart pair.
            if HasDetailActions()
                m.ctaText.text = "Continuar"
                m.secondary.visible = true
            end if
        end if
        if HasDetailActions() then Focus("cta") else Focus(m.focusArea)
    end if
    if m.switchingPlayback = true
        m.busy = false
        m.spinner.control = "stop"
        m.spinner.visible = false
    end if
    if m.playSession = invalid then return
    SendReport("stopped", failed)
    m.playSession = invalid
    m.reportTimer.control = "stop"
    m.video.control = "stop"
    m.video.visible = false
    if m.playerControls <> invalid then m.playerControls.visible = false
    m.switchingPlayback = false
    item = PlaybackItem()
    if m.page = "home"
        if IsMap(item)
            if not IsMap(item.UserData) then item.UserData = {}
            item.UserData.PlaybackPositionTicks = m.lastPosition
        end if
        ' Home comes back at once, exactly as it was, with this title's progress
        ' bar updated; fresh rows arrive quietly and update in place.
        ShowCardProgress(item, completed)
        Focus(m.focusArea)
        Send("home", {quiet: true})
        m.quietHomeRequestId = m.requestId
        return
    end if
    if m.page = "details" and IsMap(m.detail) and IsMap(item)
        if m.detail.Type = "Series"
            if not IsMap(item.UserData) then item.UserData = {}
            item.UserData.PlaybackPositionTicks = m.lastPosition
            m.refreshDetailsId = m.detail.Id
            Send("details", {itemId: m.detail.Id, kind: TextValue(m.detail.Type)})
            return
        end if
    end if
    if IsMap(item) and not HasDetailActions()
        ' Started from a library or search card: stay on that card.
        if not IsMap(item.UserData) then item.UserData = {}
        item.UserData.PlaybackPositionTicks = m.lastPosition
        Focus(m.focusArea)
        return
    end if
    if IsMap(item)
        if not IsMap(item.UserData) then item.UserData = {}
        item.UserData.PlaybackPositionTicks = m.lastPosition
        m.ctaText.text = "Continuar"
        m.secondary.visible = true
        if completed
            item.UserData.PlaybackPositionTicks = 0
            m.ctaText.text = "Reproduzir novamente"
            m.secondary.visible = false
        end if
    end if
    Focus("cta")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    NoteActivity()
    if m.video.visible
        if key = "back"
            StopPlayback()
            return true
        end if
        return false
    end if
    if DialogOpen() then return false
    if m.busy
        if key = "back"
            ' Mutating account operations continue in the Task; Back may exit
            ' the app, but cannot pretend those operations have been cancelled.
            if m.pendingNavigationRequestId = invalid then return false
            m.cancelledThroughRequestId = m.pendingNavigationRequestId
            m.pendingNavigationRequestId = invalid
            m.autoplayItemId = invalid
            m.refreshDetailsId = invalid
            m.playRequestId = -1
            m.busy = false
            m.spinner.control = "stop"
            m.spinner.visible = false
            Focus(m.focusArea)
        end if
        return true
    end if
    if key = "options"
        ShowSettings()
        return true
    else if key = "back"
        if m.focusArea = "featuredPrevious" or m.focusArea = "featuredNext" or m.focusArea = "info"
            Focus("cta")
            return true
        end if
        if m.stack.Count() > 0
            PopPage()
        else if m.focusArea <> "nav"
            Focus("nav")
        else
            return false
        end if
        return true
    end if
    if m.focusArea = "nav"
        if key = "up"
            if m.navIndex > 0 then m.navIndex--
        else if key = "down"
            if m.navIndex < m.navNames.Count() - 1 then m.navIndex++
        else if key = "right"
            area = m.contentFocusArea
            if area = "rows"
                if not m.shelves.visible or m.currentCard = invalid then area = "cta"
            end if
            if area = "secondary" and not m.secondary.visible then area = "cta"
            if area = "back" and m.page <> "details" then area = "cta"
            if area = "info" and not m.info.visible then area = "cta"
            if area = "rail" and m.page <> "browse" then area = "cta"
            if area = "choice" then area = "cta"
            Focus(area)
        else if key = "left"
            return true
        else if key = "OK"
            ActivateNav()
        else
            return false
        end if
        PaintFocus()
        return true
    else if m.focusArea = "search"
        ' Reached only when the keyboard's first column passes Left upward.
        if key = "left"
            Focus("nav")
            return true
        end if
        return false
    else if m.focusArea = "back"
        if key = "down"
            Focus("cta")
        else if key = "left"
            Focus("nav")
        else if key = "OK"
            PopPage()
        else if key <> "up" and key <> "right"
            return false
        end if
        return true
    else if m.focusArea = "info"
        if key = "left"
            Focus("cta")
        else if key = "right"
            if m.featuredCards.Count() > 1 then Focus("featuredPrevious")
        else if key = "up"
            Focus("nav")
        else if key = "down"
            if m.shelves.visible and m.currentCard <> invalid then Focus("rows")
        else if key = "OK"
            if HasFeatured() then Send("details", DetailsRequest(m.featuredCards[m.featuredIndex]))
        else if key = "play"
            ActivateCTA()
        else
            return false
        end if
        return true
    else if m.focusArea = "featuredPrevious" or m.focusArea = "featuredNext"
        if key = "left"
            if m.focusArea = "featuredNext"
                Focus("featuredPrevious")
            else if m.info.visible
                Focus("info")
            else
                Focus("cta")
            end if
        else if key = "right"
            Focus("featuredNext")
        else if key = "up"
            Focus("cta")
        else if key = "down"
            Focus("rows")
        else if key = "OK"
            stepBy = 1
            if m.focusArea = "featuredPrevious" then stepBy = -1
            ChangeFeatured(stepBy)
        else if key = "play"
            ActivateCTA()
        else
            return false
        end if
        return true
    else if m.focusArea = "cta" or m.focusArea = "secondary"
        if key = "up" and m.page = "details"
            Focus("back")
        else if key = "up"
            Focus("nav")
        else if key = "down"
            if m.shelves.visible and m.currentCard <> invalid then Focus("rows")
        else if key = "right" and m.page = "home" and HasFeatured()
            if m.info.visible
                Focus("info")
            else if m.featuredCards.Count() > 1
                Focus("featuredPrevious")
            end if
        else if key = "right" and m.secondary.visible
            Focus("secondary")
        else if key = "left"
            if m.focusArea = "secondary"
                Focus("cta")
            else
                Focus("nav")
            end if
        else if key = "OK" or key = "play"
            ActivateCTA(m.focusArea = "secondary")
        else
            return false
        end if
        return true
    else if m.focusArea = "rail"
        if key = "up"
            if m.railIndex > 0 then m.railIndex--
        else if key = "down"
            if m.railIndex < m.railRows.Count() - 1 then m.railIndex++
        else if key = "right"
            if m.shelves.visible and m.currentCard <> invalid then Focus("rows")
        else if key = "left"
            Focus("nav")
        else if key = "OK"
            ActivateRail()
        else
            return false
        end if
        PaintLibraryRail()
        return true
    else if m.focusArea = "rows"
        ' RowList consumes every arrow it can still move with, so one reaching
        ' the Scene is its edge. rowItemFocused only updates once the scroll
        ' animation finishes, so checking it dropped a quick second Up or Left.
        if key = "left"
            if m.page = "browse"
                Focus("rail")
            else
                Focus("nav")
            end if
            return true
        else if key = "up"
            if m.page = "browse"
                Focus("nav")
            else
                Focus("cta")
            end if
            return true
        else if key = "play"
            ' The remote's Play key starts any playable card at once.
            if m.currentCard <> invalid
                kind = TextValue(m.currentCard.kind)
                if kind = "Movie" or kind = "Episode" then m.autoplayItemId = m.currentCard.id
                Send("details", DetailsRequest(m.currentCard))
            end if
            return true
        else if key = "fastforward" or key = "replay" or key = "rewind"
            if m.page = "browse"
                offset = m.offset + 48
                if key <> "fastforward" then offset = m.offset - 48
                if offset >= 0 and offset < m.total
                    m.browseRequest.offset = offset
                    Send(m.page, m.browseRequest)
                end if
                return true
            end if
        end if
    end if
    return false
end function

sub ConfigurePageLayout()
    PaintFeatured()
    if m.libraryRail = invalid then return
    ConfigureHeroGeometry()
    catalog = m.page = "browse"
    m.libraryRail.visible = catalog
    m.backdrop.visible = not catalog
    m.heroShade.visible = not catalog
    m.meta.visible = not catalog
    m.synopsis.visible = not catalog
    m.cta.visible = not catalog
    layoutMode = "list"
    if m.page = "home" then layoutMode = "home"
    if catalog then layoutMode = "catalog"
    if catalog
        m.heroTitle.visible = false
        m.heroLogo.visible = false
        m.eyebrow.visible = false
        PaintLibraryRail()
    end if
    ' Apple's Library sits on charcoal; everything else on near-black.
    m.top.backgroundColor = "0x090909ff"
    if catalog then m.top.backgroundColor = "0x1c1c1eff"
    if m.uiMotionReady = true then UpdateHomeLayout(false)
    if m.shelfLayoutMode = layoutMode then return
    m.shelfLayoutMode = layoutMode
    if catalog
        m.shelves.translation = [440, 185]
        m.shelves.itemSize = [1400, 394]
        m.shelves.rowHeights = [394]
        m.shelves.rowItemSize = [[224, 372]]
        m.shelves.rowItemSpacing = [[8, 0]]
        m.shelves.itemSpacing = [0, 42]
        m.shelves.showRowLabel = [false]
        m.shelves.numRows = 2
    else
        m.shelves.translation = [68, 688]
        m.shelves.itemSize = [1784, 314]
        m.shelves.rowHeights = [314]
        m.shelves.rowItemSize = [[364, 263]]
        m.shelves.rowItemSpacing = [[2, 0]]
        m.shelves.itemSpacing = [0, 24]
        m.shelves.showRowLabel = [true]
        m.shelves.numRows = 1
        if m.page = "home" or m.page = "details" then m.shelves.numRows = 2
        ApplyRowSizes()
    end if
end sub

' Cast rows hold narrow portraits; every other rail keeps the 16:9 tile.
sub ApplyRowSizes()
    if m.shelfLayoutMode = "catalog" then return
    sizes = []
    content = m.shelves.content
    if content <> invalid
        for i = 0 to content.GetChildCount() - 1
            if content.GetChild(i).rowStyle = "person"
                sizes.Push([224, 263])
            else
                sizes.Push([364, 263])
            end if
        end for
    end if
    if sizes.Count() = 0 then sizes = [[364, 263]]
    m.shelves.rowItemSize = sizes
end sub

' The category column marks the open library with Apple's soft pill.
sub PaintLibraryRail()
    if m.railRows = invalid
        m.railRows = []
        for each name in ["Movies", "Series", "Collections", "Sort", "Genre", "Unwatched"]
            row = {bg: m.top.FindNode("rail" + name + "Bg"), label: m.top.FindNode("rail" + name), caption: m.top.FindNode("rail" + name + "Caption")}
            ApplyRounded(row.bg, 30)
            m.railRows.Push(row)
        end for
        m.railCheck = m.top.FindNode("railUnwatchedCheck")
        m.railEmpty = m.top.FindNode("railEmpty")
        if m.railIndex = invalid then m.railIndex = 0
    end if
    request = m.browseRequest
    if not IsMap(request) then request = {kind: "Movie"}
    m.railRows[3].label.text = SortLabel(TextValue(request.sort))
    m.railRows[4].label.text = TextValue(request.genreName, "Todos")
    m.railCheck.visible = request.unwatched = true
    kinds = ["Movie", "Series", "BoxSet"]
    for index = 0 to m.railRows.Count() - 1
        row = m.railRows[index]
        focused = m.focusArea = "rail" and index = m.railIndex
        ' Categories are dim until chosen; the settings below read as values.
        color = "0x9a9a9eff"
        row.bg.color = "0x00000000"
        if index < 3
            if kinds[index] = request.kind
                row.bg.color = "0xffffff24"
                color = "0xffffffff"
            end if
        else if index < 5 or request.unwatched = true
            color = "0xffffffff"
        end if
        if focused
            row.bg.color = "0xffffffff"
            color = "0x111111ff"
        end if
        row.label.color = color
        if row.caption <> invalid
            row.caption.color = "0x9a9a9eff"
            if focused then row.caption.color = "0x48484aff"
        end if
    end for
    m.railCheck.blendColor = "0xffffffff"
    if m.focusArea = "rail" and m.railIndex = 5 then m.railCheck.blendColor = "0x111111ff"
    m.railEmpty.visible = m.page = "browse" and m.currentCard = invalid
    m.railEmpty.text = "Nada por aqui ainda."
    if TextValue(request.genreId) <> "" or request.unwatched = true
        m.railEmpty.text = "Nenhum título com estes filtros."
    else if request.kind = "BoxSet"
        m.railEmpty.text = "Nenhuma coleção na biblioteca."
    end if
end sub

function SortLabel(sort as String) as String
    if sort = "name" then return "A–Z"
    if sort = "year" then return "Ano de lançamento"
    return "Data de adição"
end function

' Genres differ between categories; order and unwatched carry over.
sub ActivateRail()
    request = m.browseRequest
    if not IsMap(request) then return
    if m.railIndex < 3
        kinds = ["Movie", "Series", "BoxSet"]
        kind = kinds[m.railIndex]
        if kind = request.kind then return
        m.browseRequest = {kind: kind, offset: 0, sort: request.sort, unwatched: request.unwatched}
        if kind = "Movie" then m.activeNavIndex = NavIndex("movies")
        if kind = "Series" then m.activeNavIndex = NavIndex("series")
        Send("browse", m.browseRequest)
    else if m.railIndex = 3
        sorts = ["recent", "name", "year"]
        checked = 0
        for index = 0 to sorts.Count() - 1
            if sorts[index] = TextValue(request.sort, "recent") then checked = index
        end for
        OpenChoice("sort", "Ordenar por", ["Data de adição", "A–Z", "Ano de lançamento"], checked)
    else if m.railIndex = 4
        Send("genres", {kind: request.kind})
    else
        request.unwatched = request.unwatched <> true
        request.offset = 0
        Send("browse", request)
    end if
end sub

sub OpenChoice(purpose as String, title as String, options as Object, checked as Integer)
    m.choicePurpose = purpose
    m.choiceReturnArea = m.focusArea
    m.choiceMenu.title = title
    m.choiceMenu.checkedIndex = checked
    m.choiceMenu.options = options
    m.choiceMenu.visible = true
    Focus("choice")
end sub

sub CloseChoice()
    m.choiceMenu.visible = false
    area = TextValue(m.choiceReturnArea, "cta")
    if area = "choice" then area = "cta"
    Focus(area)
end sub

sub OnChoiceDismissed()
    CloseChoice()
end sub

sub OnChoiceChosen()
    index = m.choiceMenu.chosen
    purpose = m.choicePurpose
    CloseChoice()
    if purpose = "sort"
        sorts = ["recent", "name", "year"]
        m.browseRequest.sort = sorts[index]
        m.browseRequest.offset = 0
        Send("browse", m.browseRequest)
    else if purpose = "genre"
        m.browseRequest.genreId = ""
        m.browseRequest.genreName = invalid
        if index > 0
            genre = m.genreChoices[index - 1]
            m.browseRequest.genreId = genre.id
            m.browseRequest.genreName = genre.name
        end if
        m.browseRequest.offset = 0
        Send("browse", m.browseRequest)
    else if purpose = "profile"
        profile = m.profileChoices[index]
        Send("switchProfile", {userId: profile.id, name: profile.name, hasPassword: profile.hasPassword})
    end if
end sub

' A small deterministic selection of real Home items; duplicates across shelves
' do not consume carousel pages. Shelf focus never mutates this selection.
function FeaturedCards(content as Dynamic) as Object
    cards = []
    seen = {}
    if content = invalid then return cards
    for each row in content.GetChildren(-1, 0)
        for each card in row.GetChildren(-1, 0)
            id = TextValue(card.id)
            if id <> "" and not seen.DoesExist(id)
                cards.Push(card)
                seen[id] = true
                if cards.Count() = 5 then return cards
            end if
        end for
    end for
    return cards
end function

' Like the Jellyfin TV apps' screensaver: after three idle minutes away from
' playback, show the library's artwork full screen until any key is pressed.
' Instant Resume keeps Luma in memory when the viewer leaves. The decoder is
' lost on suspend, so playback stops and saves its position as Back would.
sub customSuspend(arg as Dynamic)
    if m.playSession <> invalid or m.video.visible then StopPlayback()
    StopAmbient()
end sub

sub customResume(arg as Dynamic)
    if m.page = "home" and m.stack.Count() = 0 and not m.busy
        Send("home", {quiet: true})
        m.quietHomeRequestId = m.requestId
    end if
    Focus(m.focusArea)
    NoteActivity()
    m.top.signalBeacon("AppResumeComplete")
end sub

sub NoteActivity()
    if m.idleTimer = invalid or m.ambientActive = true then return
    m.idleTimer.control = "stop"
    m.idleTimer.control = "start"
end sub

sub OnIdle()
    if not CanStartAmbient()
        NoteActivity()
        return
    end if
    m.ambientActive = true
    m.ambient.items = AmbientFallback()
    m.ambient.visible = true
    m.ambient.active = true
    Send("ambient", {})
end sub

function CanStartAmbient() as Boolean
    if not m.loggedIn or m.busy or m.video.visible then return false
    if DialogOpen() then return false
    return m.page = "home" or m.page = "details" or m.page = "browse"
end function

function DialogOpen() as Boolean
    return m.dialogOpen = true and m.top.dialog <> invalid
end function

' Dialog.close is write-only and Back/Home dismiss a dialog without it; only
' the wasClosed event reports every dismissal, so the Scene tracks it here.
sub OnDialogClosed(event as Object)
    if m.top.dialog = invalid then return
    if not event.GetRoSGNode().IsSameNode(m.top.dialog) then return
    if m.dialogOpen <> true then return
    m.dialogOpen = false
    if not m.video.visible then Focus(m.focusArea)
end sub

sub StopAmbient()
    if m.ambientActive <> true then return
    m.ambientActive = false
    m.ambient.active = false
    m.ambient.visible = false
    Focus(m.focusArea)
end sub

' Shown at once from the loaded Home; replaced by a random library set.
function AmbientFallback() as Object
    items = []
    seen = {}
    cards = []
    if IsList(m.featuredCards) then cards.Append(m.featuredCards)
    content = m.shelves.content
    if content <> invalid
        for each row in content.GetChildren(-1, 0)
            cards.Append(row.GetChildren(-1, 0))
        end for
    end if
    for each card in cards
        id = TextValue(card.id)
        if id <> "" and not seen.DoesExist(id) and TextValue(card.backdrop) <> ""
            seen[id] = true
            items.Push({backdrop: card.backdrop, logo: TextValue(card.logo), title: TextValue(card.title), meta: TextValue(card.meta)})
        end if
    end for
    return items
end function

' After playing from a shelf, Home returns to that shelf. The watched title
' moves to the front of Continue Watching, so that row restores to its start.
' The progress bar of the title just watched moves before Home's fresh rows
' arrive, so the page never looks stale on return.
sub ShowCardProgress(item as Dynamic, completed as Boolean)
    if not IsMap(item) or m.shelves.content = invalid then return
    progress = 0.0
    if not completed and item.RunTimeTicks <> invalid
        if item.RunTimeTicks > 0 then progress = m.lastPosition / item.RunTimeTicks
    end if
    if progress > 1 then progress = 1
    for each row in m.shelves.content.GetChildren(-1, 0)
        for each card in row.GetChildren(-1, 0)
            if TextValue(card.id) = TextValue(item.Id) then card.progress = progress
        end for
    end for
end sub

' Fresh Continue Watching after playback, applied without reloading the page:
' no spinner, no entrance animation, and focus stays on the same title.
sub RefreshHomeInPlace(content as Dynamic)
    if m.page <> "home" or m.stack.Count() > 0 or m.video.visible then return
    if content = invalid then return
    if content.GetChildCount() = 0 then return
    focusedId = invalid
    if m.currentCard <> invalid then focusedId = m.currentCard.id
    featuredId = invalid
    if HasFeatured() then featuredId = m.featuredCards[m.featuredIndex].id
    location = m.shelves.rowItemFocused
    m.featuredCards = FeaturedCards(content)
    m.featuredIndex = FeaturedIndexOf(featuredId)
    m.shelves.content = content
    target = CardLocation(content, focusedId, location)
    if target <> invalid then m.shelves.jumpToRowItem = target
    ShowFeatured()
    PaintFeatured()
end sub

' The same title in its old row first (Continue Watching reorders), then in any
' row; otherwise the old position, clamped to the new rows.
function CardLocation(content as Object, id as Dynamic, previous as Dynamic) as Dynamic
    preferred = 0
    if IsList(previous)
        if previous.Count() = 2 then preferred = previous[0]
    end if
    rows = content.GetChildren(-1, 0)
    order = [preferred]
    for index = 0 to rows.Count() - 1
        if index <> preferred then order.Push(index)
    end for
    if TextValue(id) <> ""
        for each rowIndex in order
            if rowIndex >= 0 and rowIndex < rows.Count()
                cards = rows[rowIndex].GetChildren(-1, 0)
                for column = 0 to cards.Count() - 1
                    if TextValue(cards[column].id) = TextValue(id) then return [rowIndex, column]
                end for
            end if
        end for
    end if
    if not IsList(previous) then return invalid
    if previous.Count() <> 2 then return invalid
    row = previous[0]
    if row < 0 then row = 0
    if row >= rows.Count() then row = rows.Count() - 1
    count = rows[row].GetChildCount()
    if count = 0 then return invalid
    column = previous[1]
    if column >= count then column = count - 1
    if column < 0 then column = 0
    return [row, column]
end function

function FeaturedIndexOf(id as Dynamic) as Integer
    if id = invalid then return 0
    for index = 0 to m.featuredCards.Count() - 1
        if TextValue(m.featuredCards[index].id) = TextValue(id) then return index
    end for
    return 0
end function

function HasFeatured() as Boolean
    if not IsList(m.featuredCards) then return false
    return m.featuredCards.Count() > 0
end function

sub ShowFeatured()
    if not HasFeatured() then return
    card = m.featuredCards[m.featuredIndex]
    ShowHero(card)
    SchedulePrefetch(card, IsPlayLabel(HomeActionLabel(card)))
end sub

sub ChangeFeatured(stepBy as Integer)
    if not HasFeatured() then return
    count = m.featuredCards.Count()
    m.featuredIndex = (m.featuredIndex + stepBy + count) mod count
    ShowFeatured()
end sub

' Apple's page indicator: small dots in a dark capsule; the current page is a pill.
sub PaintFeatured()
    if m.featuredDots = invalid then return
    count = 0
    if m.page = "home" and HasFeatured() then count = m.featuredCards.Count()
    m.featuredPrevious.visible = count > 1
    m.featuredNext.visible = count > 1
    m.featuredDots.visible = count > 1
    m.info.visible = m.page = "home" and count > 0
    if count < 2 then return
    if m.featuredDotNodes = invalid then m.featuredDotNodes = []
    while m.featuredDotNodes.Count() < count
        dot = m.featuredDots.CreateChild("Rectangle")
        dot.height = 10
        ApplyRounded(dot, 5)
        m.featuredDotNodes.Push(dot)
    end while
    if m.featuredPaintCount = count and m.featuredPaintIndex = m.featuredIndex then return
    m.featuredPaintCount = count
    m.featuredPaintIndex = m.featuredIndex
    x = 14
    for index = 0 to m.featuredDotNodes.Count() - 1
        dot = m.featuredDotNodes[index]
        dot.visible = index < count
        dot.width = 10
        dot.color = "0xffffff66"
        if index = m.featuredIndex
            dot.width = 30
            dot.color = "0xffffffff"
        end if
        dot.translation = [x, 9]
        if dot.visible then x += dot.width + 10
    end for
    width = x + 4
    m.featuredDotsBg.width = width
    m.featuredDots.translation = [960 - width / 2, 846]
end sub

' Home geometry follows Apple's navigation-2.png scaled to 1080p; detail geometry
' follows the SILO canvas in tvos-player-17.png (PiP dimming and badges omitted).
sub ConfigureHeroGeometry()
    details = m.page = "details"
    m.eyebrow.visible = not details and m.page <> "home"
    m.detailGenre.visible = details
    m.backButton.visible = details
    if details
        m.logoBox = {x: 80, bottom: 640, width: 560, height: 120}
        m.heroTitle.translation = [80, 500]
        m.heroTitle.width = 1040
        m.heroTitle.height = 140
        m.heroTitle.font.size = 56
        m.detailGenre.translation = [80, 652]
        m.synopsis.translation = [80, 704]
        m.synopsis.width = 670
        m.synopsis.height = 118
        m.synopsis.maxLines = 4
        m.synopsis.font.size = 23
        m.meta.translation = [80, 842]
        m.cta.translation = [80, 899]
        m.ctaBg.width = 352
        m.secondary.translation = [456, 899]
        m.backdrop.height = 1080
        m.detailGenre.text = ""
        if IsMap(m.detail) then m.detailGenre.text = DetailGenre({Type: m.detail.Type, Genres: FirstGenres(m.detail.Genres, 3)})
    else
        m.logoBox = {x: 80, bottom: 540, width: 700, height: 190}
        m.heroTitle.translation = [80, 380]
        m.heroTitle.width = 1030
        m.heroTitle.height = 160
        m.heroTitle.font.size = 72
        m.synopsis.translation = [80, 604]
        m.synopsis.width = 720
        m.synopsis.height = 76
        m.synopsis.maxLines = 2
        m.synopsis.font.size = 25
        m.meta.translation = [80, 556]
        m.cta.translation = [80, 724]
        m.ctaBg.width = 290
        m.secondary.translation = [394, 724]
        m.backdrop.height = 1080
    end if
    FitHeroLogo()
    PaintActionLabel()
end sub

' Play actions carry Apple's play glyph; the glyph and label are centered as one
' unit using Inter SemiBold's average advance at 25px.
sub PaintActionLabel()
    if m.ctaIcon = invalid then return
    width = m.ctaBg.width
    playing = IsPlayLabel(TextValue(m.ctaText.text))
    m.ctaIcon.visible = playing
    m.ctaText.horizAlign = "center"
    m.ctaText.translation = [0, 0]
    m.ctaText.width = width
    if playing
        content = 40 + Len(TextValue(m.ctaText.text)) * 14
        start = Int((width - content) / 2)
        if start < 20 then start = 20
        m.ctaIcon.translation = [start, 18]
        m.ctaText.horizAlign = "left"
        m.ctaText.translation = [start + 40, 0]
        m.ctaText.width = width - start - 40
    end if
    if m.page = "home"
        m.info.translation = [80 + width + 16, 724]
        m.featuredPrevious.translation = [80 + width + 96, 724]
        m.featuredNext.translation = [80 + width + 176, 724]
    end if
end sub

function DetailGenre(item as Dynamic) as String
    if not IsMap(item) then return ""
    label = TextValue(item.Type)
    if label = "Series" then label = "Série"
    if label = "Movie" then label = "Filme"
    if label = "Episode" then label = "Episódio"
    if label = "Season" then label = "Temporada"
    if label = "Person" then label = ""
    if label = "BoxSet" then label = "Coleção"
    if IsList(item.Genres)
        for each genre in item.Genres
            if label <> "" then label += " · "
            label += TextValue(genre)
        end for
    end if
    return label
end function
