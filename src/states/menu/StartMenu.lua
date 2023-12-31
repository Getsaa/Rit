local StartMenu = state()
local beat, time = 0, 0
local time2 = 0
local menuBPM = 120

local timers = {}

local soundData

local balls, bg, logo, twitterLogo, kofiLogo, discordLogo
local equalizer

function StartMenu:enter()
    balls = {}
    bg = Sprite(0, 0, "assets/images/ui/menu/BGsongList.png")
    for i = 1, 5 do
        balls[i] = Sprite(love.math.random(0, 1600), love.math.random(0, 720), "assets/images/ui/menu/BGball" .. i .. ".png")
        balls[i].ogX, balls[i].ogY = love.math.random(0, 1920), love.math.random(0, 1080)
    end
    --logo = Image("assets/images/ui/menu/logo.png")
    logo = Sprite(0, 0, "assets/images/ui/menu/logo.png")
    logo:centerOrigin()
    logo.scale = Point(2, 2)

    twitterLogo = Sprite(1780, 950, "assets/images/ui/icons/twitter.png")
    kofiLogo = Sprite(1780, 825, "assets/images/ui/icons/ko-fi.png")
    discordLogo = Sprite(1650, 950, "assets/images/ui/icons/discord.png")

    twitterLogo:setScale(0.25)
    kofiLogo:setScale(0.25)
    discordLogo:setScale(0.25)

    logo.alignment = "center"

    logo.y =__inits.__GAME_HEIGHT / 0.9
    logo.x =__inits.__GAME_WIDTH / 1
    
    if discordRPC then
        discordRPC.presence = {
            details = "In the menu",
            state = "",
            largeImageKey = "totallyreallogo",
            largeImageText = "Rit" .. (__DEBUG__ and " DEBUG MODE" or "")
        }
    end

    loadSongs("defaultSongs")
    loadSongs("songs")
    if not MenuSoundManager:exists("music") then playRandomSong() end

    if MenuSoundManager:exists("music") then
        soundData = MenuSoundManager:getSoundData("music")

        -- equalizer that draws on top of the screen
        equalizer = Spectrum(soundData)
    end
end

function StartMenu:update(dt)
    time = time + 1000 * dt
    time2 = time2 + 1000 * dt

    if time > (60/menuBPM) * 1000 then
        local curBeat = math.floor((time2/1000) / (60/menuBPM))
        if curBeat % 2 == 0 then
            logo:setScale(2.05)
        end
        time = 0
    end

    local mx, my = love.mouse.getPosition()

    -- Logo parallax
    local px, py = (-mx / 50), (-my / 50)
    logo.x =__inits.__GAME_WIDTH / 0.9 + px
    logo.y =__inits.__GAME_HEIGHT + py

    bg.x, bg.y = px * 0.025, py * 0.025

    for i = 1, #balls do
        balls[i].x = balls[i].ogX + px * 0.09 + (0.05 * i * 5)
        balls[i].y = balls[i].ogY + py * 0.09 + (0.05 * i * 5)
    end

    if logo.scale.x > 2 then 
        logo:setScale(logo.scale.x - (dt * ((menuBPM/60))) * 0.1)
    end

    if input:pressed("confirm") then state.switch(states.menu.SongMenu) end

    if equalizer and MenuSoundManager:getChannel("music") then
        equalizer:update(MenuSoundManager:getChannel("music").sound, soundData)
    end
end

function StartMenu:mousepressed(x, y, b)
    local x, y = toGameScreen(x, y)
    if b == 1 then
        if twitterLogo:isHovered(x, y) then
            love.system.openURL("https://twitter.com/GuglioIs2Stupid")
        elseif kofiLogo:isHovered(x, y) then
            love.system.openURL("https://ko-fi.com/guglioisstupid")
        elseif discordLogo:isHovered(x, y) then
            love.system.openURL("https://discord.gg/y5zz2Dm7A2")
        end
    end
end

function StartMenu:draw()
    bg:draw()
    for i = 1, #balls do
        balls[i]:draw()
    end
    love.graphics.push()
        love.graphics.scale(0.35, 0.35)
        love.graphics.setColor(1, 1, 1)
        logo:draw()
    love.graphics.pop()
    twitterLogo:draw()
    kofiLogo:draw()
    discordLogo:draw()

    if equalizer then
        equalizer:draw()
    end
end

return StartMenu