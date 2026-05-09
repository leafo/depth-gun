-- Owns top-level state previously dumped into _G:
--   config (viewport, scale, debug, did_tutorial),
--   audio singleton,
--   world singleton.
--
-- Scripts get state via game_state.get_world() / get_audio() / get_config()
-- instead of reading globals directly. game_state.init() is called once at
-- engine start (from bootstrap_init.script).
--
-- This file's top-level require also pulls in `lovekit.all` to set up the
-- bare-Lua porting conveniences (Vec2d, Box, smooth_approach, pop_in, the
-- Sequence DSL helpers, etc.) so callers don't have to.

require("lovekit.all")
local Audio = require("lovekit.audio").Audio
local world_module = require("main.scripts.world")

local M = {}

local _config
local _audio
local _world

function M.init()
    math.randomseed(os.time())
    _config = {
        viewport_width  = 320,
        viewport_height = 240,
        scale           = 3,
        debug           = false,
        did_tutorial    = false,
    }
    _audio = Audio()
    _world = world_module.create()
end

function M.get_config() return _config end
function M.get_audio()  return _audio end
function M.get_world()  return _world end

-- Reset gameplay-mutable fields on the existing world table without
-- replacing it. Spawn helpers and the player view stay intact (they were
-- registered by world_update / player at init, and the table identity
-- is preserved).
function M.reset_world()
    if not _world then return end
    -- Despawn any live entities so factory.create count goes back down.
    for i = 1, #(_world.entities or {}) do
        local e = _world.entities[i]
        if e and e.id then go.delete(e.id) end
    end
    _world.entities    = {}
    _world.particles   = {}
    _world.score       = 0
    _world.score_mult  = 1
    _world.time        = 0
    _world.tunnel_alpha = 1
    _world.wave        = nil
    -- Reset GameSpace's stateful fields.
    if _world.space then
        _world.space.scroll_speed   = 2
        _world.space.rot            = 0
        _world.space.world_rot      = 0
        _world.space.xtilt          = 0
        _world.space.ytilt          = 0
        _world.space.tunnel_dir_x   = 0
        _world.space.tunnel_dir_y   = 0
        _world.space.offset         = 0
    end
end

return M
