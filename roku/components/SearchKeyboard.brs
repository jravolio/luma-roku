' Compact on-page keyboard: an action row above a 6x6 letter/digit grid.
' Key focus paints instantly; typing is too frequent to animate.
sub init()
    BuildKeyboardModel()
    BuildKeyNodes()
    PaintKeys()
end sub

sub BuildKeyboardModel()
    m.columns = 6
    m.keySize = [84, 72]
    m.keyGap = 8
    m.keys = [
        {value: "space", label: "Espaço", row: 0, col: 0, span: 2},
        {value: "backspace", label: "Apagar", row: 0, col: 2, span: 2},
        {value: "clear", label: "Limpar", row: 0, col: 4, span: 2}
    ]
    characters = "abcdefghijklmnopqrstuvwxyz1234567890"
    for index = 0 to Len(characters) - 1
        character = Mid(characters, index + 1, 1)
        m.keys.Push({value: character, label: character, row: 1 + index \ m.columns, col: index mod m.columns, span: 1})
    end for
    m.rows = 1 + Len(characters) \ m.columns
    ' Start on "a", where a new query begins; col is the remembered column.
    m.row = 1
    m.col = 0
end sub

sub BuildKeyNodes()
    m.keyNodes = []
    letterFont = CreateObject("roSGNode", "Font")
    letterFont.uri = "pkg:/fonts/Inter-Regular.ttf"
    letterFont.size = 34
    actionFont = CreateObject("roSGNode", "Font")
    actionFont.uri = "pkg:/fonts/Inter-Regular.ttf"
    actionFont.size = 24
    for each key in m.keys
        width = key.span * m.keySize[0] + (key.span - 1) * m.keyGap
        group = m.top.CreateChild("Group")
        group.translation = [key.col * (m.keySize[0] + m.keyGap), key.row * (m.keySize[1] + m.keyGap)]
        bg = group.CreateChild("Rectangle")
        bg.width = width
        bg.height = m.keySize[1]
        ApplyRounded(bg, 14)
        label = group.CreateChild("Label")
        label.width = width
        label.height = m.keySize[1]
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.text = key.label
        label.font = letterFont
        if key.span > 1 then label.font = actionFont
        m.keyNodes.Push({bg: bg, label: label})
    end for
end sub

function FocusedKeyIndex() as Integer
    for index = 0 to m.keys.Count() - 1
        key = m.keys[index]
        if key.row = m.row and m.col >= key.col and m.col < key.col + key.span then return index
    end for
    return 0
end function

function FocusedKeyValue() as String
    return m.keys[FocusedKeyIndex()].value
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    current = m.keys[FocusedKeyIndex()]
    if key = "OK"
        m.top.key = current.value
        return true
    else if key = "up"
        if m.row > 0 then m.row--
    else if key = "down"
        if m.row < m.rows - 1 then m.row++
    else if key = "left"
        ' The first column belongs to the page: Left opens the menu.
        if current.col = 0 then return false
        m.col = current.col - 1
        ' Landing on a wide key anchors to its start, as Right does.
        m.col = m.keys[FocusedKeyIndex()].col
    else if key = "right"
        if current.col + current.span >= m.columns
            m.top.edge = "right"
            return true
        end if
        m.col = current.col + current.span
    else
        return false
    end if
    PaintKeys()
    return true
end function

sub PaintKeys()
    if m.keyNodes = invalid then return
    focused = FocusedKeyIndex()
    for index = 0 to m.keyNodes.Count() - 1
        node = m.keyNodes[index]
        node.bg.color = "0xffffff12"
        node.label.color = "0xd6d6d6ff"
        if index = focused
            if m.top.active
                node.bg.color = "0xffffffff"
                node.label.color = "0x090909ff"
            else
                node.bg.color = "0xffffff3a"
                node.label.color = "0xffffffff"
            end if
        end if
    end for
end sub
