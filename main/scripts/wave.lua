-- Wave — instance-bound state for a single scripted level.
--
-- The wave's body function is a coroutine that yields whenever it waits.
-- This module provides ONLY what genuinely needs wave-instance state:
--   * active_enemies bookkeeping (spawn/track/await)
--   * snapshot-relative gating (wait_for_player_to_shoot)
--   * coroutine-driver glue (update(dt))
--
-- Everything else lives in its own module:
--   * Time/coroutine control       → bare globals from lovekit.sequence
--     (wait, wait_until, tween, parallel, wait_for_one)
--   * World effects                → main.scripts.world_fx
--     (set_speed, set_bg, roll, bank, enter_bg)
--   * Entity tweens                → main.scripts.entity_fx
--     (move_to, move_to_z)
--   * UI prompts                   → main.scripts.ui_actions  (M9 phase C)
--     (show_box, hide_box, wait_or_confirm)
--
-- Wave bodies are written as `function(wave, world) ... end`. The wave param
-- is what wave-state methods are called on; world is captured locally for
-- world_fx.* calls. Bare functions like wait/tween are still globals.

local Sequence = require("lovekit.sequence").Sequence

local M = {}

local Wave = {}
Wave.__index = Wave

function M.new(world, body_fn)
    local self = setmetatable({}, Wave)
    self.world          = world
    self.active_enemies = {}
    self.difficulty     = 1
    self._seq = Sequence(function()
        body_fn(self, world)
    end)
    return self
end

-- Spawn an enemy via the world and track it in this wave's local list so
-- wait_for_enemies() can poll just our own enemies (not other waves' or
-- ambient ones).
function Wave:add_enemy(x, y, opts)
    if not self.world.spawn_enemy then return nil end
    local e = self.world.spawn_enemy(x, y, opts)
    if e then self.active_enemies[#self.active_enemies + 1] = e end
    return e
end

-- Yield until every enemy this wave spawned has died.
function Wave:wait_for_enemies()
    local enemies = self.active_enemies
    wait_until(function()
        for i = 1, #enemies do
            if enemies[i].alive then return false end
        end
        return true
    end)
end

-- Snapshot-relative: yield until the player has fired more bullets than at
-- the moment of this call. (Used to gate tutorial steps.)
function Wave:wait_for_player_to_shoot()
    local p = self.world.player
    if not p then return end
    local baseline = p.bullets_fired or 0
    wait_until(function()
        local pp = self.world.player
        return pp and (pp.bullets_fired or 0) > baseline
    end)
end

-- Driver: called every frame from world_update.script. Returns false when the
-- wave's body has run to completion.
function Wave:update(dt)
    -- Prune dead enemies so wait_for_enemies sees up-to-date state.
    local enemies = self.active_enemies
    for i = #enemies, 1, -1 do
        if not enemies[i].alive then
            table.remove(enemies, i)
        end
    end
    return self._seq:update(dt)
end

return M
