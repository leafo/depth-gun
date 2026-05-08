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

function M.reset_world()
    _world = world_module.create()
    return _world
end

return M
