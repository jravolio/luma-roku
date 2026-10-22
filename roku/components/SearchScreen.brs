' Integrated search page: query, keyboard on the left, live results on the right.
' Typing never waits for the network. Requests are debounced, at most one is
' outstanding on the serial Task, and a response is shown only if it belongs
' to the query currently on screen.
sub init()
    for each id in ["surface", "queryBox", "queryLabel", "keyboard", "heading", "resultStatus", "results", "message", "messageTitle", "messageBody", "debounce", "enterMotion"]
        m[id] = m.top.FindNode(id)
    end for
    ApplyRounded(m.queryBox, 18)
    m.queryIcon = CreateAppIcon(m.surface, "search", 102, 114, 32)
    m.queryIcon.blendColor = "0x9a9a9aff"
    m.keyboard.ObserveField("key", "OnKeyboardKey")
    m.keyboard.ObserveField("edge", "OnKeyboardEdge")
    m.debounce.ObserveField("fire", "OnDebounce")
    m.results.ObserveField("itemSelected", "OnResultSelected")
    m.top.ObserveField("focusedChild", "OnSearchFocusChange")
    ResetSearchState()
end sub

sub ResetSearchState()
    m.query = ""
    m.term = ""
    m.area = "keyboard"
    m.inFlight = false
    m.offset = 0
    m.loadedOffset = 0
    m.loadedTerm = ""
    m.total = 0
    m.debouncePending = false
    PaintQuery()
    ShowIdle()
end sub

sub OnKeyboardKey()
    EditQuery(m.keyboard.key)
end sub

sub EditQuery(value as String)
    if value = "space"
        if m.query <> "" and Right(m.query, 1) <> " " then m.query += " "
    else if value = "backspace"
        if m.query <> "" then m.query = Left(m.query, Len(m.query) - 1)
    else if value = "clear"
        m.query = ""
    else if Len(m.query) < 60
        m.query += value
    end if
    PaintQuery()
    OnQueryChanged()
end sub

sub OnQueryChanged()
    term = m.query.Trim()
    if term = m.term then return
    m.term = term
    m.offset = 0
    m.debounce.control = "stop"
    if term = ""
        m.debouncePending = false
        ShowIdle()
        return
    end if
    m.debouncePending = true
    m.debounce.control = "start"
    ' Previous results stay visible until the new answer replaces them.
    m.heading.text = ResultsHeading()
    m.resultStatus.text = "Buscando…"
end sub

sub OnDebounce()
    m.debouncePending = false
    RequestLatest()
end sub

sub RequestLatest()
    if m.term = "" or m.inFlight then return
    m.inFlight = true
    m.top.request = {query: m.term, offset: m.offset}
end sub

sub OnSearchResponse()
    response = m.top.response
    if not IsMap(response) then return
    m.inFlight = false
    responseOffset = 0
    if response.offset <> invalid then responseOffset = response.offset
    if TextValue(response.query) <> m.term or responseOffset <> m.offset
        ' Stale: the user kept typing. Ask for the current query unless the
        ' debounce timer is about to.
        if not m.debouncePending then RequestLatest()
        return
    end if
    if not response.ok
        if m.loadedTerm = m.term and HasResults()
            m.offset = m.loadedOffset
            m.resultStatus.text = "Falha ao carregar. Tente avançar novamente."
            return
        end if
        ShowSearchMessage("Não foi possível buscar agora", TextValue(response.message, "Verifique a conexão com o servidor e tente de novo."))
        return
    end if
    row = invalid
    if response.content <> invalid
        if response.content.GetChildCount() > 0 then row = response.content.GetChild(0)
    end if
    if row = invalid
        ShowSearchMessage("Nada encontrado para “" + m.term + "”", "Confira a grafia ou tente outro título.")
        return
    end if
    count = row.GetChildCount()
    total = count
    if response.total <> invalid then total = response.total
    m.loadedOffset = responseOffset
    m.loadedTerm = m.term
    m.total = total
    m.message.visible = false
    m.results.content = row
    m.results.jumpToItem = 0
    m.results.visible = true
    m.heading.text = ResultsHeading()
    if total > count
        m.resultStatus.text = (m.loadedOffset + 1).ToStr() + "–" + (m.loadedOffset + count).ToStr() + " de " + total.ToStr() + " títulos · Avançar/retroceder: mudar página"
    else if count = 1
        m.resultStatus.text = "1 título"
    else
        m.resultStatus.text = count.ToStr() + " títulos"
    end if
end sub

function ResultsHeading() as String
    return "Resultados para “" + m.term + "”"
end function

function HasResults() as Boolean
    if not m.results.visible or m.results.content = invalid then return false
    return m.results.content.GetChildCount() > 0
end function

sub ShowIdle()
    ShowSearchMessage("Encontre filmes e séries", "Digite com o teclado ao lado. Os resultados aparecem enquanto você digita.")
    m.heading.text = "Buscar"
end sub

sub ShowSearchMessage(title as String, body as String)
    m.results.visible = false
    m.results.content = invalid
    m.heading.text = ResultsHeading()
    m.resultStatus.text = ""
    m.messageTitle.text = title
    m.messageBody.text = body
    m.message.visible = true
    if m.area = "results" then FocusArea("keyboard")
end sub

sub PaintQuery()
    if m.query = ""
        m.queryLabel.text = "Títulos, séries, episódios"
        m.queryLabel.color = "0x7a7a7aff"
        return
    end if
    text = m.query
    ' Keep the end of a long query visible: that is where typing happens.
    if Len(text) > 22 then text = "…" + Right(text, 21)
    m.queryLabel.text = text
    m.queryLabel.color = "0xffffffff"
end sub

sub FocusArea(area as String)
    m.area = area
    m.top.area = area
    m.keyboard.active = area = "keyboard"
    if area = "results"
        m.results.SetFocus(true)
    else
        m.keyboard.SetFocus(true)
    end if
end sub

' The Scene focuses this page as a whole; pass focus to the remembered child.
sub OnSearchFocusChange()
    if m.top.HasFocus() then FocusArea(m.area)
end sub

sub OnKeyboardEdge()
    if m.keyboard.edge = "right" and HasResults() then FocusArea("results")
end sub

sub OnResultSelected()
    content = m.results.content
    if content = invalid then return
    card = content.GetChild(m.results.itemSelected)
    if card <> invalid then m.top.selected = card
end sub

sub AnimateSearchIn()
    m.enterMotion.control = "stop"
    m.enterMotion.control = "start"
end sub

sub ChangeSearchPage(direction as Integer)
    if m.inFlight or m.debouncePending or not HasResults() or m.loadedTerm <> m.term then return
    nextOffset = m.loadedOffset + m.results.content.GetChildCount()
    if direction < 0 then nextOffset = m.loadedOffset - 48
    if nextOffset < 0 then nextOffset = 0
    if nextOffset = m.loadedOffset or nextOffset >= m.total then return
    m.offset = nextOffset
    m.resultStatus.text = "Carregando títulos…"
    RequestLatest()
end sub

' Keys reach the page only when the keyboard or grid did not consume them.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.area = "results"
        if key = "fastforward" or key = "rewind"
            direction = 1
            if key = "rewind" then direction = -1
            ChangeSearchPage(direction)
            return true
        end if
        if key = "left" or key = "back"
            FocusArea("keyboard")
            return true
        end if
        ' Page only at grid edges; normal arrows are consumed by MarkupGrid.
        if key = "down" then ChangeSearchPage(1)
        if key = "up" then ChangeSearchPage(-1)
        return key = "up" or key = "down" or key = "right"
    end if
    ' Keyboard Left edge and Back bubble to the Scene, which opens the menu.
    return false
end function
