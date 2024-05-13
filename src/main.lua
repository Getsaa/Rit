fade = 1
masterVolume = 50
isLoading = false
__DEBUG__ = not love.filesystem.isFused()
if not __DEBUG__ then 
    function print() end -- disable print if not in debug mode, allows for better performance
end

if love.filesystem.getInfo("__VERSION__.txt") then
    __VERSION__ = love.filesystem.read("__VERSION__.txt")
else
    __VERSION__ = "vUnknown"
end

__InJukebox = false

require("modules.Utilities")
ffi = require("ffi")

Inits = require("init")
__WINDOW_WIDTH, __WINDOW_HEIGHT = Inits.__WINDOW_WIDTH, Inits.__WINDOW_HEIGHT

_TRANSITION = {
    x = Inits.GameWidth,
    width = Inits.GameWidth+200,
    y = 0,
    timer = nil, -- Timer.tween
    ovalHeight = 0
}

function switchState(newState, t, middleFunc, data)
    local t = t or 0.3
    isLoading = true
    Timer.tween(t, _TRANSITION, {x = 0}, "out-quart", function()
        if middleFunc then middleFunc() end
        state.switch(newState, data)
        isLoading = false
        Timer.after(0.01, function()
            Timer.tween(t, _TRANSITION, {x = -Inits.GameWidth}, "out-quart", function()
                _TRANSITION.x = Inits.GameWidth
            end)
        end)
    end)
end

DRAW_VIRTUAL_CONTROLLER = love.system.getOS() == "Android" or love.system.getOS() == "iOS"

if love.system.getOS() == "Windows" then
    Try(
        function()
            Steam = require("lib.sworks.main")
        end,
        function()
            Steam = nil
            print("Couldn't load Steamworks.")
        end
    )
    Try(
        function()
            discordRPC = require("lib.discordRPC") -- https://github.com/pfirsich/lua-discordRPC
            discordRPC.nextPresenceUpdate = 0
        end,
        function()
            discordRPC = nil
            print("Couldn't load Discord RPC.")
        end
    )
    Try(
        function()
            https = require("https") -- https://github.com/love2d/lua-https
        end,
        function()
            https = nil
            print("Couldn't load https.")
        end
    )
end

local winOpacity = {1}
local volume = {1}
local curVol = 1
local isClosing = false

local GameInit = require("modules.GameInit")

local function CheckAprilFools()
    local CurrentDateTime = os.date("*t") -- if april first, set the boolean "doAprilFools" to true
    return CurrentDateTime.month == 4 and CurrentDateTime.day == 1
end

function love.load(args)
    __NOTE_OBJECT_WIDTH = 0 -- Determined from the width of the noteskins note object.

    GameInit.LoadLibraries()
    importer = lovefs()

    -- remove all os function EXCEPT non-harmful ones
    -- don't want modscriptors to do anything bad :)
    GameInit.ClearOSModule()

    -- Classes
    GameInit.LoadClasses()

    -- Create folders
    GameInit.CreateFolders()

    -- Skins, create skins directory if it doesn't exist
    skinList = {}
    skin:loadSkins("skins")
    skin:loadSkins("defaultSkins")
    if not love.filesystem.getInfo("skins") then
        love.filesystem.createDirectory("skins")
    end

    -- Objects
    GameInit.LoadObjects()

    -- Parsers
    GameInit.LoadParsers()

    -- Load fonts
    GameInit.LoadDefaultFonts()
    
    -- States
    states = GameInit.LoadStates()

    -- Substates
    substates = GameInit.LoadSubstates()

    -- Shaders
    shaders = GameInit.LoadShaders()

    -- Parse the skin's data file
    skinData = ini.parse(love.filesystem.read(skin:format("skin.ini")))

    -- Initialize 3rd party applications
    GameInit.InitSteam()
    if discordRPC then -- Discord RPC initialization
        discordRPC.initialize("785717724906913843", true)
    end

    gameScreen = love.graphics.newCanvas(Inits.GameWidth, Inits.GameHeight)

    MenuSoundManager = SoundManager()

    masterVolume = Settings.options["General"].globalVolume * 100

    doAprilFools = CheckAprilFools()

    cursor = love.mouse.newCursor("assets/images/ui/cursor/cursor.png", 0, 0)
    --love.mouse.setCursor(cursor)

    love.keyboard.setKeyRepeat(true)

    -- Lastly, switch to the preloader screen to preload all of our needed assets
    state.switch(states.screens.PreloaderScreen, args)
end

function love.update(dt)
    if Steam and networking.connected then
        networking.frameCount = networking.frameCount + 1
        networking.hub:enterFrame()
    end
    threads.assets.update() -- update the threads for asset loading
    threads.replays.update() -- update the threads for replay loading
    threads.networking.update() -- update the threads for networking
    Timer.update(dt)
    input:update()
    if not isLoading then state.update(dt) end

    if not __InJukebox then
        love.audio.setVolume(volume[1] * (masterVolume/100))
    end

    if isClosing then 
        love.window.setWindowOpacity(winOpacity[1]) 
    end

    GameInit.UpdateDiscord()

    MenuSoundManager:update(dt)
end

function love.filedropped(file)
    
end

function love.focus(f)
    state.focus(f)
    if not f and volume then
        love.setFpsCap(30)
        Timer.tween(0.5, volume, {0.25}, "linear")
    elseif f and volume then
        love.setFpsCap(500)
        Timer.tween(0.5, volume, {1}, "linear")
    end
end

function love.keypressed(key)
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
        return
    elseif key == "return" and love.keyboard.isDown("lalt") then
        love.window.setFullscreen(not love.window.getFullscreen())
        return
    end

    state.keypressed(key)

    if __DEBUG__ then
        if key == "f7" then
            state.switch(states.screens.MapEditorScreen)
        end
    end
end

function love.resize(w,h)
    __WINDOW_WIDTH, __WINDOW_HEIGHT = w, h
    state.resize(w,h)
end

function toGameScreen(x, y)
    -- converts our mouse position to the game screen (canvas) with the correct ratio
    local ratio = 1
    ratio = math.min(__WINDOW_WIDTH/Inits.GameWidth, __WINDOW_HEIGHT/Inits.GameHeight)

    local x, y = x - __WINDOW_WIDTH/2, y - __WINDOW_HEIGHT/2
    x, y = x / ratio, y / ratio
    x, y = x + Inits.GameWidth/2, y + Inits.GameHeight/2

    return x, y
end

function love.draw()
    local lastFont = love.graphics.getFont()
    love.graphics.setCanvas({gameScreen, stencil = true})
        love.graphics.clear(0,0,0,1)
        state.draw()
        love.graphics.setColor(0,0,0,1)
        love.graphics.rectangle("fill", _TRANSITION.x, _TRANSITION.y, _TRANSITION.width, Inits.GameHeight)
        love.graphics.setStencilTest()
        love.graphics.setColor(1,1,1,1)
        if DRAW_VIRTUAL_CONTROLLER then
            currentController:draw()
        end
    love.graphics.setCanvas()

    -- ratio
    local ratio = 1
    ratio = math.min(love.graphics.getWidth()/Inits.GameWidth, love.graphics.getHeight()/Inits.GameHeight)
    love.graphics.setColor(1,1,1,1)
    -- draw game screen with the calculated ratio and center it on the screen
    love.graphics.draw(gameScreen, love.graphics.getWidth()/2, love.graphics.getHeight()/2, 0, ratio, ratio, Inits.GameWidth/2, Inits.GameHeight/2)

    -- draw Popup.popups
    for i, popup in ipairs(Popup.popups) do
        popup:draw()
    end

    -- info
    if Settings.options["General"].debugText then
        love.graphics.setFont(lastFont)
        love.graphics.print(
            "FPS: " .. love.timer.getFPS() .. "\n" ..

            -- debug info
            (__DEBUG__ and 
            
                ("Music Time: " .. (musicTime or "N/A") .. "\n" ..
                "Draw Calls: " .. love.graphics.getStats().drawcalls .. "\n" ..
                "Memory: " .. math.floor(collectgarbage("count")) .. "KB\n" ..
                "Graphics Memory: " .. math.floor(love.graphics.getStats().texturememory/1024/1024) .. "MB\n") 

                or ""
            ) ..
            --
        
            "Steam: " .. (Steam and "true" or "false") .. "\n" ..
            (Steam and "Steam User: " .. SteamUserName .. "\n" or "") ..
            (Steam and "Steam ID: " .. tostring(SteamID) .. "\n" or "") ..
            "Volume: " .. math.round(masterVolume, 2)
        )
    end
end

function love.quit()
    if discordRPC then
        discordRPC.shutdown()
    end

    Settings.saveOptions()

    if Steam and networking.connected and networking.currentServerData then
        networking.hub:publish({
            message = {
                action = "updateServerInfo_FORCEREMOVEUSER",
                id = networking.currentServerID,
                user = {
                    steamID = tostring(SteamID),
                    name = tostring(SteamUserName)
                }
            }
        })
    end

    if not isClosing then
        isClosing = true
        Timer.tween(0.5, winOpacity, {0}, "linear", function()
            love.event.quit()
        end)
        Timer.tween(0.5, volume, {0}, "linear")
        curVol = love.audio.getVolume()
        return true
    end
end
