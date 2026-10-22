function TextValue(value as Dynamic, fallback = "" as String) as String
    if value = invalid then return fallback
    return value.ToStr()
end function

function IsMap(value as Dynamic) as Boolean
    return Type(value) = "roAssociativeArray"
end function

function IsList(value as Dynamic) as Boolean
    return Type(value) = "roArray"
end function

function Encode(value as Dynamic) as String
    return CreateObject("roUrlTransfer").Escape(TextValue(value))
end function

' Keep the reverse-proxy base path; reject credentials, query strings and fragments.
function NormalizeBase(value as Dynamic) as String
    base = TextValue(value).Trim()
    if base = "" then return ""
    if Instr(1, base, "://") = 0 then base = "http://" + base
    pattern = CreateObject("roRegex", "^https?://[^/?#@ ]+(/[^?# ]*)?$", "i")
    if not pattern.IsMatch(base) then return ""
    while Right(base, 1) = "/"
        base = Left(base, Len(base) - 1)
    end while
    return base
end function

function Failure(message as String, code = 0 as Integer) as Object
    return {ok: false, message: message, code: code}
end function

function ItemArray(data as Dynamic) as Object
    if IsList(data) then return data
    if IsMap(data)
        if IsList(data.Items) then return data.Items
    end if
    return []
end function

function ResumeTicks(item as Object) as Double
    if IsMap(item.UserData)
        if item.UserData.PlaybackPositionTicks <> invalid then return item.UserData.PlaybackPositionTicks + 0#
    end if
    return 0#
end function

' Resolve Jellyfin's relative playback path without duplicating a reverse-proxy
' base path or forwarding authorization to a different origin.
function ResolveStreamUrl(base as String, relative as String) as String
    if relative = "" then return ""
    if Left(relative, 2) = "//" then return ""
    if Instr(1, relative, Chr(92)) > 0 then return ""
    if Instr(1, relative, "://") > 0
        if Left(relative, Len(base) + 1) = base + "/" then return relative
        return ""
    end if
    if Left(relative, 1) <> "/" then return base + "/" + relative
    origin = CreateObject("roRegex", "^(https?://[^/]+)", "i").Match(base)
    if origin.Count() < 2 then return ""
    basePath = Mid(base, Len(origin[1]) + 1)
    if basePath <> "" and Left(relative, Len(basePath) + 1) = basePath + "/" then return origin[1] + relative
    return base + relative
end function

' OS 16 supports native rounded panels. Older renderers retain legible square
' panels rather than referencing an unavailable node type.
sub ApplyRounded(node as Object, radius as Float)
    if not node.HasField("effect") then return
    effectType = "Effect" ' OS 16 node is newer than the bundled compiler schema.
    effect = CreateObject("roSGNode", effectType)
    if effect = invalid then return
    if not effect.supported then return
    effect.borderRadius = [radius]
    node.effect = effect
end sub

' Jellyfin 12.2 dynamic HLS exposes the full item timeline. StartTimeTicks in
' its URL propagates to segment routes that reject it; resume belongs solely
' in Video.playStart/seek, never in master/variant/segment query parameters.
function FullTimelineHlsUrl(url as String) as String
    question = Instr(1, url, "?")
    if question = 0 then return url
    base = Left(url, question - 1)
    query = Mid(url, question + 1)
    kept = ""
    remaining = query + "&"
    while remaining <> ""
        separator = Instr(1, remaining, "&")
        part = Left(remaining, separator - 1)
        remaining = Mid(remaining, separator + 1)
        equals = Instr(1, part, "=")
        key = part
        if equals > 0 then key = Left(part, equals - 1)
        if LCase(key) <> "starttimeticks" and part <> ""
            if kept <> "" then kept += "&"
            kept += part
        end if
    end while
    if kept = "" then return base
    return base + "?" + kept
end function
