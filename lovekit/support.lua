-- Pure-Lua subset of lovekit/support.lua. Love2D-only helpers (bench/show_grid/duty_on
-- variants that read love.timer) are dropped or rewritten against os.clock.

local punct = "[%^$()%.%[%]*+%-?]"
local _min, _max = math.min, math.max
local _random = math.random

local M = {}

function M.rand(min, max)
    return _random() * (max - min) + min
end

function M.chance(p)
    return _random() <= p
end

function M.random_normal()
    return (_random() + _random() + _random() + _random()
          + _random() + _random() + _random() + _random()
          + _random() + _random() + _random() + _random()) / 12
end

function M.smoothstep(a, b, t)
    t = t * t * t * (t * (t * 6 - 15) + 10)
    return a + (b - a) * t
end

function M.sqrt_step(a, b, t)
    return a + (b - a) * math.sqrt(t)
end

function M.pow_step(a, b, t)
    return a + (b - a) * (t ^ 2)
end

function M.lerp(a, b, t)
    return a + (b - a) * t
end

function M.cubic_bez(p0, p1, p2, p3, t)
    local nt = (1 - t)
    local nt2 = nt * nt
    local nt3 = nt2 * nt
    local t2 = t * t
    local t3 = t2 * t
    return (nt3 * p0) + (3 * nt2 * t * p1) + (3 * nt * t2 * p2) + (t3 * p3)
end

function M.ad_curve(t, start, attack, decay, stop)
    if stop == nil then stop = 1 end
    if t < start then return 0 end
    if t > stop then return 0 end
    if t < attack then return (t - start) / (attack - start) end
    if t > decay then return 1 - (t - decay) / (stop - decay) end
    return 1
end

function M.pop_in(t, time, amount, decay)
    if time == nil then time = 0.1 end
    if amount == nil then amount = 1.1 end
    if decay == nil then decay = 1 end
    local pop_out_time = time * decay
    if t < time then
        return M.lerp(0, amount, t / time)
    elseif t < time + pop_out_time then
        return M.lerp(amount, 1, (t - time) / pop_out_time)
    else
        return 1
    end
end

function M.escape_patt(str)
    return (str:gsub(punct, function(p) return "%" .. p end))
end

function M.split(str, delim)
    str = str .. delim
    local out = {}
    local n = 1
    for part in str:gmatch("(.-)" .. M.escape_patt(delim)) do
        out[n] = part
        n = n + 1
    end
    return out
end

function M.extend(...)
    local tbls = { ... }
    if #tbls < 2 then return end
    for i = 1, #tbls - 1 do
        setmetatable(tbls[i], { __index = tbls[i + 1] })
    end
    return tbls[1]
end

function M.merge(first, second, ...)
    if not (first and second) then return first end
    for k, v in pairs(second) do first[k] = v end
    return M.merge(first, ...)
end

function M.approach(val, target, amount)
    if val == target then return val end
    if val > target then
        return _max(target, val - amount)
    else
        return _min(target, val + amount)
    end
end

function M.smooth_approach(val, target, amount)
    return M.approach(val, target, amount * (1 + math.abs(val - target) ^ 1.1))
end

function M.dampen(val, amount, min)
    if min == nil then min = 0 end
    if val > min then
        return _max(min, val - amount)
    elseif val < -min then
        return _min(-min, val + amount)
    else
        return val
    end
end

function M.dampen_vector(vec, amount, min)
    local len = vec:len()
    if len == 0 then return end
    local new_len = M.dampen(len, amount, min)
    vec[1] = vec[1] / len * new_len
    vec[2] = vec[2] / len * new_len
    return vec
end

function M.pick_one(...)
    local num = select("#", ...)
    return (select(_random(1, num), ...))
end

function M.pick_dist(t)
    local sum = 0
    local dist = {}
    local n = 1
    for k, v in pairs(t) do
        if v ~= 0 and v then
            dist[n] = { sum + v, k }
            sum = sum + v
            n = n + 1
        end
    end
    local r = _random() * sum
    for i = 1, #dist do
        local pair = dist[i]
        if r <= pair[1] then return pair[2] end
    end
    error("pick_dist: empty distribution")
end

function M.duty_on(rate, duty, now, start_time)
    if rate == nil then rate = 1.2 end
    if duty == nil then duty = 0.6 end
    if now == nil then now = os.clock() end
    if start_time == nil then start_time = 0 end
    local t = (now - start_time) / rate
    t = t - math.floor(t)
    return t <= duty
end

function M.shuffle(array)
    for i = #array, 2, -1 do
        local j = _random(i)
        array[i], array[j] = array[j], array[i]
    end
    return array
end

function M.reverse(array)
    local len = #array
    for i = 1, math.floor(len / 2) do
        array[i], array[len - i + 1] = array[len - i + 1], array[i]
    end
    return array
end

function M.instance_of(object, cls)
    if type(object) ~= "table" then return false end
    local ocls = object.__class
    while ocls do
        if ocls == cls then return true end
        ocls = type(ocls) == "table" and ocls.__parent or nil
    end
    return false
end

function M.hash_color(r, g, b, a)
    return table.concat({ r, g, b }, ",")
end

function M.get_local(search_name, level)
    if level == nil then level = 1 end
    level = level + 1
    local i = 1
    while true do
        local name, val = debug.getlocal(level, i)
        if not name then break end
        if name == search_name then return val, true, i end
        i = i + 1
    end
    return nil, false, i
end

function M.find_local(name, level)
    if level == nil then level = 1 end
    while true do
        local val, found = M.get_local(name, level + 1)
        if found then return val, level end
        level = level + 1
    end
end

local lazy_key = {}

function M.lazy_value(cls, key, fn)
    local base = cls.__base
    local old_meta = getmetatable(base)
    if old_meta then
        local lazy_values = old_meta[lazy_key]
        if lazy_values then
            lazy_values[key] = fn
            return
        end
    end
    local eigen = setmetatable({}, old_meta)
    local lazy_values = { [key] = fn }
    local meta = {
        [lazy_key] = lazy_values,
        __index = function(self, name)
            local f = lazy_values[name]
            if f then
                lazy_values[name] = nil
                local val = f(base, cls)
                base[name] = val
                if next(lazy_values) == nil then
                    setmetatable(base, old_meta)
                end
                return val
            else
                return eigen[name]
            end
        end,
    }
    return setmetatable(base, meta)
end

function M.lazy_tbl(tbl)
    return setmetatable({}, {
        __index = function(self, name)
            self[name] = tbl[name]()
            return self[name]
        end,
    })
end

function M.lazy(props)
    local cls = M.get_local("self", 2)
    for k, v in pairs(props) do
        M.lazy_value(cls, k, v)
    end
end

return M
