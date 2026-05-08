-- lovekit Sequence — coroutine-driven scripted control flow.
-- Pure Lua except wait_for_key (Love-only); kept verbatim sans wait_for_key.

local support = require("lovekit.support")
local smoothstep = support.smoothstep

local insert = table.insert
local resume_co = coroutine.resume
local yield = coroutine.yield
local create_co = coroutine.create
local status_co = coroutine.status

local Sequence

local default_scope = {
    again = function()
        yield("again")
        return nil
    end,
    wait = function(time)
        while time > 0 do
            time = time - yield()
        end
        if time < 0 then
            return yield("more", -time)
        end
    end,
    wait_until = function(fn)
        local dt, ret
        local elapsed = 0
        while true do
            ret = fn(elapsed)
            if ret then break end
            dt = yield()
            elapsed = elapsed + dt
        end
        if dt then yield("more", dt) end
        return ret
    end,
    await = function(fn, ...)
        local out
        local called = false
        local cb = function(...) called = true; out = { ... } end
        if select("#", ...) > 0 then
            local args = { ... }
            insert(args, cb)
            fn(unpack(args))
        else
            fn(cb)
        end
        while not called do yield() end
        return unpack(out)
    end,
    during = function(time, fn)
        while time > 0 do
            local dt = yield()
            time = time - dt
            if time < 0 then dt = dt + time end
            if fn(dt) == "cancel" then break end
        end
        if time < 0 then return yield("more", -time) end
    end,
    wait_for_one = function(...)
        local seqs = {}
        local fns = { ... }
        for i = 1, #fns do seqs[i] = Sequence(fns[i]) end
        while true do
            local dt = yield()
            for idx, seq in ipairs(seqs) do
                if not seq:update(dt) then return idx end
            end
        end
    end,
    parallel = function(...)
        local seqs = {}
        local fns = { ... }
        for i = 1, #fns do
            local fn = fns[i]
            if fn then
                if type(fn) == "function" then
                    seqs[#seqs + 1] = Sequence(fn)
                elseif fn.__class == Sequence then
                    seqs[#seqs + 1] = fn
                else
                    error("parallel: expected function or sequence, got: " .. type(fn))
                end
            end
        end
        if not next(seqs) then return end
        while true do
            local dt = yield()
            local running = 0
            for idx, seq in pairs(seqs) do
                if seq then
                    local alive = seq:update(dt)
                    if alive then running = running + 1
                    else seqs[idx] = false end
                end
            end
            if running == 0 then break end
        end
    end,
    tween = function(obj, time, props, step, onupdate)
        step = step or smoothstep
        local t = 0
        local initial = {}
        for key in pairs(props) do initial[key] = obj[key] end
        while t < 1.0 do
            for key, finish in pairs(props) do
                obj[key] = step(initial[key], finish, t)
            end
            if onupdate then onupdate(obj) end
            t = t + (yield() / time)
        end
        for key, finish in pairs(props) do
            obj[key] = finish
            if onupdate then onupdate(obj) end
        end
        local leftover = (t - 1.0) * time
        if leftover > 0 then
            return yield("more", leftover)
        end
    end,
    run = function(fn, ...)
        local env = getfenv(2)
        setfenv(fn, env)
        return fn(...)
    end,
}

local function resume(co, ...)
    local ok, err, v = resume_co(co, ...)
    if not ok then error(err or "Failed to resume coroutine") end
    return err, v
end

Sequence = {}
Sequence.__index = Sequence
Sequence.__name = "Sequence"
Sequence.default_scope = default_scope

local Sequence_mt = {
    __call = function(cls, fn, scope, ...)
        local self = setmetatable({ elapsed = 0 }, Sequence)
        self.__class = Sequence
        if scope then
            for k, v in pairs(scope) do
                if type(v) == "function" then Sequence:setfenv(v, scope) end
            end
            setmetatable(scope, { __index = Sequence.default_scope })
        end
        self.fn = Sequence:setfenv(fn, scope)
        self:create(...)
        return self
    end,
}
setmetatable(Sequence, Sequence_mt)

function Sequence:create(...)
    self.args = { ... }
    self.co = create_co(self.fn)
    self.started = false
end

function Sequence:start(...)
    self.started = true
    return resume(self.co, ...)
end

function Sequence:is_dead()
    return status_co(self.co) == "dead"
end

function Sequence:send_time(dt)
    while true do
        if not self.started then self:start(unpack(self.args)) end
        if self:is_dead() then return false end
        local signal, val = resume(self.co, dt)
        if signal == "again" then
            self:create()
        elseif signal == "more" then
            self:send_time(0)
            dt = val
        else
            break
        end
    end
    return true
end

function Sequence:update(dt)
    self.elapsed = self.elapsed + dt
    return self:send_time(dt)
end

function Sequence:respond() end
function Sequence:draw() end

function Sequence.after(_, time, fn)
    return Sequence(function()
        wait(time)
        return fn()
    end)
end

function Sequence.extend(_, tbl)
    for k, v in pairs(tbl) do
        if type(v) == "function" then Sequence:setfenv(v, tbl) end
    end
    Sequence.default_scope = setmetatable(tbl, { __index = Sequence.default_scope })
end

function Sequence.join(...)
    local seqs = { ... }
    return setmetatable({
        _seqs = seqs,
        update = function(self, dt)
            local alive = false
            for i = 1, #seqs do
                alive = seqs[i]:update(dt) or alive
            end
            return alive
        end,
    }, {
        __index = function(t, key)
            local val = seqs[1][key]
            if type(val) == "function" then
                val = function(self, ...)
                    for i = 1, #seqs do
                        if seqs[i][key] then seqs[i][key](seqs[i], ...) end
                    end
                end
                t[key] = val
            end
            return val
        end,
    })
end

function Sequence:setfenv(fn, scope)
    scope = scope or self.default_scope or default_scope
    if scope then
        local old_env = getfenv(fn)
        setfenv(fn, setmetatable({}, {
            __index = function(_, name)
                local val = scope[name]
                if val ~= nil then return val end
                return old_env[name]
            end,
        }))
    end
    return fn
end

return { Sequence = Sequence }
