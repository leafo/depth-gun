-- game_space.lua port — pure math, no draw calls.
-- project(x, y, z) → (px, py, scale, rot) in 320×240 viewport coords.

local Vec2d = require("lovekit.geometry").Vec2d
local Box   = require("lovekit.geometry").Box

local DEFAULT_SCROLL_SPEED = 2
local VIEWPORT_W, VIEWPORT_H = 320, 240

local GameSpace = {}
GameSpace.__index = GameSpace

setmetatable(GameSpace, {
    __call = function(cls)
        local self = setmetatable({}, GameSpace)
        self.viewport = { w = VIEWPORT_W, h = VIEWPORT_H }
        self.aim_box = Box(0, 0, VIEWPORT_W * 0.75, VIEWPORT_H * 0.75)
        self.aim_box:move_center(0, 0)
        self.scroll_speed = DEFAULT_SCROLL_SPEED
        self.rot = 0
        self.world_rot = 0
        self.xtilt = 0
        self.ytilt = 0
        self.tunnel_dir_x = 0
        self.tunnel_dir_y = 0
        self.offset = 0
        return self
    end,
})

function GameSpace:update(dt)
    self.offset = self.offset + dt * self.scroll_speed
end

function GameSpace:scale_factor(z)
    local b = 1
    local speed_mod = 1 + math.max(0, self.scroll_speed - DEFAULT_SCROLL_SPEED) / 8
    return (1 / speed_mod) * math.min(20, b / (z + b))
end

function GameSpace:tunnel_bend(z)
    local wobble_x = math.cos(3 + self.offset * 1.2)
    local wobble_y = 2 * math.sin(self.offset)
    return z * (wobble_x + self.tunnel_dir_x), z * (wobble_y + self.tunnel_dir_y)
end

-- Returns: px, py, scale, total_rot
-- (in 320×240 viewport coords; the world RT projection is +Y down)
function GameSpace:project(x, y, z)
    local scale = self:scale_factor(z)
    local vw = self.viewport.w / 2
    local vh = self.viewport.h / 2
    local yadjust = vh - vh * scale
    local xadjust = vw - vw * scale
    local bx, by = self:tunnel_bend(z)
    local adjx = xadjust * self.xtilt
    local adjy = yadjust * (self.ytilt - 0.5)

    local px = x * scale + bx + adjx
    local py = y * scale + by + adjy

    local rot = self.rot + self.world_rot
    local c, s = math.cos(rot), math.sin(rot)
    local rx = px * c - py * s
    local ry = py * c + px * s

    rx = rx + vw + (-self.xtilt * 60)
    ry = ry + vh

    -- Flip Y at the boundary: source's project() returns +Y-down screen
    -- coords. The render script uses a standard +Y-up ortho, so output ry
    -- needs flipping. Rotation is left in source convention (positive=CW
    -- in +Y-down); callers negate when applying as a Defold +Y-up quat.
    return rx, VIEWPORT_H - ry, scale, rot
end

-- For input: rotate the input vector by the inverse of the world rotation so
-- player-control input is consistent regardless of banking.
function GameSpace:unproject_rot(x, y)
    local rot = -(self.rot + self.world_rot)
    local c, s = math.cos(rot), math.sin(rot)
    return x * c - y * s, y * c + x * s
end

return { GameSpace = GameSpace }
