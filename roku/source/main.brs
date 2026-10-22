sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("LumaScene")
    screen.Show()
    while true
        message = Wait(0, port)
        if Type(message) = "roSGScreenEvent"
            if message.IsScreenClosed() then return
        end if
    end while
end sub
