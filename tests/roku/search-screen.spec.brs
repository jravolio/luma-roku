' Executes the production search page logic with SceneGraph nodes as plain mocks.
sub Main()
    m.assertions = 0
    ResetScreen()
    AssertEqual(m.queryLabel.text, "Títulos, séries, episódios", "empty query shows placeholder")
    AssertEqual(m.message.visible, true, "idle explains how to search")

    ' Typing is immediate and debounced; nothing goes to the network per key.
    TypeKey("d")
    TypeKey("u")
    TypeKey("n")
    AssertEqual(m.queryLabel.text, "dun", "query is visible as typed")
    AssertEqual(m.requests.Count(), 0, "keys do not send requests before debounce")
    AssertEqual(m.debounce.control, "start", "each key restarts debounce")
    AssertEqual(m.resultStatus.text, "Buscando…", "loading feedback is immediate")
    FireDebounce()
    AssertEqual(m.requests.Count(), 1, "debounce sends one request")
    AssertEqual(m.requests[0].query, "dun", "request carries trimmed term")

    ' Typing continues while the request is outstanding; at most one in flight.
    TypeKey("e")
    FireDebounce()
    AssertEqual(m.requests.Count(), 1, "second term waits for outstanding request")
    Respond({query: "dun", ok: true, content: Rows([Card("old")]), total: 1})
    AssertEqual(m.results.visible, false, "stale response is not rendered")
    AssertEqual(m.requests.Count(), 2, "stale response immediately requests current term")
    AssertEqual(m.requests[1].query, "dune", "chained request uses latest query")
    Respond({query: "dune", ok: true, content: Rows([Card("a"), Card("b")]), total: 2})
    AssertEqual(m.results.visible, true, "current response renders")
    AssertEqual(m.results.content.GetChildCount(), 2, "grid uses the result row")
    AssertEqual(m.resultStatus.text, "2 títulos", "count is shown in pt-BR")
    AssertEqual(m.heading.text, "Resultados para “dune”", "heading names the query")

    ' Stale response while the debounce for a newer term is still pending.
    TypeKey("x")
    FireDebounce()
    TypeKey("s")
    Respond({query: "dunex", ok: true, content: Rows([Card("z")]), total: 1})
    AssertEqual(m.results.content.GetChild(0).id, "a", "stale result never replaces visible results")
    AssertEqual(m.requests.Count(), 3, "pending debounce owns the next request")
    FireDebounce()
    AssertEqual(m.requests[3].query, "dunexs", "debounce sends current term")
    Respond({query: "dunexs", ok: true, content: Rows([]), total: 0})
    AssertEqual(m.messageTitle.text, "Nada encontrado para “dunexs”", "empty state in pt-BR")
    AssertEqual(m.results.visible, false, "empty state hides grid")

    ' Editing keys.
    TypeKey("backspace")
    TypeKey("backspace")
    TypeKey("backspace")
    AssertEqual(m.query, "dun", "Apagar removes one character")
    TypeKey("space")
    TypeKey("space")
    AssertEqual(m.query, "dun ", "Espaço does not double spaces")
    AssertEqual(m.term, "dun", "trailing space does not change the term")
    FireDebounce()
    Respond({query: "dun", ok: false, message: "O servidor não respondeu."})
    AssertEqual(m.messageTitle.text, "Não foi possível buscar agora", "error state in pt-BR")
    AssertEqual(m.messageBody.text, "O servidor não respondeu.", "error explains the cause")
    TypeKey("clear")
    AssertEqual(m.query, "", "Limpar clears the query")
    AssertEqual(m.heading.text, "Buscar", "clear returns to idle")
    count = m.requests.Count()
    Respond({query: "dun", ok: true, content: Rows([Card("late")]), total: 1})
    AssertEqual(m.results.visible, false, "late response after clear is ignored")
    AssertEqual(m.requests.Count(), count, "cleared query sends nothing")
    TypeKey("space")
    AssertEqual(m.query, "", "leading space is ignored")

    ' Focus: keyboard edge to results and back.
    TypeKey("a")
    FireDebounce()
    Respond({query: "a", ok: true, content: Rows([Card("1"), Card("2"), Card("3"), Card("4")]), total: 40})
    AssertEqual(m.resultStatus.text, "1–4 de 40 títulos · Avançar/retroceder: mudar página", "partial page is labeled")
    ' Every result stays reachable without retaining an unbounded grid.
    FocusArea("results")
    AssertEqual(onKeyEvent("fastforward", true), true, "next page key is handled")
    CaptureRequest()
    AssertEqual(m.requests[m.requests.Count() - 1].offset, 4, "next page starts after rendered results")
    Respond({query: "a", offset: 4, ok: true, content: Rows([Card("5"), Card("6")]), total: 40})
    AssertEqual(m.results.content.GetChildCount(), 2, "page replaces rather than accumulates content")
    AssertEqual(m.results.content.GetChild(0).id, "5", "next page renders new titles")
    AssertEqual(onKeyEvent("rewind", true), true, "previous page key is handled")
    CaptureRequest()
    AssertEqual(m.requests[m.requests.Count() - 1].offset, 0, "previous page restores first offset")
    Respond({query: "a", offset: 0, ok: true, content: Rows([Card("1"), Card("2"), Card("3"), Card("4")]), total: 40})
    m.keyboard.edge = "right"
    OnKeyboardEdge()
    AssertEqual(m.focus.owner, "results", "keyboard right edge focuses results")
    AssertEqual(m.keyboard.active, false, "keyboard cursor dims while results focused")
    AssertEqual(m.top.area, "results", "area is published")
    m.results.itemSelected = 2
    OnResultSelected()
    AssertEqual(m.top.selected.id, "3", "OK selects the real result card")
    m.focus.owner = "status"
    m.top.focused = true
    OnSearchFocusChange()
    AssertEqual(m.focus.owner, "results", "regaining page focus restores results")
    AssertEqual(onKeyEvent("up", true), true, "grid top edge stays on page")
    AssertEqual(onKeyEvent("back", true), true, "Back from results is handled")
    AssertEqual(m.focus.owner, "keyboard", "Back from results returns to keyboard")
    AssertEqual(onKeyEvent("back", true), false, "Back from keyboard reaches the Scene")
    AssertEqual(onKeyEvent("left", true), false, "keyboard first-column Left reaches the Scene")
    FocusArea("results")
    AssertEqual(onKeyEvent("left", true), true, "results first column Left is handled")
    AssertEqual(m.focus.owner, "keyboard", "results Left returns to keyboard")
    FocusArea("results")
    TypeKey("clear")
    AssertEqual(m.focus.owner, "keyboard", "losing results returns focus to keyboard")
    m.keyboard.edge = "right"
    OnKeyboardEdge()
    AssertEqual(m.focus.owner, "keyboard", "right edge does nothing without results")
    for index = 1 to 30
        TypeKey("w")
    end for
    AssertEqual(m.queryLabel.text, "…" + String(21, "w"), "long query shows its end")
    print "PASS: "; m.assertions; " search screen assertions"
end sub

sub ResetScreen()
    m.focus = {owner: ""}
    m.requests = []
    m.top = {area: "keyboard", request: invalid, response: invalid, selected: invalid, focused: false, HasFocus: MockHasFocus}
    m.keyboard = {name: "keyboard", focus: m.focus, key: "", edge: "", active: true, SetFocus: MockSetFocus}
    m.results = {name: "results", focus: m.focus, visible: false, content: invalid, itemSelected: 0, SetFocus: MockSetFocus}
    for each id in ["queryLabel", "heading", "resultStatus", "message", "messageTitle", "messageBody", "debounce"]
        m[id] = {}
    end for
    ResetSearchState()
end sub

sub TypeKey(value as String)
    m.keyboard.key = value
    OnKeyboardKey()
    if m.top.request <> invalid
        m.requests.Push(m.top.request)
        m.top.request = invalid
    end if
end sub

sub FireDebounce()
    OnDebounce()
    CaptureRequest()
end sub

sub Respond(response as Object)
    m.top.response = response
    OnSearchResponse()
    CaptureRequest()
end sub

sub CaptureRequest()
    if m.top.request <> invalid
        m.requests.Push(m.top.request)
        m.top.request = invalid
    end if
end sub

function MockHasFocus() as Boolean
    return m.focused
end function

sub MockSetFocus(focused as Boolean)
    if focused then m.focus.owner = m.name
end sub

function Card(id as String) as Object
    return {id: id, title: id}
end function

function Rows(cards as Object) as Object
    if cards.Count() = 0 then return MockList([])
    return MockList([MockList(cards)])
end function

function MockList(children as Object) as Object
    return {children: children, GetChildCount: MockCount, GetChild: MockChild}
end function

function MockCount() as Integer
    return m.children.Count()
end function

function MockChild(index as Integer) as Dynamic
    return m.children[index]
end function

sub AssertEqual(actual as Dynamic, expected as Dynamic, description as String)
    if actual <> expected
        print "FAIL: "; description; " expected="; expected; " actual="; actual
        stop
    end if
    m.assertions++
end sub
