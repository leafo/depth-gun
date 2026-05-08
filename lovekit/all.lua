-- lovekit.all — single require entry that also exports symbols globally so
-- ported source code can call `Vec2d(...)`, `AUDIO:play(...)`, etc. without
-- per-file requires. Relies on game.project [script] shared_state = 1.

local support  = require("lovekit.support")
local geometry = require("lovekit.geometry")
local sequence = require("lovekit.sequence")

local M = {}

local function expose(t)
    for k, v in pairs(t) do
        M[k] = v
        rawset(_G, k, v)
    end
end

expose(support)
expose(geometry)
expose(sequence)

-- Inject Sequence DSL helpers (wait/tween/parallel/wait_until/...) as bare
-- globals so non-Sequence code can also call them. (Sequence functions get
-- these via setfenv-injected scope.)
for k, v in pairs(sequence.Sequence.default_scope) do
    M[k] = v
    rawset(_G, k, v)
end

return M
