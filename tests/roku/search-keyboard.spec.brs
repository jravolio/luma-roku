' Executes the production keyboard model and remote handling; only painting is stubbed.
sub Main()
    m.assertions = 0
    m.top = {key: "", edge: "", active: true}
    BuildKeyboardModel()
    AssertEqual(m.keys.Count(), 39, "three actions plus 26 letters and 10 digits")
    AssertEqual(FocusedKeyValue(), "a", "keyboard starts on the first letter")
    onKeyEvent("OK", true)
    AssertEqual(m.top.key, "a", "OK emits focused letter")
    onKeyEvent("right", true)
    onKeyEvent("right", true)
    AssertEqual(FocusedKeyValue(), "c", "right walks the row")
    onKeyEvent("down", true)
    AssertEqual(FocusedKeyValue(), "i", "down keeps the column")
    onKeyEvent("up", true)
    onKeyEvent("up", true)
    AssertEqual(FocusedKeyValue(), "backspace", "column 2 enters the wide Apagar key")
    AssertEqual(onKeyEvent("up", true), true, "top row consumes Up")
    AssertEqual(FocusedKeyValue(), "backspace", "top row does not wrap")
    onKeyEvent("right", true)
    AssertEqual(FocusedKeyValue(), "clear", "right from a wide key skips its span")
    m.top.edge = ""
    AssertEqual(onKeyEvent("right", true), true, "last column consumes Right")
    AssertEqual(m.top.edge, "right", "last column reports the results edge")
    onKeyEvent("left", true)
    onKeyEvent("left", true)
    AssertEqual(FocusedKeyValue(), "space", "left lands on Espaço")
    AssertEqual(onKeyEvent("left", true), false, "first column passes Left to the page menu")
    onKeyEvent("OK", true)
    AssertEqual(m.top.key, "space", "Espaço emits space")
    onKeyEvent("down", true)
    AssertEqual(FocusedKeyValue(), "a", "down from Espaço returns to its first column")
    for index = 1 to 10
        onKeyEvent("down", true)
    end for
    AssertEqual(FocusedKeyValue(), "5", "bottom row holds digits and does not wrap")
    AssertEqual(onKeyEvent("back", true), false, "Back is left to the page")
    AssertEqual(onKeyEvent("down", false), false, "releases are ignored")
    print "PASS: "; m.assertions; " search keyboard assertions"
end sub

sub PaintKeys()
end sub

sub AssertEqual(actual as Dynamic, expected as Dynamic, description as String)
    if actual <> expected
        print "FAIL: "; description; " expected="; expected; " actual="; actual
        stop
    end if
    m.assertions++
end sub
