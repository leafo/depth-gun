-- Forever — endless mode. Uses the coroutine wave engine: bare functions
-- (wait, parallel, tween, wait_until) for control flow; world_fx / entity_fx
-- for state mutation; wave:add_enemy / wait_for_enemies for wave-local
-- bookkeeping; ui_actions for the (currently stubbed) text-box prompts.

local fx         = require("main.scripts.world_fx")
local ent        = require("main.scripts.entity_fx")
local ui         = require("main.scripts.ui_actions")
local game_state = require("main.scripts.game_state")

local M = {}

local BG_OPTS_BASE = { hole = 1, hole2 = 1, hair = 1 }

-- Spawn `count` enemies in random aim_box positions and let them wander.
local function spawn_random_burst(wave, world, count)
    local fns = {}
    for _ = 1, count do
        fns[#fns + 1] = function()
            wait(rand(0.4, 0.8))
            local x, y = world.space.aim_box:random_point()
            local e = wave:add_enemy(x, y)
            wait(rand(0.8, 1.5))
            if e and e.alive and not e.dying then
                ent.move_to_z(e, rand(0.6, 0.9))
            end
            while e and e.alive and not e.dying do
                if chance(0.3) then
                    local nx, ny = world.space.aim_box:random_point()
                    ent.move_to(e, nx, ny)
                else
                    wait(rand(2.0, 2.5))
                end
            end
        end
    end
    parallel(unpack(fns))
end

function M.body(wave, world)
    wave.current_bg = "hole2"
    game_state.get_audio():play_music("theme")

    ui.show_box("entering intestine")
    ui.wait_or_confirm()
    ui.hide_box()
    fx.enter_bg(world, "hole")
    wave.current_bg = "hole"

    while true do
        local flipped = false
        local bursts  = 1 + math.min(5, math.floor(wave.difficulty / 2))

        for i = 1, bursts do
            if flipped then
                fx.roll(world, "normal")
                flipped = false
            else
                flipped = chance(0.3)
                if flipped then
                    fx.roll(world, "flip")
                elseif i > 1 and chance(0.3) then
                    fx.roll(world, pick_one("left", "right"))
                end
            end
            spawn_random_burst(wave, world, math.min(wave.difficulty, 8))
        end
        if flipped then fx.roll(world, "normal") end

        -- Pick a different bg for the next round.
        local opts = {}
        for k, v in pairs(BG_OPTS_BASE) do opts[k] = v end
        if wave.difficulty > 2 then opts.grid = 1 end
        opts[wave.current_bg] = nil
        local next_bg = pick_dist(opts)
        fx.enter_bg(world, next_bg)
        wave.current_bg = next_bg
        wave.difficulty = wave.difficulty + 1
    end
end

return M
