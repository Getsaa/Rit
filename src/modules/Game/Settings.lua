local Settings = {}

Settings.options = {
    ["General"] = {
        downscroll = true,
        scrollspeed = 2,
        backgroundVisibility = 1,
        skin = "Circle Default",
    },
    ["Meta"] = {
        __VERSION__ = 1
    }
}

function Settings.saveOptions()
    ini.save(Settings.options, "settings")
end

function Settings.loadOptions()
    if not love.filesystem.getInfo("settings") then
        Settings.saveOptions()
    end

    --Settings.options = ini.parse("settings")
    local savedOptions = ini.parse("settings")
    for i, type in pairs(savedOptions) do
        for j, setting in pairs(type) do
            Settings.options[i][j] = savedOptions[i][j]
        end
    end
end

return Settings