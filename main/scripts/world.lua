-- Singleton "world" table tying together the gameplay subsystems. Required by
-- bootstrap (which initializes it) and by every entity script (which reads
-- world.space, world.player, world.entities, etc.).

local GameSpace = require("main.scripts.game_space").GameSpace

local M = {}

function M.create()
    return {
        space     = GameSpace(),
        time      = 0,
        score     = 0,
        score_mult = 1,
        tunnel_alpha = 1,
        entities  = {},   -- shared entity tables, keyed by URL hash
        particles = {},
    }
end

return M
