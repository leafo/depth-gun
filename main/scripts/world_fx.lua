-- World effects — mutations to world state, often via tween.
--
-- All functions here take `world` as their first argument. They yield via
-- tween/parallel internally, so they must be called from inside a Sequence
-- (i.e. from a wave body's coroutine).

local M = {}

-- Tween scroll_speed to s over t seconds. t == 0 sets instantly.
function M.set_speed(world, s, t)
    t = t or 3.0
    s = s or 2  -- GameSpace's default scroll_speed
    if t == 0 then
        world.space.scroll_speed = s
    else
        tween(world.space, t, { scroll_speed = s })
    end
end

-- Switch the tunnel background instantly. (No yield.)
function M.set_bg(world, name)
    if world.tunnel_set_bg then world.tunnel_set_bg(name) end
end

-- Rotate the world over 1–2 seconds. Direction is one of:
--   "normal" → snap-tween back to 0
--   "flip"   → over to π
--   "left"   → full +2π loop, then truncate to original
--   "right"  → full -2π loop, then truncate to original
function M.roll(world, dir)
    local rot = world.space.world_rot
    if dir == "normal" then
        tween(world.space, 1.0, { world_rot = 0 })
    elseif dir == "flip" then
        tween(world.space, 1.0, { world_rot = math.pi })
    elseif dir == "left" then
        tween(world.space, 2.0, { world_rot = rot + math.pi * 2 })
        world.space.world_rot = rot
    elseif dir == "right" then
        tween(world.space, 2.0, { world_rot = rot - math.pi * 2 })
        world.space.world_rot = rot
    else
        error("unknown roll direction: " .. tostring(dir))
    end
end

-- Tilt the world along horiz ("left"/"right"/"center"/nil) and vert
-- ("up"/"down"/"center"/nil). speed = 1 → 1 second; bigger = faster.
function M.bank(world, horiz, vert, speed)
    speed = speed or 1
    local t = 1 / speed
    local a, b
    if horiz == "left" then
        a = function() tween(world.space, t, { world_rot = math.pi / 4, tunnel_dir_x = -10 }) end
    elseif horiz == "right" then
        a = function() tween(world.space, t, { world_rot = -math.pi / 4, tunnel_dir_x = 10 }) end
    elseif horiz == "center" then
        a = function() tween(world.space, t, { world_rot = 0, tunnel_dir_x = 0 }) end
    elseif horiz == nil then
        a = nil
    else
        error("unknown bank horizontal: " .. tostring(horiz))
    end
    if vert == "up" then
        b = function() tween(world.space, t, { tunnel_dir_y = -15 }) end
    elseif vert == "down" then
        b = function() tween(world.space, t, { tunnel_dir_y = 15 }) end
    elseif vert == "center" then
        b = function() tween(world.space, t, { tunnel_dir_y = 0 }) end
    elseif vert == nil then
        b = nil
    else
        error("unknown bank vertical: " .. tostring(vert))
    end
    parallel(a, b)
end

-- Composite: bank + speed-up + bg switch + return-to-normal. Picks a random
-- bank direction so successive enter_bg calls feel varied.
function M.enter_bg(world, bg)
    local choices = {
        { nil,    "down" },
        { "left", "up"   },
        { "right", "up"  },
    }
    local pick = choices[math.random(#choices)]
    local bx, by = pick[1], pick[2]
    parallel(
        function() M.bank(world, bx, by) end,
        function() M.set_speed(world, 10) end,
        function()
            wait(0.1)
            M.set_bg(world, bg)
        end
    )
    parallel(
        function() M.set_speed(world, nil, 1.0) end,
        function() M.bank(world, "center", "center") end
    )
    wait(1.0)
end

return M
