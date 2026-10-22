' Executes production LumaScene search integration; only paint and dialogs are stubbed.
sub Main()
    m.assertions = 0
    ResetScene()
    Focus("nav")
    m.navIndex = NavIndex("search")
    onKeyEvent("OK", true)
    AssertEqual(m.page, "search", "Buscar opens the in-app search page")
    AssertEqual(m.top.dialog, invalid, "no system keyboard dialog is opened")
    AssertEqual(m.searchScreen.visible, true, "search page is visible")
    AssertEqual(m.contentSurface.visible, false, "hero and shelves are hidden on search")
    AssertEqual(m.backdrop.visible, false, "backdrop is hidden on search")
    AssertEqual(m.focusState.owner, "search", "search page receives focus immediately")
    AssertEqual(m.searchScreen.enter, true, "entrance motion is requested")
    AssertEqual(m.activeNavIndex, NavIndex("search"), "menu marks Buscar active")

    ' Requests never take the busy state, so typing is never parked.
    RequestSearch("dun")
    first = m.service.request.requestId
    AssertEqual(m.service.request.action, "search", "page request goes to the Task")
    AssertEqual(m.service.request.query, "dun", "Task receives the query")
    AssertEqual(m.busy, false, "search does not block input")
    AssertEqual(m.focusState.owner, "search", "search request keeps focus on the page")
    AssertEqual(m.spinner.visible, false, "search request shows no blocking spinner")
    RequestSearch("dune")
    m.service.result = {action: "search", requestId: first, ok: true, content: "old"}
    OnResult()
    AssertEqual(m.searchScreen.response, invalid, "superseded request id is rejected")
    m.service.result = {action: "search", requestId: m.searchRequestId, ok: true, content: "rows", total: 2}
    OnResult()
    AssertEqual(m.searchScreen.response.query, "dune", "current response carries its query")
    AssertEqual(m.searchScreen.response.content, "rows", "current response carries content")

    ' Opening a result uses the normal details flow and Back restores search.
    card = {id: "dune-1", title: "Dune", kind: "Movie", description: "", meta: "", backdrop: "", logo: ""}
    m.searchScreen.selected = card
    OnSearchSelected()
    AssertEqual(m.service.request.action, "details", "result opens details")
    AssertEqual(m.busy, true, "details is a pending navigation")
    detailsId = m.service.request.requestId
    RequestSearch("dunes")
    m.service.result = {action: "search", requestId: m.searchRequestId, ok: true, content: "late"}
    OnResult()
    AssertEqual(m.busy, true, "a search response cannot release pending details")
    AssertEqual(m.focusState.owner, "pending", "a search response cannot steal focus from pending details")
    m.service.result = {action: "details", requestId: detailsId, ok: true, card: card, item: {Type: "Movie", Id: "dune-1", Name: "Dune"}}
    OnResult()
    AssertEqual(m.page, "details", "details opens from search")
    AssertEqual(m.searchScreen.visible, false, "details hides search page")
    AssertEqual(m.contentSurface.visible, true, "details restores hero surface")
    AssertEqual(m.stack[m.stack.Count() - 1].page, "search", "search is on the Back stack")
    onKeyEvent("back", true)
    AssertEqual(m.page, "search", "Back from details returns to search")
    AssertEqual(m.searchScreen.visible, true, "Back shows the same search page")
    AssertEqual(m.contentSurface.visible, false, "Back hides hero again")
    AssertEqual(m.focusArea, "search", "Back restores search focus")
    AssertEqual(m.focusState.owner, "search", "search page owns input after Back")
    AssertEqual(m.stack.Count(), 0, "Back stack is empty on search")

    ' The visible Voltar action returns to the same search page and query.
    OnSearchSelected()
    m.service.result = {action: "details", requestId: m.service.request.requestId, ok: true, card: card, item: {Type: "Movie", Id: "dune-1", Name: "Dune"}}
    OnResult()
    onKeyEvent("up", true)
    AssertEqual(m.focusState.owner, "back", "Up from search details reaches Voltar")
    onKeyEvent("OK", true)
    AssertEqual(m.page, "search", "Voltar returns to search")
    AssertEqual(m.searchScreen.visible, true, "Voltar shows the same search page")
    AssertEqual(m.focusState.owner, "search", "Voltar restores search input")
    AssertEqual(m.searchQuery, "dunes", "Voltar keeps the search query")
    AssertEqual(m.stack.Count(), 0, "Voltar leaves no stale page")

    ' Cancelling a pending result open keeps the page.
    OnSearchSelected()
    AssertEqual(m.busy, true, "second open is pending")
    onKeyEvent("back", true)
    AssertEqual(m.busy, false, "Back cancels pending details")
    AssertEqual(m.focusState.owner, "search", "cancel returns to search")
    AssertEqual(m.page, "search", "cancel stays on search")

    ' Keys the page does not consume: keyboard Back/Left open the menu.
    AssertEqual(onKeyEvent("back", true), true, "keyboard Back is handled")
    AssertEqual(m.focusArea, "nav", "keyboard Back opens the menu")
    onKeyEvent("right", true)
    AssertEqual(m.focusState.owner, "search", "menu Right returns to search")
    AssertEqual(onKeyEvent("left", true), true, "keyboard first-column Left is handled")
    AssertEqual(m.focusArea, "nav", "Left opens the menu")
    onKeyEvent("OK", true)
    AssertEqual(m.focusState.owner, "search", "choosing Buscar again keeps the same page")
    AssertEqual(m.page, "search", "reopening search does not reset it")

    ' Leaving through the menu keeps search visible until Home is ready.
    Focus("nav")
    m.navIndex = NavIndex("home")
    onKeyEvent("OK", true)
    AssertEqual(m.searchScreen.visible, true, "search stays until the next page renders")
    m.service.result = {action: "home", requestId: m.service.request.requestId, ok: true, title: "Para você", content: NodeChildren([NodeChildren([card])])}
    OnResult()
    AssertEqual(m.page, "home", "Home renders")
    AssertEqual(m.searchScreen.visible, false, "Home hides search")
    AssertEqual(m.contentSurface.visible, true, "Home restores hero and shelves")
    AssertEqual(m.backdrop.visible, true, "Home restores artwork")

    ' Empty library action opens search too.
    m.currentCard = invalid
    m.featuredCards = []
    Focus("cta")
    onKeyEvent("OK", true)
    AssertEqual(m.page, "search", "empty-library action opens search")
    AssertEqual(m.focusState.owner, "search", "empty-library search focuses the page")

    ' Expired session while searching.
    RequestSearch("x")
    m.service.result = {action: "search", requestId: m.searchRequestId, ok: false, code: 401, message: "expired"}
    OnResult()
    AssertEqual(m.loggedIn, false, "401 during search revokes sign-in")
    AssertEqual(m.page, "welcome", "401 during search shows sign-in")
    AssertEqual(m.searchScreen.visible, false, "sign-in hides search")
    AssertEqual(m.dialogMode, "expired", "sign-in prompt is shown")
    print "PASS: "; m.assertions; " search scene assertions"
end sub

sub RequestSearch(query as String)
    m.searchScreen.request = {query: query}
    OnSearchRequest()
end sub

sub ResetScene()
    m.focusState = {owner: "cta"}
    m.top = FocusNode("scene", m.focusState)
    m.top.dialog = invalid
    m.shelves = FocusNode("rows", m.focusState)
    m.shelves.visible = true
    m.shelves.rowItemFocused = [0, 0]
    m.sidebar = FocusNode("nav", m.focusState)
    m.cta = FocusNode("cta", m.focusState)
    m.secondary = FocusNode("secondary", m.focusState)
    m.secondary.visible = false
    m.featuredPrevious = FocusNode("featuredPrevious", m.focusState)
    m.featuredNext = FocusNode("featuredNext", m.focusState)
    m.backButton = FocusNode("back", m.focusState)
    m.searchScreen = FocusNode("search", m.focusState)
    m.searchScreen.visible = false
    m.searchScreen.response = invalid
    m.status = FocusNode("pending", m.focusState)
    m.video = {visible: false}
    m.navNames = ["Buscar", "Início", "Filmes", "Séries", "Ajustes"]
    m.navIds = ["search", "home", "movies", "series", "settings"]
    m.navIndex = 1
    m.activeNavIndex = 1
    m.info = FocusNode("info", m.focusState)
    m.info.visible = false
    m.ctaIcon = {}
    m.ctaBg = {width: 290}
    m.featuredDotsBg = {}
    m.logoBox = {x: 80, bottom: 540, width: 700, height: 190}
    m.focusArea = "cta"
    m.contentFocusArea = "cta"
    m.stack = []
    m.busy = false
    m.loggedIn = true
    m.connected = true
    m.currentCard = {id: "item"}
    m.page = "home"
    m.featuredCards = []
    m.featuredIndex = 0
    for each id in ["eyebrow", "hint", "ctaText", "account", "heroLogo", "heroTitle", "synopsis", "meta", "backdrop", "heroShade", "welcome", "contentSurface", "service", "spinner"]
        m[id] = {visible: true}
    end for
    m.spinner.visible = false
    m.requestId = 0
    m.serverName = "Home PC"
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
    return {children: children, GetChildren: GetMockChildren, GetChild: GetMockChild, GetChildCount: GetMockCount}
end function

function GetMockChildren(count as Integer, start as Integer) as Object
    return m.children
end function

function GetMockChild(index as Integer) as Dynamic
    return m.children[index]
end function

function GetMockCount() as Integer
    return m.children.Count()
end function

function FocusNode(name as String, state as Object) as Object
    return {name: name, focusState: state, SetFocus: SetMockFocus}
end function

sub SetMockFocus(focused as Boolean)
    if focused then m.focusState.owner = m.name
end sub
