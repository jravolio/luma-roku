sub init()
    ' The name RunService aborts startup on G510X/OS 16.0.4, even with an empty body.
    m.top.functionName = "RunJellyfinService"
end sub

' The persistent Task is the only owner of registry and all network state.
sub RunJellyfinService()
    m.port = CreateObject("roMessagePort")
    m.top.ObserveField("request", m.port)
    m.registry = CreateObject("roRegistrySection", "Luma")
    storedState = m.registry.Read("state")
    m.saved = invalid
    if storedState <> "" then m.saved = ParseJson(storedState)
    if not IsMap(m.saved) then m.saved = {}
    if not IsMap(m.saved.accounts) then m.saved.accounts = {}
    if TextValue(m.saved.deviceId) = "" then m.saved.deviceId = CreateObject("roDeviceInfo").GetRandomUUID()
    m.account = invalid
    m.verified = false
    Persist()
    m.top.cachedHome = CachedHome()
    m.top.ready = true
    while true
        event = Wait(0, m.port)
        if Type(event) = "roSGNodeEvent"
            request = event.GetData()
            if IsMap(request)
                result = Dispatch(request)
                result.action = request.action
                result.requestId = request.requestId
                m.top.result = result
                ' Written after the result is out, so saving never delays Home.
                if m.homeCacheLists <> invalid
                    SaveHomeCache(m.homeCacheLists)
                    m.homeCacheLists = invalid
                end if
            end if
        end if
    end while
end sub

function HomeCachePath() as String
    return "cachefs:/luma-home.json"
end function

function HomeRowTitles() as Object
    return ["Continue assistindo", "Adicionados recentemente", "Filmes para hoje", "Séries para maratonar"]
end function

sub SaveHomeCache(lists as Object)
    if not IsMap(m.account) then return
    WriteAsciiFile(HomeCachePath(), FormatJson({serverId: TextValue(m.account.id), userId: TextValue(m.account.userId), lists: lists}))
end sub

function CachedHome() as Dynamic
    ' The cache is gone after a reboot; reading a missing file logs an error.
    if not CreateObject("roFileSystem").Exists(HomeCachePath()) then return invalid
    raw = ReadAsciiFile(HomeCachePath())
    if raw = "" then return invalid
    return HomeFromCache(ParseJson(raw))
end function

' Last session's Home, rebuilt at start so Luma opens on it while the server is
' still being verified. Only for the saved, signed-in account; artwork URLs
' carry no token, and nothing authenticated is sent until verification.
function HomeFromCache(cached as Dynamic) as Dynamic
    if not IsMap(cached) or not IsList(cached.lists) then return invalid
    saved = m.saved.accounts[TextValue(m.saved.activeId)]
    if not IsMap(saved) then return invalid
    if TextValue(saved.token) = "" or TextValue(saved.userId) = "" then return invalid
    if TextValue(cached.serverId) <> TextValue(saved.id) or TextValue(cached.userId) <> TextValue(saved.userId) then return invalid
    m.account = {id: saved.id, base: TextValue(saved.base), userId: saved.userId}
    titles = HomeRowTitles()
    rows = []
    for index = 0 to titles.Count() - 1
        items = []
        if index < cached.lists.Count()
            if IsList(cached.lists[index]) then items = cached.lists[index]
        end if
        rows.Push({title: titles[index], items: items})
    end for
    content = BuildRows(rows)
    m.account = invalid
    if content.GetChildCount() = 0 then return invalid
    return {content: content, userName: TextValue(saved.userName), serverName: TextValue(saved.name)}
end function

sub Persist()
    m.registry.Write("state", FormatJson(m.saved))
    m.registry.Flush()
end sub

function AuthHeader(token = "" as String) as String
    q = Chr(34)
    header = "MediaBrowser Client=" + q + "Luma" + q + ", Device=" + q + "Roku TV" + q
    header += ", DeviceId=" + q + m.saved.deviceId + q + ", Version=" + q + "1.0.0" + q
    if token <> "" then header += ", Token=" + q + token + q
    return header
end function

' Async transfers with an absolute deadline; no UI-thread network calls.
function NewTransfer(url as String, token as String, port as Object) as Object
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(port)
    transfer.SetUrl(url)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnablePeerVerification(true)
    transfer.EnableHostVerification(true)
    transfer.RetainBodyOnError(true)
    ' Jellyfin gzips JSON on request (a 24-film page: 46 → 20 KB); Roku inflates it.
    transfer.EnableEncodings(true)
    transfer.AddHeader("Accept", "application/json")
    transfer.AddHeader("Content-Type", "application/json")
    transfer.AddHeader("Authorization", AuthHeader(token))
    return transfer
end function

function TransferResult(event as Object) as Object
    code = event.GetResponseCode()
    if code >= 200 and code < 300
        ' Reports return 204 with no body; ParseJson("") logs an error.
        body = event.GetString()
        data = invalid
        if body <> "" then data = ParseJson(body)
        return {ok: true, code: code, data: data}
    end if
    if code = 401 then return Failure("Sua sessão expirou. Entre novamente.", code)
    if code = 403 then return Failure("Sua conta não tem acesso a este conteúdo.", code)
    return Failure("O servidor não conseguiu concluir a solicitação. Tente novamente.", code)
end function

function Http(base as String, path as String, method = "GET" as String, body = invalid as Dynamic, token = "" as String, timeout = 9000 as Integer) as Object
    port = CreateObject("roMessagePort")
    transfer = NewTransfer(base + path, token, port)
    transfer.SetRequest(method)
    if method = "GET"
        started = transfer.AsyncGetToString()
    else
        payload = ""
        if body <> invalid then payload = FormatJson(body)
        started = transfer.AsyncPostFromString(payload)
    end if
    if not started then return Failure("Não foi possível iniciar a conexão.")
    clock = CreateObject("roTimespan")
    while clock.TotalMilliseconds() < timeout
        remaining = timeout - clock.TotalMilliseconds()
        if remaining < 1 then remaining = 1
        event = Wait(remaining, port)
        if Type(event) = "roUrlEvent"
            if event.GetSourceIdentity() = transfer.GetIdentity() then return TransferResult(event)
        end if
    end while
    transfer.AsyncCancel()
    return Failure("Seu servidor não está respondendo. Seus dados de acesso continuam salvos.")
end function

' Independent GETs share one wait: the page costs the slowest response, not
' the sum of all of them.
function HttpAll(base as String, paths as Object, token as String, timeout = 9000 as Integer) as Object
    port = CreateObject("roMessagePort")
    results = []
    active = {}
    for index = 0 to paths.Count() - 1
        results.Push(Failure("Seu servidor não está respondendo. Seus dados de acesso continuam salvos."))
        transfer = NewTransfer(base + paths[index], token, port)
        transfer.SetRequest("GET")
        if transfer.AsyncGetToString()
            active[transfer.GetIdentity().ToStr()] = {transfer: transfer, index: index}
        else
            results[index] = Failure("Não foi possível iniciar a conexão.")
        end if
    end for
    clock = CreateObject("roTimespan")
    while active.Count() > 0 and clock.TotalMilliseconds() < timeout
        remaining = timeout - clock.TotalMilliseconds()
        if remaining < 1 then remaining = 1
        event = Wait(remaining, port)
        if Type(event) = "roUrlEvent"
            key = event.GetSourceIdentity().ToStr()
            entry = active[key]
            if entry <> invalid
                results[entry.index] = TransferResult(event)
                active.Delete(key)
            end if
        end if
    end while
    CancelProbes(active)
    return results
end function

function Verify(base as String, expectedId = "" as String) as Object
    if base = "" then return Failure("Informe um endereço de servidor válido com http:// ou https://.")
    response = Http(base, "/System/Info/Public", "GET", invalid, "", 3500)
    if not response.ok then return response
    check = PublicServerInfo(response.data, base, expectedId)
    if check.ok and expectedId <> ""
        m.verifiedAt = CreateObject("roTimespan")
        m.verifiedBase = base
        m.verifiedId = expectedId
    end if
    return check
end function

' Proving the server ID before every request added a round trip to everything.
' A proof from the last 15 s at the same address still guards the saved token;
' a network failure, reconnect or new address asks again.
function RecentlyVerified() as Boolean
    if m.verified <> true or m.verifiedAt = invalid or not IsMap(m.account) then return false
    if m.verifiedBase <> TextValue(m.account.base) or m.verifiedId <> TextValue(m.account.id) then return false
    return m.verifiedAt.TotalMilliseconds() < 15000
end function

' Shared by manual/UDP verification and the token-free subnet probes.
function PublicServerInfo(data as Dynamic, base as String, expectedId = "" as String) as Object
    if not IsMap(data) then return Failure("Este endereço não retornou informações de um servidor Jellyfin.")
    if LCase(TextValue(data.ProductName)) <> "jellyfin server" then return Failure("Este endereço não é de um servidor Jellyfin.")
    id = TextValue(data.Id)
    if id = "" then return Failure("O servidor não informou sua identidade.")
    if expectedId <> "" and id <> expectedId then return Failure("Outro servidor está usando este endereço. Seus dados de acesso não foram enviados.", 409)
    return {ok: true, server: {id: id, name: TextValue(data.ServerName, "Jellyfin"), base: base}}
end function

' Never trust the UDP Id alone. Each address is verified through the public endpoint.
function Discover() as Object
    socket = CreateObject("roDatagramSocket")
    port = CreateObject("roMessagePort")
    socket.SetMessagePort(port)
    destination = CreateObject("roSocketAddress")
    destination.SetAddress("255.255.255.255:7359")
    socket.SetSendToAddress(destination)
    socket.SetBroadcast(true)
    socket.NotifyReadable(true)
    candidates = []
    seen = {}
    for attempt = 1 to 3
        socket.SendStr("Who is JellyfinServer?")
        timer = CreateObject("roTimespan")
        while timer.TotalMilliseconds() < 900
            event = Wait(100, port)
            if Type(event) = "roSocketEvent"
                if event.GetSocketId() = socket.GetId()
                    if socket.IsReadable()
                        reply = ParseJson(socket.ReceiveStr(8192))
                        if IsMap(reply)
                            base = NormalizeBase(reply.Address)
                            id = TextValue(reply.Id)
                            if base <> "" and id <> "" and seen[base] = invalid
                                seen[base] = true
                                candidates.Push({base: base, id: id})
                            end if
                        end if
                    end if
                end if
            end if
            if candidates.Count() >= 12 then exit while
        end while
        if candidates.Count() >= 12 then exit for
    end for
    socket.Close()
    servers = []
    identities = {}
    for each candidate in candidates
        check = Verify(candidate.base, candidate.id)
        if check.ok
            if identities[check.server.id] = invalid
                identities[check.server.id] = true
                servers.Push(check.server)
            end if
        end if
    end for
    target = TextValue(m.saved.activeId)
    found = false
    for each server in servers
        if server.id = target then found = true
    end for
    if servers.Count() = 0 or (target <> "" and not found)
        for each server in ProbeLocalSubnet()
            if identities[server.id] = invalid
                identities[server.id] = true
                servers.Push(server)
            end if
        end for
    end if
    return servers
end function

' UDP is often blocked by the PC firewall. This fallback sends only public,
' unauthenticated GETs; it never guesses that a responding host is our server.
function ProbeLocalSubnet() as Object
    servers = []
    prefix = PrivateSubnetPrefix(CreateObject("roDeviceInfo").GetIPAddrs())
    if prefix = "" then return servers
    template = ProbeTemplate("")
    saved = m.saved.accounts[TextValue(m.saved.activeId)]
    if IsMap(saved) then template = ProbeTemplate(TextValue(saved.base))
    port = CreateObject("roMessagePort")
    deadline = CreateObject("roTimespan")
    active = {}
    seen = {}
    nextHost = 1
    while deadline.TotalMilliseconds() < 15000
        while active.Count() < 24 and nextHost <= 254
            base = template.scheme + "://" + prefix + nextHost.ToStr() + template.port + template.path
            nextHost++
            transfer = CreateObject("roUrlTransfer")
            transfer.SetMessagePort(port)
            transfer.SetUrl(base + "/System/Info/Public")
            transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
            transfer.InitClientCertificates()
            transfer.EnablePeerVerification(true)
            transfer.EnableHostVerification(true)
            transfer.AddHeader("Accept", "application/json")
            if transfer.AsyncGetToString()
                active[transfer.GetIdentity().ToStr()] = {transfer: transfer, base: base, clock: CreateObject("roTimespan")}
            end if
            if deadline.TotalMilliseconds() >= 15000 then exit while
        end while
        if active.Count() = 0 and nextHost > 254 then exit while
        event = Wait(20, port)
        if Type(event) = "roUrlEvent"
            key = event.GetSourceIdentity().ToStr()
            probe = active[key]
            if probe <> invalid
                if event.GetResponseCode() = 200
                    check = PublicServerInfo(ParseJson(event.GetString()), probe.base)
                    if check.ok
                        identity = check.server.id
                        if seen[identity] = invalid
                            seen[identity] = true
                            servers.Push(check.server)
                            ' A verified match lets DHCP reconnection finish immediately.
                            if identity = TextValue(m.saved.activeId)
                                CancelProbes(active)
                                return servers
                            end if
                        end if
                    end if
                end if
                active.Delete(key)
            end if
        end if
        expired = []
        for each key in active
            if active[key].clock.TotalMilliseconds() >= 650 then expired.Push(key)
        end for
        for each key in expired
            active[key].transfer.AsyncCancel()
            active.Delete(key)
        end for
    end while
    CancelProbes(active)
    return servers
end function

sub CancelProbes(active as Object)
    for each key in active
        active[key].transfer.AsyncCancel()
    end for
end sub

function PrivateSubnetPrefix(addresses as Dynamic) as String
    if not IsMap(addresses) then return ""
    for each name in addresses
        ip = TextValue(addresses[name])
        parts = ip.Split(".")
        if parts.Count() = 4
            first = parts[0].ToInt()
            second = parts[1].ToInt()
            private = first = 10 or (first = 172 and second >= 16 and second <= 31) or (first = 192 and second = 168)
            if private then return parts[0] + "." + parts[1] + "." + parts[2] + "."
        end if
    end for
    return ""
end function

function ProbeTemplate(base as String) as Object
    template = {scheme: "http", port: ":8096", path: ""}
    if base = "" then return template
    match = CreateObject("roRegex", "^(https?)://([^/]+)(/.*)?$", "i").Match(base)
    if match.Count() < 3 then return template
    template.scheme = LCase(match[1])
    template.port = ""
    ports = CreateObject("roRegex", ":[0-9]+$", "").Match(match[2])
    if ports.Count() > 0 then template.port = ports[0]
    if match.Count() > 3 then template.path = match[3]
    return template
end function

function Activate(server as Object) as Object
    m.playbackCatalog = invalid
    account = m.saved.accounts[server.id]
    if not IsMap(account) then account = {}
    account.id = server.id
    account.base = server.base
    account.name = server.name
    m.account = account
    m.verified = true
    m.saved.activeId = server.id
    m.saved.accounts[server.id] = account
    Persist()
    loggedIn = TextValue(account.token) <> "" and TextValue(account.userId) <> ""
    ' Jellyfin allows empty passwords, so a saved username alone marks saved credentials.
    if not loggedIn and TextValue(account.loginName) <> ""
        loggedIn = ReauthenticateAccount().ok
    end if
    return {ok: true, connected: true, loggedIn: loggedIn, serverName: account.name, userName: TextValue(account.userName), canSwitchProfiles: CanSwitchProfiles()}
end function

' Credentials are only posted after a fresh, token-free check of the saved server ID.
function ReauthenticateAccount() as Object
    if not IsMap(m.account) then return Failure("Escolha um servidor primeiro.", 401)
    username = TextValue(m.account.loginName)
    password = TextValue(m.account.loginPassword)
    if username = "" then return Failure("Sua sessão expirou. Entre novamente.", 401)
    check = Verify(TextValue(m.account.base), TextValue(m.account.id))
    if not check.ok then return check
    response = Http(m.account.base, "/Users/AuthenticateByName", "POST", {Username: username, Pw: password})
    if not response.ok then return Failure("Sua sessão expirou. Entre novamente.", response.code)
    if not IsMap(response.data) or not IsMap(response.data.User) then return Failure("Sua sessão expirou. Entre novamente.", 401)
    if TextValue(response.data.ServerId) <> "" and TextValue(response.data.ServerId) <> m.account.id then return Failure("A identidade do servidor mudou durante o acesso.", 409)
    if TextValue(response.data.AccessToken) = "" or TextValue(response.data.User.Id) = "" then return Failure("Sua sessão expirou. Entre novamente.", 401)
    m.account.token = response.data.AccessToken
    m.account.userId = response.data.User.Id
    m.account.userName = TextValue(response.data.User.Name, username)
    m.account.admin = IsAdministrator(response.data.User)
    StoreProfile()
    m.saved.accounts[m.account.id] = m.account
    m.playbackCatalog = invalid
    m.verified = true
    Persist()
    return {ok: true}
end function

function Bootstrap(forceSelect as Boolean) as Object
    m.verified = false
    saved = m.saved.accounts[TextValue(m.saved.activeId)]
    if IsMap(saved) and not forceSelect
        check = Verify(TextValue(saved.base), TextValue(saved.id))
        if check.ok then return Activate(check.server)
    end if
    servers = Discover()
    if not forceSelect
        for each server in servers
            if server.id = TextValue(m.saved.activeId) then return Activate(server)
        end for
        if TextValue(m.saved.activeId) = "" and servers.Count() = 1 then return Activate(servers[0])
    end if
    message = "Escolha seu servidor Jellyfin ou informe o endereço."
    if servers.Count() = 0 then message = "Nenhum servidor encontrado. Ligue seu computador e verifique se ele está na mesma rede. Seus dados de acesso continuam salvos."
    if TextValue(m.saved.activeId) <> "" and not forceSelect then message = "Seu servidor salvo está desconectado. Tente novamente quando ele estiver disponível ou escolha outro servidor. Seus dados de acesso continuam salvos."
    return {ok: true, connected: false, servers: servers, message: message}
end function

' Reverify before every authenticated command, including reports, to avoid sending
' a saved token to a recycled DHCP address. A mismatch never clears the account.
function EnsureAccount() as Object
    if not RecentlyVerified()
        m.verified = false
        if not IsMap(m.account) then return Failure("Conecte-se ao servidor primeiro.", 428)
        check = Verify(m.account.base, m.account.id)
        if not check.ok
            recovered = ReconnectSaved()
            if not recovered.ok then return recovered
        end if
    end if
    m.verified = true
    if TextValue(m.account.token) = "" then return Failure("Entre na sua conta para continuar.", 401)
    return {ok: true}
end function

function ReconnectSaved() as Object
    m.verified = false
    if not IsMap(m.account) then return Failure("Conecte-se ao servidor primeiro.", 428)
    ' Throttle repeated playback reports when a PC goes offline.
    if m.reconnectClock <> invalid
        if m.reconnectClock.TotalMilliseconds() < 15000 then return Failure("Seu servidor está desconectado. Seus dados de acesso continuam salvos.")
    end if
    m.reconnectClock = CreateObject("roTimespan")
    identity = m.account.id
    for each server in Discover()
        if server.id = identity
            Activate(server)
            return {ok: true}
        end if
    end for
    return Failure("Seu servidor está desconectado. Ligue-o e selecione Reconectar. Seus dados de acesso continuam salvos.")
end function

function Api(path as String, method = "GET" as String, body = invalid as Dynamic) as Object
    if not m.verified then return Failure("A identidade do servidor ainda não foi verificada.", 409)
    response = Http(m.account.base, path, method, body, TextValue(m.account.token))
    if not response.ok and response.code = 401
        refreshed = ReauthenticateAccount()
        if refreshed.ok then response = Http(m.account.base, path, method, body, TextValue(m.account.token))
    end if
    if not response.ok and response.code <= 0
        m.verifiedAt = invalid
        recovered = ReconnectSaved()
        if recovered.ok
            response = Http(m.account.base, path, method, body, TextValue(m.account.token))
        end if
    end if
    return response
end function

' Failures that need re-authentication or reconnection retry one at a time
' through Api, which owns that recovery.
function ApiAll(paths as Object) as Object
    if not m.verified
        failures = []
        for each path in paths
            failures.Push(Failure("A identidade do servidor ainda não foi verificada.", 409))
        end for
        return failures
    end if
    responses = HttpAll(m.account.base, paths, TextValue(m.account.token))
    for index = 0 to paths.Count() - 1
        response = responses[index]
        if not response.ok and (response.code = 401 or response.code <= 0) then responses[index] = Api(paths[index])
    end for
    return responses
end function

function Dispatch(request as Object) as Object
    action = TextValue(request.action)
    if action = "bootstrap" then return Bootstrap(false)
    if action = "discover" then return Bootstrap(true)
    if action = "select" or action = "manual"
        check = Verify(NormalizeBase(request.base), TextValue(request.serverId))
        if not check.ok then return check
        return Activate(check.server)
    end if
    if action = "rememberTracks"
        RememberSeriesTrack(TextValue(request.seriesId), TextValue(request.kind), request.track)
        return {ok: true}
    end if
    if action = "logout"
        m.playbackCatalog = invalid
        m.detailsCache = {}
        DeleteFile(HomeCachePath())
        if IsMap(m.account)
            m.account.token = ""
            m.account.userId = ""
            m.account.userName = ""
            m.account.loginPassword = ""
            m.account.loginName = ""
            m.account.admin = invalid
            m.account.profiles = {}
            m.saved.accounts[m.account.id] = m.account
            Persist()
        end if
        return {ok: true}
    end if
    if action = "login"
        if not IsMap(m.account) then return Failure("Escolha um servidor primeiro.")
        check = Verify(m.account.base, m.account.id)
        if not check.ok then return check
        signedIn = SignIn(TextValue(request.username), TextValue(request.password))
        if not signedIn.ok then return signedIn
        return {ok: true, userName: m.account.userName, canSwitchProfiles: CanSwitchProfiles()}
    end if
    guard = EnsureAccount()
    if not guard.ok then return guard
    if action = "profiles" then return ServerProfiles()
    if action = "switchProfile" then return SwitchProfile(request)
    ' Requested after playback starts so a slow plugin never delays the video.
    if action = "segments"
        itemId = TextValue(request.itemId)
        seriesId = TextValue(request.seriesId)
        ' Segments and the next episode come back together, freeing this serial
        ' Task sooner for reports and track changes early in playback.
        paths = ["/MediaSegments/" + Encode(itemId), TrickplayPath(itemId)]
        if seriesId <> "" then paths.Push(NextEpisodePath(seriesId, itemId))
        first = HttpAll(m.account.base, paths, TextValue(m.account.token), 3000)
        nextItem = invalid
        if seriesId <> "" then nextItem = NextEpisode(seriesId, itemId, first[2])
        nextImage = ""
        if nextItem <> invalid then nextImage = ImageUrl(nextItem, false, "400")
        return {ok: true, itemId: itemId, segments: FetchPlaybackSegments(itemId, first[0]), nextEpisode: nextItem, nextImage: nextImage, trickplay: TrickplayInfo(itemId, TextValue(request.mediaSourceId), first[1])}
    end if
    uid = Encode(m.account.userId)
    ' Lists never read MediaSources (details and playback fetch their own); it was
    ' ~80% of every list payload, all parsed and copied into cards on the TV.
    fields = "&Fields=Overview,PrimaryImageAspectRatio,Genres&EnableUserData=true"
    if action = "home"
        titles = HomeRowTitles()
        paths = [
            "/UserItems/Resume?UserId=" + uid + "&Limit=18&MediaTypes=Video" + fields
            "/Items/Latest?UserId=" + uid + "&Limit=24&IncludeItemTypes=Movie,Series" + fields
            "/Items?UserId=" + uid + "&Recursive=true&IncludeItemTypes=Movie&SortBy=DateCreated,SortName&SortOrder=Descending,Ascending&Limit=24" + fields
            "/Items?UserId=" + uid + "&Recursive=true&IncludeItemTypes=Series&SortBy=DateCreated,SortName&SortOrder=Descending,Ascending&Limit=24" + fields
        ]
        ' A session saved before profiles existed learns once, alongside Home,
        ' whether it belongs to the server's administrator.
        if m.account.admin = invalid then paths.Push("/Users/Me")
        responses = ApiAll(paths)
        rows = []
        lists = []
        for index = 0 to titles.Count() - 1
            if not responses[index].ok then return responses[index]
            rows.Push({title: titles[index], items: ItemArray(responses[index].data)})
            lists.Push(ItemArray(responses[index].data))
        end for
        if responses.Count() > titles.Count()
            if responses[titles.Count()].ok and IsMap(responses[titles.Count()].data)
                m.account.admin = IsAdministrator(responses[titles.Count()].data)
                StoreProfile()
                Persist()
            end if
        end if
        m.homeCacheLists = lists
        return {ok: true, content: BuildRows(rows), title: "Para você", canSwitchProfiles: CanSwitchProfiles()}
    else if action = "search"
        offset = 0
        if request.offset <> invalid then offset = request.offset
        title = "Busca · " + TextValue(request.query)
        found = SearchItems(TextValue(request.query), offset, uid, fields)
        if not found.ok then return found
        return {ok: true, content: BuildRows([{title: title, items: found.items}]), title: title, offset: offset, total: found.total, count: found.items.Count()}
    else if action = "ambient"
        response = Api("/Items?UserId=" + uid + "&IncludeItemTypes=Movie,Series&Recursive=true&SortBy=Random&Limit=40&ImageTypes=Backdrop&Fields=Genres&EnableUserData=false")
        if not response.ok then return response
        slides = []
        for each item in ItemArray(response.data)
            if IsMap(item) then slides.Push({backdrop: ImageUrl(item, true), logo: LogoUrl(item), title: TextValue(item.Name), meta: AmbientMeta(item)})
        end for
        return {ok: true, items: slides}
    else if action = "browse"
        offset = 0
        if request.offset <> invalid then offset = request.offset
        path = "/Items?UserId=" + uid + "&Recursive=true&Limit=48&StartIndex=" + Encode(offset) + fields
        path += "&IncludeItemTypes=" + Encode(request.kind) + LibraryOrder(request)
        if TextValue(request.genreId) <> "" then path += "&GenreIds=" + Encode(request.genreId)
        if request.unwatched = true then path += "&Filters=IsUnplayed"
        title = "Biblioteca"
        if request.kind = "Movie" then title = "Filmes"
        if request.kind = "Series" then title = "Séries"
        if request.kind = "BoxSet" then title = "Coleções"
        if request.kind = "Series" and not SeasonPostersFresh()
            ' The season-poster index rides along with the first Séries page.
            responses = ApiAll([path, SeasonPostersPath()])
            response = responses[0]
            StoreSeasonPosters(responses[1])
        else
            response = Api(path)
        end if
        if not response.ok then return response
        items = ItemArray(response.data)
        content = BuildLibraryRows(items)
        total = offset + items.Count()
        if IsMap(response.data)
            if response.data.TotalRecordCount <> invalid then total = response.data.TotalRecordCount
        end if
        return {ok: true, content: content, title: title, offset: offset, total: total, count: items.Count()}
    else if action = "genres"
        response = Api("/Genres?UserId=" + uid + "&IncludeItemTypes=" + Encode(request.kind) + "&Recursive=true&SortBy=SortName&SortOrder=Ascending")
        if not response.ok then return response
        genres = []
        for each genre in ItemArray(response.data)
            if IsMap(genre) and TextValue(genre.Id) <> "" then genres.Push({id: TextValue(genre.Id), name: TextValue(genre.Name)})
        end for
        return {ok: true, genres: genres}
    else if action = "details" or action = "prefetch"
        ' A card held in focus for a moment is fetched ahead; OK then opens it
        ' from this short-lived cache instead of the network.
        ' A card that plays at once is fetched without its page extras, so the
        ' two kinds of fetch are kept apart.
        cacheKey = TextValue(request.itemId)
        if request.autoplay = true then cacheKey += "|play"
        if action = "prefetch" and HasPrefetched(cacheKey) then return {ok: true}
        if action = "details"
            cached = TakePrefetched(cacheKey)
            if cached <> invalid
                if request.autoplay = true then PlaybackCatalog(TextValue(request.itemId))
                return cached
            end if
        end if
        itemId = TextValue(request.itemId)
        kind = TextValue(request.kind)
        ' Everything the page needs goes out as one batch: the item, a show's
        ' episodes and next-up, "Mais como este", or the stream catalog for a
        ' card that plays at once (which shows no page, so no extras).
        paths = ["/Items/" + Encode(itemId) + "?UserId=" + uid]
        seriesAt = -1
        similarAt = -1
        catalogAt = -1
        if kind = "Series"
            seriesAt = paths.Count()
            paths.Append(SeriesPaths(itemId))
        end if
        if request.autoplay = true
            catalogAt = paths.Count()
            paths.Push(PlaybackCatalogPath(itemId))
        else if kind = "Movie" or kind = "Series"
            similarAt = paths.Count()
            paths.Push(SimilarPath(itemId))
        end if
        if paths.Count() > 1
            responses = ApiAll(paths)
        else
            responses = [Api(paths[0])]
        end if
        response = responses[0]
        if catalogAt >= 0
            m.playbackCatalog = invalid
            CachePlaybackCatalog(itemId, responses[catalogAt])
        end if
        if not response.ok then return response
        if not IsMap(response.data) then return Failure("Este título não está mais disponível.")
        result = {ok: true, item: response.data, card: MakeCard(response.data)}
        if response.data.Type = "Series"
            prefetched = invalid
            if seriesAt >= 0 and TextValue(response.data.Id) = itemId then prefetched = [responses[seriesAt], responses[seriesAt + 1]]
            AddSeriesEpisodes(result, TextValue(response.data.Id), prefetched)
        end if
        if response.data.Type = "Person"
            AddPersonTitles(result, TextValue(response.data.Id), uid, fields)
        else if response.data.Type = "BoxSet"
            AddCollectionTitles(result, TextValue(response.data.Id), uid, fields)
        else if request.autoplay <> true
            similar = invalid
            if similarAt >= 0 then similar = responses[similarAt]
            AddExtras(result, response.data, similar)
        end if
        if action = "prefetch"
            ' Kept in the Task; the UI only needs to know it is ready.
            StorePrefetched(cacheKey, result)
            return {ok: true}
        end if
        return result
    else if action = "children"
        if request.kind = "Series"
            path = "/Shows/" + Encode(request.itemId) + "/Seasons?UserId=" + uid + fields
        else
            path = "/Shows/" + Encode(request.seriesId) + "/Episodes?UserId=" + uid + "&SeasonId=" + Encode(request.itemId) + fields
        end if
        response = Api(path)
        if not response.ok then return response
        return {ok: true, content: BuildRows([{title: request.title, items: ItemArray(response.data)}]), title: request.title}
    else if action = "play"
        m.detailsCache = {}
        return PreparePlayback(request)
    else if action = "report"
        ' Progress just changed; a prefetched page would show the old position.
        if request.event = "stopped" then m.detailsCache = {}
        path = "/Sessions/Playing"
        if request.event = "progress" then path += "/Progress"
        if request.event = "stopped" then path += "/Stopped"
        response = Api(path, "POST", request.body)
        return response
    end if
    return Failure("Solicitação desconhecida.")
end function

'' Apple's "Top Results" order: shows and movies first, then episodes, paged as
' one list of 48. Two requests per page keep the combined total exact.
function SearchItems(query as String, offset as Integer, uid as String, fields as String) as Object
    base = "/Items?UserId=" + uid + "&Recursive=true&SearchTerm=" + Encode(query) + fields
    titlesPath = base + "&IncludeItemTypes=Movie,Series&Limit=48&StartIndex=" + Encode(offset)
    ' The first page (nearly every search) needs no title count to place its
    ' episodes, so both lists go out together.
    if offset = 0
        responses = ApiAll([titlesPath, base + "&IncludeItemTypes=Episode&Limit=48&StartIndex=0"])
        if not responses[0].ok then return responses[0]
        if not responses[1].ok then return responses[1]
        items = []
        for each item in ItemArray(responses[0].data)
            items.Push(item)
        end for
        for each item in ItemArray(responses[1].data)
            if items.Count() < 48 then items.Push(item)
        end for
        return {ok: true, items: items, total: RecordTotal(responses[0].data) + RecordTotal(responses[1].data)}
    end if
    titles = Api(titlesPath)
    if not titles.ok then return titles
    titleTotal = RecordTotal(titles.data)
    items = []
    for each item in ItemArray(titles.data)
        items.Push(item)
    end for
    episodeOffset = offset - titleTotal
    if episodeOffset < 0 then episodeOffset = 0
    episodeLimit = 48 - items.Count()
    episodes = Api(base + "&IncludeItemTypes=Episode&Limit=" + episodeLimit.ToStr() + "&StartIndex=" + episodeOffset.ToStr())
    if not episodes.ok then return episodes
    if episodeLimit > 0
        for each item in ItemArray(episodes.data)
            if items.Count() < 48 then items.Push(item)
        end for
    end if
    return {ok: true, items: items, total: titleTotal + RecordTotal(episodes.data)}
end function

' A show's poster follows its newest season (e.g. Season 2's key art once it is
' in the library). One library-wide season query, cached for ten minutes.
function SeasonPostersFresh() as Boolean
    if m.seasonPosterClock = invalid or not IsMap(m.seasonPosters) then return false
    return m.seasonPosterClock.TotalMilliseconds() < 600000
end function

function SeasonPostersPath() as String
    return "/Items?UserId=" + Encode(m.account.userId) + "&IncludeItemTypes=Season&Recursive=true&Limit=2000&EnableUserData=false"
end function

sub StoreSeasonPosters(response as Object)
    if not response.ok then return
    m.seasonPosters = LatestSeasonPosters(ItemArray(response.data))
    m.seasonPosterClock = CreateObject("roTimespan")
end sub

' Only a newer season's art replaces the show poster: the newest season must be
' season 2 or later and have its own poster. Otherwise the show's poster stays.
function LatestSeasonPosters(seasons as Object) as Object
    newest = {}
    for each season in seasons
        if IsMap(season)
            seriesId = TextValue(season.SeriesId)
            number = season.IndexNumber
            if seriesId <> "" and number <> invalid
                hasPoster = false
                if IsMap(season.ImageTags) then hasPoster = TextValue(season.ImageTags.Primary) <> ""
                current = newest[seriesId]
                if current = invalid
                    newest[seriesId] = {id: TextValue(season.Id), number: number, poster: hasPoster}
                else if number > current.number
                    newest[seriesId] = {id: TextValue(season.Id), number: number, poster: hasPoster}
                end if
            end if
        end if
    end for
    posters = {}
    for each seriesId in newest
        season = newest[seriesId]
        if season.poster and season.number > 1 then posters[seriesId] = season
    end for
    return posters
end function

function PosterUrl(item as Object) as String
    if item.Type = "Series" and IsMap(m.seasonPosters)
        season = m.seasonPosters[TextValue(item.Id)]
        if IsMap(season) then return m.account.base + "/Items/" + Encode(season.id) + "/Images/Primary?maxWidth=240&quality=85"
    end if
    ' Library posters show at 200 px (214 when focused).
    return ImageUrl(item, false, "240")
end function

function AmbientMeta(item as Object) as String
    parts = []
    if item.Type = "Movie" then parts.Push("Filme")
    if item.Type = "Series" then parts.Push("Série")
    if TextValue(item.ProductionYear) <> "" then parts.Push(TextValue(item.ProductionYear))
    if IsList(item.Genres)
        for each genre in item.Genres
            if parts.Count() < 4 then parts.Push(TextValue(genre))
        end for
    end if
    label = ""
    for each part in parts
        if label <> "" then label += " · "
        label += part
    end for
    return label
end function

function RecordTotal(data as Dynamic) as Integer
    if IsMap(data)
        if data.TotalRecordCount <> invalid then return data.TotalRecordCount
    end if
    return ItemArray(data).Count()
end function

' Apple TV's show page: one row per season beneath the hero and a Play action
' for the next episode. A failed episode lookup leaves a plain details page.
' At most four pages, each used once and only within 45 s of being fetched.
sub StorePrefetched(itemId as String, result as Object)
    if itemId = "" or not result.ok then return
    if not IsMap(m.detailsCache) then m.detailsCache = {}
    if m.detailsCache.Count() >= 4 then m.detailsCache = {}
    m.detailsCache[itemId] = {result: result, clock: CreateObject("roTimespan")}
end sub

function HasPrefetched(itemId as String) as Boolean
    if not IsMap(m.detailsCache) or itemId = "" then return false
    entry = m.detailsCache[itemId]
    if not IsMap(entry) then return false
    return entry.clock.TotalMilliseconds() <= 45000
end function

function TakePrefetched(itemId as String) as Dynamic
    if not IsMap(m.detailsCache) or itemId = "" then return invalid
    entry = m.detailsCache[itemId]
    if not IsMap(entry) then return invalid
    m.detailsCache.Delete(itemId)
    if entry.clock.TotalMilliseconds() > 45000 then return invalid
    return entry.result
end function

function SimilarPath(itemId as String) as String
    return "/Items/" + Encode(itemId) + "/Similar?UserId=" + Encode(m.account.userId) + "&Limit=12&Fields=Overview,PrimaryImageAspectRatio,Genres&EnableUserData=true"
end function

' Apple's details pages end with "Cast & Crew" and "More Like This".
sub AddExtras(result as Object, item as Object, similar as Dynamic)
    kind = TextValue(item.Type)
    if kind <> "Movie" and kind <> "Series" and kind <> "Episode" then return
    root = result.content
    if root = invalid then root = CreateObject("roSGNode", "ContentNode")
    people = PeopleRow(item.People)
    if people <> invalid then root.AppendChild(people)
    if kind <> "Episode"
        if not IsMap(similar) then similar = Api(SimilarPath(TextValue(item.Id)))
        if similar.ok
            items = ItemArray(similar.data)
            if items.Count() > 0
                row = root.CreateChild("ContentNode")
                row.title = "Mais como este"
                for each similarItem in items
                    if IsMap(similarItem) then row.AppendChild(MakeCard(similarItem))
                end for
            end if
        end if
    end if
    if root.GetChildCount() > 0 then result.content = root
end sub

function PeopleRow(people as Dynamic) as Dynamic
    if not IsList(people) then return invalid
    row = CreateObject("roSGNode", "ContentNode")
    row.title = "Elenco e equipe"
    row.AddFields({rowStyle: "person"})
    roles = {Director: "Direção", Writer: "Roteiro", Producer: "Produção", Composer: "Música", GuestStar: "Participação"}
    seen = {}
    for each person in people
        id = TextValue(person.Id)
        if id <> "" and not seen.DoesExist(id) and row.GetChildCount() < 20
            seen[id] = true
            card = row.CreateChild("ContentNode")
            card.id = id
            card.title = TextValue(person.Name)
            role = TextValue(person.Role)
            if role = "" or person.Type <> "Actor" then role = TextValue(roles[TextValue(person.Type)], role)
            photo = ""
            if TextValue(person.PrimaryImageTag) <> "" then photo = m.account.base + "/Items/" + Encode(id) + "/Images/Primary?maxWidth=200&quality=85"
            card.HDPosterUrl = photo
            card.AddFields({kind: "Person", caption: role, person: true, placeholder: PlaceholderColor(person, false), progress: 0.0})
        end if
    end for
    if row.GetChildCount() = 0 then return invalid
    return row
end function

' A person's page lists their titles in this library, newest first, over the
' backdrop of the first one.
sub AddPersonTitles(result as Object, personId as String, uid as String, fields as String)
    response = Api("/Items?UserId=" + uid + "&PersonIds=" + Encode(personId) + "&Recursive=true&IncludeItemTypes=Movie,Series&SortBy=ProductionYear,SortName&SortOrder=Descending,Ascending&Limit=60" + fields)
    if not response.ok then return
    items = ItemArray(response.data)
    if items.Count() = 0 then return
    result.content = BuildRows([{title: "Na sua biblioteca", items: items}])
    result.card.backdrop = ImageUrl(items[0], true)
    result.card.kind = "Person"
end sub

' A collection's page lists its titles in release order.
sub AddCollectionTitles(result as Object, collectionId as String, uid as String, fields as String)
    response = Api("/Items?UserId=" + uid + "&ParentId=" + Encode(collectionId) + "&SortBy=ProductionYear,SortName&SortOrder=Ascending" + fields)
    if not response.ok then return
    items = ItemArray(response.data)
    if items.Count() > 0 then result.content = BuildRows([{title: "Nesta coleção", items: items}])
end sub

' "recent" by default: shows sort by their newest episode, so a just-released
' season comes first.
function LibraryOrder(request as Object) as String
    sort = TextValue(request.sort)
    if sort = "name" then return "&SortBy=SortName&SortOrder=Ascending"
    if sort = "year" then return "&SortBy=PremiereDate,ProductionYear,SortName&SortOrder=Descending,Descending,Ascending"
    if request.kind = "Series" then return "&SortBy=DateLastContentAdded,SortName&SortOrder=Descending,Ascending"
    return "&SortBy=DateCreated,SortName&SortOrder=Descending,Ascending"
end function

function SeriesPaths(seriesId as String) as Object
    uid = Encode(m.account.userId)
    series = Encode(seriesId)
    ' Rail cards never read chapters (playing one fetches its full item); only
    ' next-up, which the hero plays directly, needs them.
    return [
        "/Shows/" + series + "/Episodes?UserId=" + uid + "&Limit=600&Fields=Overview,PrimaryImageAspectRatio&EnableUserData=true"
        "/Shows/NextUp?UserId=" + uid + "&SeriesId=" + series + "&Limit=1&EnableResumable=true&Fields=Overview,PrimaryImageAspectRatio,Chapters&EnableUserData=true"
    ]
end function

' The episode list and next-up are fetched together, or come prefetched with
' the show itself when the card already said it was a show.
sub AddSeriesEpisodes(result as Object, seriesId as String, prefetched = invalid as Dynamic)
    responses = prefetched
    if not IsList(responses) then responses = ApiAll(SeriesPaths(seriesId))
    response = responses[0]
    if not response.ok then return
    episodes = ItemArray(response.data)
    if episodes.Count() = 0 then return
    rows = []
    current = invalid
    for each episode in episodes
        if IsMap(episode)
            season = TextValue(episode.ParentIndexNumber, "0")
            if current = invalid or current.season <> season
                title = "Temporada " + season
                if season = "0" then title = "Especiais"
                current = {season: season, title: title, items: []}
                rows.Push(current)
            end if
            current.items.Push(episode)
        end if
    end for
    content = BuildRows(rows)
    for each row in content.GetChildren(-1, 0)
        for each card in row.GetChildren(-1, 0)
            number = TextValue(card.raw.IndexNumber)
            if number <> "" then card.title = number + ". " + card.title
            ' Every tile in a show's rail would repeat the same logo.
            card.caption = card.title
            card.AddFields({plainTile: true})
        end for
    end for
    result.content = content
    nextUp = invalid
    response = responses[1]
    if response.ok
        items = ItemArray(response.data)
        if items.Count() > 0 then nextUp = items[0]
    end if
    if not IsMap(nextUp)
        nextUp = episodes[0]
        full = Api("/Items/" + Encode(TextValue(nextUp.Id)) + "?UserId=" + Encode(m.account.userId))
        if full.ok and IsMap(full.data) then nextUp = full.data
    end if
    result.nextUp = nextUp
    ' Entering the rails lands on the next episode, as on Apple TV.
    rowIndex = 0
    for each row in content.GetChildren(-1, 0)
        itemIndex = 0
        for each card in row.GetChildren(-1, 0)
            if card.id = TextValue(nextUp.Id) then result.nextUpLocation = [rowIndex, itemIndex]
            itemIndex++
        end for
        rowIndex++
    end for
end sub

function ImageUrl(item as Object, backdrop = false as Boolean, maxWidth = "" as String) as String
    id = TextValue(item.Id)
    imageType = "Primary"
    if backdrop
        hasBackdrop = false
        if IsList(item.BackdropImageTags) then hasBackdrop = item.BackdropImageTags.Count() > 0
        if hasBackdrop
            imageType = "Backdrop/0"
        else if TextValue(item.ParentBackdropItemId) <> ""
            id = item.ParentBackdropItemId
            imageType = "Backdrop/0"
        end if
    end if
    if imageType = "Primary"
        hasImage = false
        if IsMap(item.ImageTags) then hasImage = TextValue(item.ImageTags.Primary) <> ""
        if not hasImage then id = TextValue(item.SeriesId, id)
    end if
    width = "440"
    if backdrop then width = "1920"
    if maxWidth <> "" then width = maxWidth
    ' Jellyfin serves images anonymously: artwork never carries the token, so
    ' it can be shown (even from cache) without exposing the login.
    return m.account.base + "/Items/" + Encode(id) + "/Images/" + imageType + "?maxWidth=" + width + "&quality=85"
end function

function LogoUrl(item as Object, maxWidth = "1000" as String) as String
    id = ""
    if IsMap(item.ImageTags)
        if TextValue(item.ImageTags.Logo) <> "" then id = TextValue(item.Id)
    end if
    if id = "" then id = TextValue(item.ParentLogoItemId)
    if id = "" then return ""
    return m.account.base + "/Items/" + Encode(id) + "/Images/Logo?maxWidth=" + maxWidth + "&quality=95"
end function

function RuntimeLabel(ticks as Dynamic) as String
    if ticks = invalid then return ""
    minutes = Int(ticks / 600000000#)
    if minutes < 1 then return ""
    if minutes < 60 then return minutes.ToStr() + " min"
    label = Int(minutes / 60).ToStr() + " h"
    if minutes mod 60 > 0 then label += " " + (minutes mod 60).ToStr() + " min"
    return label
end function

' Cards cross from this Task to the render thread by copy; they carry only the
' fields the hero line, tile titles and episode rails read (~90% smaller on Home).
function CardFields(item as Object) as Object
    fields = {}
    for each key in ["Id", "Type", "Name", "SeriesName", "SeriesId", "ParentIndexNumber", "IndexNumber", "ProductionYear", "OfficialRating"]
        if item[key] <> invalid then fields[key] = item[key]
    end for
    if IsList(item.Genres) then fields.Genres = item.Genres
    return fields
end function

function MakeCard(item as Object) as Object
    node = CreateObject("roSGNode", "ContentNode")
    node.id = TextValue(item.Id)
    node.title = TextValue(item.Name, "Sem título")
    node.description = TextValue(item.Overview)
    ' Tiles show at 340 px (364 when focused) on the 1080p interface plane.
    node.HDPosterUrl = ImageUrl(item, item.Type <> "Episode", "400")
    ' Apple's metadata line: year · runtime · rating, with tight separators.
    parts = []
    if TextValue(item.ProductionYear) <> "" then parts.Push(TextValue(item.ProductionYear))
    if item.Type <> "Series" then parts.Push(RuntimeLabel(item.RunTimeTicks))
    if TextValue(item.OfficialRating) <> "" then parts.Push(item.OfficialRating)
    if item.Type = "Episode" then parts = [TextValue(item.SeriesName), "T" + TextValue(item.ParentIndexNumber) + ", E" + TextValue(item.IndexNumber), RuntimeLabel(item.RunTimeTicks)]
    meta = ""
    for each part in parts
        if part <> ""
            if meta <> "" then meta += " · "
            meta += part
        end if
    end for
    ' Tiles carry the title art like Apple TV's; a small logo keeps rows light.
    caption = node.title
    if item.Type = "Episode" then caption = "T" + TextValue(item.ParentIndexNumber) + ", E" + TextValue(item.IndexNumber) + " · " + node.title
    played = false
    unplayed = 0
    if IsMap(item.UserData)
        played = item.UserData.Played = true
        if item.UserData.UnplayedItemCount <> invalid then unplayed = item.UserData.UnplayedItemCount
    end if
    node.AddFields({logo: LogoUrl(item), tileLogo: LogoUrl(item, "360"), caption: caption, kind: TextValue(item.Type), backdrop: ImageUrl(item, true), meta: meta, raw: CardFields(item), progress: 0.0, placeholder: PlaceholderColor(item, item.Type <> "Episode"), played: played, unplayed: unplayed})
    if item.RunTimeTicks <> invalid
        if item.RunTimeTicks > 0 then node.progress = ResumeTicks(item) / item.RunTimeTicks
    end if
    return node
end function

' A blurhash starts with the image's average colour, so a tile can show that
' colour while its artwork loads instead of a grey block.
function PlaceholderColor(item as Object, backdrop as Boolean) as String
    if not IsMap(item.ImageBlurHashes) then return ""
    kinds = ["Primary"]
    if backdrop then kinds = ["Backdrop", "Thumb", "Primary"]
    for each kind in kinds
        hashes = item.ImageBlurHashes[kind]
        if IsMap(hashes)
            for each tag in hashes
                color = BlurHashColor(TextValue(hashes[tag]))
                if color <> "" then return color
            end for
        end if
    end for
    return ""
end function

function BlurHashColor(hash as String) as String
    if Len(hash) < 6 then return ""
    alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~"
    value = 0
    for index = 3 to 6
        digit = Instr(1, alphabet, Mid(hash, index, 1)) - 1
        if digit < 0 then return ""
        value = value * 83 + digit
    end for
    hex = "0123456789abcdef"
    color = "0x"
    for each divisor in [65536, 256, 1]
        channel = Int(value / divisor) mod 256
        color += Mid(hex, Int(channel / 16) + 1, 1) + Mid(hex, (channel mod 16) + 1, 1)
    end for
    return color + "ff"
end function

function BuildLibraryRows(items as Object) as Object
    root = CreateObject("roSGNode", "ContentNode")
    row = invalid
    index = 0
    for each item in items
        if index mod 6 = 0 then row = root.CreateChild("ContentNode")
        card = MakeCard(item)
        card.AddFields({portrait: true})
        card.HDPosterUrl = PosterUrl(item)
        card.placeholder = PlaceholderColor(item, false)
        row.AppendChild(card)
        index++
    end for
    return root
end function

function BuildRows(rows as Object) as Object
    root = CreateObject("roSGNode", "ContentNode")
    for each row in rows
        if row.items.Count() > 0
            shelf = root.CreateChild("ContentNode")
            shelf.title = row.title
            for each item in row.items
                if IsMap(item) then shelf.AppendChild(MakeCard(item))
            end for
        end if
    end for
    return root
end function

function RokuProfile() as Object
    ' Conservative SDR fallback. Safe source video can survive container/audio
    ' conversion; HEVC is added only after positive device capability checks.
    return {
        Name: "Luma Roku G510X"
        MaxStreamingBitrate: 20000000
        MaxStaticBitrate: 20000000
        DirectPlayProfiles: [{Container: "mp4,m4v,mov,mkv", Type: "Video", VideoCodec: "h264", AudioCodec: "aac,mp3"}]
        TranscodingProfiles: [{Container: "ts", Type: "Video", VideoCodec: "h264", AudioCodec: "aac", Protocol: "hls", Context: "Streaming", MaxAudioChannels: "2", MinSegments: 2, BreakOnNonKeyFrames: false}]
        CodecProfiles: [
            {Type: "Video", Codec: "h264", Conditions: [
                {Condition: "LessThanEqual", Property: "VideoLevel", Value: "41", IsRequired: true}
                {Condition: "LessThanEqual", Property: "Width", Value: "1920", IsRequired: true}
                {Condition: "LessThanEqual", Property: "Height", Value: "1080", IsRequired: true}
                {Condition: "LessThanEqual", Property: "VideoBitDepth", Value: "8", IsRequired: true}
                {Condition: "EqualsAny", Property: "VideoProfile", Value: "baseline|constrained baseline|main|high", IsRequired: true}
                {Condition: "LessThanEqual", Property: "VideoFramerate", Value: "60", IsRequired: true}
                {Condition: "LessThanEqual", Property: "VideoBitrate", Value: "20000000", IsRequired: true}
                {Condition: "Equals", Property: "VideoRangeType", Value: "SDR", IsRequired: true}
            ]}
            {Type: "VideoAudio", Codec: "aac,mp3", Conditions: [{Condition: "LessThanEqual", Property: "AudioChannels", Value: "2", IsRequired: true}]}
        ]
        SubtitleProfiles: [{Format: "srt,ass,ssa,sub,pgssub,dvdsub", Method: "Encode"}]
    }
end function

function OriginalVideoCapabilities() as Object
    device = CreateObject("roDeviceInfo")
    supported = {hevc4k: false, hevcMain10: false, hdr10: false}
    if Left(device.GetVideoMode(), 5) <> "2160p" then return supported
    if device.GetModelType() <> "TV"
        hdmi = CreateObject("roHdmiStatus")
        if not hdmi.IsHdcpActive("2.2") then return supported
    end if
    main = device.CanDecodeVideo({codec: "hevc", profile: "main", level: "5.1"})
    supported.hevc4k = main.result = true
    if supported.hevc4k
        main10 = device.CanDecodeVideo({codec: "hevc", profile: "main 10", level: "5.1"})
        supported.hevcMain10 = main10.result = true
        if supported.hevcMain10
            display = device.GetDisplayProperties()
            if IsMap(display) then supported.hdr10 = display.hdr10 = true
        end if
    end if
    return supported
end function

' Dolby Digital (Plus) that this TV decodes itself is kept as recorded instead
' of being re-encoded to stereo AAC: no lossy generation, and 5.1 still reaches
' a soundbar. Only Roku's positive runtime answer adds a codec.
function AudioCapabilities() as Object
    device = CreateObject("roDeviceInfo")
    supported = {ac3: false, eac3: false}
    for each codec in ["ac3", "eac3"]
        answer = device.CanDecodeAudio({Codec: codec, ChCnt: 6})
        if IsMap(answer) then supported[codec] = answer.result = true
    end for
    return supported
end function

sub AddAudioCapabilities(profile as Object, audio as Object)
    codecs = ""
    if audio.ac3 = true then codecs = "ac3"
    if audio.eac3 = true
        if codecs <> "" then codecs += ","
        codecs += "eac3"
    end if
    if codecs = "" then return
    for each direct in profile.DirectPlayProfiles
        direct.AudioCodec = direct.AudioCodec + "," + codecs
    end for
    ' AAC stays first, so anything that must be converted still becomes stereo
    ' AAC under its own channel limit; Dolby can now be copied with its 5.1.
    for each transcode in profile.TranscodingProfiles
        transcode.AudioCodec = transcode.AudioCodec + "," + codecs
        transcode.MaxAudioChannels = "6"
    end for
    profile.CodecProfiles.Push({Type: "VideoAudio", Codec: codecs, Conditions: [{Condition: "LessThanEqual", Property: "AudioChannels", Value: "6", IsRequired: true}]})
end sub

sub AddOriginalCapabilities(profile as Object, capabilities as Object)
    if not capabilities.hevc4k then return
    bitDepth = "8"
    if capabilities.hevcMain10 then bitDepth = "10"
    profile.DirectPlayProfiles.Push({Container: "mp4,m4v,mov,mkv", Type: "Video", VideoCodec: "hevc", AudioCodec: "aac,mp3"})
    hevcProfiles = "main"
    if capabilities.hevcMain10 then hevcProfiles += "|main 10"
    videoRanges = "SDR"
    rangeCondition = "Equals"
    if capabilities.hevcMain10 = true and capabilities.hdr10 = true
        videoRanges = "SDR|HDR10"
        rangeCondition = "EqualsAny"
    end if
    profile.CodecProfiles.Push({Type: "Video", Codec: "hevc", Conditions: [
        {Condition: "LessThanEqual", Property: "Width", Value: "3840", IsRequired: true}
        {Condition: "LessThanEqual", Property: "Height", Value: "2160", IsRequired: true}
        {Condition: "LessThanEqual", Property: "VideoLevel", Value: "153", IsRequired: true}
        {Condition: "LessThanEqual", Property: "VideoBitDepth", Value: bitDepth, IsRequired: true}
        {Condition: "LessThanEqual", Property: "VideoBitrate", Value: "25000000", IsRequired: true}
        {Condition: rangeCondition, Property: "VideoRangeType", Value: videoRanges, IsRequired: true}
        {Condition: "EqualsAny", Property: "VideoProfile", Value: hevcProfiles, IsRequired: true}
        {Condition: "LessThanEqual", Property: "VideoFramerate", Value: "60", IsRequired: true}
    ]})
end sub

function PlaybackQualities() as Object
    return [
        {id: "auto", label: "Automática · melhor qualidade compatível", maxHeight: 1080, maxWidth: 1920, maxBitrate: 20000000}
        {id: "maximum", label: "Máxima · 4K/HDR compatível", maxHeight: 1080, maxWidth: 1920, maxBitrate: 20000000}
        {id: "original", label: "Original · reprodução direta", maxHeight: 1080, maxWidth: 1920, maxBitrate: 100000000}
        {id: "1080p", label: "1080p · 12 Mbps", maxHeight: 1080, maxWidth: 1920, maxBitrate: 12000000}
        {id: "720p", label: "720p · 6 Mbps", maxHeight: 720, maxWidth: 1280, maxBitrate: 6000000}
        {id: "480p", label: "480p · 2,5 Mbps", maxHeight: 480, maxWidth: 854, maxBitrate: 2500000}
        {id: "360p", label: "360p · 1 Mbps", maxHeight: 360, maxWidth: 640, maxBitrate: 1000000}
    ]
end function

function TrackLabel(stream as Object) as String
    ' Preserve server-authored names; localize only our fallback and markers.
    label = TextValue(stream.DisplayTitle)
    if label = "" then label = TextValue(stream.Title)
    if label = "" then label = TextValue(stream.Language)
    if label = ""
        kind = "Faixa"
        if stream.Type = "Audio" then kind = "Áudio"
        if stream.Type = "Subtitle" then kind = "Legenda"
        label = kind + " " + TextValue(stream.Index)
    end if
    if stream.IsForced = true and Instr(1, LCase(label), "forced") = 0 and Instr(1, LCase(label), "forçada") = 0 then label += " · Forçada"
    return label
end function

function IsNativeSubtitle(stream as Dynamic) as Boolean
    if not IsMap(stream) then return false
    if stream.Type <> "Subtitle" or stream.IsExternal <> true then return false
    if stream.Index = invalid then return false
    if stream.Index < 0 then return false
    codec = LCase(TextValue(stream.Codec))
    return codec = "srt" or codec = "subrip"
end function

function RokuSubtitleLanguage(language as String) as String
    code = LCase(language).Split("-")[0]
    codes = {pt: "por", en: "eng", es: "spa", fr: "fre", fra: "fre", de: "ger", deu: "ger", it: "ita", ja: "jpn", ko: "kor", zh: "chi", zho: "chi", ru: "rus", ar: "ara"}
    if codes.DoesExist(code) then return codes[code]
    if Len(code) = 3 then return code
    return "und"
end function

function NativeSubtitleTracks(itemId as String, source as Object) as Object
    tracks = []
    if not IsList(source.MediaStreams) then return tracks
    for each stream in source.MediaStreams
        if IsNativeSubtitle(stream)
            ' Never trust DeliveryUrl with the account token. This endpoint is
            ' bound to the verified server, chosen item and validated version.
            url = m.account.base + "/Videos/" + Encode(itemId) + "/" + Encode(source.Id) + "/Subtitles/" + Encode(stream.Index) + "/Stream.srt?StartPositionTicks=0&CopyTimestamps=true&api_key=" + Encode(m.account.token)
            tracks.Push({index: stream.Index, trackName: url, language: TextValue(stream.Language), label: TrackLabel(stream)})
        end if
    end for
    return tracks
end function

function FindMediaStream(source as Object, kind as String, index as Dynamic) as Dynamic
    if not IsList(source.MediaStreams) then return invalid
    for each stream in source.MediaStreams
        if stream.Type = kind and stream.Index = index then return stream
    end for
    return invalid
end function

function PlaybackChoices(sources as Object, source as Object, selection as Object) as Object
    options = {audioTracks: [], subtitleTracks: [], mediaSources: [], qualityOptions: PlaybackQualities(), selection: selection}
    for each version in sources
        label = TextValue(version.Name, "Versão " + (options.mediaSources.Count() + 1).ToStr())
        options.mediaSources.Push({id: version.Id, label: label})
    end for
    if IsList(source.MediaStreams)
        for each stream in source.MediaStreams
            if stream.Type = "Audio" or stream.Type = "Subtitle"
                track = {index: stream.Index, label: TrackLabel(stream), title: TextValue(stream.Title), language: TextValue(stream.Language), codec: TextValue(stream.Codec), isDefault: stream.IsDefault = true, isForced: stream.IsForced = true, isExternal: stream.IsExternal = true}
                if stream.Type = "Audio"
                    options.audioTracks.Push(track)
                else
                    options.subtitleTracks.Push(track)
                end if
            end if
        end for
    end if
    return options
end function


' Keep one short-lived catalog, never URLs/sessions. Every play still negotiates
' with Jellyfin and Dispatch still verifies server identity before any token.
function PlaybackCatalog(itemId as String) as Object
    cached = m.playbackCatalog
    if IsMap(cached)
        if cached.itemId = itemId and cached.serverId = m.account.id and cached.base = m.account.base and cached.userId = m.account.userId and cached.token = m.account.token
            if cached.clock.TotalMilliseconds() < 30000 then return {ok: true, data: cached.data}
        end if
    end if
    m.playbackCatalog = invalid
    response = Api(PlaybackCatalogPath(itemId))
    CachePlaybackCatalog(itemId, response)
    return response
end function

function PlaybackCatalogPath(itemId as String) as String
    return "/Items/" + Encode(itemId) + "/PlaybackInfo?UserId=" + Encode(m.account.userId)
end function

sub CachePlaybackCatalog(itemId as String, response as Object)
    if not response.ok then return
    if not IsMap(response.data) then return
    if not IsList(response.data.MediaSources) then return
    for each source in response.data.MediaSources
        if source.IsInfiniteStream = true or source.RequiresOpening = true or TextValue(source.LiveStreamId) <> "" then return
    end for
    m.playbackCatalog = {itemId: itemId, serverId: m.account.id, base: m.account.base, userId: m.account.userId, token: m.account.token, data: response.data, clock: CreateObject("roTimespan")}
end sub

' A separate HEVC copy profile avoids Jellyfin merging H264's 1080p limits
' into the HEVC output. Unknown source metadata never enters this path.
function HevcCopySource(source as Object, capabilities as Object, maximum = false as Boolean) as Dynamic
    ceiling = 25000000
    if maximum
        if capabilities.hevcMain10 <> true or capabilities.hdr10 <> true then return invalid
        ceiling = 65000000
    end if
    if capabilities.hevc4k <> true then return invalid
    if source.RequiresOpening = true or source.IsInfiniteStream = true then return invalid
    if not IsList(source.MediaStreams) then return invalid
    if source.Bitrate = invalid then return invalid
    if source.Bitrate <= 0 or source.Bitrate > ceiling then return invalid
    video = invalid
    for each stream in source.MediaStreams
        if stream.Type = "Video"
            if video <> invalid then return invalid
            video = stream
        end if
    end for
    if video = invalid then return invalid
    if LCase(TextValue(video.Codec)) <> "hevc" then return invalid
    for each field in ["Width", "Height", "Level", "BitDepth", "BitRate"]
        if video[field] = invalid then return invalid
        if video[field] <= 0 then return invalid
    end for
    if video.Width > 3840 or video.Height > 2160 or video.Level > 153 or video.BitRate > ceiling then return invalid
    if video.IsInterlaced = true then return invalid
    fps = video.AverageFrameRate
    if fps = invalid then fps = video.RealFrameRate
    if fps = invalid then return invalid
    if fps <= 0 or fps > 60 then return invalid
    profile = LCase(TextValue(video.Profile))
    if profile = "main"
        if video.BitDepth > 8 then return invalid
    else if profile = "main 10"
        if capabilities.hevcMain10 <> true or video.BitDepth > 10 then return invalid
    else
        return invalid
    end if
    range = TextValue(video.VideoRangeType)
    hdr10Base = false
    if maximum and range = "DOVIWithEL"
        if video.DvProfile <> 7 or video.DvBlSignalCompatibilityId <> 6 or video.BlPresentFlag <> 1 then return invalid
        if TextValue(video.ColorTransfer) <> "smpte2084" or TextValue(video.ColorPrimaries) <> "bt2020" or TextValue(video.ColorSpace) <> "bt2020nc" then return invalid
        hdr10Base = true
        range = "HDR10"
    end if
    if range <> "SDR"
        if range <> "HDR10" or capabilities.hdr10 <> true or capabilities.hevcMain10 <> true then return invalid
        if profile <> "main 10" or video.BitDepth <> 10 then return invalid
    end if
    return {width: video.Width, height: video.Height, bitrate: video.BitRate, fps: fps, level: video.Level, bitdepth: video.BitDepth, profile: profile, range: range, hdr10Base: hdr10Base, maximum: maximum}
end function

' Inspect controls without rewriting the server URL. Duplicate/encoded keys
' fail closed so no second spelling can override the validated copy contract.
function HevcCopyUrlSafe(url as String, video as Object) as Boolean
    queryStart = Instr(1, url, "?")
    if queryStart = 0 then return false
    values = {}
    for each part in Mid(url, queryStart + 1).Split("&")
        equals = Instr(1, part, "=")
        if equals > 0
            key = LCase(Left(part, equals - 1))
            if Instr(1, key, "%") > 0 or values.DoesExist(key) then return false
            values[key] = LCase(Mid(part, equals + 1))
        end if
    end for
    if TextValue(values.videocodec) <> "hevc" then return false
    for each key in ["allowvideostreamcopy", "enableautostreamcopy"]
        if values[key] <> invalid
            if values[key] <> "true" then return false
        end if
    end for
    for each check in [{key: "maxwidth", required: video.width}, {key: "maxheight", required: video.height}, {key: "videobitrate", required: video.bitrate}, {key: "maxframerate", required: video.fps}]
        if values[check.key] <> invalid
            if Val(values[check.key]) < check.required then return false
        end if
    end for
    for each check in [{key: "hevc-level", required: video.level}, {key: "level", required: video.level}, {key: "hevc-videobitdepth", required: video.bitdepth}, {key: "maxvideobitdepth", required: video.bitdepth}]
        if values[check.key] <> invalid
            if check.required = invalid then return false
            if not CreateObject("roRegex", "^[0-9]+([.][0-9]+)?$", "").IsMatch(values[check.key]) then return false
            if Val(values[check.key]) < check.required then return false
        end if
    end for
    for each key in ["hevc-profile", "profile"]
        if values[key] <> invalid
            if video.profile = invalid then return false
            profiles = values[key].Replace("%20", "").Replace(" ", "").Replace("%2c", ",").Replace("%7c", ",").Replace("|", ",")
            wanted = LCase(video.profile).Replace(" ", "")
            if Instr(1, "," + profiles + ",", "," + wanted + ",") = 0 then return false
        end if
    end for
    if values.width <> invalid or values.height <> invalid or values.framerate <> invalid then return false
    if video.maximum = true
        for each required in ["videobitrate", "maxwidth", "maxheight"]
            if TextValue(values[required]) = "" then return false
        end for
        if TextValue(values.segmentlength) <> "3" then return false
        ranges = TextValue(values["hevc-rangetype"]).Replace("%2c", ",").Replace("%7c", ",").Replace("|", ",")
        if ranges <> "sdr,hdr10" then return false
    end if
    reasons = TextValue(values.transcodereasons)
    if reasons = "" then return false
    allowed = ",directplayerror,audiocodecnotsupported,audiochannelsnotsupported,audiobitratenotsupported,audioprofilenotsupported,audiosampleratenotsupported,audiobitdepthnotsupported,audioisexternal,secondaryaudionotsupported,containernotsupported,"
    if video.hdr10Base = true then allowed += "videorangetypenotsupported,"
    for each reason in reasons.Split(",")
        if Instr(1, allowed, "," + reason + ",") = 0 then return false
    end for
    return true
end function

function RetryHevcAsH264(request as Object, selection as Object) as Object
    if TextValue(request.quality) = "maximum" then return Failure("Não foi possível preservar a qualidade Máxima. Escolha Tentar compatível para converter o vídeo.")
    retry = {}
    for each key in request
        retry[key] = request[key]
    end for
    retry.mediaSourceId = selection.mediaSourceId
    retry.audioStreamIndex = selection.audioStreamIndex
    retry.subtitleStreamIndex = selection.subtitleStreamIndex
    retry.forceTranscode = true
    return PreparePlayback(retry)
end function

' Firmware and simulators box JSON numbers under different names.
function NumericTypes() as Object
    return {Integer: true, roInt: true, roInteger: true, LongInteger: true, roLongInteger: true, Float: true, roFloat: true, Double: true, roDouble: true}
end function

' Val() rejects numbers on Roku, so only strings are parsed.
function SegmentSeconds(value as Dynamic, ticks as Boolean) as Dynamic
    if value = invalid then return invalid
    kind = Type(value)
    if kind = "String" or kind = "roString"
        number = Val(value)
    else if NumericTypes().DoesExist(kind)
        number = value * 1#
    else
        return invalid
    end if
    if ticks then return number / 10000000#
    return number
end function

function SegmentValue(data as Object, names as Object) as Object
    for each name in names
        if data[name] <> invalid then return {value: data[name], ticks: Instr(1, LCase(name), "tick") > 0 or Instr(1, LCase(name), "position") > 0}
    end for
    return invalid
end function

sub AddPlaybackSegment(output as Object, kind as String, startValue as Dynamic, endValue as Dynamic, areTicks as Boolean)
    allowed = ["Intro", "Outro", "Recap", "Preview"]
    normalized = ""
    for each candidate in allowed
        if LCase(kind) = LCase(candidate) then normalized = candidate
    end for
    if normalized = "" then return
    start = SegmentSeconds(startValue, areTicks)
    finish = SegmentSeconds(endValue, areTicks)
    if start = invalid or finish = invalid or finish <= start or finish - start < 3 then return
    entry = {kind: normalized, startTime: start, endTime: finish}
    index = output.Count()
    output.Push(entry)
    while index > 0
        if output[index - 1].startTime <= start then exit while
        output[index] = output[index - 1]
        index--
    end while
    output[index] = entry
end sub

function ParseSegmentRecords(data as Dynamic) as Object
    output = []
    records = invalid
    if IsList(data) then records = data
    if IsMap(data)
        if IsList(data.Items) then records = data.Items
        if IsList(data.Segments) then records = data.Segments
        if IsList(data.segments) then records = data.segments
    end if
    if IsList(records)
        for each record in records
            if IsMap(record)
                kind = TextValue(record.Type, TextValue(record.type, "Intro"))
                start = SegmentValue(record, ["StartTicks", "StartPositionTicks", "StartTimeTicks", "IntroStartTicks", "startTicks", "start"])
                finish = SegmentValue(record, ["EndTicks", "EndPositionTicks", "EndTimeTicks", "IntroEndTicks", "endTicks", "end"])
                if start <> invalid and finish <> invalid
                    AddPlaybackSegment(output, kind, start.value, finish.value, start.ticks or finish.ticks)
                end if
            end if
        end for
    else if IsMap(data) and (IsMap(data.Introduction) or IsMap(data.Credits))
        ' Intro Skipper keys its segments by mode instead of returning a list.
        for each mode in [{key: "Introduction", kind: "Intro"}, {key: "Credits", kind: "Outro"}, {key: "Recap", kind: "Recap"}, {key: "Preview", kind: "Preview"}]
            record = data[mode.key]
            if IsMap(record)
                start = SegmentValue(record, ["IntroStart", "Start", "start"])
                finish = SegmentValue(record, ["IntroEnd", "End", "end"])
                if start <> invalid and finish <> invalid then AddPlaybackSegment(output, mode.kind, start.value, finish.value, false)
            end if
        end for
    else if IsMap(data)
        start = SegmentValue(data, ["IntroStartTicks", "StartTicks", "StartPositionTicks", "IntroStart", "start"])
        finish = SegmentValue(data, ["IntroEndTicks", "EndTicks", "EndPositionTicks", "IntroEnd", "end"])
        if start <> invalid and finish <> invalid then AddPlaybackSegment(output, TextValue(data.Type, "Intro"), start.value, finish.value, start.ticks or finish.ticks)
    end if
    return output
end function

function ChapterPlaybackSegments(chapters as Dynamic) as Object
    output = []
    if not IsList(chapters) then return output
    for index = 0 to chapters.Count() - 2
        chapter = chapters[index]
        following = chapters[index + 1]
        if IsMap(chapter) and IsMap(following)
            name = LCase(TextValue(chapter.Name))
            kind = ""
            if Instr(1, name, "intro") > 0 or Instr(1, name, "opening") > 0 or Instr(1, name, "abertura") > 0 then kind = "Intro"
            if Instr(1, name, "credits") > 0 or Instr(1, name, "créditos") > 0 or Instr(1, name, "encerramento") > 0 then kind = "Outro"
            if kind <> ""
                AddPlaybackSegment(output, kind, chapter.StartPositionTicks, following.StartPositionTicks, true)
            end if
        end if
    end for
    return output
end function

function FetchPlaybackSegments(itemId as String, mediaSegments = invalid as Dynamic) as Object
    empty = []
    if not m.verified or not IsMap(m.account) then return empty
    encoded = Encode(itemId)
    response = mediaSegments
    if not IsMap(response) then response = Http(m.account.base, "/MediaSegments/" + encoded, "GET", invalid, TextValue(m.account.token), 2500)
    segments = []
    if response.ok then segments = ParseSegmentRecords(response.data)
    if segments.Count() > 0 then return segments
    response = Http(m.account.base, "/Episode/" + encoded + "/IntroTimestamps/v1", "GET", invalid, TextValue(m.account.token), 1500)
    if response.ok then segments = ParseSegmentRecords(response.data)
    if segments.Count() > 0 then return segments
    response = Http(m.account.base, "/Episode/" + encoded + "/IntroSkipperSegments", "GET", invalid, TextValue(m.account.token), 1500)
    if response.ok then segments = ParseSegmentRecords(response.data)
    if segments.Count() > 0 then return segments
    response = Http(m.account.base, "/Items/" + encoded + "?UserId=" + Encode(m.account.userId) + "&Fields=Chapters", "GET", invalid, TextValue(m.account.token), 2500)
    if response.ok and IsMap(response.data) then return ChapterPlaybackSegments(response.data.Chapters)
    return empty
end function

function TrickplayPath(itemId as String) as String
    return "/Items?Ids=" + Encode(itemId) + "&UserId=" + Encode(m.account.userId) + "&Fields=Trickplay&EnableImages=false&EnableUserData=false"
end function

' Jellyfin's thumbnail sheets for the file being played, at the width closest
' to the 320 px preview. Items not processed yet have none.
function TrickplayInfo(itemId as String, mediaSourceId as String, response as Object) as Dynamic
    if not response.ok then return invalid
    items = ItemArray(response.data)
    if items.Count() = 0 then return invalid
    if not IsMap(items[0]) or not IsMap(items[0].Trickplay) then return invalid
    sources = items[0].Trickplay
    sourceId = mediaSourceId
    if not IsMap(sources[sourceId])
        sourceId = ""
        for each key in sources
            if sourceId = "" then sourceId = key
        end for
    end if
    widths = sources[sourceId]
    if not IsMap(widths) then return invalid
    best = invalid
    for each key in widths
        info = widths[key]
        if IsMap(info)
            if best = invalid then best = info
            if Abs(info.Width - 320) < Abs(best.Width - 320) then best = info
        end if
    end for
    if best = invalid then return invalid
    if best.ThumbnailCount = invalid or best.Interval = invalid or best.TileWidth = invalid or best.TileHeight = invalid then return invalid
    if best.ThumbnailCount <= 0 or best.Interval <= 0 then return invalid
    prefix = m.account.base + "/Videos/" + Encode(itemId) + "/Trickplay/" + TextValue(best.Width) + "/"
    ' Unlike artwork, the sheets need the session. Jellyfin 12 reads it from
    ' ApiKey; the older api_key name is refused with 401.
    suffix = ".jpg?MediaSourceId=" + Encode(sourceId) + "&ApiKey=" + Encode(m.account.token)
    return {prefix: prefix, suffix: suffix, width: best.Width, height: best.Height, tileWidth: best.TileWidth, tileHeight: best.TileHeight, frames: best.ThumbnailCount, interval: best.Interval}
end function

' Posts the login and, once the reply proves the same server, makes it the
' active profile.
function SignIn(username as String, password as String) as Object
    response = Http(m.account.base, "/Users/AuthenticateByName", "POST", {Username: username, Pw: password})
    if not response.ok then return Failure("Não foi possível entrar. Confira seu usuário e sua senha e tente novamente.", response.code)
    if not IsMap(response.data) then return Failure("O servidor retornou uma resposta inesperada ao entrar.")
    data = response.data
    if not IsMap(data.User) then return Failure("O servidor não retornou um usuário.")
    if TextValue(data.AccessToken) = "" or TextValue(data.User.Id) = "" then return Failure("O servidor não retornou uma sessão.")
    if TextValue(data.ServerId) <> "" and TextValue(data.ServerId) <> m.account.id then return Failure("A identidade do servidor mudou durante o acesso.", 409)
    m.account.token = data.AccessToken
    m.account.userId = data.User.Id
    m.account.userName = TextValue(data.User.Name)
    m.account.loginName = username
    m.account.loginPassword = password
    m.account.admin = IsAdministrator(data.User)
    StoreProfile()
    m.saved.accounts[m.account.id] = m.account
    m.verified = true
    Persist()
    return {ok: true}
end function

function IsAdministrator(user as Object) as Boolean
    if not IsMap(user.Policy) then return false
    return user.Policy.IsAdministrator = true
end function

' Every profile signed in on this Roku is kept per server; the active one is
' also copied onto the account, where every request reads it.
sub StoreProfile()
    if TextValue(m.account.userId) = "" then return
    if not IsMap(m.account.profiles) then m.account.profiles = {}
    m.account.profiles[m.account.userId] = {userId: m.account.userId, userName: TextValue(m.account.userName), token: TextValue(m.account.token), loginName: TextValue(m.account.loginName), loginPassword: TextValue(m.account.loginPassword), admin: m.account.admin = true}
end sub

' Profiles are the administrator's to switch: the active profile if it is the
' administrator, or an administrator profile already signed in here.
function AdminProfile() as Dynamic
    if not IsMap(m.account) then return invalid
    if m.account.admin = true and TextValue(m.account.token) <> "" then return m.account
    if not IsMap(m.account.profiles) then return invalid
    for each id in m.account.profiles
        profile = m.account.profiles[id]
        if IsMap(profile)
            if profile.admin = true and TextValue(profile.token) <> "" then return profile
        end if
    end for
    return invalid
end function

function CanSwitchProfiles() as Boolean
    return AdminProfile() <> invalid
end function

function ServerProfiles() as Object
    admin = AdminProfile()
    if admin = invalid then return Failure("Só o administrador do servidor pode trocar de perfil neste Roku.", 403)
    if TextValue(admin.userId) = TextValue(m.account.userId)
        response = Api("/Users")
    else
        response = Http(m.account.base, "/Users", "GET", invalid, TextValue(admin.token))
    end if
    if not response.ok or not IsList(response.data) then return Failure("Não foi possível listar os perfis do servidor.", 502)
    profiles = []
    for each user in response.data
        if IsMap(user)
            disabled = false
            if IsMap(user.Policy) then disabled = user.Policy.IsDisabled = true
            if TextValue(user.Id) <> "" and not disabled then profiles.Push({id: TextValue(user.Id), name: TextValue(user.Name), hasPassword: user.HasPassword = true})
        end if
    end for
    return {ok: true, profiles: profiles, currentId: TextValue(m.account.userId)}
end function

' A profile signed in here before switches at once; another asks for its
' password the first time (none if it has none), then is kept like the rest.
function SwitchProfile(request as Object) as Object
    userId = TextValue(request.userId)
    name = TextValue(request.name)
    if userId = TextValue(m.account.userId) then return {ok: true, userName: m.account.userName, canSwitchProfiles: CanSwitchProfiles()}
    StoreProfile()
    profile = invalid
    if IsMap(m.account.profiles) then profile = m.account.profiles[userId]
    if request.password = invalid and IsMap(profile)
        if TextValue(profile.token) <> "" or TextValue(profile.loginName) <> ""
            m.account.userId = profile.userId
            m.account.userName = profile.userName
            m.account.token = profile.token
            m.account.loginName = profile.loginName
            m.account.loginPassword = profile.loginPassword
            m.account.admin = profile.admin = true
            m.saved.accounts[m.account.id] = m.account
            Persist()
            ForgetProfileState()
            return {ok: true, userName: m.account.userName, canSwitchProfiles: CanSwitchProfiles()}
        end if
    end if
    if request.password = invalid and request.hasPassword = true then return {ok: false, needsPassword: true, userId: userId, name: name, message: ""}
    signedIn = SignIn(name, TextValue(request.password))
    if not signedIn.ok
        ' A wrong password is not an expired session: ask again.
        signedIn.needsPassword = signedIn.code = 401
        signedIn.userId = userId
        signedIn.name = name
        return signedIn
    end if
    ForgetProfileState()
    return {ok: true, userName: m.account.userName, canSwitchProfiles: CanSwitchProfiles()}
end function

' Pages, progress and the cached Home all belonged to the previous profile.
sub ForgetProfileState()
    m.detailsCache = {}
    m.playbackCatalog = invalid
    m.homeCacheLists = invalid
    DeleteFile(HomeCachePath())
end sub

' Episodes list the whole series in order, across seasons; the item after this
' one is next. The last episode, or a server ignoring StartItemId, gives none.
function NextEpisodePath(seriesId as String, itemId as String) as String
    return "/Shows/" + Encode(seriesId) + "/Episodes?UserId=" + Encode(m.account.userId) + "&StartItemId=" + Encode(itemId) + "&Limit=2&Fields=Overview,Chapters&EnableUserData=true"
end function

function NextEpisode(seriesId as String, itemId as String, prefetched = invalid as Dynamic) as Dynamic
    if seriesId = "" or itemId = "" or not m.verified or not IsMap(m.account) then return invalid
    response = prefetched
    if not IsMap(response) then response = Http(m.account.base, NextEpisodePath(seriesId, itemId), "GET", invalid, TextValue(m.account.token), 3000)
    if not response.ok then return invalid
    items = ItemArray(response.data)
    if items.Count() < 2 then return invalid
    if TextValue(items[0].Id) <> itemId or TextValue(items[1].Id) = "" then return invalid
    return items[1]
end function

' The registry holds a few KB, so only the most recent series keep their choice.
sub RememberSeriesTrack(seriesId as String, kind as String, track as Dynamic)
    if seriesId = "" or (kind <> "audio" and kind <> "subtitle") or not IsMap(track) then return
    stored = {off: track.off = true}
    if not stored.off then stored = {language: TextValue(track.language), title: TextValue(track.title), label: TextValue(track.label), codec: TextValue(track.codec), forced: track.forced = true, external: track.external = true}
    if not IsMap(m.saved.seriesTracks) then m.saved.seriesTracks = {}
    entry = m.saved.seriesTracks[seriesId]
    if not IsMap(entry) then entry = {}
    entry[kind] = stored
    m.saved.seriesTracks[seriesId] = entry
    order = []
    if IsList(m.saved.seriesTrackOrder)
        for each id in m.saved.seriesTrackOrder
            if id <> seriesId then order.Push(id)
        end for
    end if
    order.Push(seriesId)
    while order.Count() > 20
        m.saved.seriesTracks.Delete(order.Shift())
    end while
    m.saved.seriesTrackOrder = order
    Persist()
end sub

' Stream indices shift between episodes (one extra forced track renumbers every
' later subtitle), so a remembered track is found again by what it is.
function RememberedStreamIndex(source as Object, kind as String, wanted as Object) as Dynamic
    if kind = "Subtitle" and wanted.off = true then return -1
    if not IsList(source.MediaStreams) then return invalid
    language = RokuSubtitleLanguage(TextValue(wanted.language))
    best = invalid
    bestScore = 0
    for each stream in source.MediaStreams
        if stream.Type = kind and RokuSubtitleLanguage(TextValue(stream.Language)) = language and (stream.IsForced = true) = (wanted.forced = true)
            score = 1
            if TextValue(stream.Title) = TextValue(wanted.title) then score += 4
            if TrackLabel(stream) = TextValue(wanted.label) then score += 2
            if LCase(TextValue(stream.Codec)) = LCase(TextValue(wanted.codec)) then score += 1
            if (stream.IsExternal = true) = (wanted.external = true) then score += 1
            if score > bestScore
                best = stream.Index
                bestScore = score
            end if
        end if
    end for
    return best
end function

function PreparePlayback(request as Object) as Object
    ticks = request.ticks
    if ticks = invalid then ticks = 0
    if ticks < 0 then ticks = 0
    qualityId = TextValue(request.quality, "auto")
    quality = invalid
    for each candidate in PlaybackQualities()
        if candidate.id = qualityId then quality = candidate
    end for
    if quality = invalid then return Failure("Escolha uma qualidade de reprodução compatível.")
    catalog = PlaybackCatalog(TextValue(request.itemId))
    if not catalog.ok then return catalog
    if not IsMap(catalog.data) then return Failure("O servidor não retornou versões deste conteúdo.")
    if not IsList(catalog.data.MediaSources) then return Failure("Nenhuma versão deste conteúdo está disponível.")
    sources = catalog.data.MediaSources
    if sources.Count() = 0 then return Failure("Nenhuma versão deste conteúdo está disponível.")
    source = sources[0]
    if TextValue(request.mediaSourceId) <> ""
        source = invalid
        for each candidate in sources
            if candidate.Id = request.mediaSourceId then source = candidate
        end for
        if source = invalid then return Failure("Esta versão do conteúdo não está mais disponível.")
    end if
    ' A fresh episode starts on the tracks last chosen for its series. Original
    ' cannot change tracks and Maximum cannot burn in, so those keep defaults.
    if request.audioStreamIndex = invalid and request.subtitleStreamIndex = invalid and qualityId <> "original" and IsMap(m.saved.seriesTracks)
        remembered = m.saved.seriesTracks[TextValue(request.seriesId)]
        if IsMap(remembered)
            if IsMap(remembered.audio) then request.audioStreamIndex = RememberedStreamIndex(source, "Audio", remembered.audio)
            if IsMap(remembered.subtitle)
                subtitle = RememberedStreamIndex(source, "Subtitle", remembered.subtitle)
                if qualityId = "maximum" and subtitle <> invalid and subtitle <> -1
                    if not IsNativeSubtitle(FindMediaStream(source, "Subtitle", subtitle)) then subtitle = invalid
                end if
                request.subtitleStreamIndex = subtitle
            end if
        end if
    end if
    audioIndex = source.DefaultAudioStreamIndex
    if request.audioStreamIndex <> invalid
        audioIndex = request.audioStreamIndex
        if FindMediaStream(source, "Audio", audioIndex) = invalid then return Failure("Esta faixa de áudio não está disponível nesta versão.")
    end if
    subtitleIndex = -1
    if request.subtitleStreamIndex <> invalid then subtitleIndex = request.subtitleStreamIndex
    if subtitleIndex <> -1
        if FindMediaStream(source, "Subtitle", subtitleIndex) = invalid then return Failure("Esta legenda não está disponível nesta versão.")
    end if
    selection = {mediaSourceId: source.Id, audioStreamIndex: audioIndex, subtitleStreamIndex: subtitleIndex, quality: qualityId}
    nativeTracks = NativeSubtitleTracks(TextValue(request.itemId), source)
    externalSubtitle = false
    for each track in nativeTracks
        if track.index = subtitleIndex then externalSubtitle = true
    end for
    negotiatedSubtitleIndex = subtitleIndex
    if externalSubtitle then negotiatedSubtitleIndex = -1
    forceVideoTranscode = request.forceTranscode = true or negotiatedSubtitleIndex <> -1
    forceTranscode = forceVideoTranscode
    audioCount = 0
    if IsList(source.MediaStreams)
        for each stream in source.MediaStreams
            if stream.Type = "Audio" then audioCount++
        end for
    end if
    ' A static file ignores Jellyfin audio indices. For multi-track Auto/HLS,
    ' let the server produce the selected track rather than guess Roku IDs.
    if audioCount > 1 and qualityId <> "original" then forceTranscode = true
    if qualityId = "original" and audioCount > 1
        originalAudio = FindMediaStream(source, "Audio", audioIndex)
        if originalAudio <> invalid
            if originalAudio.IsDefault <> true then forceTranscode = true
        end if
    end if
    if request.audioStreamIndex <> invalid and request.audioStreamIndex <> source.DefaultAudioStreamIndex then forceTranscode = true
    if qualityId = "original" and forceTranscode then return Failure("A qualidade Original reproduz o arquivo compatível sem alterações. Escolha Automática para mudar o áudio ou usar legendas.")
    hevcCopy = invalid
    profile = RokuProfile()
    profile.MaxStreamingBitrate = quality.maxBitrate
    profile.MaxStaticBitrate = quality.maxBitrate
    for each condition in profile.CodecProfiles[0].Conditions
        if condition.Property = "Width" then condition.Value = quality.maxWidth.ToStr()
        if condition.Property = "Height" then condition.Value = quality.maxHeight.ToStr()
    end for
    if qualityId = "original" or qualityId = "auto"
        capabilities = OriginalVideoCapabilities()
        AddOriginalCapabilities(profile, capabilities)
        if qualityId = "auto" and capabilities.hevc4k
            ' Device-confirmed HEVC supports 25 Mbps; explicit quality caps never change.
            quality.maxBitrate = 25000000
            profile.MaxStreamingBitrate = quality.maxBitrate
            profile.MaxStaticBitrate = quality.maxBitrate
            if not forceVideoTranscode
                hevcCopy = HevcCopySource(source, capabilities)
                if hevcCopy <> invalid then profile.TranscodingProfiles[0].VideoCodec = "hevc"
            end if
        end if
    end if
    if qualityId = "maximum" and request.forceTranscode <> true
        if forceVideoTranscode then return Failure("A qualidade Máxima não permite gravar legendas no vídeo. Use uma legenda SRT externa ou escolha Automática.")
        capabilities = OriginalVideoCapabilities()
        hevcCopy = HevcCopySource(source, capabilities, true)
        if hevcCopy = invalid then return Failure("Este arquivo ou aparelho não atende aos requisitos da qualidade Máxima. Escolha Automática para uma versão compatível.")
        AddOriginalCapabilities(profile, capabilities)
        quality.maxBitrate = 65000000
        profile.MaxStreamingBitrate = quality.maxBitrate
        profile.MaxStaticBitrate = quality.maxBitrate
        profile.TranscodingProfiles[0].VideoCodec = "hevc"
        profile.TranscodingProfiles[0].SegmentLength = 3
        for each codecProfile in profile.CodecProfiles
            if codecProfile.Codec = "hevc"
                for each condition in codecProfile.Conditions
                    if condition.Property = "VideoBitrate" then condition.Value = "65000000"
                end for
            end if
        end for
        ' Always remux this explicit mode: DV7 enhancement metadata must be
        ' stripped by Jellyfin, and three-second segments fit the measured TV.
        forceTranscode = true
    end if
    AddAudioCapabilities(profile, AudioCapabilities())
    ' Embedded text and image subtitles retain burn-in. External SRT selection
    ' is disabled in this request and registered separately on the Video content.
    profile.SubtitleProfiles = []
    if IsList(source.MediaStreams)
        for each stream in source.MediaStreams
            if stream.Type = "Subtitle" then profile.SubtitleProfiles.Push({Format: TextValue(stream.Codec), Method: "Encode"})
        end for
    end if
    payload = {UserId: m.account.userId, DeviceProfile: profile, MaxStreamingBitrate: quality.maxBitrate, StartTimeTicks: ticks, MediaSourceId: source.Id, SubtitleStreamIndex: negotiatedSubtitleIndex, EnableDirectPlay: not forceTranscode, EnableDirectStream: not forceVideoTranscode and qualityId <> "original", EnableTranscoding: qualityId <> "original", AllowVideoStreamCopy: not forceVideoTranscode, AllowAudioStreamCopy: request.forceTranscode <> true, AutoOpenLiveStream: true, AlwaysBurnInSubtitleWhenTranscoding: true}
    if audioIndex <> invalid then payload.AudioStreamIndex = audioIndex
    response = Api("/Items/" + Encode(request.itemId) + "/PlaybackInfo", "POST", payload)
    if not response.ok
        if hevcCopy <> invalid and response.code <> 401 and response.code <> 403 and response.code <> 409 then return RetryHevcAsH264(request, selection)
        m.playbackCatalog = invalid
        return response
    end if
    if not IsMap(response.data) then return Failure("O servidor não retornou informações de reprodução.")
    info = response.data
    if hevcCopy <> invalid and TextValue(info.ErrorCode) = "NoCompatibleStream" then return RetryHevcAsH264(request, selection)
    if not IsList(info.MediaSources) then return Failure("Nenhum vídeo compatível está disponível.")
    negotiated = invalid
    for each candidate in info.MediaSources
        if candidate.Id = source.Id then negotiated = candidate
    end for
    if negotiated = invalid then return Failure("Não foi possível preparar a versão solicitada.")
    if hevcCopy <> invalid and (negotiated.SupportsDirectPlay <> true or forceTranscode)
        if TextValue(negotiated.TranscodingUrl) = "" then return RetryHevcAsH264(request, selection)
        candidateUrl = ResolveStreamUrl(m.account.base, TextValue(negotiated.TranscodingUrl))
        if candidateUrl = "" then return Failure("O servidor forneceu um endereço de reprodução fora do endereço verificado.")
        if not HevcCopyUrlSafe(candidateUrl, hevcCopy) then return RetryHevcAsH264(request, selection)
    end if
    url = ""
    format = "mp4"
    method = "DirectPlay"
    if negotiated.SupportsDirectPlay = true and not forceTranscode
        container = LCase(TextValue(negotiated.Container, TextValue(source.Container)))
        if container = "" then container = LCase(TextValue(source.Container))
        for each alias in container.Split(",")
            if alias.Trim() = "mkv" or alias.Trim() = "matroska" then format = "mkv"
        end for
        url = m.account.base + "/Videos/" + Encode(request.itemId) + "/stream?Static=true&MediaSourceId=" + Encode(source.Id) + "&PlaySessionId=" + Encode(info.PlaySessionId) + "&DeviceId=" + Encode(m.saved.deviceId) + "&api_key=" + Encode(m.account.token)
    else if TextValue(negotiated.TranscodingUrl) <> "" and qualityId <> "original"
        url = FullTimelineHlsUrl(ResolveStreamUrl(m.account.base, negotiated.TranscodingUrl))
        if url = "" then return Failure("O servidor forneceu um endereço de reprodução fora do endereço verificado.")
        format = "hls"
        method = "Transcode"
    end if
    if url = ""
        if qualityId = "original" then return Failure("Esta versão não pode ser reproduzida sem alterações neste Roku. Escolha Automática para uma reprodução compatível.")
        return Failure("Não é possível reproduzir esta seleção. Confira as permissões de transcodificação da sua conta no Jellyfin.")
    end if
    node = CreateObject("roSGNode", "ContentNode")
    node.url = url
    node.title = TextValue(request.title)
    node.streamFormat = format
    node.playStart = ticks / 10000000#
    node.HttpCertificatesFile = "common:/certs/ca-bundle.crt"
    node.HttpSendClientCertificate = true
    node.HttpHeaders = ["Authorization: " + AuthHeader(m.account.token)]
    subtitleTracks = []
    for each track in nativeTracks
        subtitleTracks.Push({Language: RokuSubtitleLanguage(track.language), Description: track.label, TrackName: track.trackName})
    end for
    node.SubtitleTracks = subtitleTracks
    session = {ItemId: request.itemId, MediaSourceId: source.Id, PlaySessionId: TextValue(info.PlaySessionId), PlayMethod: method, PositionTicks: ticks, CanSeek: true, SubtitleStreamIndex: subtitleIndex}
    if audioIndex <> invalid then session.AudioStreamIndex = audioIndex
    options = PlaybackChoices(sources, source, selection)
    delivery = "off"
    if subtitleIndex <> -1 then delivery = "encoded"
    if externalSubtitle then delivery = "external"
    options.subtitleDelivery = delivery
    options.nativeSubtitleTracks = nativeTracks
    return {ok: true, content: node, session: session, options: options, positionOffsetTicks: 0, offsetTicks: ticks, transcoded: method = "Transcode"}
end function
