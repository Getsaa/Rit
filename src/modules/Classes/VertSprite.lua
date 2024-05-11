local VertSprite = Object:extend()
VertSprite:implement(Sprite)

local vertexFormat = {
    {"VertexPosition", "float", 2},
	{"VertexTexCoord", "float", 3},
	{"VertexColor",    "byte",  4}
}

local width, height = Inits.GameWidth, Inits.GameHeight

local function toScreen(x, y, z, fov)
    local hw, hh, z = width/2, height/2, math.max(((z / 200) * (fov / 180)) + 1, 0.00001)
    local x = hw + (x - hw) / z
    local y = hh + (y - hh) / z
    local z = (1 / z)
    return x, y, z
end

local function worldSpin(x, y, z, ax, ay, az, midx, midy, midz)
    local radx, rady, radz = math.rad(ax), math.rad(ay), math.rad(az)
    local angx0, angx1, angy0, angy1, angz0, angz1 = math.cos(radx), math.sin(radx), math.cos(rady), math.sin(rady), math.cos(radz), math.sin(radz)
    local gapx, gapy, gapz = x - midx, y - midy, z - midz

    local nx = midx  + angy0 * angz0 * gapx + (-angz1 * angx0 + angx1 * angy1 * angz0) * gapy + (angx1 * angz1 + angx0 * angy1 * angz0) * gapz
	local ny = midy - angy0 * angz1 * gapx - (angx0 * angz0 + angx1 * angy1 * angz1) * gapy - (-angx1 * angz0 + angx0 * angy1 * angz1) * gapz
	local nz = midz + angy1 * gapx - angx1 * angy0 * gapy - angx0 * angy0 * gapz

	return nx, ny, nz
end

local defaultShader

function VertSprite.init()
    if defaultShader then return end
	defaultShader = love.graphics.newShader [[
		uniform Image MainTex;
		void effect() {
			love_PixelColor = Texel(MainTex, VaryingTexCoord.xy / VaryingTexCoord.z) * VaryingColor;
		}
	]]
	VertSprite.defaultShader = defaultShader
end

function VertSprite:new(x, y, z, graphic)
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

    self.z = z
    self.offset.z = 0
    self.scale.z = 1
    self.origin.z = 0
    self.fov = 60
    self.rotation = {x = 0, y = 0, z = 0}
    self.init()
    self.graphic = Cache:loadImage(graphic)

    self.vertices = {
		{0, 0, 0, 0, 0},
		{1, 0, 0, 1, 0},
		{1, 1, 0, 1, 1},
		{0, 1, 0, 0, 1},
	}
	self.__vertices = {
		{0, 0, 0, 0, 1},
		{1, 0, 1, 0, 1},
		{1, 1, 1, 1, 1},
		{0, 1, 0, 1, 1},
	}

    self.mesh = love.graphics.newMesh(vertexFormat, self.vertices, "fan")

    return self
end

function VertSprite:draw()
    if self.exists and self.alive and self.visible and self.graphic then
        local x = self.x
        local y = self.y
        local z = self.z or 0

        x = x + self.origin.x - self.offset.x
        y = y + self.origin.y - self.offset.y
        z = (z or 0) + (self.origin.z or 0) - (self.offset.z or 0)
        local rx, ry, rz = self.rotation.x, self.rotation.y, (self.rotation.z or 0)
        local sx, sy, sz = self.scale.x, self.scale.y, (self.scale.z or 0)
        local ox, oy, oz = self.origin.x, self.origin.y, (self.origin.z or 0)

        local gw, gh = self.graphic:getDimensions()
        local lastColor = {love.graphics.getColor()}
        local lastBlend, lastAlphaMode = love.graphics.getBlendMode()
        local fw, fh, uvx, uvy, uvw, uvh = gw, gh, 0, 0, 1, 1
        -- why is this flipped???
        -- ig we can just do the opposite of flipY.....
        if not self.flipY then uvy, uvh = uvy + uvh, -uvh end

        fw, fh = fw * sx, fh * sy
        ox, oy, oz = ox * sx, oy * sy, oz * sz

        local mesh, verts, length = self.mesh, self.__vertices, #self.vertices
        local vert, vx, vy, vz
        for i, v in pairs(self.vertices) do
            vert = verts[i] or {0, 0, 0, 0, 0}
            verts[i] = vert

            vx, vy, vz = worldSpin(v[1] * fw, v[2] * fh, v[3] * sz, rx, ry, rz, ox, oy, oz)
            vert[1], vert[2], vert[5] = toScreen(vx + x - ox, vy + y - oy, vz + z - oz, self.fov)
            vert[3], vert[4] = (v[4] * uvw + uvx) * vert[5], (v[5] * uvh + uvy) * vert[5]
        end
        -- is mesh image same as self.graphic?
        if mesh:getTexture() ~= self.graphic then mesh:setTexture(self.graphic) end
        mesh:setDrawRange(1, length)
        mesh:setVertices(verts)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
        love.graphics.setShader(defaultShader)

        if self.forcedDimensions then
            local w, h = self:getFrameDimensions()
            sx = self.dimensions.width / w
            sy = self.dimensions.height / h
        end
        love.graphics.draw(mesh, 0, self.height, 0 --[[ sx, sy ]])
        
        love.graphics.setColor(lastColor)
        love.graphics.setBlendMode(lastBlend, lastAlphaMode)
    end

    love.graphics.setShader()
end

return VertSprite