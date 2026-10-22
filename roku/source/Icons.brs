' Generated white PNGs share the web SVG geometry. Focus tints the existing texture.
function CreateAppIcon(parent as Object, name as String, x as Float, y as Float, size as Float) as Object
    icon = parent.CreateChild("Poster")
    icon.translation = [x, y]
    icon.width = size
    icon.height = size
    icon.loadDisplayMode = "scaleToFit"
    icon.uri = AppIconUri(name)
    return icon
end function

function AppIconUri(name as String) as String
    return "pkg:/images/icons/" + name + ".png"
end function
