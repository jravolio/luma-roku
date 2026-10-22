' Exercise production navigation with only SceneGraph nodes and dialogs mocked.
sub Main()
    m.assertions = 0
    AssertEqual(ResumeTicks({UserData: {PlaybackPositionTicks: 900000000}}), 900000000#, "short integer resume preserves ticks")
    AssertEqual(ResumeTicks({UserData: {PlaybackPositionTicks: 72000000000#}}), 72000000000#, "long resume preserves double precision")
    AssertEqual(ResumeTicks({UserData: {}}), 0#, "missing position returns double zero")
    AssertEqual(ResumeTicks({}), 0#, "missing user data returns double zero")
    TestHardwareSidebarFocus()
    TestExclusiveInput()
    TestDetailsBackButton()
    TestDialogDismissedByBack()
    TestCachedLaunch()
    TestLibraryRail()
    TestProfileSettings()
    ResetNavigation()
    Focus("nav")
    AssertEqual(onKeyEvent("up", true), true, "sidebar consumes up at first item")
    AssertEqual(m.navIndex, 0, "sidebar does not wrap at top")
    for index = 1 to 8
        onKeyEvent("down", true)
    end for
    AssertEqual(m.navIndex, 4, "sidebar stops at final item")
    onKeyEvent("up", true)
    AssertEqual(m.navIndex, 3, "sidebar moves vertically")
    onKeyEvent("right", true)
    AssertEqual(m.focusArea, "cta", "right returns to content action")
    onKeyEvent("left", true)
    AssertEqual(m.focusArea, "nav", "left from primary action enters sidebar")

    ResetNavigation()
    Focus("rows")
    m.shelves.rowItemFocused = [1, 0]
    AssertEqual(onKeyEvent("left", true), true, "first card transfers left to sidebar")
    AssertEqual(m.contentFocusArea, "rows", "sidebar remembers content focus")
    onKeyEvent("right", true)
    AssertEqual(m.focusArea, "rows", "right restores same shelf")
    AssertEqual(m.shelves.rowItemFocused[0], 1, "sidebar return preserves row")
    ' RowList consumes Up while a row is above, but sets rowItemFocused only after
    ' its scroll animation: a quick second Up arrives still reporting row 1.
    AssertEqual(onKeyEvent("up", true), true, "Up passed on mid-scroll reaches hero action")
    AssertEqual(m.focusArea, "cta", "first shelf transfers to primary action")
    onKeyEvent("down", true)
    AssertEqual(m.focusArea, "rows", "down from action returns to collection")
    m.shelves.rowItemFocused = [0, 3]
    AssertEqual(onKeyEvent("left", true), true, "Left passed on mid-scroll reaches the sidebar")
    AssertEqual(m.focusArea, "nav", "a quick second Left does not get lost")
    AssertEqual(onKeyEvent("left", false), false, "key releases do not move focus")

    ResetNavigation()
    m.secondary.visible = true
    onKeyEvent("right", true)
    AssertEqual(m.focusArea, "secondary", "right reaches play-from-start action")
    onKeyEvent("left", true)
    AssertEqual(m.focusArea, "cta", "left from secondary reaches primary")
    onKeyEvent("left", true)
    AssertEqual(m.focusArea, "nav", "another left reaches sidebar")
    Focus("secondary")
    Focus("nav")
    m.secondary.visible = false
    onKeyEvent("right", true)
    AssertEqual(m.focusArea, "cta", "hidden action cannot receive restored focus")

    ResetNavigation()
    Focus("rows")
    onKeyEvent("back", true)
    AssertEqual(m.focusArea, "nav", "back from root shelf reaches sidebar")
    AssertEqual(onKeyEvent("back", true), false, "back from root sidebar exits through platform")
    m.stack.Push({page: "home", content: {}, card: invalid, detail: {}, location: [0, 2], eyebrow: "HOME", hint: "hint", cta: "Ver detalhes", secondary: false, browseRequest: invalid, total: 3, offset: 0, count: 3})
    m.page = "details"
    onKeyEvent("back", true)
    AssertEqual(m.page, "home", "back from details restores previous page")
    AssertEqual(m.shelves.jumpToRowItem[1], 2, "back restores previous card")
    AssertEqual(m.focusArea, "rows", "back restores shelf focus")

    ResetNavigation()
    m.loggedIn = false
    m.connected = false
    m.page = "welcome"
    m.navIndex = NavIndex("movies")
    ActivateNav()
    AssertEqual(m.service.request.action, "bootstrap", "unauthenticated movies starts server discovery")
    AssertEqual(m.loggedIn, false, "discovery does not imply authentication")
    m.busy = false
    ShowSettings()
    AssertEqual(Instr(1, m.message, "Entre na sua conta") > 0, true, "settings does not claim a saved login before auth")

    ResetNavigation()
    m.service.result = {action: "home", ok: false, code: 401}
    OnResult()
    AssertEqual(m.loggedIn, false, "expired session revokes signed-in UI")
    AssertEqual(m.account.text, "Não conectado", "expired session clears account label")
    AssertEqual(m.currentCard, invalid, "expired session clears previous card")
    AssertEqual(m.page, "welcome", "expired session returns to login landing")
    AssertEqual(m.shelves.visible, false, "expired session hides collection")
    ResetNavigation()
    a = {id: "a", title: "First", logo: "", backdrop: "a.jpg", description: "A", meta: "Movie"}
    b = {id: "b", title: "Second", logo: "", backdrop: "b.jpg", description: "B", meta: "Movie"}
    content = NodeChildren([NodeChildren([a, b]), NodeChildren([a, {id: "c"}, {id: "d"}, {id: "e"}, {id: "f"}])])
    m.featuredCards = FeaturedCards(content)
    AssertEqual(m.featuredCards.Count(), 5, "featured selection caps at five actual items")
    AssertEqual(m.featuredCards[2].id, "c", "repeated items across shelves do not consume pages")
    AssertEqual(FeaturedCards(invalid).Count(), 0, "missing Home content yields no features")
    AssertEqual(FeaturedCards(NodeChildren([])).Count(), 0, "empty library yields no features")
    m.featuredCards = [a, b]
    m.featuredIndex = 0
    m.shelves.rowItemFocused = [0, 2]
    onKeyEvent("right", true)
    AssertEqual(m.focusArea, "featuredPrevious", "hero action reaches previous feature control")
    onKeyEvent("right", true)
    AssertEqual(m.focusArea, "featuredNext", "next feature is reachable with right")
    onKeyEvent("OK", true)
    AssertEqual(m.featuredIndex, 1, "OK advances actual featured item")
    AssertEqual(m.heroTitle.text, "Second", "featured selection updates visible title")
    AssertEqual(m.backdrop.uri, "b.jpg", "featured selection updates real artwork")
    AssertEqual(m.currentCard.id, "item", "featured change preserves shelf selection")
    AssertEqual(m.shelves.rowItemFocused[1], 2, "featured change preserves shelf location")
    onKeyEvent("OK", true)
    AssertEqual(m.featuredIndex, 0, "next wraps to first feature")
    onKeyEvent("left", true)
    onKeyEvent("OK", true)
    AssertEqual(m.featuredIndex, 1, "previous wraps to last feature")
    onKeyEvent("back", true)
    AssertEqual(m.focusArea, "cta", "Back from carousel returns to action")
    ActivateCTA()
    AssertEqual(m.service.request.itemId, "b", "hero action opens feature independently of shelf")
    m.shelves.content = NodeChildren([NodeChildren([a, b, a])])
    m.busy = false
    Focus("rows")
    OnCardFocus()
    Focus("cta")
    AssertEqual(m.currentCard.id, "a", "shelf focus still updates selected shelf item")
    AssertEqual(m.heroTitle.text, "Second", "shelf focus does not replace featured hero")
    m.busy = false
    PushPage()
    m.page = "details"
    m.featuredIndex = 0
    PopPage()
    AssertEqual(m.featuredIndex, 1, "detail Back restores feature page")
    AssertEqual(m.focusArea, "cta", "detail Back restores hero action focus")
    AssertEqual(m.shelves.jumpToRowItem[1], 2, "detail Back preserves independently focused shelf")
    m.featuredCards = [a]
    m.featuredIndex = 0
    PaintFeatured()
    AssertEqual(m.featuredNext.visible, false, "singleton hides carousel arrows")
    onKeyEvent("right", true)
    AssertEqual(m.focusArea, "info", "singleton keeps the Apple info button")
    onKeyEvent("right", true)
    AssertEqual(m.focusArea, "info", "singleton has no carousel controls past info")
    onKeyEvent("OK", true)
    AssertEqual(m.service.request.action, "details", "info opens the featured title's details")
    AssertEqual(m.service.request.autoplay, false, "opening details does not prefetch a stream")
    m.busy = false
    onKeyEvent("left", true)
    AssertEqual(m.focusArea, "cta", "left from info returns to the primary action")

    ' Home Play goes straight to playback without leaving Home.
    ResetNavigation()
    movie = {id: "m1", title: "Movie", kind: "Movie", progress: 0.4, logo: "", backdrop: "m.jpg", description: "", meta: ""}
    m.featuredCards = [movie]
    m.featuredIndex = 0
    m.playerControls = {}
    AssertEqual(HomeActionLabel(movie), "Continuar", "Home action resumes a started movie")
    AssertEqual(HomeActionLabel({kind: "Series"}), "Ver detalhes", "series hero opens details")
    ActivateCTA()
    AssertEqual(m.service.request.action, "details", "Play fetches playable details first")
    AssertEqual(m.autoplayItemId, "m1", "Play marks the title for direct playback")
    AssertEqual(m.service.request.autoplay, true, "Play asks the Task to bring the stream catalog along")
    AssertEqual(m.service.request.kind, "Movie", "details requests carry the card's type")
    m.service.result = {action: "details", requestId: m.service.request.requestId, ok: true, item: {Id: "m1", Name: "Movie", Type: "Movie", UserData: {PlaybackPositionTicks: 600000000}}, card: {id: "m1", kind: "Movie"}}
    OnResult()
    AssertEqual(m.service.request.action, "play", "details response starts playback directly")
    AssertEqual(m.service.request.ticks, 600000000#, "Home Play resumes from the saved position")
    AssertEqual(m.page, "home", "Home Play does not push a details page")
    AssertEqual(m.stack.Count(), 0, "Back from the player returns Home")
    AssertEqual(m.autoplayItemId, invalid, "autoplay is consumed once")

    ' Show page: next-up action, season rails, Back from an episode restores the show.
    ResetNavigation()
    m.playerControls = {}
    m.detailGenre = {}
    m.heroTitle.font = {}
    m.synopsis.font = {}
    show = {id: "show", title: "Show", kind: "Series", logo: "", backdrop: "show.jpg", description: "", meta: ""}
    episode = {Id: "ep2", Name: "Two", Type: "Episode", ParentIndexNumber: 1, IndexNumber: 2, UserData: {PlaybackPositionTicks: 0}}
    rails = NodeChildren([NodeChildren([{id: "ep1"}, {id: "ep2"}])])
    m.service.result = {action: "details", requestId: 0, ok: true, item: {Id: "show", Name: "Show", Type: "Series"}, card: show, content: rails, nextUp: episode, nextUpLocation: [0, 1]}
    OnResult()
    AssertEqual(m.ctaText.text, "Reproduzir T1, E2", "show page offers the next-up episode")
    AssertEqual(m.shelves.visible, true, "show page shows its season rails")
    AssertEqual(m.shelves.jumpToRowItem[1], 1, "rails land on the next-up episode")
    ActivateCTA()
    AssertEqual(m.service.request.itemId, "ep2", "show Play plays the next-up episode")
    AssertEqual(PlaybackItem().Id, "ep2", "player metadata comes from the episode, not the show")
    AssertEqual(m.detail.Id, "show", "the page item stays the show")
    m.busy = false
    Focus("rows")
    m.currentCard = {id: "ep1", title: "One", backdrop: "ep1.jpg", logo: "", description: "", meta: ""}
    m.service.result = {action: "details", requestId: 0, ok: true, item: {Id: "ep1", Name: "One", Type: "Episode"}, card: {id: "ep1", title: "One", kind: "Episode", backdrop: "ep1.jpg", logo: "", description: "", meta: ""}}
    OnResult()
    AssertEqual(m.shelves.visible, false, "episode details hides the show's rails")
    PopPage()
    AssertEqual(m.heroTitle.text, "Show", "Back restores the show's hero, not the focused episode")
    AssertEqual(m.backdrop.uri, "show.jpg", "Back restores the show's artwork")
    AssertEqual(m.shelves.visible, true, "Back restores the season rails")
    AssertEqual(m.focusArea, "rows", "Back returns to the episode rail")

    ' Shelf cards: episodes and started titles play on OK; others open details.
    AssertEqual(PlaysDirectly({kind: "Episode"}), true, "episode cards play directly")
    AssertEqual(PlaysDirectly({kind: "Movie", progress: 0.3}), true, "started movies resume directly")
    AssertEqual(PlaysDirectly({kind: "Movie", progress: 0}), false, "new movies open details")
    AssertEqual(PlaysDirectly({kind: "Series"}), false, "shows open their page")
    ResetNavigation()
    m.playerControls = {}
    m.shelves.content = NodeChildren([NodeChildren([{id: "ep9", kind: "Episode", title: "Nine"}])])
    Focus("rows")
    m.shelves.rowItemSelected = [0, 0]
    OnCardSelected()
    AssertEqual(m.autoplayItemId, "ep9", "OK on an episode card requests direct playback")
    m.service.result = {action: "details", requestId: m.service.request.requestId, ok: true, item: {Id: "ep9", Name: "Nine", Type: "Episode"}, card: {id: "ep9", kind: "Episode"}}
    OnResult()
    AssertEqual(m.service.request.action, "play", "episode card starts playback in one press")
    AssertEqual(m.stack.Count(), 0, "no details page is pushed for direct playback")
    ' Back from that playback: Home is shown at once and refreshes quietly.
    savedFeatured = m.featuredCards
    savedFeaturedIndex = m.featuredIndex
    m.playSession = {ItemId: "ep9", PlaySessionId: "s"}
    m.reportTimer = {}
    m.lastPosition = 300000000#
    m.reportsPending = 0
    m.video.state = "stopped"
    m.started = true
    m.playItem = {Id: "ep9", Name: "Nine", Type: "Episode", RunTimeTicks: 600000000#, UserData: {}}
    m.busy = false
    StopPlayback()
    AssertEqual(m.service.request.action, "home", "Home refreshes after playback")
    AssertEqual(m.service.request.quiet, true, "the refresh is quiet")
    AssertEqual(m.busy, false, "returning Home never blocks the remote")
    AssertEqual(m.focusArea, "rows", "focus returns to the shelf straight away")
    AssertEqual(m.shelves.content.GetChild(0).GetChild(0).progress, 0.5, "the watched title's progress updates before the refresh lands")
    fresh = NodeChildren([NodeChildren([{id: "new", kind: "Movie", title: "New"}, {id: "ep9", kind: "Episode", title: "Nine"}])])
    m.service.result = {action: "home", requestId: m.quietHomeRequestId, ok: true, content: fresh, title: "Para você"}
    OnResult()
    AssertEqual(m.shelves.content.GetChild(0).GetChild(0).id, "new", "fresh rows replace the old ones in place")
    AssertEqual(m.shelves.jumpToRowItem[1], 1, "focus follows the same title to its new position")
    AssertEqual(m.page, "home", "the quiet refresh never changes page")
    AssertEqual(m.busy, false, "the quiet refresh never holds the UI")
    m.shelves.content = NodeChildren([NodeChildren([{id: "ep9"}])])
    ShowCardProgress({Id: "ep9", RunTimeTicks: 100}, true)
    AssertEqual(m.shelves.content.GetChild(0).GetChild(0).progress, 0, "a finished title shows no progress bar")
    rows = NodeChildren([NodeChildren([{id: "a"}]), NodeChildren([{id: "b"}, {id: "c"}])])
    AssertEqual(CardLocation(rows, "c", [0, 0])[0], 1, "a title is found in another row")
    AssertEqual(CardLocation(rows, "gone", [1, 5])[1], 1, "a vanished title falls back to the clamped old spot")
    AssertEqual(CardLocation(rows, "gone", invalid), invalid, "nothing to restore without a previous spot")
    m.featuredCards = savedFeatured
    m.featuredIndex = savedFeaturedIndex
    ChangeFeatured(-1)
    AssertEqual(m.featuredIndex, 0, "singleton feature remains stable")
    m.featuredCards = []
    ChangeFeatured(1)
    AssertEqual(HasFeatured(), false, "empty library navigation is safe")
    ResetNavigation()
    m.detailGenre = {}
    m.cta = {}
    m.ctaBg = {}
    m.heroTitle.font = {}
    m.synopsis.font = {}
    m.page = "details"
    m.detail = {Type: "Series", Genres: ["Sci-Fi", "Adventure"]}
    ConfigureHeroGeometry()
    AssertEqual(m.detailGenre.text, "Série · Sci-Fi · Adventure", "detail genre line uses real metadata")
    AssertEqual(m.eyebrow.visible, false, "detail removes upper eyebrow for full artwork")
    AssertEqual(m.heroLogo.translation[1] > 500, true, "detail identity sits in reference lower-left area")
    AssertEqual(m.heroTitle.translation[1] + m.heroTitle.height < 652, true, "two-line fallback title clears genre line")
    AssertEqual(m.synopsis.translation[1] + m.synopsis.height < m.meta.translation[1], true, "long synopsis clears metadata")
    AssertEqual(m.meta.translation[1] + 35 < m.cta.translation[1], true, "metadata clears primary action")
    AssertEqual(m.secondary.translation[0] > m.cta.translation[0] + m.ctaBg.width, true, "resume and restart actions do not overlap")
    AssertEqual(m.backButton.visible, true, "detail shows the Voltar action")
    m.page = "home"
    ConfigureHeroGeometry()
    AssertEqual(m.heroTitle.translation[1], 380, "returning Home restores the Apple hero position")
    AssertEqual(m.cta.translation[1] + 64 < 846, true, "Home actions clear the page indicator and peeking shelf")
    AssertEqual(m.detailGenre.visible, false, "detail metadata does not leak onto Home")
    AssertEqual(m.backButton.visible, false, "Voltar does not leak onto Home")
    AssertEqual(m.heroTitle.font.size, 72, "Home title typography restores after detail")
    AssertEqual(DetailGenre({Type: "Movie"}), "Filme", "missing genres remain readable")
    print "PASS: "; m.assertions; " navigation assertions"
end sub

sub ResetRail()
    ResetNavigation()
    m.libraryRail = FocusNode("rail", m.focusState)
    m.libraryRail.visible = true
    m.choiceMenu = FocusNode("choice", m.focusState)
    m.railRows = []
    for index = 0 to 5
        m.railRows.Push({bg: {}, label: {}, caption: invalid})
    end for
    m.railCheck = {}
    m.railEmpty = {}
    m.railIndex = 0
    m.page = "browse"
    m.browseRequest = {kind: "Movie", offset: 0}
    m.detailGenre = {}
    m.heroShade = {}
    m.heroTitle = {font: {}}
    m.meta = {font: {}}
    m.synopsis = {font: {}}
end sub

sub TestLibraryRail()
    ResetRail()
    Focus("rows")
    onKeyEvent("left", true)
    AssertEqual(m.focusArea, "rail", "Left from the library grid enters its column")
    for index = 1 to 3
        onKeyEvent("down", true)
    end for
    onKeyEvent("OK", true)
    AssertEqual(m.focusArea, "choice", "Ordenar por opens its menu")
    AssertEqual(m.choiceMenu.options.Count(), 3, "three orders are offered")
    AssertEqual(m.choiceMenu.checkedIndex, 0, "the current order is checked")
    m.choiceMenu.chosen = 1
    OnChoiceChosen()
    AssertEqual(m.service.request.sort, "name", "choosing A–Z reloads the grid by name")
    AssertEqual(m.focusArea, "rail", "the menu returns focus to the column")
    m.busy = false
    onKeyEvent("down", true)
    onKeyEvent("OK", true)
    AssertEqual(m.service.request.action, "genres", "Gênero asks the server for this category's genres")
    m.service.result = {action: "genres", ok: true, requestId: m.requestId, genres: [{id: "g1", name: "Ação"}, {id: "g2", name: "Drama"}]}
    OnResult()
    AssertEqual(m.choiceMenu.options[0], "Todos", "every genre comes first")
    AssertEqual(m.choiceMenu.options[2], "Drama", "genres follow by name")
    m.choiceMenu.chosen = 2
    OnChoiceChosen()
    AssertEqual(m.service.request.genreId, "g2", "a genre filters the grid")
    AssertEqual(m.service.request.sort, "name", "the order is kept")
    m.busy = false
    onKeyEvent("down", true)
    onKeyEvent("OK", true)
    AssertEqual(m.service.request.unwatched, true, "Não assistidos toggles on")
    m.busy = false
    m.railIndex = 1
    onKeyEvent("OK", true)
    AssertEqual(m.service.request.kind, "Series", "a category switches the grid")
    AssertEqual(m.service.request.genreId, invalid, "a movie genre does not follow into shows")
    AssertEqual(m.service.request.sort, "name", "the order follows into the new category")
    AssertEqual(m.service.request.unwatched, true, "unwatched follows into the new category")
    m.busy = false
    m.choiceReturnArea = "rail"
    m.choicePurpose = "sort"
    Focus("choice")
    OnChoiceDismissed()
    AssertEqual(m.focusArea, "rail", "Back closes the menu without changing anything")
    m.service.result = {action: "browse", ok: true, requestId: m.requestId, content: NodeChildren([]), title: "Séries"}
    m.busy = true
    OnResult()
    AssertEqual(m.focusArea, "rail", "an empty filter keeps focus in the column to change it")
end sub

sub TestProfileSettings()
    ResetNavigation()
    m.canSwitchProfiles = true
    ShowSettings()
    AssertEqual(m.settingsActions[0], "profiles", "the administrator sees Trocar perfil first")
    m.top.dialog = {buttonSelected: 0}
    m.dialogMode = "settings"
    OnDialogButton()
    AssertEqual(m.service.request.action, "profiles", "Trocar perfil lists the server's profiles")
    m.canSwitchProfiles = false
    ShowSettings()
    AssertEqual(m.settingsActions[0], "reconnect", "other profiles do not see the switch")
    m.busy = false
    Send("switchProfile", {userId: "guest", name: "Guest", hasPassword: true, password: "secret"})
    AssertEqual(m.lastRequest.password, invalid, "a profile password is never kept for retries")
end sub

sub ResetNavigation()
    m.focusState = {owner: "cta"}
    m.top = FocusNode("scene", m.focusState)
    m.top.dialog = invalid
    m.shelves = FocusNode("rows", m.focusState)
    m.shelves.visible = true
    m.shelves.rowItemFocused = [0, 0]
    m.sidebar = FocusNode("nav", m.focusState)
    m.cta = FocusNode("cta", m.focusState)
    m.featuredPrevious = FocusNode("featuredPrevious", m.focusState)
    m.featuredNext = FocusNode("featuredNext", m.focusState)
    m.backButton = FocusNode("back", m.focusState)
    m.backButton.visible = false
    m.info = FocusNode("info", m.focusState)
    m.info.visible = false
    m.ctaIcon = {}
    m.ctaBg = {width: 290}
    m.featuredDotsBg = {}
    m.featuredDots = {}
    m.featuredDotNodes = [{}, {}]
    m.logoBox = {x: 80, bottom: 540, width: 700, height: 190}
    m.video = {visible: false}
    m.navNames = ["Buscar", "Início", "Filmes", "Séries", "Ajustes"]
    m.navIds = ["search", "home", "movies", "series", "settings"]
    m.navIndex = 1
    m.activeNavIndex = 1
    m.focusArea = "cta"
    m.contentFocusArea = "cta"
    m.secondary = FocusNode("secondary", m.focusState)
    m.secondary.visible = false
    m.stack = []
    m.busy = false
    m.loggedIn = true
    m.connected = true
    m.currentCard = {id: "item"}
    m.page = "home"
    m.eyebrow = {}
    m.hint = {}
    m.ctaText = {}
    m.account = {}
    m.featuredCards = []
    m.featuredIndex = 0
    m.heroLogo = {}
    m.heroTitle = {}
    m.synopsis = {}
    m.meta = {}
    m.backdrop = {}
    m.welcome = {}
    m.service = {}
    m.message = invalid
    m.spinner = {}
    m.status = FocusNode("pending", m.focusState)
    m.cancelledThroughRequestId = invalid
    m.pendingNavigationRequestId = invalid
    m.requestId = 0
    m.serverName = "Home PC"
    m.libraryRail = invalid
end sub

sub NoopFocus(focused as Boolean)
end sub

sub PaintFocus()
end sub

sub ShowMessage(title as String, message as String, buttons as Object, mode as String)
    m.message = message
    m.dialogMode = mode
end sub

sub AssertEqual(actual as Dynamic, expected as Dynamic, description as String)
    if actual <> expected
        print "FAIL: "; description; " expected="; expected; " actual="; actual
        stop
    end if
    m.assertions++
end sub

function NodeChildren(children as Object) as Object
    return {children: children, GetChildren: GetMockChildren, GetChild: GetMockChild, GetChildCount: GetMockChildCount}
end function

function GetMockChildCount() as Integer
    return m.children.Count()
end function

function GetMockChildren(count as Integer, start as Integer) as Object
    return m.children
end function

function GetMockChild(index as Integer) as Dynamic
    return m.children[index]
end function

' A focused child gets the key first. Native RowList handles directional input
' before the Scene sees it; focusing an ancestor is modeled as exclusive per SDK.
function FocusNode(name as String, state as Object) as Object
    return {name: name, focusState: state, SetFocus: SetMockFocus}
end function

sub SetMockFocus(focused as Boolean)
    ' Device-specific replay: physical G510X OS16.0.4 retained RowList focus
    ' after Scene.SetFocus(true), proven by sgnodes + next Down changing a card.
    ' Other cases retain the documented exclusive SetFocus semantics.
    if focused and m.name = "scene" and m.focusState.retainChildOnSceneFocus = true
        if m.focusState.owner = "rows" then return
    end if
    if focused
        m.focusState.owner = m.name
    else if m.focusState.owner = m.name
        m.focusState.owner = ""
    end if
end sub

function DispatchRemote(key as String) as Boolean
    if m.focusState.owner = "rows"
        location = m.shelves.rowItemFocused
        if key = "down"
            m.shelves.rowItemFocused = [location[0] + 1, location[1]]
            OnCardFocus()
            return true
        else if key = "right"
            m.shelves.rowItemFocused = [location[0], location[1] + 1]
            OnCardFocus()
            return true
        else if key = "up" and location[0] > 0
            m.shelves.rowItemFocused = [location[0] - 1, location[1]]
            OnCardFocus()
            return true
        else if key = "left" and location[1] > 0
            m.shelves.rowItemFocused = [location[0], location[1] - 1]
            OnCardFocus()
            return true
        else if key = "OK"
            m.shelves.rowItemSelected = location
            OnCardSelected()
            return true
        end if
    end if
    return onKeyEvent(key, true)
end function

sub TestExclusiveInput()
    ResetNavigation()
    first = {id: "continue", title: "Continue watching"}
    second = {id: "other", title: "Other shelf"}
    m.shelves.content = NodeChildren([NodeChildren([first]), NodeChildren([second])])
    Focus("rows")
    DispatchRemote("OK")
    AssertEqual(m.service.request.itemId, "continue", "Continue Watching selects the actual shelf item")
    AssertEqual(m.busy, true, "details request is pending")
    requestId = m.service.request.requestId
    DispatchRemote("down")
    AssertEqual(m.shelves.rowItemFocused[0], 0, "pending details blocks child RowList movement")
    AssertEqual(m.currentCard.id, "continue", "pending details retains chosen card")
    DispatchRemote("back")
    AssertEqual(m.busy, false, "Back cancels pending details without waiting for server")
    AssertEqual(m.focusArea, "rows", "cancel returns to the originating shelf")
    AssertEqual(m.focusState.owner, "rows", "cancel restores native shelf input")
    m.service.result = {action: "details", requestId: requestId, ok: false, message: "late response"}
    OnResult()
    AssertEqual(m.message, invalid, "cancelled result cannot open a stale error dialog")
    AssertEqual(m.page, "home", "cancelled result cannot navigate")

    Focus("nav")
    savedRow = m.shelves.rowItemFocused[0]
    DispatchRemote("down")
    AssertEqual(m.navIndex, NavIndex("movies"), "sidebar handles its own down key")
    AssertEqual(m.shelves.rowItemFocused[0], savedRow, "sidebar down does not move shelves")
    AssertEqual(m.focusState.owner, "nav", "sidebar uses an independent focus target")
    m.shelves.rowItemSelected = [1, 0]
    OnCardSelected()
    AssertEqual(m.service.request.requestId, requestId, "late shelf selection cannot open details from sidebar")
    m.shelves.rowItemFocused = [1, 0]
    OnCardFocus()
    AssertEqual(m.currentCard.id, "continue", "late shelf focus cannot replace sidebar return selection")
    DispatchRemote("right")
    AssertEqual(m.focusState.owner, "rows", "right restores shelf key handling")

    m.shelves.rowItemSelected = []
    OnCardSelected()
    AssertEqual(m.busy, false, "empty selection during content replacement is ignored")
    m.shelves.rowItemSelected = [9, 0]
    OnCardSelected()
    AssertEqual(m.busy, false, "stale row index is ignored")

    m.shelves.rowItemSelected = [1, 0]
    OnCardSelected()
    nextId = m.service.request.requestId
    AssertEqual(nextId > requestId, true, "a new selection starts after cancellation")
    m.service.result = {action: "details", requestId: requestId, ok: true}
    OnResult()
    AssertEqual(m.busy, true, "late cancelled success cannot clear a newer request")
    AssertEqual(m.focusState.owner, "pending", "late response cannot restore shelf input during new request")
    AssertEqual(m.page, "home", "late cancelled success cannot open old details")
    DispatchRemote("back")
    AssertEqual(m.busy, false, "second pending selection is also cancellable")
    AssertEqual(m.spinner.visible, false, "cancellation clears spinner")
    AssertEqual(m.spinner.control, "stop", "cancellation stops the loading indicator")
    m.shelves.visible = false
    OnCardSelected()
    AssertEqual(m.service.request.requestId, nextId, "hidden shelves cannot send selection requests")

    ResetNavigation()
    card = {id: "resume-item", title: "Continue Watching", kind: "Movie", description: "Movie", meta: "HD", backdrop: "", logo: ""}
    m.shelves.content = NodeChildren([NodeChildren([card])])
    Focus("rows")
    DispatchRemote("OK")
    m.service.result = {action: "details", requestId: m.service.request.requestId, ok: true, card: card, item: {UserData: {PlaybackPositionTicks: 900000000}}}
    OnResult()
    AssertEqual(m.page, "details", "successful Continue Watching selection opens details")
    AssertEqual(m.busy, false, "successful details release pending input")
    AssertEqual(m.focusState.owner, "cta", "details focus the Resume action sibling")
    AssertEqual(m.ctaText.text, "Continuar", "Continue Watching retains resume behavior")
    AssertEqual(m.secondary.visible, true, "Continue Watching retains play-from-start action")
    DispatchRemote("back")
    AssertEqual(m.page, "home", "Back from Continue Watching details restores Home")
    AssertEqual(m.focusState.owner, "rows", "Back from details restores actual shelf focus")

    ResetNavigation()
    Focus("cta")
    Send("login", {})
    AssertEqual(DispatchRemote("back"), false, "Back permits platform exit during account mutation")
    AssertEqual(m.busy, true, "account mutation is not falsely cancelled")
    AssertEqual(m.cancelledThroughRequestId, invalid, "account response remains authoritative")
end sub

' The visible Voltar action is the on-screen equivalent of the remote Back key.
sub TestDetailsBackButton()
    ResetNavigation()
    movie = {id: "movie", title: "Movie", kind: "Movie", description: "", meta: "", backdrop: "", logo: ""}
    other = {id: "other", title: "Other", kind: "Movie", description: "", meta: "", backdrop: "", logo: ""}
    m.shelves.content = NodeChildren([NodeChildren([other, movie])])
    m.shelves.rowItemFocused = [0, 1]
    Focus("rows")
    DispatchRemote("OK")
    m.service.result = {action: "details", requestId: m.service.request.requestId, ok: true, card: movie, item: {Type: "Movie", Id: "movie", Name: "Movie", UserData: {PlaybackPositionTicks: 900000000}}}
    OnResult()
    AssertEqual(m.focusState.owner, "cta", "movie details focus the primary action")
    AssertEqual(DispatchRemote("up"), true, "Up from detail action is handled")
    AssertEqual(m.focusArea, "back", "Up from detail action reaches Voltar")
    AssertEqual(m.focusState.owner, "back", "Voltar owns remote input")
    AssertEqual(DispatchRemote("up"), true, "Up at Voltar is consumed")
    AssertEqual(m.focusArea, "back", "Up at Voltar does not open the sidebar")
    DispatchRemote("down")
    AssertEqual(m.focusArea, "cta", "Down from Voltar returns to the primary action")
    DispatchRemote("right")
    AssertEqual(m.focusArea, "secondary", "resume details still reach play-from-start")
    DispatchRemote("up")
    AssertEqual(m.focusArea, "back", "Up from play-from-start reaches Voltar")
    DispatchRemote("left")
    AssertEqual(m.focusArea, "nav", "Left from Voltar opens the sidebar deliberately")
    DispatchRemote("right")
    AssertEqual(m.focusArea, "back", "sidebar Right returns to Voltar")
    requestId = m.service.request.requestId
    DispatchRemote("OK")
    AssertEqual(m.page, "home", "OK on Voltar returns to the previous page")
    AssertEqual(m.service.request.requestId, requestId, "Voltar restores locally without a request")
    AssertEqual(m.focusState.owner, "rows", "Voltar restores shelf focus")
    AssertEqual(m.shelves.jumpToRowItem[1], 1, "Voltar restores the opened card")
    AssertEqual(m.stack.Count(), 0, "Voltar pops exactly one page")
    Focus("cta")
    DispatchRemote("up")
    AssertEqual(m.focusArea, "nav", "Home keeps Up from its action opening the sidebar")

    ResetNavigation()
    series = {id: "series", title: "Series", kind: "Series", description: "", meta: "", backdrop: "", logo: ""}
    m.shelves.content = NodeChildren([NodeChildren([series])])
    m.page = "browse"
    Focus("rows")
    DispatchRemote("OK")
    m.service.result = {action: "details", requestId: m.service.request.requestId, ok: true, card: series, item: {Type: "Series", Id: "series", Name: "Series"}}
    OnResult()
    AssertEqual(m.ctaText.text, "Ver temporadas", "series details keep their primary action")
    DispatchRemote("up")
    AssertEqual(m.focusArea, "back", "series details reach Voltar")
    DispatchRemote("OK")
    AssertEqual(m.page, "browse", "Voltar from series returns to the catalog")
    AssertEqual(m.focusState.owner, "rows", "Voltar from series restores catalog focus")

    ResetNavigation()
    m.shelves.content = NodeChildren([NodeChildren([series])])
    Focus("rows")
    DispatchRemote("OK")
    m.service.result = {action: "details", requestId: m.service.request.requestId, ok: true, card: series, item: {Type: "Series", Id: "series", Name: "Series"}}
    OnResult()
    DispatchRemote("up")
    AssertEqual(DispatchRemote("back"), true, "remote Back is still handled on Voltar")
    AssertEqual(m.page, "home", "remote Back from Voltar returns to the previous page")
end sub

' Roku's Dialog.close is write-only and Back dismisses without it; only the
' wasClosed event says the dialog is gone.
sub TestDialogDismissedByBack()
    ResetNavigation()
    m.shelves.content = NodeChildren([NodeChildren([{id: "first"}]), NodeChildren([{id: "second"}])])
    Focus("rows")
    dialog = {id: "settings", IsSameNode: StubSameNode}
    m.top.dialog = dialog
    m.dialogOpen = true
    AssertEqual(onKeyEvent("up", true), false, "an open dialog keeps keys away from the Scene")
    OnDialogClosed({node: dialog, GetRoSGNode: StubEventNode})
    AssertEqual(DialogOpen(), false, "Back-dismissed dialog stops blocking the Scene")
    AssertEqual(m.focusState.owner, "rows", "closing the dialog returns input to the shelf")
    AssertEqual(onKeyEvent("up", true), true, "Up reaches the Scene after a dialog closed with Back")
    AssertEqual(m.focusArea, "cta", "Up from the shelf edge reaches the hero again")
    stale = {id: "old", IsSameNode: StubSameNode}
    m.dialogOpen = true
    OnDialogClosed({node: stale, GetRoSGNode: StubEventNode})
    AssertEqual(DialogOpen(), true, "a replaced dialog closing late does not unblock the new one")
    m.dialogOpen = false
end sub

function StubSameNode(other as Dynamic) as Boolean
    if not IsMap(other) then return false
    return other.id = m.id
end function

function StubEventNode() as Object
    return m.node
end function

sub TestCachedLaunch()
    ResetNavigation()
    m.contentSurface = {visible: false}
    m.prefetchTimer = {}
    rows = NodeChildren([NodeChildren([{id: "ep", kind: "Episode", title: "Ep", description: "", meta: "", backdrop: "b.jpg", logo: ""}])])
    m.service = {ready: true, cachedHome: {content: rows, userName: "Viewer", serverName: "PC"}}
    OnServiceReady()
    AssertEqual(m.contentSurface.visible, true, "the first frame is drawn once Luma knows where it opens")
    AssertEqual(m.page, "home", "a saved Home opens at once")
    AssertEqual(m.welcome.visible, false, "no welcome flash when a Home is cached")
    AssertEqual(m.service.request.action, "bootstrap", "the server is still verified")
    AssertEqual(m.service.request.quiet, true, "verification happens behind the cached Home")
    AssertEqual(m.busy, false, "the cached Home is usable at once")
    m.service.result = {action: "bootstrap", requestId: m.service.request.requestId, ok: true, connected: true, loggedIn: true, serverName: "PC", userName: "Viewer"}
    OnResult()
    AssertEqual(m.service.request.action, "home", "a verified server refreshes the cached Home")
    AssertEqual(m.service.request.quiet, true, "the refresh is in place, not a reload")
    AssertEqual(m.quietHomeRequestId, m.service.request.requestId, "the refresh is matched to its result")
    m.prefetchTimer = {}
    SchedulePrefetch({id: "ep", kind: "Episode"}, true)
    AssertEqual(m.prefetchTimer.control, "start", "a focused card starts the prefetch timer")
    OnPrefetchTimer()
    AssertEqual(m.service.request.action, "prefetch", "a held card is fetched ahead")
    AssertEqual(m.service.request.autoplay, true, "a card that plays at once prefetches its stream catalog too")
    AssertEqual(m.busy, false, "prefetching never blocks the remote")
    ResetNavigation()
    m.contentSurface = {visible: false}
    m.service = {ready: true}
    OnServiceReady()
    AssertEqual(m.welcome.visible, true, "without a cached Home the welcome shows")
    AssertEqual(m.service.request.quiet, invalid, "first-run discovery shows its progress")
end sub

sub TestHardwareSidebarFocus()
    ResetNavigation()
    m.focusState.retainChildOnSceneFocus = true
    m.shelves.content = NodeChildren([NodeChildren([{id: "first"}]), NodeChildren([{id: "second"}])])
    Focus("rows")
    DispatchRemote("left")
    AssertEqual(m.focusArea, "nav", "left edge opens sidebar")
    DispatchRemote("down")
    AssertEqual(m.shelves.rowItemFocused[0], 0, "G510X sidebar Down cannot move shelf behind it")
    AssertEqual(m.navIndex, NavIndex("movies"), "G510X sidebar Down reaches next menu item")
    AssertEqual(m.focusState.owner, "nav", "G510X focus is on sidebar sibling")
    DispatchRemote("right")
    AssertEqual(m.focusState.owner, "rows", "G510X closes sidebar and restores shelf input")
    DispatchRemote("down")
    AssertEqual(m.shelves.rowItemFocused[0], 1, "restored shelf handles Down normally")
end sub
