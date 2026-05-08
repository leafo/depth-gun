-- lovekit geometry: Vec2d, Box, SetList, UniformGrid.
-- Box.draw / Box.outline / Selector classes are dropped (Love-graphics-only).

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local cos, sin, abs, deg, rad = math.cos, math.sin, math.abs, math.deg, math.rad
local random = math.random

local function floor(n)
    if n < 0 then return -math.floor(-n) else return math.floor(n) end
end

local function ceil(n)
    if n < 0 then return -math.ceil(-n) else return math.ceil(n) end
end

-- Vec2d ---------------------------------------------------------------------

local Vec2d = {}
Vec2d.__index = Vec2d
Vec2d.__name = "Vec2d"

local Vec2d_mt = {}
function Vec2d_mt.__call(cls, x, y)
    local v = setmetatable({ x or 0, y or 0 }, Vec2d)
    return v
end
setmetatable(Vec2d, Vec2d_mt)

Vec2d.__index = function(self, name)
    if name == "x" then return self[1]
    elseif name == "y" then return self[2]
    else return rawget(Vec2d, name) end
end

function Vec2d:angle() return deg(atan2(self[2], self[1])) end
function Vec2d:radians() return atan2(self[2], self[1]) end

function Vec2d:len()
    local n = self[1] * self[1] + self[2] * self[2]
    if n == 0 then return 0 end
    return math.sqrt(n)
end

function Vec2d:cap(len)
    local l = self:len()
    if l > len then
        self[1] = self[1] / l * len
        self[2] = self[2] / l * len
    end
    return self
end

function Vec2d:dup() return Vec2d(self[1], self[2]) end
function Vec2d:is_zero() return self[1] == 0 and self[2] == 0 end
function Vec2d:left() return self[1] < 0 end
function Vec2d:right() return self[1] > 0 end

function Vec2d:move(dx, dy)
    self[1], self[2] = self[1] + dx, self[2] + dy
    return self
end

function Vec2d:update(x, y)
    self[1], self[2] = x, y
    return self
end

function Vec2d:adjust(dx, dy)
    self[1], self[2] = self[1] + dx, self[2] + dy
    return self
end

function Vec2d:normalized()
    local len = self:len()
    if len == 0 then return Vec2d() end
    return Vec2d(self[1] / len, self[2] / len)
end

function Vec2d:cross() return Vec2d(-self[2], self[1]) end
function Vec2d:flip() return Vec2d(-self[1], -self[2]) end

function Vec2d:truncate(max_len)
    local l = self:len()
    if l > max_len then
        self[1] = self[1] / l * max_len
        self[2] = self[2] / l * max_len
    end
end

local _direction_names = { "up", "right", "down", "left" }
function Vec2d:direction_name(names)
    names = names or _direction_names
    if abs(self[1]) > abs(self[2]) then
        if self[1] < 0 then return names[4] else return names[2] end
    else
        if self[2] < 0 then return names[1] else return names[3] end
    end
end

function Vec2d:rotate(rads)
    local x, y = self[1], self[2]
    local c, s = cos(rads), sin(rads)
    return Vec2d(x * c - y * s, y * c + x * s)
end

function Vec2d:merge_angle(other, p)
    p = p or 0.5
    local a, b = self:radians(), other:radians()
    if b - a > math.pi then a = a + 2 * math.pi end
    if b - a < -math.pi then a = a - 2 * math.pi end
    return Vec2d.from_radians(a + (b - a) * p)
end

function Vec2d:random_heading(spread, r)
    spread = spread or 10
    r = r or random()
    return self:rotate(rad((r - 0.5) * spread))
end

function Vec2d:primary_direction()
    local x, y = self[1], self[2]
    if x == 0 and y == 0 then return Vec2d(0, 0) end
    if abs(x) > abs(y) then
        if x < 0 then return Vec2d(-1, 0) else return Vec2d(1, 0) end
    else
        if y < 0 then return Vec2d(0, -1) else return Vec2d(0, 1) end
    end
end

Vec2d.__mul = function(left, right)
    if type(left) == "number" then
        return Vec2d(left * right[1], left * right[2])
    elseif type(right) ~= "number" then
        return left[1] * right[1] + left[2] * right[2]
    else
        return Vec2d(left[1] * right, left[2] * right)
    end
end

Vec2d.__div = function(left, right)
    if type(left) == "number" then error("vector division undefined") end
    return Vec2d(left[1] / right, left[2] / right)
end

Vec2d.__add = function(self, other) return Vec2d(self[1] + other[1], self[2] + other[2]) end
Vec2d.__sub = function(self, other) return Vec2d(self[1] - other[1], self[2] - other[2]) end
Vec2d.__tostring = function(self) return ("vec2d<%f, %f>"):format(self[1], self[2]) end

function Vec2d.from_angle(d)
    local theta = rad(d)
    return Vec2d(cos(theta), sin(theta))
end

function Vec2d.from_radians(r)
    return Vec2d(cos(r), sin(r))
end

function Vec2d.random(mag)
    mag = mag or 1
    local v = Vec2d.from_angle(random() * 360)
    return v * mag
end

-- Box -----------------------------------------------------------------------

local Box = {}
Box.__index = Box
Box.__name = "Box"

local Box_mt = {}
function Box_mt.__call(cls, x, y, w, h)
    local b = setmetatable({ x = x, y = y, w = w, h = h }, Box)
    b.__class = Box
    return b
end
setmetatable(Box, Box_mt)

function Box:unpack() return self.x, self.y, self.w, self.h end
function Box:unpack2() return self.x, self.y, self.x + self.w, self.y + self.h end
function Box:dup() return Box(self.x, self.y, self.w, self.h) end

function Box:pad(amount)
    local a2 = amount * 2
    return Box(self.x + amount, self.y + amount, self.w - a2, self.h - a2)
end

function Box:pos() return self.x, self.y end
function Box:set_pos(x, y) self.x, self.y = x, y end

function Box:move(x, y)
    self.x, self.y = self.x + x, self.y + y
    return self
end

function Box:move_center(x, y)
    self.x = x - self.w / 2
    self.y = y - self.h / 2
    return self
end

function Box:center() return self.x + self.w / 2, self.y + self.h / 2 end

function Box:touches_pt(x, y)
    local x1, y1, x2, y2 = self:unpack2()
    return x > x1 and x < x2 and y > y1 and y < y2
end

function Box:touches_box(o)
    local x1, y1, x2, y2 = self:unpack2()
    local ox1, oy1, ox2, oy2 = o:unpack2()
    if x2 <= ox1 then return false end
    if x1 >= ox2 then return false end
    if y2 <= oy1 then return false end
    if y1 >= oy2 then return false end
    return true
end

function Box:contains_box(o)
    local x1, y1, x2, y2 = self:unpack2()
    local ox1, oy1, ox2, oy2 = o:unpack2()
    if ox1 <= x1 then return false end
    if ox2 >= x2 then return false end
    if oy1 <= y1 then return false end
    if oy2 >= y2 then return false end
    return true
end

function Box:left_of(box) return self.x < box.x end
function Box:above_of(box) return self.y <= box.y + box.h end

function Box:vector_to(other)
    local x1, y1 = self:center()
    local x2, y2 = other:center()
    return Vec2d(x2 - x1, y2 - y1)
end

function Box:random_point()
    return self.x + random() * self.w, self.y + random() * self.h
end

function Box:fix()
    local x, y, w, h = self:unpack()
    if w < 0 then x, w = x + w, -w end
    if h < 0 then y, h = y + h, -h end
    return Box(x, y, w, h)
end

function Box:scale(sx, sy, center)
    sx = sx or 1
    sy = sy or sx
    local s = Box(self.x, self.y, self.w * sx, self.h * sy)
    if center then s:move_center(self:center()) end
    return s
end

function Box:shrink(dx, dy)
    dx = dx or 1
    dy = dy or dx
    local hx, hy = dx / 2, dy / 2
    local w, h = self.w - dx, self.h - dy
    if w < 0 or h < 0 then error("box too small") end
    return Box(self.x + hx, self.y + hy, w, h)
end

function Box:add_box(other)
    if self.w == 0 or self.h == 0 then
        self.x, self.y, self.w, self.h = other:unpack()
    else
        local x1, y1, x2, y2 = self:unpack2()
        local ox1, oy1, ox2, oy2 = other:unpack2()
        x1 = math.min(x1, ox1)
        y1 = math.min(y1, oy1)
        x2 = math.max(x2, ox2)
        y2 = math.max(y2, oy2)
        self.x, self.y, self.w, self.h = x1, y1, x2 - x1, y2 - y1
    end
end

function Box:clamp_vector(vec)
    local x, y = vec[1], vec[2]
    if x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h then
        return vec
    end
    return Vec2d(
        math.min(math.max(self.x, x), self.x + self.w),
        math.min(math.max(self.y, y), self.y + self.h)
    )
end

Box.__div = function(left, right)
    return Box((left.x - right.x) / right.w, (left.y - right.y) / right.h, left.w / right.w, left.h / right.h)
end

Box.__tostring = function(self)
    return ("box<(%.2f, %.2f), (%.2f, %.2f)>"):format(self:unpack())
end

function Box.from_pt(x1, y1, x2, y2) return Box(x1, y1, x2 - x1, y2 - y1) end

-- Box.draw / Box.outline are no-ops here (callers in entity scripts handle drawing
-- via sprite components on game objects, not direct love.graphics calls).
function Box:draw() end
function Box:outline() end

-- SetList -------------------------------------------------------------------

local SetList = {}
SetList.__index = SetList

local SetList_mt = {}
function SetList_mt.__call(cls)
    return setmetatable({ contains = {} }, SetList)
end
setmetatable(SetList, SetList_mt)

function SetList:add(item, value)
    if self.contains[item] then return end
    self.contains[item] = true
    self[#self + 1] = value or item
end

-- UniformGrid ---------------------------------------------------------------

local function hash_pt(x, y) return tostring(x) .. ":" .. tostring(y) end

local UniformGrid = {}
UniformGrid.__index = UniformGrid

local UniformGrid_mt = {}
function UniformGrid_mt.__call(cls, cell_size)
    cell_size = cell_size or 10
    return setmetatable({
        cell_size = cell_size,
        buckets = {},
        values = {},
    }, UniformGrid)
end
setmetatable(UniformGrid, UniformGrid_mt)

function UniformGrid:clear()
    for _, bucket in pairs(self.buckets) do
        for k in pairs(bucket) do bucket[k] = nil end
    end
    for k in pairs(self.values) do self.values[k] = nil end
end

function UniformGrid:bucket_for_pt(x, y, insert)
    x = math.floor(x / self.cell_size)
    y = math.floor(y / self.cell_size)
    local key = hash_pt(x, y)
    local b = self.buckets[key]
    if not b and insert then
        b = {}
        self.buckets[key] = b
    end
    return b, key
end

function UniformGrid:buckets_for_box(box, insert)
    return coroutine.wrap(function()
        local x1, y1, x2, y2 = box:unpack2()
        local x = x1
        while x < x2 + self.cell_size do
            local y = y1
            while y < y2 + self.cell_size do
                local b, k = self:bucket_for_pt(x, y, insert)
                if b then coroutine.yield(b, k) end
                y = y + self.cell_size
            end
            x = x + self.cell_size
        end
    end)
end

function UniformGrid:add(box, value)
    if value == nil then value = box end
    for bucket in self:buckets_for_box(box, true) do
        bucket[#bucket + 1] = box
    end
    self.values[box] = value
end

function UniformGrid:get_touching(query_box)
    local values = self.values
    local list = SetList()
    for bucket in self:buckets_for_box(query_box) do
        for i = 1, #bucket do
            local box = bucket[i]
            if query_box ~= box and box:touches_box(query_box) then
                list:add(box, values[box])
            end
        end
    end
    return list
end

function UniformGrid:get_touching_pt(x, y)
    local bucket = self:bucket_for_pt(x, y)
    if not bucket then return end
    local values = self.values
    local list = SetList()
    for i = 1, #bucket do
        local box = bucket[i]
        if box:touches_pt(x, y) then
            list:add(box, values[box])
        end
    end
    if next(list) then return list end
end

return {
    floor = floor,
    ceil = ceil,
    hash_pt = hash_pt,
    Vec2d = Vec2d,
    Box = Box,
    UniformGrid = UniformGrid,
    SetList = SetList,
}
