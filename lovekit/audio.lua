-- Audio module — Defold port of lovekit/audio.lua.
--
-- Sound components are pre-declared on `/cues.go` (see main/cues.go).
-- Each cue maps a string name to a sound URL. Music tracks (theme/title) are
-- looping sound components; they're started/stopped via play_sound/stop_sound.

local Audio = {}
Audio.__index = Audio

local DEFAULT_CUES = {
    explode    = "/cues#snd_explode",
    lock       = "/cues#snd_lock",
    locking    = "/cues#snd_locking",
    missile    = "/cues#snd_missile",
    notarget   = "/cues#snd_notarget",
    shoot      = "/cues#snd_shoot",
    enemy_hit  = "/cues#snd_enemy_hit",
    player_hit = "/cues#snd_player_hit",
    lose_shield = "/cues#snd_lose_shield",
    start      = "/cues#snd_start",
    theme      = "/cues#snd_theme",
    title      = "/cues#snd_title",
}

setmetatable(Audio, {
    __call = function(cls, cues)
        local self = setmetatable({}, Audio)
        self.cues = cues or DEFAULT_CUES
        self.current_music = nil
        return self
    end,
})

function Audio:url(name)
    local u = self.cues[name]
    if not u then
        print("AUDIO: unknown cue '" .. tostring(name) .. "'")
        return nil
    end
    return u
end

function Audio:play(name, gain)
    local u = self:url(name); if not u then return end
    msg.post(u, "play_sound", { gain = gain or 1.0 })
end

function Audio:stop(name)
    local u = self:url(name); if not u then return end
    msg.post(u, "stop_sound")
end

function Audio:play_music(name, looping)
    if self.current_music and self.current_music ~= name then
        self:stop(self.current_music)
    end
    self.current_music = name
    local u = self:url(name); if not u then return end
    msg.post(u, "play_sound", { gain = 0.5 })
end

function Audio:stop_music()
    if self.current_music then
        self:stop(self.current_music)
        self.current_music = nil
    end
end

function Audio:fade_music()
    -- TODO: implement fade via Sequence. For M3 just stop.
    self:stop_music()
end

function Audio:preload(_) end -- Defold preloads via component declaration

return { Audio = Audio }
