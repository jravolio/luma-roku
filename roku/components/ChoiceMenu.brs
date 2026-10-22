' Seven rows at most are on screen; longer lists scroll with the focus.
sub init()
    m.panel = m.top.FindNode("choicePanel")
    m.rowsGroup = m.top.FindNode("choiceRows")
    m.more = m.top.FindNode("choiceMore")
    ApplyRounded(m.panel, 30)
    m.visibleRows = 7
    m.rows = []
    font = CreateObject("roSGNode", "Font")
    font.uri = "pkg:/fonts/Inter-Medium.ttf"
    font.size = 25
    for index = 0 to m.visibleRows - 1
        row = m.rowsGroup.CreateChild("Group")
        row.translation = [0, index * 64]
        bg = row.CreateChild("Rectangle")
        bg.width = 568
        bg.height = 58
        ApplyRounded(bg, 16)
        check = row.CreateChild("Poster")
        check.uri = "pkg:/images/icons/check.png"
        check.translation = [20, 18]
        check.width = 22
        check.height = 22
        label = row.CreateChild("Label")
        label.translation = [58, 0]
        label.width = 490
        label.height = 58
        label.vertAlign = "center"
        label.font = font
        m.rows.Push({group: row, bg: bg, check: check, label: label})
    end for
    m.focusIndex = 0
    m.firstRow = 0
end sub

sub OnOptions()
    m.focusIndex = 0
    if m.top.checkedIndex >= 0 and m.top.checkedIndex < OptionCount() then m.focusIndex = m.top.checkedIndex
    m.firstRow = 0
    count = OptionCount()
    shown = count
    if shown > m.visibleRows then shown = m.visibleRows
    m.panel.height = 88 + shown * 64 + 20
    if count > m.visibleRows then m.panel.height += 30
    m.more.translation = [32, 88 + shown * 64 + 8]
    PaintRows()
end sub

function OptionCount() as Integer
    if not IsList(m.top.options) then return 0
    return m.top.options.Count()
end function

sub PaintRows()
    count = OptionCount()
    if m.focusIndex < m.firstRow then m.firstRow = m.focusIndex
    if m.focusIndex >= m.firstRow + m.visibleRows then m.firstRow = m.focusIndex - m.visibleRows + 1
    for slot = 0 to m.visibleRows - 1
        row = m.rows[slot]
        index = m.firstRow + slot
        row.group.visible = index < count
        if index < count
            focused = index = m.focusIndex
            row.label.text = TextValue(m.top.options[index])
            row.check.visible = index = m.top.checkedIndex
            row.bg.color = "0x00000000"
            row.label.color = "0xffffffff"
            row.check.blendColor = "0xffffffff"
            if focused
                row.bg.color = "0xffffffff"
                row.label.color = "0x111111ff"
                row.check.blendColor = "0x111111ff"
            end if
        end if
    end for
    m.more.visible = count > m.visibleRows
    m.more.text = (m.focusIndex + 1).ToStr() + " de " + count.ToStr()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return true
    count = OptionCount()
    if key = "up" and m.focusIndex > 0
        m.focusIndex--
        PaintRows()
    else if key = "down" and m.focusIndex < count - 1
        m.focusIndex++
        PaintRows()
    else if key = "OK" and count > 0
        m.top.chosen = m.focusIndex
    else if key = "back" or key = "left"
        m.top.dismissed = true
    end if
    return true
end function
