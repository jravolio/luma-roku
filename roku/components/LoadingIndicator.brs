sub init()
    m.root = m.top.FindNode("indicatorRoot")
    m.dim = m.top.FindNode("indicatorDim")
    m.label = m.top.FindNode("indicatorLabel")
    m.spin = m.top.FindNode("indicatorSpin")
    m.fade = m.top.FindNode("indicatorFade")
    m.delay = m.top.FindNode("indicatorDelay")
    ApplyRounded(m.top.FindNode("indicatorPlate"), 28)
    m.delay.ObserveField("fire", "OnDelay")
    OnText()
end sub

' Instant loads never flash a panel: it fades in only after a short wait.
sub OnControl()
    m.delay.control = "stop"
    m.fade.control = "stop"
    m.root.opacity = 0
    if m.top.control = "start"
        ' The dim covers the whole screen wherever the panel itself sits.
        m.dim.visible = m.top.dimScreen
        m.dim.translation = [-m.top.translation[0], -m.top.translation[1]]
        m.spin.control = "start"
        m.delay.control = "start"
    else
        m.spin.control = "stop"
    end if
end sub

sub OnText()
    m.label.text = m.top.text
    if m.top.text = "" then m.label.text = "Carregando…"
end sub

sub OnDelay()
    if m.top.control = "start" then m.fade.control = "start"
end sub
