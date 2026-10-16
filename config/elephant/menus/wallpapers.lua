-- Wallpaper picker (Ctrl+Alt+T): `walker -m menus:wallpapers`. Lists the images under
-- ~/Pictures/Wallpapers with a preview; the chosen one goes to awww, which remembers it.
Name = "wallpapers"
NamePretty = "Wallpapers"
Icon = "preferences-desktop-wallpaper"
-- The path arrives on stdin, so names with spaces or quotes are safe.
Action = 'awww img "$(cat)"'

function GetEntries()
    local entries = {}
    local dir = os.getenv("HOME") .. "/Pictures/Wallpapers"
    local handle = io.popen("find '" .. dir .. "' -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png'"
        .. " -o -iname '*.webp' -o -iname '*.gif' \\) 2>/dev/null | sort")
    if handle then
        for path in handle:lines() do
            table.insert(entries, {
                Text = path:sub(#dir + 2),
                Value = path,
                Preview = path,
                PreviewType = "file",
            })
        end
        handle:close()
    end
    return entries
end
