local __DEBUG__ = not love.filesystem.isFused()
local major, minor, revision, codename = love.getVersion()
function love.conf(t)
    t.window.title = "Rit."
    if __DEBUG__ then
        t.window.title = t.window.title .. " | DEBUG | " .. jit.version .. " | " ..
            jit.os .. " " .. jit.arch .. " | LOVE " ..
            (
                major .. "." .. minor .. "." .. revision .. " - " .. codename
            )
    end
    t.identity = "rit"

    t.window.width = 1280
    t.window.height = 720

    t.window.resizable = true
    t.window.vsync = false
    
    t.console = __DEBUG__
    t.window.icon = "assets/images/icon.png"

    -- disable modules we don't need
    t.modules.physics = false
end