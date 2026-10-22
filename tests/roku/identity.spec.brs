' Runs the actual channel functions with only HTTP, discovery and registry I/O
' replaced. No fake implementation of server selection or authentication policy.
sub Main()
    m.assertions = 0
    AssertEqual(NormalizeBase("192.168.1.2:8096/jellyfin/"), "http://192.168.1.2:8096/jellyfin", "base path retained")
    AssertEqual(NormalizeBase("https://media.example.test/media"), "https://media.example.test/media", "HTTPS base retained")
    AssertEqual(NormalizeBase("http://user:secret@host:8096"), "", "URL credentials rejected")
    AssertEqual(NormalizeBase("http://host/?api_key=secret"), "", "URL query rejected")
    AssertEqual(NormalizeBase("ftp://host"), "", "non HTTP scheme rejected")
    AssertEqual(PrivateSubnetPrefix({eth0: "192.168.6.48"}), "192.168.6.", "LAN subnet from Roku interface")
    AssertEqual(PrivateSubnetPrefix({eth0: "172.24.3.11"}), "172.24.3.", "RFC1918 172 subnet")
    AssertEqual(PrivateSubnetPrefix({eth0: "8.8.8.8"}), "", "no public subnet scan")
    template = ProbeTemplate("https://old.example.test:9443/jellyfin")
    AssertEqual(template.scheme, "https", "scan preserves scheme")
    AssertEqual(template.port, ":9443", "scan preserves port")
    AssertEqual(template.path, "/jellyfin", "scan preserves base path")
    AssertEqual(ProbeTemplate("").port, ":8096", "first run default port")

    AssertEqual(ResolveStreamUrl("http://host:8096/media", "/Videos/id/master.m3u8"), "http://host:8096/media/Videos/id/master.m3u8", "HLS keeps proxy base path")
    AssertEqual(ResolveStreamUrl("http://host:8096/media", "/media/Videos/id/master.m3u8"), "http://host:8096/media/Videos/id/master.m3u8", "HLS does not duplicate base path")
    AssertEqual(ResolveStreamUrl("http://host:8096/media", "Videos/id/master.m3u8"), "http://host:8096/media/Videos/id/master.m3u8", "HLS supports relative path")
    AssertEqual(ResolveStreamUrl("http://host:8096", "https://other/video"), "", "HLS refuses other origins")
    AssertEqual(ResolveStreamUrl("http://host:8096", "//other/video"), "", "HLS refuses protocol-relative origins")

    segments = ParseSegmentRecords({Items: [{Type: "Intro", StartTicks: 1349900000, EndTicks: 2250230000}, {Type: "Commercial", StartTicks: 0, EndTicks: 90000000}, {Type: "Recap", StartTicks: 10000000, EndTicks: 20000000}]})
    AssertEqual(segments.Count(), 1, "tick parser filters unsupported and under-three-second segments")
    AssertEqual(segments[0].kind, "Intro", "MediaSegments preserves Intro type")
    AssertEqual(segments[0].startTime, 134.99, "MediaSegments ticks convert to seconds")
    AssertEqual(segments[0].endTime, 225.023, "MediaSegments end ticks convert to seconds")
    segments = ParseSegmentRecords({IntroStart: 10.5, IntroEnd: 81.25})
    AssertEqual(segments.Count(), 1, "legacy timestamp response shape parsed")
    AssertEqual(segments[0].startTime, 10.5, "legacy timestamps remain seconds")
    segments = ParseSegmentRecords({Introduction: {EpisodeId: "e", Valid: true, IntroStart: 62.4, IntroEnd: 151.9}, Credits: {EpisodeId: "e", Valid: true, IntroStart: 1290, IntroEnd: 1350}})
    AssertEqual(segments.Count(), 2, "Intro Skipper keyed response parsed")
    AssertEqual(segments[0].kind, "Intro", "Introduction maps to Intro")
    AssertEqual(segments[1].kind, "Outro", "Credits maps to Outro")
    AssertEqual(segments[1].startTime, 1290, "Intro Skipper values remain seconds")
    segments = ChapterPlaybackSegments([{Name: "Credits", StartPositionTicks: 80000000}, {Name: "Final", StartPositionTicks: 1320000000}, {Name: "Abertura", StartPositionTicks: 0}, {Name: "Episode", StartPositionTicks: 2500000000}])
    AssertEqual(segments.Count(), 2, "chapter names create intro and outro segments")
    AssertEqual(segments[0].kind, "Intro", "chapter results sorted by start")
    AssertEqual(segments[0].endTime, 250, "chapter segment ends at next chapter")
    AssertEqual(segments[1].kind, "Outro", "credits map to Outro")
    segments = ParseSegmentRecords({Items: [{Type: "Intro", StartTicks: 90000000, EndTicks: 90000000}, {Type: "Outro", StartTicks: 300000000, EndTicks: 329999999}]})
    AssertEqual(segments.Count(), 0, "invalid and shorter-than-three-second ranges are dropped")

    posters = LatestSeasonPosters([{Id: "s1", SeriesId: "cp", IndexNumber: 1, ImageTags: {Primary: "a"}}, {Id: "s2", SeriesId: "cp", IndexNumber: 2, ImageTags: {Primary: "b"}}, {Id: "s3", SeriesId: "cp", IndexNumber: 3, ImageTags: {}}, {Id: "sp", SeriesId: "cp", IndexNumber: 0, ImageTags: {Primary: "c"}}])
    AssertEqual(posters.cp, invalid, "a newer season without art keeps the show poster")
    posters = LatestSeasonPosters([{Id: "s1", SeriesId: "cp", IndexNumber: 1, ImageTags: {Primary: "a"}}, {Id: "s2", SeriesId: "cp", IndexNumber: 2, ImageTags: {Primary: "b"}}, {Id: "bb1", SeriesId: "bb", IndexNumber: 1, ImageTags: {Primary: "c"}}, {Id: "sp", SeriesId: "cp", IndexNumber: 0, ImageTags: {Primary: "d"}}])
    AssertEqual(posters.cp.id, "s2", "show poster follows its newest season's art")
    AssertEqual(posters.bb, invalid, "a first-season poster never replaces the show poster")
    ResetState()
    m.seasonPosters = posters
    AssertEqual(Instr(1, PosterUrl({Id: "cp", Type: "Series"}), "/Items/s2/Images/Primary") > 0, true, "library poster points at the season art")
    AssertEqual(Instr(1, PosterUrl({Id: "other", Type: "Series", ImageTags: {Primary: "x"}}), "/Items/other/Images/Primary") > 0, true, "shows without season art keep their own poster")
    m.seasonPosters = invalid

    ResetState()
    m.responses = [{ok: true, data: {Items: [{Id: "show"}, {Id: "film"}], TotalRecordCount: 2}}, {ok: true, data: {Items: [{Id: "e1"}, {Id: "e2"}], TotalRecordCount: 100}}]
    found = SearchItems("fu", 0, "viewer", "")
    AssertEqual(found.items[0].Id, "show", "search lists shows and movies before episodes")
    AssertEqual(found.items[2].Id, "e1", "episodes follow the titles on the same page")
    AssertEqual(found.total, 102, "search total combines titles and episodes")
    AssertEqual(Instr(1, m.calls[1].path, "IncludeItemTypes=Episode&Limit=48&StartIndex=0") > 0, true, "the first page asks for episodes alongside the titles")
    AssertEqual(found.items.Count(), 4, "episodes fill the rest of the first page")
    ResetState()
    full = []
    for index = 1 to 48
        full.Push({Id: "t" + index.ToStr()})
    end for
    m.responses = [{ok: true, data: {Items: full, TotalRecordCount: 60}}, {ok: true, data: {Items: [{Id: "e1"}], TotalRecordCount: 9}}]
    found = SearchItems("a", 0, "viewer", "")
    AssertEqual(found.items.Count(), 48, "a page full of titles stays at 48")
    AssertEqual(found.items[47].Id, "t48", "titles keep the page when they fill it")
    AssertEqual(found.total, 69, "the total still counts every episode")
    ResetState()
    m.responses = [{ok: true, data: {Items: [], TotalRecordCount: 2}}, {ok: true, data: {Items: [{Id: "e47"}], TotalRecordCount: 100}}]
    found = SearchItems("fu", 48, "viewer", "")
    AssertEqual(Instr(1, m.calls[1].path, "Limit=48&StartIndex=46") > 0, true, "second page continues the episode list without gaps")
    AssertEqual(found.items[0].Id, "e47", "second page starts with episodes")

    ResetState()
    m.responses = [{ok: true, data: {Id: "other", ServerName: "Wrong server", ProductName: "Jellyfin Server"}}]
    result = Verify("http://old:8096", "saved")
    AssertEqual(result.ok, false, "recycled DHCP address rejected")
    AssertEqual(result.code, 409, "identity mismatch explicit")
    AssertEqual(m.calls[0].token, "", "public verification never sends token")
    AssertEqual(m.account.token, "saved-token", "mismatch preserves token")

    ResetState()
    m.responses = [{ok: true, data: {Id: "saved", ServerName: "Not Jellyfin", ProductName: "Emby Server"}}]
    result = Verify("http://old:8096", "saved")
    AssertEqual(result.ok, false, "matching ID from a different product rejected")
    AssertEqual(m.calls[0].token, "", "product verification stays token-free")
    AssertEqual(m.account.token, "saved-token", "wrong product preserves saved login")
    AssertEqual(PublicServerInfo({Id: "saved", ServerName: "Unknown"}, "http://old:8096").ok, false, "missing product cannot identify Jellyfin")
    AssertEqual(PublicServerInfo({ProductName: "Jellyfin Server"}, "http://old:8096").ok, false, "product alone is not server identity")
    AssertEqual(PublicServerInfo([], "http://old:8096").ok, false, "non-object public response rejected")
    check = PublicServerInfo({Id: "saved", ProductName: "Jellyfin Server"}, "http://new:8096/jellyfin")
    AssertEqual(check.ok, true, "subnet validator accepts official product and ID")
    AssertEqual(check.server.base, "http://new:8096/jellyfin", "subnet validator retains probed base path")

    ResetState()
    m.responses = [{ok: true, data: {Id: "saved", ServerName: "Not Jellyfin", ProductName: "Emby Server"}}]
    result = EnsureAccount()
    AssertEqual(result.ok, false, "wrong product blocks authenticated command")
    result = Api("/Items?UserId=viewer")
    AssertEqual(result.ok, false, "wrong product leaves token dispatch disabled")
    AssertEqual(m.calls.Count(), 1, "wrong product never receives authenticated HTTP")

    ResetState()
    m.responses = [Failure("offline")]
    m.discovery = []
    result = Bootstrap(false)
    AssertEqual(result.connected, false, "offline bootstrap offers reconnect")
    AssertEqual(m.saved.accounts.saved.token, "saved-token", "offline preserves account")
    AssertEqual(m.persistCount, 0, "offline does not rewrite registry")

    ResetState()
    m.responses = [Failure("old address unavailable")]
    m.discovery = [{id: "saved", name: "My cinema", base: "http://new:8096/jellyfin"}]
    result = Bootstrap(false)
    AssertEqual(result.loggedIn, true, "DHCP bootstrap restores login")
    AssertEqual(m.account.base, "http://new:8096/jellyfin", "new address persisted")
    AssertEqual(m.account.token, "saved-token", "DHCP preserves token")
    AssertEqual(m.saved.deviceId, "persistent-device", "DHCP preserves device identity")

    ResetState()
    m.responses = [Failure("old address unavailable")]
    m.discovery = [{id: "saved", name: "My cinema", base: "http://new:8096"}]
    result = EnsureAccount()
    AssertEqual(result.ok, true, "in-session DHCP recovery")
    AssertEqual(m.account.base, "http://new:8096", "active account changes address")
    AssertEqual(m.calls[0].token, "", "recovery checks public endpoint before auth")

    ResetState()
    m.responses = [{ok: true, data: {Id: "other", ServerName: "Other", ProductName: "Jellyfin Server"}}]
    m.discovery = []
    result = EnsureAccount()
    AssertEqual(result.ok, false, "in-session mismatch cannot authorize")
    AssertEqual(m.verified, false, "mismatched host remains unverified")
    result = Api("/Users/private")
    AssertEqual(result.ok, false, "API blocks token until verified")
    AssertEqual(m.calls.Count(), 1, "no authenticated HTTP sent on mismatch")

    ResetState()
    m.responses = [Failure("offline"), {ok: true, data: {Items: []}}]
    m.discovery = [{id: "saved", name: "My cinema", base: "http://new:8096"}]
    result = Api("/Users/private")
    AssertEqual(result.ok, true, "request retries after network address recovery")
    AssertEqual(m.calls[1].base, "http://new:8096", "retry uses discovered verified address")

    ResetState()
    m.responses = [Failure("expired", 401)]
    result = Api("/Users/private")
    AssertEqual(result.code, 401, "revoked token surfaced for sign-in")
    AssertEqual(m.calls.Count(), 1, "no retry loop for revoked token")
    AssertEqual(m.discoveryCalls, 0, "revoked token does not trigger network scan")

    ResetState()
    m.account.loginName = "Viewer"
    m.account.loginPassword = "saved-password"
    m.responses = [Failure("expired", 401), {ok: true, data: {Id: "saved", ProductName: "Jellyfin Server"}}, {ok: true, data: {ServerId: "saved", AccessToken: "renewed-token", User: {Id: "viewer", Name: "Viewer"}}}, {ok: true, data: {Name: "Viewer"}}]
    result = Api("/Users/viewer")
    AssertEqual(result.ok, true, "401 reauthenticates and retries request")
    AssertEqual(m.calls.Count(), 4, "401 flow retries original call once")
    AssertEqual(m.calls[1].token, "", "refresh verifies public server without token")
    AssertEqual(m.calls[2].body.Pw, "saved-password", "stored password sent only to verified server")
    AssertEqual(m.calls[3].token, "renewed-token", "retry uses refreshed token")
    AssertEqual(m.account.token, "renewed-token", "refreshed token persisted on account")

    ResetState()
    m.account.loginName = "Viewer"
    m.account.loginPassword = "saved-password"
    m.responses = [Failure("expired", 401), {ok: true, data: {Id: "saved", ProductName: "Jellyfin Server"}}, Failure("bad saved credentials", 401)]
    result = Api("/Users/viewer")
    AssertEqual(result.ok, false, "failed reauthentication surfaces original unauthorized result")
    AssertEqual(result.code, 401, "failed reauthentication leaves login-required status")
    AssertEqual(m.calls.Count(), 3, "failed reauthentication does not retry original request")

    ResetState()
    m.account.loginName = "Viewer"
    m.account.loginPassword = "saved-password"
    m.responses = [Failure("expired", 401), {ok: true, data: {Id: "other", ProductName: "Jellyfin Server"}}]
    result = Api("/Users/viewer")
    AssertEqual(result.code, 401, "identity mismatch keeps unauthorized response")
    AssertEqual(m.calls.Count(), 2, "mismatched ServerId never receives credentials")

    ResetState()
    m.account.loginName = "Viewer"
    m.account.loginPassword = ""
    m.responses = [Failure("expired", 401), {ok: true, data: {Id: "saved", ProductName: "Jellyfin Server"}}, {ok: true, data: {ServerId: "saved", AccessToken: "renewed-token", User: {Id: "viewer", Name: "Viewer"}}}, {ok: true, data: {Name: "Viewer"}}]
    result = Api("/Users/viewer")
    AssertEqual(result.ok, true, "empty Jellyfin password still reauthenticates")

    ResetState()
    m.account.loginName = "Viewer"
    m.account.loginPassword = "saved-password"
    result = Dispatch({action: "logout"})
    AssertEqual(m.account.loginPassword, "", "logout wipes stored password")
    AssertEqual(m.account.token, "", "logout clears token")

    ResetState()
    result = Activate({id: "other", name: "Other", base: "http://other:8096"})
    AssertEqual(result.loggedIn, false, "new server never inherits another token")
    AssertEqual(m.saved.accounts.saved.token, "saved-token", "switching keeps original account")
    result = Activate({id: "saved", name: "My cinema", base: "http://new:8096"})
    AssertEqual(result.loggedIn, true, "switching back restores correct account")

    ResetState()
    m.responses = [{ok: true, data: {Id: "saved", ServerName: "My cinema", ProductName: "Jellyfin Server"}}, {ok: true, data: {ServerId: "saved", AccessToken: "new-token", User: {Id: "user2", Name: "Viewer"}}}]
    result = Dispatch({action: "login", username: "Viewer", password: "test-password"})
    AssertEqual(result.ok, true, "password authentication saves valid session")
    AssertEqual(m.account.userId, "user2", "authenticated user id saved")
    AssertEqual(m.account.token, "new-token", "authenticated token saved")
    AssertEqual(m.account.loginName, "Viewer", "username saved for silent sign-in")
    AssertEqual(m.account.loginPassword, "test-password", "password saved for silent sign-in")
    AssertEqual(m.calls[1].token, "", "login never sends old token")

    result = Dispatch({action: "logout"})
    AssertEqual(m.account.token, "", "logout removes active token")
    AssertEqual(m.account.userId, "", "logout removes active user id")
    AssertEqual(m.account.id, "saved", "logout retains server identity")
    AssertEqual(m.saved.deviceId, "persistent-device", "logout retains device identity")
    TestSeriesTrackMemory()
    TestNextEpisode()
    profile = RokuProfile()
    AssertEqual(profile.TranscodingProfiles[0].Protocol, "hls", "Roku HLS fallback")
    AssertEqual(profile.TranscodingProfiles[0].MaxAudioChannels, "2", "stereo baseline")
    AssertEqual(ResumeTicks({UserData: {PlaybackPositionTicks: 72000000000#}}), 72000000000#, "resume does not overflow 32-bit ticks")
    ResetState()
    m.responses = [
        {ok: true, data: {Id: "saved", ServerName: "My cinema", ProductName: "Jellyfin Server"}}
        {ok: true, data: {Items: []}}
        {ok: true, data: []}
        {ok: true, data: {Items: []}}
        {ok: true, data: {Items: []}}
    ]
    result = Dispatch({action: "home"})
    AssertEqual(result.ok, true, "empty library succeeds")
    AssertEqual(result.content.GetChildCount(), 0, "empty shelves omitted")
    AssertEqual(Instr(1, m.calls[1].path, "/UserItems/Resume?UserId=viewer&"), 1, "12.2 resume endpoint")
    AssertEqual(Instr(1, m.calls[2].path, "/Items/Latest?UserId=viewer&"), 1, "12.2 latest endpoint")
    AssertEqual(Instr(1, m.calls[3].path, "/Items?UserId=viewer&"), 1, "12.2 movies endpoint")
    AssertEqual(Instr(1, m.calls[4].path, "/Items?UserId=viewer&"), 1, "12.2 series endpoint")

    ResetState()
    m.responses = [{ok: true, data: {Id: "saved", ServerName: "My cinema", ProductName: "Jellyfin Server"}}, {ok: true, data: {Items: [], TotalRecordCount: 120}}]
    result = Dispatch({action: "browse", kind: "Movie", offset: 48})
    AssertEqual(result.total, 120, "paging retains total count")
    AssertEqual(Instr(1, m.calls[1].path, "StartIndex=48" ) > 0, true, "browse passes page offset")
    AssertEqual(Instr(1, m.calls[1].path, "/Items?UserId=viewer&"), 1, "browse uses current root endpoint")

    ResetState()
    m.responses = [{ok: true, data: {Id: "saved", ServerName: "My cinema", ProductName: "Jellyfin Server"}}, {ok: true, data: {Id: "movie", Name: "Film", Type: "Movie"}}]
    result = Dispatch({action: "details", itemId: "movie"})
    AssertEqual(result.ok, true, "details creates a native card")
    AssertEqual(m.calls[1].path, "/Items/movie?UserId=viewer", "12.2 item detail endpoint")
    AssertEqual(result.card.title, "Film", "native content metadata populated")

    ResetState()
    m.responses = [{ok: true, data: {Id: "saved", ServerName: "My cinema", ProductName: "Jellyfin Server"}}, {ok: true, code: 204}]
    result = Dispatch({action: "report", event: "stopped", body: {ItemId: "movie", PlaySessionId: "session", PositionTicks: 90000000#}})
    AssertEqual(m.calls[1].path, "/Sessions/Playing/Stopped", "stop report uses current session endpoint")
    AssertEqual(m.calls.Count(), 2, "stop avoids removed ActiveEncodings endpoint")

    ResetState()
    m.responses = [{ok: true, data: {PlaySessionId: "play-session", MediaSources: [{Id: "source", SupportsDirectPlay: true}]}}, {ok: true, data: {PlaySessionId: "play-session", MediaSources: [{Id: "source", SupportsDirectPlay: true}]}}]
    result = PreparePlayback({itemId: "movie", title: "Film", ticks: 72000000000#})
    AssertEqual(result.ok, true, "compatible MP4 creates playback content")
    AssertEqual(result.content.playStart, 7200, "direct play resumes in seconds")
    AssertEqual(result.content.streamFormat, "mp4", "direct playback format")
    AssertEqual(result.content.HttpSendClientCertificate, true, "documented TLS client-certificate metadata populated")
    AssertEqual(result.session.PlayMethod, "DirectPlay", "direct play report method")

    ResetState()
    m.account.base = "http://host:8096/media"
    m.responses = [{ok: true, data: {PlaySessionId: "play-session", MediaSources: [{Id: "source", SupportsDirectPlay: false, TranscodingUrl: "/media/Videos/movie/master.m3u8"}]}}, {ok: true, data: {PlaySessionId: "play-session", MediaSources: [{Id: "source", SupportsDirectPlay: false, TranscodingUrl: "/media/Videos/movie/master.m3u8"}]}}]
    result = PreparePlayback({itemId: "movie", title: "Film", ticks: 72000000000#, forceTranscode: true})
    AssertEqual(result.ok, true, "HLS transcode creates playback content")
    AssertEqual(result.content.playStart, 7200, "HLS keeps original presentation timeline")
    AssertEqual(result.content.streamFormat, "hls", "HLS playback format")
    AssertEqual(result.content.url, "http://host:8096/media/Videos/movie/master.m3u8", "transcode URL preserves proxy base path")
    AssertEqual(m.calls[1].body.EnableDirectPlay, false, "compatible retry disables direct play")
    AssertEqual(m.calls[1].body.AllowVideoStreamCopy, false, "compatible retry forces video conversion")

    ResetState()
    m.responses = [{ok: true, data: {PlaySessionId: "play-session", MediaSources: [{Id: "source", SupportsDirectPlay: false, TranscodingUrl: "https://other/video.m3u8"}]}}, {ok: true, data: {PlaySessionId: "play-session", MediaSources: [{Id: "source", SupportsDirectPlay: false, TranscodingUrl: "https://other/video.m3u8"}]}}]
    result = PreparePlayback({itemId: "movie", title: "Film", ticks: 0})
    AssertEqual(result.ok, false, "playback refuses a foreign authenticated stream")

    ' Jellyfin 12.2 returns lowercase routes and dashed GUIDs even when the
    ' requested item ID is compact. Preserve its URL, query and report identity.
    compactId = "5c14a75749ebd89d90585009c1cd1840"
    hlsPath = "/videos/5c14a757-49eb-d89d-9058-5009c1cd1840/master.m3u8?MediaSourceId=source&PlaySessionId=play-session&api_key=fixture-token"
    ResetState()
    m.account.base = "http://192.168.1.50:8096"
    m.responses = [{ok: true, data: {PlaySessionId: "play-session", MediaSources: [{Id: "source", SupportsDirectPlay: false, TranscodingUrl: hlsPath}]}}, {ok: true, data: {PlaySessionId: "play-session", MediaSources: [{Id: "source", SupportsDirectPlay: false, TranscodingUrl: hlsPath}]}}]
    result = PreparePlayback({itemId: compactId, title: "Film", ticks: 0})
    AssertEqual(result.ok, true, "12.2 lowercase dashed GUID HLS route is playable")
    AssertEqual(result.content.url, m.account.base + hlsPath, "12.2 URL and transcode query remain verbatim")
    AssertEqual(result.content.streamFormat, "hls", "12.2 route selects native HLS playback")
    AssertEqual(result.session.ItemId, compactId, "playback reports retain requested compact item identity")
    AssertEqual(m.calls[1].path, "/Items/" + compactId + "/PlaybackInfo", "playback info uses requested compact item identity")
    AssertEqual(ResolveStreamUrl("http://host:8096/media", hlsPath), "http://host:8096/media" + hlsPath, "dashed lowercase route keeps configured proxy prefix")
    AssertEqual(ResolveStreamUrl("http://host:8096/media", "/media" + hlsPath), "http://host:8096/media" + hlsPath, "dashed lowercase route does not double proxy prefix")
    AssertEqual(ResolveStreamUrl("http://host:8096/media", "http://host:8096" + hlsPath), "", "absolute HLS URL cannot escape configured proxy prefix")
    AssertEqual(ResolveStreamUrl("http://host:8096", "http://host:8096.evil.test" + hlsPath), "", "host prefix alone cannot authorize a foreign origin")
    AssertEqual(ResolveStreamUrl("http://host:8096", "//other" + hlsPath), "", "real HLS shape cannot bypass protocol-relative rejection")

    ResetState()
    image = ImageUrl({Id: "movie", BackdropImageTags: ["backdrop"], ImageTags: {Primary: "poster"}}, true, "680")
    AssertEqual(Instr(1, image, "/Items/movie/Images/Backdrop/0?maxWidth=680") > 0, true, "landscape shelf prefers backdrop at shelf resolution")
    image = ImageUrl({Id: "season", ParentBackdropItemId: "series", BackdropImageTags: []}, true)
    AssertEqual(Instr(1, image, "/Items/series/Images/Backdrop/0") > 0, true, "season inherits series landscape art")
    image = ImageUrl({Id: "movie", BackdropImageTags: [], ImageTags: {Primary: "poster"}}, true)
    AssertEqual(Instr(1, image, "/Items/movie/Images/Primary") > 0, true, "missing backdrop falls back to available primary art")
    image = ImageUrl({Id: "episode", SeriesId: "series", ImageTags: {Primary: "still"}}, false, "680")
    AssertEqual(Instr(1, image, "/Items/episode/Images/Primary?maxWidth=680") > 0, true, "episode shelf uses episode still")
    ResetState()
    AssertEqual(Instr(1, LogoUrl({Id: "movie", ImageTags: {Logo: "tag"}}), "/Items/movie/Images/Logo") > 0, true, "hero uses real library title logo")
    AssertEqual(LogoUrl({Id: "movie", ImageTags: {Primary: "poster"}}), "", "missing title art uses text fallback")
    items = []
    for index = 1 to 13
        items.Push({Id: "movie-" + index.ToStr(), Name: "Film " + index.ToStr(), Type: "Movie", ImageTags: {Primary: "poster"}})
    end for
    library = BuildLibraryRows(items)
    AssertEqual(library.GetChildCount(), 3, "catalog uses six-column portrait rows")
    AssertEqual(library.GetChild(0).GetChildCount(), 6, "first portrait row has six titles")
    AssertEqual(library.GetChild(2).GetChildCount(), 1, "partial last portrait row retains remaining title")
    AssertEqual(library.GetChild(0).GetChild(0).portrait, true, "catalog content identifies portrait geometry")
    AssertEqual(Instr(1, library.GetChild(0).GetChild(0).HDPosterUrl, "/Images/Primary") > 0, true, "catalog uses portrait primary artwork")
    TestListPayloads()
    TestParallelHome()
    TestShowPageBatch()
    TestAutoplayPrefetch()
    TestRecentProof()
    TestCardFields()
    TestSeriesBrowseBatch()
    TestSegmentsBatch()
    TestCardImages()
    TestHomeCache()
    TestPrefetchCache()
    TestDetailsExtras()
    TestProfiles()
    TestLibraryFilters()
    print "PASS: "; m.assertions; " native assertions"
end sub

' Cyberpunk: Mercenários T2 E2 adds a forced Japanese track at index 6, so every
' later subtitle moves up one index compared with E1.
function ShiftedEpisodeSource() as Object
    return {MediaStreams: [
        {Type: "Audio", Index: 1, Language: "jpn", Codec: "eac3", DisplayTitle: "Japanese - Dolby Digital+"}
        {Type: "Audio", Index: 2, Language: "eng", Codec: "eac3", DisplayTitle: "English - Dolby Digital+"}
        {Type: "Subtitle", Index: 3, Language: "eng", Codec: "subrip", DisplayTitle: "English - SUBRIP"}
        {Type: "Subtitle", Index: 6, Language: "jpn", Codec: "subrip", Title: "Forced", IsForced: true, DisplayTitle: "Forced - Japanese"}
        {Type: "Subtitle", Index: 7, Language: "jpn", Codec: "subrip", DisplayTitle: "Japanese - SUBRIP"}
        {Type: "Subtitle", Index: 32, Language: "por", Codec: "subrip", Title: "Brazilian", DisplayTitle: "Brazilian - Portuguese - SUBRIP"}
        {Type: "Subtitle", Index: 33, Language: "por", Codec: "subrip", Title: "European", DisplayTitle: "European - Portuguese - SUBRIP"}
    ]}
end function

sub TestSeriesTrackMemory()
    persisted = m.persistCount
    Dispatch({action: "rememberTracks", seriesId: "cyberpunk", kind: "subtitle", track: {language: "por", title: "Brazilian", label: "Brazilian - Portuguese - SUBRIP", codec: "subrip", forced: false, external: false, index: 31}})
    Dispatch({action: "rememberTracks", seriesId: "cyberpunk", kind: "audio", track: {language: "jpn", title: "", label: "Japanese - Dolby Digital+", codec: "eac3"}})
    AssertEqual(m.persistCount, persisted + 2, "each remembered choice is persisted")
    AssertEqual(m.saved.seriesTracks.cyberpunk.subtitle.title, "Brazilian", "subtitle choice stored per series")
    AssertEqual(m.saved.seriesTracks.cyberpunk.subtitle.index, invalid, "stream index is not stored, it shifts between episodes")
    source = ShiftedEpisodeSource()
    AssertEqual(RememberedStreamIndex(source, "Subtitle", m.saved.seriesTracks.cyberpunk.subtitle), 32, "Brazilian Portuguese found after indices shift")
    AssertEqual(RememberedStreamIndex(source, "Audio", m.saved.seriesTracks.cyberpunk.audio), 1, "Japanese audio found by language")
    AssertEqual(RememberedStreamIndex(source, "Subtitle", {language: "jpn", label: "Japanese - SUBRIP", codec: "subrip"}), 7, "a full Japanese track never picks the forced one")
    AssertEqual(RememberedStreamIndex(source, "Subtitle", {language: "jpn", title: "Forced", forced: true}), 6, "a forced choice stays forced")
    AssertEqual(RememberedStreamIndex(source, "Subtitle", {language: "pt-BR", label: "Portuguese (Brazil)"}), 32, "pt-BR and por name the same language")
    AssertEqual(RememberedStreamIndex(source, "Subtitle", {language: "fre"}), invalid, "a language the episode lacks falls back to defaults")
    AssertEqual(RememberedStreamIndex(source, "Subtitle", {off: true}), -1, "Off is remembered as Off")
    Dispatch({action: "rememberTracks", seriesId: "", kind: "audio", track: {language: "eng"}})
    Dispatch({action: "rememberTracks", seriesId: "film", kind: "video", track: {language: "eng"}})
    AssertEqual(m.saved.seriesTracks.film, invalid, "only audio and subtitle choices are stored")
    for index = 1 to 21
        Dispatch({action: "rememberTracks", seriesId: "series" + index.ToStr(), kind: "subtitle", track: {off: true}})
    end for
    AssertEqual(m.saved.seriesTrackOrder.Count(), 20, "only the 20 most recent series are kept")
    AssertEqual(m.saved.seriesTracks.cyberpunk, invalid, "the oldest series is dropped first")
    AssertEqual(m.saved.seriesTracks.series21.subtitle.off, true, "the newest series is kept")
end sub

sub TestNextEpisode()
    m.calls = []
    m.responses = [{ok: true, data: {Items: [{Id: "s2e1", Name: "Now"}, {Id: "s2e2", Name: "Next", SeriesId: "cyberpunk", Chapters: []}]}}]
    nextItem = NextEpisode("cyberpunk", "s2e1")
    AssertEqual(nextItem.Id, "s2e2", "the episode after the current one is next")
    found = false
    for each call in m.calls
        if Instr(1, call.path, "/Shows/cyberpunk/Episodes?") = 1 and Instr(1, call.path, "StartItemId=s2e1") > 0 and Instr(1, call.path, "Limit=2") > 0 then found = true
    end for
    AssertEqual(found, true, "next episode comes from the series list starting at the current item")
    m.responses = [{ok: true, data: {Items: [{Id: "s1e9", Name: "Finale"}]}}]
    AssertEqual(NextEpisode("dutton", "s1e9"), invalid, "the final episode has no next")
    m.responses = [{ok: true, data: {Items: [{Id: "s1e1"}, {Id: "s1e2"}]}}]
    AssertEqual(NextEpisode("dutton", "s1e5"), invalid, "a list that does not start at the current item is not trusted")
    m.calls = []
    AssertEqual(NextEpisode("", "movie"), invalid, "movies have no next episode")
    AssertEqual(m.calls.Count(), 0, "movies make no episode request")
end sub

' MediaSources (every track of every file) was ~80% of list payloads and unused.
sub TestListPayloads()
    ResetState()
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    empty = {ok: true, data: {Items: []}}
    m.responses = [verify, empty, empty, empty, empty]
    result = Dispatch({action: "home"})
    AssertEqual(result.ok, true, "home loads with lightweight lists")
    heavy = 0
    for each call in m.calls
        if Instr(1, call.path, "MediaSources") > 0 then heavy++
    end for
    AssertEqual(heavy, 0, "home lists never ask for MediaSources")
    m.calls = []
    m.responses = [empty]
    Dispatch({action: "browse", kind: "Movie", offset: 0})
    AssertEqual(m.calls.Count(), 1, "browsing right after Home reuses the server proof")
    AssertEqual(Instr(1, m.calls[0].path, "MediaSources"), 0, "library pages never ask for MediaSources")
end sub

sub TestParallelHome()
    ResetState()
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    one = {ok: true, data: {Items: [{Id: "one", Name: "One", Type: "Movie"}]}}
    empty = {ok: true, data: {Items: []}}
    m.responses = [verify, one, empty, empty, one]
    result = Dispatch({action: "home"})
    AssertEqual(m.calls.Count(), 5, "home is one identity check plus one batch of four lists")
    AssertEqual(result.content.GetChild(0).title, "Continue assistindo", "batched rows keep their order")
    AssertEqual(result.content.GetChild(1).title, "Séries para maratonar", "empty rows are still skipped")
    ResetState()
    m.responses = [verify, one, {ok: false, code: 401, message: "expired"}, empty, empty, {ok: false, code: 401, message: "expired"}]
    result = Dispatch({action: "home"})
    AssertEqual(m.calls.Count(), 6, "a list needing re-login retries once through Api")
    AssertEqual(m.calls[5].path, m.calls[2].path, "only the failed list is retried")
    AssertEqual(result.code, 401, "an unrecoverable session still reports sign-in")
end sub

sub TestShowPageBatch()
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    show = {ok: true, data: {Id: "show", Name: "Show", Type: "Series"}}
    episodes = {ok: true, data: {Items: [{Id: "e1", Name: "One", Type: "Episode", SeriesId: "show", ParentIndexNumber: 1, IndexNumber: 1}, {Id: "e2", Name: "Two", Type: "Episode", SeriesId: "show", ParentIndexNumber: 1, IndexNumber: 2}]}}
    nextUp = {ok: true, data: {Items: [{Id: "e2", Name: "Two", Type: "Episode", SeriesId: "show", ParentIndexNumber: 1, IndexNumber: 2}]}}
    similar = {ok: true, data: {Items: [{Id: "other", Name: "Other", Type: "Series"}]}}
    ResetState()
    m.responses = [verify, show, episodes, nextUp, similar]
    result = Dispatch({action: "details", itemId: "show", kind: "Series"})
    AssertEqual(m.calls.Count(), 5, "a show page is one identity check plus one batch of four")
    AssertEqual(Instr(1, m.calls[4].path, "/Items/show/Similar") = 1, true, "Mais como este rides in the same batch")
    AssertEqual(result.content.GetChild(result.content.GetChildCount() - 1).title, "Mais como este", "similar titles follow the seasons")
    AssertEqual(Instr(1, m.calls[2].path, "/Shows/show/Episodes") > 0, true, "episodes come in the show's batch")
    AssertEqual(Instr(1, m.calls[3].path, "/Shows/NextUp") > 0, true, "next-up comes in the show's batch")
    AssertEqual(result.content.GetChild(0).title, "Temporada 1", "season rails are built from the batch")
    AssertEqual(result.nextUp.Id, "e2", "next-up comes from the batch")
    AssertEqual(result.nextUpLocation[1], 1, "the rail lands on next-up")
    AssertEqual(Instr(1, m.calls[2].path, "Chapters"), 0, "the episode list leaves chapters to playback")
    AssertEqual(Instr(1, m.calls[3].path, "Chapters") > 0, true, "next-up keeps chapters for the hero's Play")
    ResetState()
    m.responses = [verify, show, episodes, {ok: true, data: {Items: []}}, similar, {ok: true, data: {Id: "e1", Name: "One", Type: "Episode", Chapters: [{Name: "Intro", StartPositionTicks: 0}]}}]
    result = Dispatch({action: "details", itemId: "show", kind: "Series"})
    AssertEqual(result.nextUp.Chapters.Count(), 1, "a first-episode fallback is fetched in full, chapters included")
    ResetState()
    m.responses = [verify, show, episodes, nextUp, similar]
    result = Dispatch({action: "details", itemId: "show"})
    AssertEqual(m.calls.Count(), 5, "without a hint the show comes first, then episodes and next-up together, then similar")
    AssertEqual(result.nextUp.Id, "e2", "unhinted show pages still find next-up")
    ResetState()
    m.responses = [verify, {ok: true, data: {Id: "film", Name: "Film", Type: "Movie"}}, episodes, nextUp, similar]
    result = Dispatch({action: "details", itemId: "film", kind: "Series"})
    AssertEqual(result.ok, true, "a wrong hint still opens the title")
    AssertEqual(result.content.GetChild(0).title, "Mais como este", "a wrong hint builds no season rails")
end sub

sub TestAutoplayPrefetch()
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    film = {ok: true, data: {Id: "film", Name: "Film", Type: "Movie", RunTimeTicks: 100}}
    catalog = {ok: true, data: {MediaSources: [{Id: "v1", MediaStreams: []}]}}
    ResetState()
    m.playbackCatalog = invalid
    m.responses = [verify, film, catalog]
    result = Dispatch({action: "details", itemId: "film", kind: "Movie", autoplay: true})
    AssertEqual(result.item.Id, "film", "a card that plays at once still returns its details")
    AssertEqual(m.calls.Count(), 3, "item and stream catalog come in one batch")
    AssertEqual(Instr(1, m.calls[2].path, "/Items/film/PlaybackInfo?UserId=viewer"), 1, "the batch asks for the same catalog playback reads")
    calls = m.calls.Count()
    cached = PlaybackCatalog("film")
    AssertEqual(m.calls.Count(), calls, "playback reuses the prefetched catalog")
    AssertEqual(cached.data.MediaSources[0].Id, "v1", "the cached catalog is the prefetched one")
    ResetState()
    m.playbackCatalog = invalid
    m.responses = [verify, film, {ok: true, data: {Items: []}}]
    Dispatch({action: "details", itemId: "film", kind: "Movie"})
    AssertEqual(Instr(1, m.calls[2].path, "/Similar") > 0, true, "opening a page that will not play fetches similar titles, not a catalog")
    AssertEqual(m.playbackCatalog, invalid, "nothing is cached for a page that will not play")
end sub

sub TestRecentProof()
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    film = {ok: true, data: {Id: "film", Name: "Film", Type: "Episode"}}
    ResetState()
    m.responses = [verify, film, film]
    Dispatch({action: "details", itemId: "film"})
    Dispatch({action: "details", itemId: "film"})
    AssertEqual(m.calls.Count(), 3, "a second action moments later reuses the server proof")
    AssertEqual(m.calls[2].token, "saved-token", "the reused proof still sends the token only to the proven address")
    m.verifiedAt = invalid
    m.verifiedBase = invalid
    ResetState()
    m.responses = [verify, film]
    Dispatch({action: "details", itemId: "film"})
    m.account.base = "http://new:8096"
    m.responses = [{ok: true, data: {ProductName: "Jellyfin Server", Id: "other"}}]
    m.discovery = []
    calls = m.calls.Count()
    result = Dispatch({action: "details", itemId: "film"})
    AssertEqual(m.calls[calls].path, "/System/Info/Public", "a new address is proven again before any token")
    AssertEqual(m.calls[calls].token, "", "the new address never receives the token")
    AssertEqual(result.ok, false, "a different server at the new address is refused")
    ResetState()
    m.responses = [verify, {ok: false, code: 0, message: "offline"}]
    m.discovery = []
    Dispatch({action: "details", itemId: "film"})
    AssertEqual(m.verifiedAt, invalid, "a network failure forgets the proof")
end sub

sub TestCardFields()
    ResetState()
    card = MakeCard({Id: "e1", Type: "Episode", Name: "Pilot", SeriesName: "Show", SeriesId: "show", ParentIndexNumber: 2, IndexNumber: 1, Genres: ["Drama"], ProductionYear: 2024, OfficialRating: "16", Overview: "Long synopsis", UserData: {PlaybackPositionTicks: 5}, ImageTags: {Primary: "x"}, RunTimeTicks: 100, People: [{Name: "Actor"}]})
    AssertEqual(card.raw.SeriesName, "Show", "cards keep the show name for tile titles")
    AssertEqual(card.raw.IndexNumber, 1, "cards keep episode numbers for rails and the hero")
    AssertEqual(card.raw.Genres[0], "Drama", "cards keep genres for the hero line")
    AssertEqual(card.raw.Overview, invalid, "the synopsis travels once, as the card description")
    AssertEqual(card.raw.UserData, invalid, "progress travels once, as the card progress")
    AssertEqual(card.raw.People, invalid, "fields no card reads stay in the Task")
    AssertEqual(card.description, "Long synopsis", "the description still carries the synopsis")
end sub

sub TestSeriesBrowseBatch()
    ResetState()
    m.seasonPosters = invalid
    m.seasonPosterClock = invalid
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    shows = {ok: true, data: {Items: [{Id: "cp", Name: "Cyberpunk", Type: "Series"}], TotalRecordCount: 1}}
    seasons = {ok: true, data: {Items: [{Id: "s1", SeriesId: "cp", IndexNumber: 1, ImageTags: {Primary: "a"}}, {Id: "s2", SeriesId: "cp", IndexNumber: 2, ImageTags: {Primary: "b"}}]}}
    m.responses = [verify, shows, seasons]
    result = Dispatch({action: "browse", kind: "Series", offset: 0})
    AssertEqual(m.calls.Count(), 3, "the first Séries page fetches shows and season posters together")
    AssertEqual(Instr(1, m.calls[2].path, "IncludeItemTypes=Season") > 0, true, "the season index rides in the same batch")
    AssertEqual(Instr(1, result.content.GetChild(0).GetChild(0).HDPosterUrl, "/Items/s2/Images/Primary") > 0, true, "the newest season's poster shows on the first visit")
    calls = m.calls.Count()
    m.responses = [shows]
    Dispatch({action: "browse", kind: "Series", offset: 0})
    AssertEqual(m.calls.Count(), calls + 1, "a second visit reuses the season index")
    m.seasonPosters = invalid
end sub

sub TestSegmentsBatch()
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    segments = {ok: true, data: {Items: [{Type: "Intro", StartTicks: 0, EndTicks: 300000000}]}}
    none = {ok: true, data: {Items: [{Id: "e1"}]}}
    ResetState()
    m.responses = [verify, segments, none, {ok: true, data: {Items: [{Id: "e1"}, {Id: "e2", Name: "Two"}]}}]
    result = Dispatch({action: "segments", itemId: "e1", seriesId: "show"})
    AssertEqual(m.calls.Count(), 4, "an episode's segments, thumbnails and next episode come in one batch")
    AssertEqual(result.segments[0].kind, "Intro", "segments still parse from the batch")
    AssertEqual(result.nextEpisode.Id, "e2", "the next episode still comes from the batch")
    AssertEqual(result.trickplay, invalid, "an item without thumbnails gets no preview")
    sheets = {Width: 320, Height: 134, TileWidth: 5, TileHeight: 5, ThumbnailCount: 700, Interval: 10000}
    small = {Width: 160, Height: 67, TileWidth: 5, TileHeight: 5, ThumbnailCount: 700, Interval: 10000}
    trick = {ok: true, data: {Items: [{Id: "film", Trickplay: {other: {"160": small}, src1: {"160": small, "320": sheets}}}]}}
    ResetState()
    m.responses = [verify, segments, trick]
    result = Dispatch({action: "segments", itemId: "film", mediaSourceId: "src1"})
    AssertEqual(m.calls.Count(), 3, "a film asks for its segments and thumbnails")
    AssertEqual(Instr(1, m.calls[2].path, "Fields=Trickplay") > 0, true, "thumbnail sheets are described by the item")
    AssertEqual(result.nextEpisode, invalid, "a film has no next episode")
    AssertEqual(result.trickplay.width, 320, "the 320 px sheets are chosen for the preview")
    AssertEqual(result.trickplay.prefix, "http://old:8096/Videos/film/Trickplay/320/", "sheets come from the playing item")
    AssertEqual(result.trickplay.suffix, ".jpg?MediaSourceId=src1&ApiKey=saved-token", "sheets belong to the file being played and need the session")
    ResetState()
    m.responses = [verify, segments, trick]
    result = Dispatch({action: "segments", itemId: "film", mediaSourceId: "missing"})
    AssertEqual(result.trickplay <> invalid, true, "an unknown file id still finds the item's sheets")
end sub

sub TestCardImages()
    ResetState()
    AssertEqual(BlurHashColor("LEHV6nWB2yk8pyo0adR*.7kCMdnj"), "0x979695ff", "the blurhash reference image averages to its known colour")
    AssertEqual(BlurHashColor("djLW;M-:E2kC"), "0xbaaca2ff", "a live library hash decodes to its average colour")
    AssertEqual(BlurHashColor("L"), "", "a malformed hash gives no colour")
    film = {Id: "f", Type: "Movie", Name: "Film", BackdropImageTags: ["b"], ImageBlurHashes: {Backdrop: {b: "djLW;M-:E2kC"}, Primary: {p: "LEHV6nWB2yk8pyo0adR*.7kCMdnj"}}}
    card = MakeCard(film)
    AssertEqual(card.placeholder, "0xbaaca2ff", "a landscape tile uses its backdrop's colour")
    AssertEqual(Instr(1, card.HDPosterUrl, "maxWidth=400") > 0, true, "tiles download near their on-screen size")
    library = BuildLibraryRows([film])
    AssertEqual(library.GetChild(0).GetChild(0).placeholder, "0x979695ff", "a poster uses its primary image's colour")
    AssertEqual(Instr(1, library.GetChild(0).GetChild(0).HDPosterUrl, "maxWidth=240") > 0, true, "posters download near their on-screen size")
    AssertEqual(MakeCard({Id: "x", Type: "Movie"}).placeholder, "", "no hash, no colour")
end sub

sub TestHomeCache()
    ResetState()
    lists = [[{Id: "e1", Name: "Ep", Type: "Episode", SeriesName: "Show"}], [], [{Id: "f1", Name: "Film", Type: "Movie"}], []]
    cached = HomeFromCache({serverId: "saved", userId: "viewer", lists: lists})
    AssertEqual(cached.content.GetChildCount(), 2, "the cached Home rebuilds its non-empty rows")
    AssertEqual(cached.content.GetChild(0).title, "Continue assistindo", "cached rows keep their titles")
    AssertEqual(cached.userName, "Viewer", "the sidebar name comes with the cache")
    AssertEqual(Instr(1, cached.content.GetChild(0).GetChild(0).HDPosterUrl, "api_key"), 0, "cached artwork carries no token")
    AssertEqual(m.account, invalid, "building the cache never activates the account")
    AssertEqual(HomeFromCache({serverId: "other", userId: "viewer", lists: lists}), invalid, "another server's Home is never shown")
    AssertEqual(HomeFromCache({serverId: "saved", userId: "someone", lists: lists}), invalid, "another user's Home is never shown")
    m.saved.accounts.saved.token = ""
    AssertEqual(HomeFromCache({serverId: "saved", userId: "viewer", lists: lists}), invalid, "a signed-out account gets no cached Home")
    ResetState()
    m.responses = [{ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}, {ok: true, data: {Items: [{Id: "e1"}]}}, {ok: true, data: []}, {ok: true, data: {Items: []}}, {ok: true, data: {Items: []}}]
    Dispatch({action: "home"})
    AssertEqual(m.homeCacheLists.Count(), 4, "a loaded Home is queued for the launch cache")
    AssertEqual(m.homeCacheLists[0][0].Id, "e1", "the cache keeps each row's items")
    m.homeCacheLists = invalid
end sub

sub TestPrefetchCache()
    ResetState()
    m.detailsCache = {}
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    film = {ok: true, data: {Id: "film", Name: "Film", Type: "Movie"}}
    similar = {ok: true, data: {Items: []}}
    m.responses = [verify, film, similar]
    ack = Dispatch({action: "prefetch", itemId: "film", kind: "Movie"})
    AssertEqual(ack.item, invalid, "a prefetch keeps the page in the Task, not the UI")
    calls = m.calls.Count()
    again = Dispatch({action: "prefetch", itemId: "film", kind: "Movie"})
    AssertEqual(m.calls.Count(), calls, "a page already fetched ahead is not fetched again")
    result = Dispatch({action: "details", itemId: "film", kind: "Movie"})
    AssertEqual(m.calls.Count(), calls, "OK opens a prefetched page without the network")
    AssertEqual(result.item.Id, "film", "the prefetched page is the right one")
    m.responses = [film, similar]
    Dispatch({action: "details", itemId: "film", kind: "Movie"})
    AssertEqual(m.calls.Count(), calls + 2, "a prefetched page is used once")
    m.responses = [film, {ok: true, data: {MediaSources: []}}]
    Dispatch({action: "prefetch", itemId: "film", kind: "Movie", autoplay: true})
    calls = m.calls.Count()
    m.responses = [film, similar]
    result = Dispatch({action: "details", itemId: "film", kind: "Movie"})
    AssertEqual(m.calls.Count(), calls + 2, "a page fetched to play is not reused as an info page without its rows")
    m.responses = [film, similar]
    Dispatch({action: "prefetch", itemId: "film", kind: "Movie"})
    Dispatch({action: "report", event: "stopped", body: {}})
    AssertEqual(m.detailsCache.Count(), 0, "stopping playback drops pages with old progress")
end sub

sub TestDetailsExtras()
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    people = [{Id: "p1", Name: "Russell Crowe", Role: "Hermann Göring", Type: "Actor", PrimaryImageTag: "t"}, {Id: "p2", Name: "Director Name", Type: "Director"}, {Id: "p1", Name: "Russell Crowe", Type: "Producer"}]
    film = {ok: true, data: {Id: "nur", Name: "Nuremberg", Type: "Movie", People: people}}
    similar = {ok: true, data: {Items: [{Id: "s1", Name: "Similar", Type: "Movie"}]}}
    ResetState()
    m.responses = [verify, film, similar]
    result = Dispatch({action: "details", itemId: "nur", kind: "Movie"})
    cast = result.content.GetChild(0)
    AssertEqual(cast.title, "Elenco e equipe", "a film page starts its rows with cast and crew")
    AssertEqual(cast.rowStyle, "person", "the cast row is drawn as portraits")
    AssertEqual(cast.GetChildCount(), 2, "each person appears once")
    AssertEqual(cast.GetChild(0).caption, "Hermann Göring", "actors show their character")
    AssertEqual(cast.GetChild(1).caption, "Direção", "crew show their job in Portuguese")
    AssertEqual(Instr(1, cast.GetChild(0).HDPosterUrl, "/Items/p1/Images/Primary") > 0, true, "portraits come from the person's photo")
    AssertEqual(cast.GetChild(1).HDPosterUrl, "", "people without a photo get none")
    AssertEqual(result.content.GetChild(1).title, "Mais como este", "similar titles follow the cast")
    ResetState()
    m.responses = [verify, {ok: true, data: {Id: "p1", Name: "Russell Crowe", Type: "Person", Overview: "Bio"}}, {ok: true, data: {Items: [{Id: "nur", Name: "Nuremberg", Type: "Movie", BackdropImageTags: ["b"]}]}}]
    result = Dispatch({action: "details", itemId: "p1", kind: "Person"})
    AssertEqual(result.content.GetChild(0).title, "Na sua biblioteca", "a person's page lists their titles here")
    AssertEqual(Instr(1, m.calls[2].path, "PersonIds=p1") > 0, true, "titles are found by person")
    AssertEqual(Instr(1, result.card.backdrop, "/Items/nur/Images/Backdrop") > 0, true, "the person's page uses their first title's backdrop")
    AssertEqual(result.card.kind, "Person", "the page knows it is a person")
    ResetState()
    m.playbackCatalog = invalid
    m.responses = [verify, film, {ok: true, data: {MediaSources: []}}]
    result = Dispatch({action: "details", itemId: "nur", kind: "Movie", autoplay: true})
    AssertEqual(result.content, invalid, "a title that plays at once builds no extra rows")
end sub

sub TestProfiles()
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    empty = {ok: true, data: {Items: []}}
    ResetState()
    m.account.admin = invalid
    m.responses = [verify, empty, empty, empty, empty, {ok: true, data: {Id: "viewer", Name: "Viewer", Policy: {IsAdministrator: true}}}]
    result = Dispatch({action: "home"})
    AssertEqual(m.calls[5].path, "/Users/Me", "a session saved before profiles asks once, with Home, who it is")
    AssertEqual(result.canSwitchProfiles, true, "the administrator can switch profiles")
    AssertEqual(m.saved.accounts.saved.profiles.viewer.token, "saved-token", "the active profile is kept for switching back")
    calls = m.calls.Count()
    m.responses = [empty, empty, empty, empty]
    Dispatch({action: "home"})
    AssertEqual(m.calls.Count(), calls + 4, "once known, Home does not ask again")
    users = [{Id: "viewer", Name: "Viewer", HasPassword: true}, {Id: "kid", Name: "Kid", HasPassword: false}, {Id: "guest", Name: "Guest", HasPassword: true}, {Id: "old", Name: "Old", Policy: {IsDisabled: true}}]
    m.responses = [{ok: true, data: users}]
    result = Dispatch({action: "profiles"})
    AssertEqual(result.profiles.Count(), 3, "disabled users are not offered")
    AssertEqual(result.currentId, "viewer", "the list knows the active profile")
    calls = m.calls.Count()
    result = Dispatch({action: "switchProfile", userId: "guest", name: "Guest", hasPassword: true})
    AssertEqual(result.needsPassword, true, "a new profile with a password asks for it")
    AssertEqual(m.calls.Count(), calls, "nothing is sent before the password")
    m.responses = [{ok: false, code: 401, message: "denied"}]
    result = Dispatch({action: "switchProfile", userId: "guest", name: "Guest", hasPassword: true, password: "wrong"})
    AssertEqual(result.needsPassword, true, "a wrong password asks again instead of signing out")
    AssertEqual(m.account.userId, "viewer", "a wrong password leaves the active profile alone")
    m.responses = [{ok: true, data: {AccessToken: "guest-token", ServerId: "saved", User: {Id: "guest", Name: "Guest", Policy: {IsAdministrator: false}}}}]
    result = Dispatch({action: "switchProfile", userId: "guest", name: "Guest", hasPassword: true, password: "secret"})
    AssertEqual(m.calls[m.calls.Count() - 1].body.Username, "Guest", "the profile signs in by its name")
    AssertEqual(m.account.token, "guest-token", "the new profile becomes active")
    AssertEqual(result.canSwitchProfiles, true, "the administrator signed in here still unlocks switching")
    AssertEqual(m.saved.accounts.saved.profiles.guest.loginPassword, "secret", "the profile is kept so it never asks again")
    m.responses = [{ok: true, data: users}]
    result = Dispatch({action: "profiles"})
    AssertEqual(m.calls[m.calls.Count() - 1].token, "saved-token", "another profile lists users with the administrator's session")
    calls = m.calls.Count()
    result = Dispatch({action: "switchProfile", userId: "viewer", name: "Viewer", hasPassword: true})
    AssertEqual(m.calls.Count(), calls, "a profile kept here switches without the network")
    AssertEqual(m.account.token, "saved-token", "switching back restores the administrator's session")
    m.responses = [{ok: true, data: {AccessToken: "kid-token", ServerId: "saved", User: {Id: "kid", Name: "Kid"}}}]
    result = Dispatch({action: "switchProfile", userId: "kid", name: "Kid", hasPassword: false})
    AssertEqual(m.calls[m.calls.Count() - 1].body.Pw, "", "a profile without a password signs in without asking")
    AssertEqual(m.account.userId, "kid", "the passwordless profile becomes active")
    Dispatch({action: "logout"})
    AssertEqual(m.saved.accounts.saved.profiles.Count(), 0, "signing out forgets every profile on this server")
    ResetState()
    m.responses = [verify]
    result = Dispatch({action: "profiles"})
    AssertEqual(result.code, 403, "without an administrator here, profiles stay private")
end sub

sub TestLibraryFilters()
    verify = {ok: true, data: {ProductName: "Jellyfin Server", Id: "saved"}}
    empty = {ok: true, data: {Items: [], TotalRecordCount: 0}}
    ResetState()
    m.responses = [verify, empty]
    Dispatch({action: "browse", kind: "Movie", offset: 0, sort: "name", genreId: "g1", unwatched: true})
    path = m.calls[1].path
    AssertEqual(Instr(1, path, "SortBy=SortName&SortOrder=Ascending") > 0, true, "A–Z sorts by name")
    AssertEqual(Instr(1, path, "GenreIds=g1") > 0, true, "a genre filters the grid")
    AssertEqual(Instr(1, path, "Filters=IsUnplayed") > 0, true, "unwatched hides what was seen")
    m.responses = [empty]
    Dispatch({action: "browse", kind: "Movie", offset: 0, sort: "year"})
    AssertEqual(Instr(1, m.calls[2].path, "SortBy=PremiereDate") > 0, true, "release year sorts newest first")
    AssertEqual(Instr(1, m.calls[2].path, "GenreIds"), 0, "no genre means every genre")
    m.responses = [empty]
    result = Dispatch({action: "browse", kind: "BoxSet", offset: 0})
    AssertEqual(Instr(1, m.calls[3].path, "IncludeItemTypes=BoxSet") > 0, true, "collections browse as their own category")
    AssertEqual(result.title, "Coleções", "the category is named in Portuguese")
    m.responses = [{ok: true, data: {Items: [{Id: "g1", Name: "Ação"}, {Name: "No id"}]}}]
    result = Dispatch({action: "genres", kind: "Movie"})
    AssertEqual(result.genres.Count(), 1, "genres without an id are skipped")
    AssertEqual(result.genres[0].name, "Ação", "genre names keep their accents")
    m.responses = [{ok: true, data: {Id: "box", Name: "Box", Type: "BoxSet"}}, {ok: true, data: {Items: [{Id: "a", Name: "A", Type: "Movie"}]}}]
    result = Dispatch({action: "details", itemId: "box", kind: "BoxSet"})
    AssertEqual(result.content.GetChild(0).title, "Nesta coleção", "a collection's page lists its titles")
    AssertEqual(Instr(1, m.calls[m.calls.Count() - 1].path, "ParentId=box") > 0, true, "a collection's titles are its children")
end sub

sub ResetState()
    account = {id: "saved", base: "http://old:8096", name: "My cinema", token: "saved-token", userId: "viewer", userName: "Viewer", admin: false}
    m.saved = {activeId: "saved", accounts: {saved: account}, deviceId: "persistent-device"}
    m.account = account
    m.verified = true
    m.responses = []
    m.calls = []
    m.discovery = []
    m.discoveryCalls = 0
    m.persistCount = 0
    m.reconnectClock = invalid
    m.verifiedAt = invalid
end sub

function Http(base as String, path as String, method = "GET" as String, body = invalid as Dynamic, token = "" as String, timeout = 9000 as Integer) as Object
    m.calls.Push({base: base, path: path, method: method, token: token, body: body})
    if m.responses.Count() = 0 then return Failure("No fixture")
    return m.responses.Shift()
end function

' Parallel GETs replay through the same ordered Http fixture.
function HttpAll(base as String, paths as Object, token as String, timeout = 9000 as Integer) as Object
    results = []
    for each path in paths
        results.Push(Http(base, path, "GET", invalid, token, timeout))
    end for
    return results
end function

function Discover() as Object
    m.discoveryCalls++
    return m.discovery
end function

sub Persist()
    m.persistCount++
end sub

sub AssertEqual(actual as Dynamic, expected as Dynamic, description as String)
    if actual <> expected
        print "FAIL: "; description; " expected="; expected; " actual="; actual
        stop
    end if
    m.assertions++
end sub

' Encoding is a Roku network component boundary; all test IDs are ASCII.
function Encode(value as Dynamic) as String
    return TextValue(value)
end function
