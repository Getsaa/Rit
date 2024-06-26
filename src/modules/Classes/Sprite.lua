---@class Sprite
---@diagnostic disable-next-line: assign-type-mismatch
local Sprite = Object:extend()

Sprite.frame = 1
Sprite.frameWidth = 0
Sprite.frameHeight = 0
Sprite.frames = nil
Sprite.graphic = nil
Sprite.alpha = 1.0
Sprite.flipX, Sprite.flipY = false, false

Sprite.origin = Point()
Sprite.offset = Point()
Sprite.scale = Point(1, 1)
Sprite.shear = Point(0, 0)

Sprite.color = {1, 1, 1}

Sprite.clipRect = nil

Sprite.x, Sprite.y = 0, 0

Sprite.type = "Image"

local function NewFrame(FrameName, X, Y, W, H, Sw, Sh, Ox, Oy, Ow, Oh) -- Creates a new frame for a sprite
    local Aw, Ah = X + W, Y + H
    local frame = {
        name = FrameName,
        quad = love.graphics.newQuad(X, Y, Aw > Sw and W - (Aw - Sw) or W, Ah > Sh and H - (Ah - Sh) or H, Sw, Sh),
        width = Ow or W,
        height = Oh or H,
        offset = {x = Ox or 0, y = Oy or 0}
    }
    return frame
end

local function GetFrames(graphic, xmldata) -- Get's all the frames from an xml adobe sparrow
    local frames = {graphic = graphic, frames = {}}
    local sw, sh = graphic:getDimensions()
    for _, frame in ipairs(xmldata) do
        if frame.tag == "SubTexture" then
            local name = frame.attr.name
            local x, y = frame.attr.x, frame.attr.y
            local w, h = frame.attr.width, frame.attr.height
            local frameX, frameY = frame.attr.frameX, frame.attr.frameY
            local frameW, frameH = frame.attr.frameWidth, frame.attr.frameHeight
            table.insert(frames.frames, NewFrame(name, tonumber(x), tonumber(y), tonumber(w), tonumber(h), tonumber(sw), tonumber(sh), tonumber(frameX), tonumber(frameY), tonumber(frameW), tonumber(frameH)))
        end
    end

    return frames
end

local Stencil = {
    sprite = {},
    x = 0,
    y = 0
}

local function stencilFunc()
    if Stencil.sprite then
        love.graphics.push()
            love.graphics.translate(Stencil.x + Stencil.clipRect.x + Stencil.clipRect.width / 2, Stencil.y + Stencil.clipRect.y + Stencil.clipRect.height / 2)
            love.graphics.rotate(math.rad(Stencil.angle or 0))
            love.graphics.translate(-Stencil.clipRect.width / 2, -Stencil.clipRect.height / 2)
            love.graphics.rectangle("fill", -Stencil.clipRect.width /2, -Stencil.clipRect.height / 2, Stencil.clipRect.width, Stencil.clipRect.height)
        love.graphics.pop()
    end
end

function Sprite:new(x, y, graphic)
    self.x, self.y = x or 0, y or 0

    self.graphic = nil
    self.width, self.height = 0, 0

    self.alive, self.exists, self.visible = true, true, true

    self.origin = Point()
    self.offset = Point()
    self.scale = Point(1, 1)
    self.shear = Point(0, 0)

    self.clipRect = nil
    self.flipX, self.flipY = false, false

    self.alpha = 1
    self.color = {1, 1, 1}
    self.angle = 0 -- ! in degrees

    self.frames = nil -- Todo.
    self.animations = nil -- Todo.

    self.curAnim = nil
    self.curFrame = nil
    self.animFinished = false
    self.indexFrame = 1

    self.blend = "alpha"
    self.blendAlphaMode = "alphamultiply"

    self.type = "Image"

    if graphic then self:load(graphic) end

    return self
end

function Sprite:load(graphic, animated, frameWidth, frameHeight)
    local graphic = graphic or nil
    local animated = animated or false
    local frameWidth = frameWidth or 0
    local frameHeight = frameHeight or 0

    if type(graphic) == "string" then
        graphic = Cache:loadImage(graphic)
    end
    self.graphic = graphic

    self.width = self.graphic:getWidth()
    self.height = self.graphic:getHeight()

    return self
end

function Sprite:mapBezier(bezier, graphic, resolution, meshMode)
    -- Maps the image to a bezier curve
    if type(graphic) == "string" then
        graphic = Cache:loadImage(graphic)
    end
    graphic:setWrap("repeat", "clamp")

    local resolution = resolution or 4
    local meshMode = meshMode or "fan"
    
    local points = bezier:render(resolution)

    table.insert(points, 1, points[1])
    table.insert(points, points[3])

    local vertices = {}
    local w = graphic:getWidth()
    local h = graphic:getHeight()
    local u = 0

    for x = 1, #points -1, 2 do 
        local pv = {
            points[x-2], 
            points[x-1]
        }
        local v = {
            points[x], 
            points[x+1]
        }
        local nv = {
            points[x+2], 
            points[x+3]
        }

        local dist, vert

        if x == 1 then
            dist = ((nv[1] - v[1]) ^ 2 + (nv[2] - v[2]) ^ 2) ^ 0.5
            vert = {
                (nv[2] - v[2]) * self.width / (dist * 2),
                -(nv[1] - v[1]) * self.height / (dist * 2)
            }
        elseif x == #points - 1 then
            dist = ((v[1] - pv[1]) ^ 2 + (v[2] - pv[2]) ^ 2) ^ 0.5
            vert = {
                (v[2] - pv[2]) * self.width / (dist * 2),
                -(v[1] - pv[1]) * self.height / (dist * 2)
            }
        else
            dist = ((nv[1] - pv[1]) ^ 2 + (nv[2] - pv[2]) ^ 2) ^ 0.5
            vert = {
                (nv[2] - pv[2]) * self.width / (dist * 2),
                -(nv[1] - pv[1]) * self.height / (dist * 2)
            }
        end

        u = u + dist / self.height / 2

        table.insert(vertices, {
            v[1] + vert[1],
            v[2] - vert[2],
            u, 0
        })
        table.insert(vertices, {
            v[1] - vert[1],
            v[2] + vert[2],
            u, 1
        })
    end

    table.remove(vertices, 1)
    table.remove(vertices, 1)

    -- Create our textured mesh
    if meshMode then
        self.graphic = love.graphics.newMesh(vertices, "strip", meshMode)
    else
        self.graphic = love.graphics.newMesh(vertices, "strip", "fan")
    end

    self.graphic:setTexture(graphic)

    self.width = self.graphic:getWidth()
    self.height = self.graphic:getHeight()

    return self
end

function Sprite:updateVertices(vertices)
    self.graphic:setVertices(vertices)
end

function Sprite:setFrames(xmlPath)
    local data = xml.parse(xmlPath)
    local frames = GetFrames(self.graphic, data)

    self.frames = frames.frames
    self.width, self.height = self:getFrameDimensions()
    self:centerOrigin()
end

function Sprite:addAnimation(name, prefix, framerate, looped)
    -- Adds a new animation to the sprite
    local framerate = framerate or 30
    local looped = looped or true

    local anim = {
        name = name,
        prefix = prefix,
        framerate = framerate,
        looped = looped,
        frames = {}
    }

    for _, f in ipairs(self.frames) do
        if f.name:startsWith(prefix) then
            table.insert(anim.frames, f)
        end
    end

    if not self.animations then self.animations = {} end
    self.animations[name] = anim
end

function Sprite:getMidpoint() -- Middle point of the sprite
    return Point(self.x + self.width / 2, self.y + self.height / 2)
end

function Sprite:update(dt) -- Updates the sprite
   --[[  if self.curAnim then
        if not self.animPaused then
            self.indexFrame = self.indexFrame + self.curAnim.framerate * dt
            if self.indexFrame > #self.curAnim.frames then
                if self.curAnim.looped then
                    self.indexFrame = 1
                else
                    self.indexFrame = #self.curAnim.frames
                    self.animFinished = true
                end
            end
        end
    end]]
end

function Sprite:play(anim) -- Plays the current animation
    self.curAnim = self.animations[anim]
    self.indexFrame = 1
    self.animFinished = false
    self.animPaused = false
end

function Sprite:getFrameWidth()
    local frame = self:getCurrentFrame()
    if frame then
        return frame:getWidth()
    end
    return self.width
end

function Sprite:getFrameHeight()
    local frame = self:getCurrentFrame()
    if frame then
        return frame:getHeight()
    end
    return self.height
end

function Sprite:getFrameDimensions()
    return self:getFrameWidth(), self:getFrameHeight()
end

function Sprite:getCurrentFrame()
    if self.curAnim then
        return self.curAnim:getFrame(self.indexFrame)
    end
    return self.graphic
end

function Sprite:setGraphicSize(w, h)
    local w = w or 0
    local h = h or 0

    self.scale.x = w / self:getFrameWidth()
    self.scale.y = h / self:getFrameHeight()

    if w <= 0 then
        self.scale.x = self.scale.y
    elseif h <= 0 then
        self.scale.y = self.scale.x
    end

    return self
end

function Sprite:updateHitbox() -- Updates the hitbox of the sprite
    local w, h = self:getFrameDimensions()

    self.width = math.abs(self.scale.x) * w
    self.height = math.abs(self.scale.y) * h

    --self.offset = Point(-0.5 * (self.width - w), -0.5 * (self.height - h))
    --self:centerOrigin()

    return self
end

function Sprite:centerOffsets()
    self.offset = Point(
        self:getFrameWidth() - self.width / 2,
        self:getFrameHeight() - self.height / 2
    )

    return self
end 

function Sprite:centerOrigin()
    self.origin = Point(self.width / 2, self.height / 2)

    return self
end

function Sprite:setScale(x, y)
    local x = x or 1
    local y = y or x or 1

    self.scale = Point(x, y)

    return self
end

function Sprite:kill()
    self.alive = false
    self.exists = false
end

function Sprite:revive()
    self.alive = true
    self.exists = true
end

function Sprite:destroy()
    self.exists = false
    self.graphic = nil

    self.origin = {x = 0, y = 0}
    self.offset = {x = 0, y = 0}
    self.scale = {x = 1, y = 1}
    
    self.frames = nil
    self.animations = nil
    
    self.curAnim = nil
    self.curFrame = nil
    self.animFinished = false
    self.animPaused = false
end

function Sprite:isHovered(x, y) -- Checks if the sprite is hovered by an x and y position
    local x = x or love.mouse.getX()
    local y = y or love.mouse.getY()

    -- account for the offset
    x = x - self.offset.x
    y = y - self.offset.y

    local width, height = self:getFrameDimensions()
    width = width * self.scale.x
    height = height * self.scale.y

    return x >= self.x and x <= self.x + width and y >= self.y and y <= self.y + height
end

function Sprite:draw() -- Draws the sprite, only if it's visible and exists
    if self.exists and self.alive and self.visible and self.graphic then
        local frame = self:getCurrentFrame()

        if self.clipRect then
            love.graphics.setStencilTest("greater", 0)
        end
        local x, y = self.x, self.y
        local angle = math.rad(self.angle)
        local sx, sy = self.scale:get()
        local ox, oy = self.origin:get()
        
        sx = sx * (self.flipX and -1 or 1)
        sy = sy * (self.flipY and -1 or 1)

        local lastColor = {love.graphics.getColor()}
        local lastBlend, lastAlphaMode 
        if love.graphics.getSupportedBlend() then
            lastBlend, lastAlphaMode = love.graphics.getBlendMode()
            love.graphics.setBlendMode(self.blend, self.blendAlphaMode)
        end
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
        x, y = x + ox - self.offset.x, y + oy - self.offset.y

        love.graphics.push()
            if self.clipRect then
                Stencil = {
                    sprite = self,
                    x = x,
                    y = y,
                    clipRect = self.clipRect,
                    func = Stencil.func
                }
                love.graphics.stencil(stencilFunc, "replace", 1, false)
            end
            if self.forcedDimensions then
                -- use self.dimensions for new sx and sy
                local w, h = self:getFrameDimensions()
                sx = self.dimensions.width / w
                sy = self.dimensions.height / h

                sx = sx * (self.flipX and -1 or 1)
                sy = sy * (self.flipY and -1 or 1)
            end
            
            love.graphics.draw(self.graphic, x, y, angle, sx, sy, ox, oy, self.shear.x, self.shear.y)
        love.graphics.pop()

        if self.clipRect then
            love.graphics.setStencilTest()
        end
        love.graphics.setColor(lastColor)
        if love.graphics.getSupportedBlend() then
            love.graphics.setBlendMode(lastBlend, lastAlphaMode)
        end
    end
end

function Sprite:screenCenter(XY) -- Centers the sprite on the screen
    local doX, doY = true, true

    if type(XY) == "string" then
        doX = XY:find("x") ~= nil
        doY = XY:find("y") ~= nil
    end

    if doX then
        self.x = (Inits.GameWidth / 2) - (self.width / 2)
    end
    if doY then
        self.y = (Inits.GameHeight / 2) - (self.height / 2)
    end

    return self
end

return Sprite