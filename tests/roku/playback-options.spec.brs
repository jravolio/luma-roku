sub Main()
    m.assertions = 0
    TestMaximumQuality()
    TestRememberedTracks()
    TestDolbyAudio()
    ResetOptions()
    result = PreparePlayback({itemId: "item", title: "Film", ticks: 72000000000#, audioStreamIndex: 3, subtitleStreamIndex: 6, quality: "720p"})
    AssertEqual(result.ok, true, "actual audio and image subtitle indices negotiate")
    AssertEqual(m.calls[0].method, "GET", "catalog obtained before validating choices")
    AssertEqual(m.calls[1].body.AudioStreamIndex, 3, "audio index is not array position")
    AssertEqual(m.calls[1].body.SubtitleStreamIndex, 6, "PGS index sent to server")
    AssertEqual(m.calls[1].body.MediaSourceId, "version-a", "negotiation pins validated version")
    AssertEqual(m.calls[1].body.EnableDirectPlay, false, "selected captions force compatible stream")
    AssertEqual(m.calls[1].body.AllowVideoStreamCopy, false, "subtitle burn-in forces video conversion")
    AssertEqual(m.calls[1].body.AlwaysBurnInSubtitleWhenTranscoding, true, "caption rendering delegated to server")
    AssertEqual(m.calls[1].body.MaxStreamingBitrate, 6000000, "720p bitrate is actually constrained")
    AssertEqual(m.calls[1].body.StartTimeTicks, 72000000000#, "two-hour position retained through negotiation")
    AssertEqual(result.content.playStart, 7200, "native HLS receives absolute two-hour position once")
    AssertEqual(result.options.subtitleDelivery, "encoded", "burned subtitle delivery reported")
    AssertEqual(result.content.url, "http://server:8096/videos/item/master.m3u8?MediaSourceId=version-a&api_key=fixture", "dynamic HLS strips illegal resume query without changing other parameters")
    AssertEqual(result.positionOffsetTicks, 0, "dynamic HLS uses full original timeline, not an added offset")
    AssertEqual(result.options.selection.audioStreamIndex, 3, "effective selection keeps Jellyfin index")
    AssertEqual(result.options.audioTracks.Count(), 3, "all real audio tracks listed")
    AssertEqual(result.options.subtitleTracks.Count(), 3, "text and image captions all listed")
    AssertEqual(result.options.subtitleTracks[0].index, 0, "subtitle index zero is retained")
    AssertEqual(result.options.subtitleTracks[1].codec, "pgssub", "image subtitle metadata retained")
    AssertEqual(result.options.mediaSources.Count(), 2, "all available versions retained")
    AssertEqual(result.options.qualityOptions.Count(), 7, "seven meaningful quality options available")
    AssertEqual(result.session.AudioStreamIndex, 3, "reports include selected audio")
    AssertEqual(result.session.SubtitleStreamIndex, 6, "reports include selected subtitles")
    foundHeight = false
    for each condition in m.calls[1].body.DeviceProfile.CodecProfiles[0].Conditions
        if condition.Property = "Height" then foundHeight = condition.Value = "720"
    end for
    AssertEqual(foundHeight, true, "720p height constraint reaches device profile")
    AssertEqual(m.calls[1].body.DeviceProfile.SubtitleProfiles[1].Method, "Encode", "PGS codec has Encode profile")

    for each quality in PlaybackQualities()
        if quality.id <> "maximum"
        ResetOptions()
        result = PreparePlayback({itemId: "item", ticks: 0, quality: quality.id})
        AssertEqual(result.ok, true, quality.id + " negotiates")
        AssertEqual(m.calls[1].body.MaxStreamingBitrate, quality.maxBitrate, quality.id + " bitrate ceiling sent")
        for each condition in m.calls[1].body.DeviceProfile.CodecProfiles[0].Conditions
            if condition.Property = "Height" then AssertEqual(condition.Value, quality.maxHeight.ToStr(), quality.id + " height ceiling sent")
            if condition.Property = "Width" then AssertEqual(condition.Value, quality.maxWidth.ToStr(), quality.id + " width ceiling sent")
        end for
        end if
    end for

    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, subtitleStreamIndex: -1})
    AssertEqual(m.calls[1].body.SubtitleStreamIndex, -1, "Off explicitly disables server subtitle selection")
    AssertEqual(result.options.subtitleDelivery, "off", "Off has no encoded caption delivery")
    AssertEqual(result.options.selection.audioStreamIndex, 2, "default audio uses server's real index")

    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, subtitleStreamIndex: 0})
    AssertEqual(result.ok, true, "external text index zero is selectable")
    AssertEqual(m.calls[1].body.SubtitleStreamIndex, -1, "external text does not request burn-in")
    AssertEqual(result.options.subtitleDelivery, "external", "external SRT uses native delivery")
    AssertEqual(m.calls[1].body.AllowVideoStreamCopy, true, "external SRT does not force video encoding")
    AssertEqual(result.options.selection.subtitleStreamIndex, 0, "native subtitle index zero survives selection")
    AssertEqual(result.session.SubtitleStreamIndex, 0, "session reports retain selected native subtitle")
    AssertEqual(result.options.nativeSubtitleTracks.Count(), 1, "only external SRT is offered natively")
    AssertEqual(result.content.SubtitleTracks.Count(), 1, "native tracks are registered on ContentNode")
    AssertEqual(result.options.nativeSubtitleTracks[0].trackName, result.content.SubtitleTracks[0].TrackName, "selection mapping matches native TrackName exactly")
    AssertEqual(result.content.SubtitleTracks[0].TrackName, "http://server:8096/Videos/item/version-a/Subtitles/0/Stream.srt?StartPositionTicks=0&CopyTimestamps=true&api_key=fixture-token", "native SRT uses full timeline and verified source path")
    AssertEqual(m.calls.Count(), 2, "native subtitle metadata adds no HTTP request")

    ResetOptions()
    m.account.base = "http://server:8096/jellyfin"
    m.catalog[0].MediaStreams[0].Codec = "subrip"
    m.catalog[0].MediaStreams[0].Language = "pt-br"
    m.catalog[0].MediaStreams[0].DeliveryUrl = "http://foreign.invalid/captions.srt"
    result = PreparePlayback({itemId: "item", ticks: 72000000000#, subtitleStreamIndex: -1})
    AssertEqual(result.options.nativeSubtitleTracks.Count(), 1, "Off preloads native subtitle track metadata")
    AssertEqual(result.content.SubtitleTracks[0].Language, "por", "Roku caption language uses ISO639-2B")
    AssertEqual(result.options.nativeSubtitleTracks[0].language, "pt-br", "original Jellyfin language ID remains unchanged")
    AssertEqual(Instr(1, result.content.SubtitleTracks[0].TrackName, "http://server:8096/jellyfin/Videos/") = 1, true, "subtitle URL retains verified reverse-proxy base")
    AssertEqual(Instr(1, result.content.SubtitleTracks[0].TrackName, "foreign.invalid"), 0, "untrusted subtitle delivery URL is never used")

    ResetOptions()
    m.catalog[0].MediaStreams[0].IsExternal = false
    result = PreparePlayback({itemId: "item", ticks: 0, subtitleStreamIndex: 0})
    AssertEqual(result.options.subtitleDelivery, "encoded", "embedded text retains proven burn-in fallback")
    AssertEqual(m.calls[1].body.SubtitleStreamIndex, 0, "embedded text index reaches encoder")
    AssertEqual(m.calls[1].body.AllowVideoStreamCopy, false, "embedded text still forces encoding")

    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "original", subtitleStreamIndex: 0})
    AssertEqual(result.ok, true, "Original permits external SRT without modifying source video")
    AssertEqual(m.calls[1].body.EnableTranscoding, false, "Original with external captions never permits encoding")

    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, mediaSourceId: "version-b"})
    AssertEqual(result.ok, true, "alternate version negotiates")
    AssertEqual(result.session.MediaSourceId, "version-b", "alternate negotiated source selected by ID")
    AssertEqual(result.options.selection.audioStreamIndex, 8, "version change adopts its own default audio")
    AssertEqual(result.options.audioTracks[0].index, 8, "version's actual track list replaces old list")
    AssertEqual(result.options.nativeSubtitleTracks.Count(), 0, "version switch cannot retain old source caption URLs")
    AssertEqual(result.content.SubtitleTracks.Count(), 0, "caption-free source registers no native subtitle")

    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, mediaSourceId: "missing"})
    AssertEqual(result.ok, false, "invalid source rejected")
    AssertEqual(m.calls.Count(), 1, "invalid source never negotiates a different version")
    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, audioStreamIndex: 6})
    AssertEqual(result.ok, false, "subtitle index cannot masquerade as audio")
    AssertEqual(m.calls.Count(), 1, "invalid audio fails before POST")
    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, subtitleStreamIndex: 2})
    AssertEqual(result.ok, false, "audio index cannot masquerade as subtitle")
    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "4k"})
    AssertEqual(result.ok, false, "unsupported quality rejected")
    AssertEqual(m.calls.Count(), 0, "unsupported quality performs no network requests")

    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "original"})
    AssertEqual(result.ok, true, "compatible Original plays directly")
    AssertEqual(m.calls[1].body.EnableTranscoding, false, "Original never silently converts source")
    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "original", subtitleStreamIndex: 6})
    AssertEqual(result.ok, false, "Original with burn-in returns useful incompatibility")
    AssertEqual(Instr(1, result.message, "Automática") > 0, true, "Original incompatibility offers actionable recovery")
    AssertEqual(m.account.token, "fixture-token", "incompatible selection preserves login")
    ResetOptions()
    m.negotiated[0].SupportsDirectPlay = false
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "original"})
    AssertEqual(result.ok, false, "incompatible source does not quietly transcode Original")
    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "original"})
    AssertEqual(m.calls[1].body.DeviceProfile.DirectPlayProfiles.Count(), 1, "unverified device keeps conservative Original profile")
    ResetOptions()
    m.capabilities = {hevc4k: true, hevcMain10: true}
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "original"})
    AssertEqual(m.calls[1].body.DeviceProfile.DirectPlayProfiles.Count(), 2, "verified 4K HEVC device gains direct-play support")
    hevc = m.calls[1].body.DeviceProfile.CodecProfiles[2]
    AssertEqual(hevc.Codec, "hevc", "4K extension applies only to proven HEVC codec")
    AssertEqual(hevc.Conditions[1].Value, "2160", "verified Original permits original 4K height")
    AssertEqual(hevc.Conditions[3].Value, "10", "Main10 allowed only after positive capability query")
    AssertEqual(hevc.Conditions[4].Value, "25000000", "4K bitrate stays within documented Roku recommendation")
    AssertEqual(hevc.Conditions[5].Value, "SDR", "4K extension does not guess HDR support")
    AssertEqual(m.calls[1].body.EnableTranscoding, false, "4K Original never downscales through transcoding")
    AssertEqual(FullTimelineHlsUrl("http://server/master.m3u8?startTimeTicks=0"), "http://server/master.m3u8", "zero start ticks also removed")
    AssertEqual(FullTimelineHlsUrl("http://server/master.m3u8?A=1&STARTTIMETICKS=9&B=2&StartTimeTicks=0"), "http://server/master.m3u8?A=1&B=2", "all mixed-case duplicate start ticks removed")
    AssertEqual(FullTimelineHlsUrl("http://server/master.m3u8?StartTimeTicksOther=1&token=keep"), "http://server/master.m3u8?StartTimeTicksOther=1&token=keep", "only exact start-time key removed")
    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0})
    AssertEqual(m.calls[1].body.EnableDirectPlay, false, "multiple audio tracks use server-selected output, not guessed Roku track IDs")
    AssertEqual(FullTimelineHlsUrl("http://server/main.m3u8?startTimeTicks=72000000000&AudioStreamIndex=3"), "http://server/main.m3u8?AudioStreamIndex=3", "variant-shaped HLS URL also omits absolute resume query")
    ResetOptions()
    m.capabilities = {hevc4k: true, hevcMain10: true}
    m.catalog[0].Container = "mkv"
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "original"})
    AssertEqual(result.content.streamFormat, "mkv", "Original MKV uses the native MKV decoder format")
    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, audioStreamIndex: 3})
    AssertEqual(m.calls[1].body.AllowVideoStreamCopy, true, "audio selection preserves compatible source video")
    AssertEqual(m.calls[1].body.EnableDirectStream, true, "audio selection permits server remux")
    AssertEqual(m.calls[1].body.EnableDirectPlay, false, "static file cannot ignore selected audio")
    result = PreparePlayback({itemId: "item", ticks: 0, audioStreamIndex: 2})
    AssertEqual(m.calls.Count(), 3, "repeat switch reuses catalog but negotiates a fresh session")
    print "METRIC: two audio selections metadata GETs=1 negotiation POSTs=2 video copy=true"
    result = PreparePlayback({itemId: "item", ticks: 0, forceTranscode: true})
    AssertEqual(m.calls[3].body.AllowVideoStreamCopy, false, "decoder retry disables copying")
    m.account.token = "different-fixture"
    result = PreparePlayback({itemId: "item", ticks: 0})
    AssertEqual(m.calls.Count(), 6, "token change invalidates catalog")
    for each field in ["id", "base", "userId"]
        ResetOptions()
        result = PreparePlayback({itemId: "item", ticks: 0})
        m.account[field] = "changed"
        result = PreparePlayback({itemId: "item", ticks: 0})
        AssertEqual(m.calls.Count(), 4, field + " isolates cached catalog")
    end for
    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0})
    result = PreparePlayback({itemId: "another-item", ticks: 0})
    AssertEqual(m.calls.Count(), 4, "item change refreshes catalog")
    ResetOptions()
    m.catalog[0].IsInfiniteStream = true
    result = PreparePlayback({itemId: "item", ticks: 0})
    result = PreparePlayback({itemId: "item", ticks: 0})
    AssertEqual(m.calls.Count(), 4, "live source catalogs are never reused")
    ResetOptions()
    m.capabilities = {hevc4k: true, hevcMain10: false}
    result = PreparePlayback({itemId: "item", ticks: 0})
    profile = m.calls[1].body.DeviceProfile
    AssertEqual(profile.DirectPlayProfiles.Count(), 2, "Auto offers proven HEVC instead of gratuitous downscale")
    AssertEqual(profile.CodecProfiles[2].Conditions[1].Value, "2160", "Auto preserves supported 4K resolution")
    AssertEqual(profile.CodecProfiles[2].Conditions[3].Value, "8", "unproven Main10 remains excluded")
    AssertEqual(profile.MaxStreamingBitrate, 25000000, "Auto uses documented capability bitrate ceiling")
    AssertEqual(profile.CodecProfiles[0].Conditions[3].IsRequired, true, "unknown H264 bit depth cannot direct play")
    AssertEqual(profile.CodecProfiles[0].Conditions[4].Value, "baseline|constrained baseline|main|high", "H264 excludes unsupported high chroma profiles")
    AssertEqual(profile.CodecProfiles[0].Conditions[5].Value, "60", "H264 preserves 720p60 while level 4.1 bounds decoding")
    AssertEqual(profile.CodecProfiles[0].Conditions[7].Value, "SDR", "H264 HDR not optimistically advertised")
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "720p"})
    AssertEqual(m.calls[2].body.MaxStreamingBitrate, 6000000, "4K device respects explicit 720p bandwidth cap")
    AssertEqual(m.calls[2].body.DeviceProfile.DirectPlayProfiles.Count(), 1, "4K extension never overrides explicit resolution")
    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "720p", audioStreamIndex: 3})
    AssertEqual(m.calls[1].body.AllowVideoStreamCopy, true, "explicit quality keeps already-compatible video even when changing audio")
    AssertEqual(m.calls[1].body.AllowAudioStreamCopy, true, "compatible audio can also survive subtitle or track negotiation")
    m.playbackCatalog.clock = {TotalMilliseconds: ExpiredCatalogMilliseconds}
    result = PreparePlayback({itemId: "item", ticks: 0})
    AssertEqual(m.calls.Count(), 4, "expired catalog refreshes before negotiation")
    ResetOptions()
    m.capabilities = {hevc4k: true, hevcMain10: true, hdr10: true}
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "original"})
    AssertEqual(m.calls[1].body.DeviceProfile.CodecProfiles[2].Conditions[5].Value, "SDR|HDR10", "verified HDR10 display preserves original HDR10")
    AssertEqual(m.calls[1].body.DeviceProfile.CodecProfiles[2].Conditions[5].Condition, "EqualsAny", "HDR10 gate allows exact ranges only")
    ResetOptions()
    m.capabilities = {hevc4k: true, hevcMain10: false, hdr10: true}
    result = PreparePlayback({itemId: "item", ticks: 0})
    AssertEqual(m.calls[1].body.DeviceProfile.CodecProfiles[2].Conditions[5].Value, "SDR", "display HDR without Main10 decoder never enables HDR")
    ResetOptions()
    m.capabilities = {hevc4k: true, hevcMain10: true, hdr10: false}
    result = PreparePlayback({itemId: "item", ticks: 0})
    AssertEqual(m.calls[1].body.DeviceProfile.CodecProfiles[2].Conditions[5].Value, "SDR", "Main10 alone never proves HDR display")
    ResetOptions()
    m.catalog[0].Container = "matroska,webm"
    m.negotiated[0].Container = "mkv"
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "original"})
    AssertEqual(result.content.streamFormat, "mkv", "normalized negotiated container overrides ambiguous catalog")
    ResetOptions()
    m.capabilities = {hevc4k: true, hevcMain10: true, hdr10: false}
    m.catalog[0].Bitrate = 18000000
    m.catalog[0].MediaStreams.Push(HevcFixture())
    m.negotiated[0].TranscodingUrl = "/videos/item/master.m3u8?VideoCodec=hevc&MaxWidth=3840&MaxHeight=2160&VideoBitrate=24616000&TranscodeReasons=AudioCodecNotSupported"
    result = PreparePlayback({itemId: "item", ticks: 0, audioStreamIndex: 3})
    AssertEqual(m.calls[1].body.DeviceProfile.TranscodingProfiles[0].VideoCodec, "hevc", "verified 4K Auto isolates HEVC copy from H264 resolution caps")
    result = PreparePlayback({itemId: "item", ticks: 0, forceTranscode: true})
    AssertEqual(m.calls[2].body.DeviceProfile.TranscodingProfiles[0].VideoCodec, "h264", "decoder retry uses proven H264 fallback only")
    result = PreparePlayback({itemId: "item", ticks: 0, subtitleStreamIndex: 6})
    AssertEqual(m.calls[3].body.DeviceProfile.TranscodingProfiles[0].VideoCodec, "h264", "subtitle burn never requests HEVC encoder")
    result = PreparePlayback({itemId: "item", ticks: 0, quality: "1080p"})
    AssertEqual(m.calls[4].body.DeviceProfile.TranscodingProfiles[0].VideoCodec, "h264", "explicit H264 quality profile stays H264")
    ResetOptions()
    result = PreparePlayback({itemId: "item", ticks: 0})
    AssertEqual(m.calls[1].body.DeviceProfile.TranscodingProfiles[0].VideoCodec, "h264", "unverified device never advertises HEVC HLS")
    ResetOptions()
    m.capabilities = {hevc4k: true, hevcMain10: true, hdr10: false}
    m.catalog[0].Bitrate = 18000000
    m.catalog[0].MediaStreams.Push(HevcFixture())
    m.negotiated[0].TranscodingUrl = "/videos/item/master.m3u8?VideoCodec=hevc&MaxWidth=1920&MaxHeight=1080&VideoBitrate=24616000&TranscodeReasons=AudioCodecNotSupported"
    result = PreparePlayback({itemId: "item", ticks: 72000000000#, audioStreamIndex: 3})
    AssertEqual(result.ok, true, "contradictory HEVC response obtains compatible fallback")
    AssertEqual(m.calls.Count(), 3, "fallback reuses catalog and obtains a fresh negotiation")
    AssertEqual(m.calls[1].body.DeviceProfile.TranscodingProfiles[0].VideoCodec, "hevc", "first request preserves 4K source")
    AssertEqual(m.calls[2].body.DeviceProfile.TranscodingProfiles[0].VideoCodec, "h264", "fallback never requires HEVC encoding")
    AssertEqual(m.calls[2].body.AllowVideoStreamCopy, false, "fallback really converts rejected source")
    AssertEqual(m.calls[2].body.AudioStreamIndex, 3, "fallback retains selected audio")
    AssertEqual(m.calls[2].body.StartTimeTicks, 72000000000#, "fallback retains resume")
    for each field in ["Width", "Height", "Level", "BitDepth", "BitRate", "AverageFrameRate", "Profile", "VideoRangeType"]
        bad = HevcFixture()
        bad.Delete(field)
        AssertEqual(HevcCopySource({Bitrate: 18000000, MediaStreams: [bad]}, m.capabilities), invalid, field + " required before isolated copy negotiation")
    end for
    video = HevcFixture()
    video.Width = 4096
    AssertEqual(HevcCopySource({Bitrate: 18000000, MediaStreams: [video]}, m.capabilities), invalid, "overwidth cannot enter HEVC-only path")
    video = HevcFixture()
    video.VideoRangeType = "HDR10"
    AssertEqual(HevcCopySource({Bitrate: 18000000, MediaStreams: [video]}, m.capabilities), invalid, "unverified HDR10 cannot enter HEVC-only path")
    safe = "http://server:8096/videos/item/master.m3u8?VideoCodec=hevc&MaxWidth=3840&MaxHeight=2160&VideoBitrate=24616000&TranscodeReasons=AudioCodecNotSupported"
    verified = {width: 3840, height: 1600, bitrate: 17700000, fps: 24, level: 153, bitdepth: 10, profile: "Main 10", range: "SDR"}
    AssertEqual(HevcCopyUrlSafe(safe, verified), true, "unmodified server copy plan validated")
    AssertEqual(HevcCopyUrlSafe(safe + "&AllowVideoStreamCopy=false", verified), false, "server copy prohibition causes fallback")
    AssertEqual(HevcCopyUrlSafe(safe + "&VideoCodec=h264", verified), false, "duplicate negotiation controls fail closed")
    AssertEqual(HevcCopyUrlSafe(safe + "&MaxFramerate=20", verified), false, "server framerate reduction causes fallback")
    video = HevcFixture()
    video.VideoRangeType = "HDR10"
    video.Profile = "Main"
    video.BitDepth = 8
    AssertEqual(HevcCopySource({Bitrate: 18000000, MediaStreams: [video]}, {hevc4k: true, hevcMain10: true, hdr10: true}), invalid, "contradictory HDR10 metadata cannot request HEVC-only output")
    AssertEqual(HevcCopyUrlSafe("http://server:8096/videos/item/master.m3u8?VideoCodec=hevc&VideoBitrate=24616000&TranscodeReasons=DirectPlayError", verified), true, "disabled static playback does not reject an otherwise valid HEVC copy plan")
    AssertEqual(HevcCopyUrlSafe(safe + "&hevc-level=150", verified), false, "lower server HEVC level cannot silently re-encode")
    AssertEqual(HevcCopyUrlSafe(safe + "&hevc-videobitdepth=8", verified), false, "lower server bit depth cannot silently re-encode")
    AssertEqual(HevcCopyUrlSafe(safe + "&maxvideobitdepth=8", verified), false, "global lower bit depth cannot silently re-encode")
    AssertEqual(HevcCopyUrlSafe(safe + "&hevc-profile=main", verified), false, "Main-only response cannot silently re-encode Main10")
    AssertEqual(HevcCopyUrlSafe(safe + "&hevc-profile=main%2cmain%2010&hevc-level=153&hevc-videobitdepth=10", verified), true, "server encoded Main10 profile list preserves validated source")
    ResetOptions()
    m.capabilities = {hevc4k: true, hevcMain10: true, hdr10: false}
    m.catalog[0].Bitrate = 18000000
    m.catalog[0].MediaStreams.Push(HevcFixture())
    m.rejectHevcUrl = true
    result = PreparePlayback({itemId: "item", ticks: 0, audioStreamIndex: 3})
    AssertEqual(result.ok, true, "missing HEVC URL negotiates compatible H264 instead of reporting a foreign server")
    AssertEqual(m.calls.Count(), 3, "missing URL triggers exactly one fallback POST")
    AssertEqual(m.calls[2].body.DeviceProfile.TranscodingProfiles[0].VideoCodec, "h264", "missing URL fallback keeps H264 safety profile")
    m.calls = []
    m.rejectHevcUrl = false
    m.hevcErrorCode = "NoCompatibleStream"
    result = PreparePlayback({itemId: "item", ticks: 0, audioStreamIndex: 3})
    AssertEqual(result.ok, true, "explicit no-compatible-stream response retries H264")
    AssertEqual(m.calls.Count(), 2, "explicit rejection uses one bounded fallback with cached metadata")
    m.calls = []
    m.hevcErrorCode = "NotAllowed"
    result = PreparePlayback({itemId: "item", ticks: 0, audioStreamIndex: 3})
    AssertEqual(result.ok, false, "permission rejection never retries with different output")
    AssertEqual(m.calls.Count(), 1, "permission rejection has no fallback POST")
    m.calls = []
    m.hevcErrorCode = ""
    m.negotiated[0].TranscodingUrl = "http://different-server.invalid/videos/item/master.m3u8"
    result = PreparePlayback({itemId: "item", ticks: 0, audioStreamIndex: 3})
    AssertEqual(result.ok, false, "nonempty foreign HEVC URL remains fail closed")
    AssertEqual(m.calls.Count(), 1, "foreign URL never triggers fallback or token delivery")
    print "PASS: "; m.assertions; " playback option assertions"
end sub

sub RememberedFixture()
    ResetOptions()
    streams = [
        {Type: "Audio", Index: 1, Language: "jpn", Codec: "eac3", DisplayTitle: "Japanese - Dolby Digital+"}
        {Type: "Audio", Index: 2, Language: "eng", Codec: "eac3", DisplayTitle: "English - Dolby Digital+", IsDefault: true}
        {Type: "Subtitle", Index: 6, Language: "jpn", Codec: "subrip", Title: "Forced", IsForced: true, DisplayTitle: "Forced - Japanese"}
        {Type: "Subtitle", Index: 32, Language: "por", Codec: "subrip", Title: "Brazilian", DisplayTitle: "Brazilian - Portuguese - SUBRIP"}
        {Type: "Subtitle", Index: 33, Language: "por", Codec: "subrip", Title: "European", DisplayTitle: "European - Portuguese - SUBRIP"}
    ]
    m.catalog = [{Id: "version-a", Name: "1080p", DefaultAudioStreamIndex: 2, MediaStreams: streams}]
    m.saved.seriesTracks = {show: {audio: {language: "jpn", label: "Japanese - Dolby Digital+", codec: "eac3"}, subtitle: {language: "por", title: "Brazilian", label: "Brazilian - Portuguese - SUBRIP", codec: "subrip"}}}
end sub

sub TestRememberedTracks()
    RememberedFixture()
    result = PreparePlayback({itemId: "item", ticks: 0, seriesId: "show"})
    AssertEqual(result.ok, true, "an episode with remembered series tracks negotiates")
    AssertEqual(result.options.selection.audioStreamIndex, 1, "remembered Japanese audio starts the episode")
    AssertEqual(result.options.selection.subtitleStreamIndex, 32, "remembered Brazilian subtitles start the episode")
    AssertEqual(m.calls[1].body.AudioStreamIndex, 1, "remembered audio reaches Jellyfin")
    AssertEqual(m.calls[1].body.SubtitleStreamIndex, 32, "remembered subtitles reach Jellyfin")
    AssertEqual(result.session.SubtitleStreamIndex, 32, "reports carry the remembered subtitles")
    RememberedFixture()
    result = PreparePlayback({itemId: "item", ticks: 0, seriesId: "show", audioStreamIndex: 2, subtitleStreamIndex: -1})
    AssertEqual(result.options.selection.audioStreamIndex, 2, "an explicit choice in the player wins over memory")
    AssertEqual(result.options.selection.subtitleStreamIndex, -1, "an explicit Off wins over memory")
    RememberedFixture()
    result = PreparePlayback({itemId: "item", ticks: 0, seriesId: "show", quality: "original"})
    AssertEqual(result.ok, true, "Original quality still plays with remembered tracks around")
    AssertEqual(result.options.selection.audioStreamIndex, 2, "Original keeps the default audio it can play unchanged")
    AssertEqual(result.options.selection.subtitleStreamIndex, -1, "Original never burns in remembered subtitles")
    RememberedFixture()
    result = PreparePlayback({itemId: "item", ticks: 0, seriesId: "other"})
    AssertEqual(result.options.selection.audioStreamIndex, 2, "another series keeps the server default")
    AssertEqual(result.options.selection.subtitleStreamIndex, -1, "another series keeps subtitles off")
    RememberedFixture()
    result = PreparePlayback({itemId: "item", ticks: 0})
    AssertEqual(result.options.selection.audioStreamIndex, 2, "a movie keeps the server default")
end sub

sub TestDolbyAudio()
    ResetOptions()
    m.audioCaps = invalid
    PreparePlayback({itemId: "item", ticks: 0})
    profile = m.calls[1].body.DeviceProfile
    AssertEqual(profile.DirectPlayProfiles[0].AudioCodec, "aac,mp3", "without Dolby decoding the profile is unchanged")
    AssertEqual(profile.TranscodingProfiles[0].MaxAudioChannels, "2", "without Dolby conversions stay stereo")
    ResetOptions()
    m.audioCaps = {ac3: true, eac3: true}
    PreparePlayback({itemId: "item", ticks: 0})
    profile = m.calls[1].body.DeviceProfile
    AssertEqual(profile.DirectPlayProfiles[0].AudioCodec, "aac,mp3,ac3,eac3", "Dolby the TV decodes plays from the original file")
    AssertEqual(profile.TranscodingProfiles[0].AudioCodec, "aac,ac3,eac3", "AAC stays first for anything that must be converted")
    AssertEqual(profile.TranscodingProfiles[0].MaxAudioChannels, "6", "copied Dolby keeps its 5.1")
    dolby = invalid
    aac = invalid
    for each codecProfile in profile.CodecProfiles
        if codecProfile.Type = "VideoAudio" and codecProfile.Codec = "ac3,eac3" then dolby = codecProfile
        if codecProfile.Type = "VideoAudio" and codecProfile.Codec = "aac,mp3" then aac = codecProfile
    end for
    AssertEqual(dolby.Conditions[0].Value, "6", "Dolby is limited to the 5.1 the TV confirmed")
    AssertEqual(aac.Conditions[0].Value, "2", "converted AAC stays stereo")
    AssertEqual(m.calls[1].body.AllowAudioStreamCopy, true, "Dolby audio is copied, not re-encoded")
    ResetOptions()
    m.audioCaps = {ac3: false, eac3: true}
    PreparePlayback({itemId: "item", ticks: 0})
    AssertEqual(m.calls[1].body.DeviceProfile.DirectPlayProfiles[0].AudioCodec, "aac,mp3,eac3", "only codecs the TV confirmed are added")
    ResetOptions()
    m.audioCaps = {ac3: true, eac3: true}
    PreparePlayback({itemId: "item", ticks: 0, forceTranscode: true})
    AssertEqual(m.calls[1].body.AllowAudioStreamCopy, false, "compatible-mode recovery still converts audio")
    m.audioCaps = invalid
end sub

sub ResetOptions()
    m.account = {base: "http://server:8096", token: "fixture-token", userId: "viewer"}
    m.saved = {deviceId: "device"}
    m.verified = true
    m.capabilities = {hevc4k: false, hevcMain10: false}
    m.calls = []
    m.playbackCatalog = invalid
    m.rejectHevcUrl = false
    m.hevcErrorCode = ""
    streams = [
        {Type: "Subtitle", Index: 0, Codec: "srt", DisplayTitle: "English - External", IsExternal: true}
        {Type: "Audio", Index: 2, Codec: "aac", DisplayTitle: "Portuguese - Stereo", IsDefault: true}
        {Type: "Audio", Index: 3, Codec: "ac3", DisplayTitle: "English - Surround"}
        {Type: "Audio", Index: 4, Codec: "aac", DisplayTitle: "Commentary"}
        {Type: "Subtitle", Index: 6, Codec: "pgssub", DisplayTitle: "Portuguese - PGS"}
        {Type: "Subtitle", Index: 19, Codec: "ass", DisplayTitle: "English - ASS"}
    ]
    m.catalog = [{Id: "version-a", Name: "1080p Blu-ray", DefaultAudioStreamIndex: 2, MediaStreams: streams}, {Id: "version-b", Name: "720p Alternate", DefaultAudioStreamIndex: 8, MediaStreams: [{Type: "Audio", Index: 8, Codec: "aac", DisplayTitle: "English"}]}]
    m.negotiated = [{Id: "version-a", SupportsDirectPlay: true, TranscodingUrl: "/videos/item/master.m3u8?MediaSourceId=version-a&StartTimeTicks=72000000000&api_key=fixture"}, {Id: "version-b", SupportsDirectPlay: true, TranscodingUrl: "/videos/item-b/master.m3u8"}]
end sub

function Http(base as String, path as String, method = "GET" as String, body = invalid as Dynamic, token = "" as String, timeout = 9000 as Integer) as Object
    m.calls.Push({path: path, method: method, body: body})
    if method = "GET" then return {ok: true, data: {MediaSources: m.catalog}}
    if m.hevcErrorCode <> "" and body.DeviceProfile.TranscodingProfiles[0].VideoCodec = "hevc" then return {ok: true, data: {ErrorCode: m.hevcErrorCode}}
    if m.rejectHevcUrl and body.DeviceProfile.TranscodingProfiles[0].VideoCodec = "hevc"
        return {ok: true, data: {MediaSources: [{Id: "version-a", SupportsDirectPlay: false}], PlaySessionId: "session"}}
    end if
    return {ok: true, data: {MediaSources: m.negotiated, PlaySessionId: "session"}}
end function

function Encode(value as Dynamic) as String
    return TextValue(value)
end function

sub AssertEqual(actual as Dynamic, expected as Dynamic, description as String)
    if actual <> expected
        print "FAIL: "; description; " expected="; expected; " actual="; actual
        stop
    end if
    m.assertions++
end sub

function AudioCapabilities() as Object
    if IsMap(m.audioCaps) then return m.audioCaps
    return {ac3: false, eac3: false}
end function

function OriginalVideoCapabilities() as Object
    return m.capabilities
end function

function ExpiredCatalogMilliseconds() as Integer
    return 30000
end function

function HevcFixture() as Object
    return {Type: "Video", Codec: "hevc", Index: 1, Width: 3840, Height: 1600, Level: 153, BitDepth: 10, BitRate: 17700000, AverageFrameRate: 24, Profile: "Main 10", VideoRangeType: "SDR"}
end function

sub MaximumFixture()
    ResetOptions()
    m.capabilities = {hevc4k: true, hevcMain10: true, hdr10: true}
    video = HevcFixture()
    video.Height = 2160
    video.BitRate = 52731613
    video.VideoRangeType = "DOVIWithEL"
    video.DvProfile = 7
    video.DvBlSignalCompatibilityId = 6
    video.BlPresentFlag = 1
    video.ColorTransfer = "smpte2084"
    video.ColorPrimaries = "bt2020"
    video.ColorSpace = "bt2020nc"
    m.catalog[0].Bitrate = 58191682
    m.catalog[0].MediaStreams.Push(video)
    m.negotiated[0].TranscodingUrl = "/videos/item/master.m3u8?VideoCodec=hevc&MaxWidth=3840&MaxHeight=2160&VideoBitrate=64616000&SegmentLength=3&hevc-rangetype=SDR,HDR10&TranscodeReasons=AudioCodecNotSupported,VideoRangeTypeNotSupported"
end sub

sub TestMaximumQuality()
    MaximumFixture()
    result = PreparePlayback({itemId: "item", quality: "maximum", subtitleStreamIndex: 0})
    AssertEqual(result.ok, true, "Maximum preserves verified DV7 HDR10 base layer")
    body = m.calls[1].body
    AssertEqual(body.MaxStreamingBitrate, 65000000, "Maximum alone permits measured high bitrate")
    AssertEqual(body.DeviceProfile.TranscodingProfiles[0].VideoCodec, "hevc", "Maximum never requests HEVC encoder through H264 mixed constraints")
    AssertEqual(body.DeviceProfile.TranscodingProfiles[0].SegmentLength, 3, "Maximum balances physical media and playlist buffers")
    AssertEqual(body.EnableDirectPlay, false, "DV enhancement layer must pass through server stripping")
    AssertEqual(body.SubtitleStreamIndex, -1, "Maximum external SRT does not burn video")
    AssertEqual(result.options.subtitleDelivery, "external", "Maximum retains native caption switching")
    for each change in ["DvProfile", "DvBlSignalCompatibilityId", "BlPresentFlag", "ColorTransfer", "ColorPrimaries", "ColorSpace"]
        MaximumFixture()
        m.catalog[0].MediaStreams[6].Delete(change)
        result = PreparePlayback({itemId: "item", quality: "maximum"})
        AssertEqual(result.ok, false, "Maximum requires verified " + change)
        AssertEqual(m.calls.Count(), 1, "invalid source never negotiates lower quality")
    end for
    MaximumFixture()
    m.catalog[0].MediaStreams[6].DvProfile = 8
    result = PreparePlayback({itemId: "item", quality: "maximum"})
    AssertEqual(result.ok, false, "unknown DV profile cannot claim HDR10 base layer")
    MaximumFixture()
    m.catalog[0].MediaStreams[6].DvBlSignalCompatibilityId = 1
    result = PreparePlayback({itemId: "item", quality: "maximum"})
    AssertEqual(result.ok, false, "DV7 requires verified HDR10 compatibility ID6")
    for each field in ["hevc4k", "hevcMain10", "hdr10"]
        MaximumFixture()
        m.capabilities.Delete(field)
        result = PreparePlayback({itemId: "item", quality: "maximum"})
        AssertEqual(result.ok, false, "Maximum requires runtime " + field)
    end for
    MaximumFixture()
    verified = HevcCopySource(m.catalog[0], m.capabilities, true)
    safe = m.negotiated[0].TranscodingUrl
    AssertEqual(HevcCopyUrlSafe(safe, verified), true, "vetted DV7 permits stripping reason")
    for each replacement in ["SDR", "SDR,DOVIWithEL", "SDR,HDR10,DOVIWithEL"]
        AssertEqual(HevcCopyUrlSafe(safe.Replace("SDR,HDR10", replacement), verified), false, "Maximum demands HDR10 only negotiation")
    end for
    AssertEqual(HevcCopyUrlSafe(safe.Replace("SegmentLength=3", "SegmentLength=6"), verified), false, "Maximum rejects oversized segment configuration")
    verified.hdr10Base = false
    AssertEqual(HevcCopyUrlSafe(safe, verified), false, "range conversion reason denied without verified DV base")
    MaximumFixture()
    m.catalog[0].Bitrate = 65000001
    result = PreparePlayback({itemId: "item", quality: "maximum"})
    AssertEqual(result.ok, false, "Maximum retains65Mbps ceiling")
    MaximumFixture()
    m.capabilities.hdr10 = false
    result = PreparePlayback({itemId: "item", quality: "maximum"})
    AssertEqual(result.ok, false, "Maximum cannot assume HDR display")
    MaximumFixture()
    result = PreparePlayback({itemId: "item", quality: "maximum", subtitleStreamIndex: 6})
    AssertEqual(result.ok, false, "PGS cannot silently lower Maximum HDR quality")
    MaximumFixture()
    m.negotiated[0].TranscodingUrl += "&Height=1080"
    result = PreparePlayback({itemId: "item", quality: "maximum"})
    AssertEqual(result.ok, false, "Maximum refuses unexpected conversion")
    AssertEqual(m.calls.Count(), 2, "Maximum does not silently retry lower quality")
    MaximumFixture()
    result = PreparePlayback({itemId: "item", quality: "auto"})
    AssertEqual(m.calls[1].body.MaxStreamingBitrate, 25000000, "Maximum leaves Auto ceiling unchanged")
    MaximumFixture()
    result = PreparePlayback({itemId: "item", quality: "maximum", forceTranscode: true})
    AssertEqual(m.calls[1].body.DeviceProfile.TranscodingProfiles[0].VideoCodec, "h264", "explicit compatibility recovery remains available")
    AssertEqual(m.calls[1].body.MaxStreamingBitrate, 20000000, "explicit recovery keeps safe H264 cap")
end sub
