-- Entity definitions: Bullet, Enemy, Particle. Each has a shared methods
-- table (used as __index metatable) so spawn functions don't allocate
-- closures per instance.
--
-- An entity is a plain Lua table representing the game-side state of a
-- factory-spawned GO. The world_update.script drives the per-frame loop:
--   e:update(dt, world)                — kinematics, AI ticks
--   e:on_hit_by(other, world)          — collision response (enemies only)
--   e:update_transform(space)          — write position/scale/rotation/tint to the GO
--
-- All collision and z-projection happens through this shared interface,
-- so adding a new entity type means: new metatable + new spawn function +
-- (optionally) new factory URL.

local game_state = require("main.scripts.game_state")

local FLASH_DURATION = 0.15
local ENEMY_DEFAULT_HEALTH = 3

local M = {}

-- ---------------------------------------------------------------------------
-- Bullet
-- ---------------------------------------------------------------------------

local Bullet = {}
Bullet.__index = Bullet

function Bullet:update(dt, world)
    self.z = self.z + dt * self.speed
    if self.z >= 3 then self.alive = false end
    return self.alive
end

function Bullet:update_transform(space)
    local px, py, scale = space:project(self.x, self.y, self.z)
    go.set_position(vmath.vector3(px, py, 23), self.id)
    go.set_scale(scale, self.id)
end

function M.create_bullet(factory_url, x, y, z)
    local id = factory.create(factory_url)
    if not id then return nil end
    return setmetatable({
        id        = id,
        kind      = "bullet",
        is_bullet = true,
        x         = x,
        y         = y,
        z         = z,
        w         = 5,
        h         = 5,
        alive     = true,
        damage    = 1,
        speed     = 2,
    }, Bullet)
end

-- ---------------------------------------------------------------------------
-- Enemy
-- ---------------------------------------------------------------------------

local Enemy = {}
Enemy.__index = Enemy

function Enemy:update(dt, world)
    if self.flash_time > 0 then
        self.flash_time = self.flash_time - dt
    end
    return self.alive
end

function Enemy:on_hit_by(bullet, world)
    if self.dying or not self.alive then return end
    if math.abs(self.z - bullet.z) >= 0.1 then return end

    bullet.alive = false
    self.health = self.health - bullet.damage
    self.flash_time = FLASH_DURATION
    local audio = game_state.get_audio()
    audio:play("enemy_hit")
    if self.health <= 0 then
        self.dying = true
        self.alive = false
        audio:play("explode")
        world.score = world.score + 7 * world.score_mult
        if world.spawn_explosion then
            world.spawn_explosion(self.x, self.y, self.z)
        end
    end
end

function Enemy:update_transform(space)
    local px, py, scale, rot = space:project(self.x, self.y, self.z)
    go.set_position(vmath.vector3(px, py, 22), self.id)
    go.set_scale(scale, self.id)
    go.set_rotation(vmath.quat_rotation_z(-rot), self.id)
    local tint
    if self.flash_time > 0 then
        tint = vmath.vector4(1.5, 0.4, 0.4, 1)
    else
        tint = vmath.vector4(1, 1, 1, 1)
    end
    go.set(self.body_l_url, "tint", tint)
    go.set(self.body_r_url, "tint", tint)
end

function M.create_enemy(factory_url, x, y, opts)
    opts = opts or {}
    local id = factory.create(factory_url)
    if not id then return nil end
    return setmetatable({
        id          = id,
        body_l_url  = msg.url(nil, id, "body_l"),
        body_r_url  = msg.url(nil, id, "body_r"),
        kind        = "enemy",
        is_enemy    = true,
        x           = x,
        y           = y,
        z           = opts.z or 2.0,
        w           = opts.w or 12,
        h           = opts.h or 8,
        alive       = true,
        dying       = false,
        health      = opts.health or ENEMY_DEFAULT_HEALTH,
        flash_time  = 0,
    }, Enemy)
end

-- ---------------------------------------------------------------------------
-- Missile
-- ---------------------------------------------------------------------------

local Missile = {}
Missile.__index = Missile

function Missile:update(dt, world)
    -- Target died: stop chasing, fizzle out.
    if not self.target or not self.target.alive then
        self.alive = false
        return false
    end

    -- Home on target's space-coords.
    self.x = smooth_approach(self.x, self.target.x, dt * 5)
    self.y = smooth_approach(self.y, self.target.y, dt * 5)
    self.z = self.z + dt * self.speed
    if self.z >= 3 then self.alive = false; return false end

    -- Smoke trail every 0.05s.
    self.smoke_timer = self.smoke_timer - dt
    if self.smoke_timer <= 0 then
        self.smoke_timer = 0.05
        if world.spawn_smoke then
            world.spawn_smoke(self.x, self.y, self.z)
        end
    end
    return true
end

function Missile:update_transform(space)
    local px, py, scale = space:project(self.x, self.y, self.z)
    go.set_position(vmath.vector3(px, py, 23), self.id)
    go.set_scale(scale, self.id)
end

function M.create_missile(factory_url, x, y, z, target)
    local id = factory.create(factory_url)
    if not id then return nil end
    return setmetatable({
        id          = id,
        kind        = "missile",
        is_bullet   = true,    -- collide via the same bullet→enemy pipeline
        is_missile  = true,
        x           = x,
        y           = y,
        z           = z,
        w           = 6,
        h           = 6,
        alive       = true,
        damage      = 4,
        speed       = 1,
        target      = target,
        smoke_timer = 0,
    }, Missile)
end

-- ---------------------------------------------------------------------------
-- Particle
-- ---------------------------------------------------------------------------

local Particle = {}
Particle.__index = Particle

function Particle:update(dt, world)
    self.life = self.life - dt
    if self.life <= 0 then
        self.alive = false
        return false
    end
    self.vx = self.vx + self.ax * dt
    self.vy = self.vy + self.ay * dt
    self.vz = self.vz + self.az * dt
    self.x  = self.x  + self.vx * dt
    self.y  = self.y  + self.vy * dt
    self.z  = self.z  + self.vz * dt
    self.scale = self.scale * (1 + self.dscale * dt)
    self.rot   = self.rot   + self.spin * dt
    return true
end

function Particle:update_transform(space)
    local px, py, scale = space:project(self.x, self.y, self.z)
    go.set_position(vmath.vector3(px, py, 23.5), self.id)
    go.set_scale(scale * self.scale, self.id)
    go.set_rotation(vmath.quat_rotation_z(self.rot), self.id)
    local p = 1 - (self.life / self.max_life)
    local a = ad_curve(p, 0, self.ad_left, self.ad_right) * self.alpha
    go.set(self.sprite_url, "tint",
        vmath.vector4(self.tint_r, self.tint_g, self.tint_b, a))
end

function M.create_particle(factory_url, opts)
    local id = factory.create(factory_url)
    if not id then return nil end
    local life = opts.life or 0.5
    local p = setmetatable({
        id          = id,
        sprite_url  = msg.url(nil, id, "sprite"),
        kind        = "particle",
        is_particle = true,
        x  = opts.x or 0, y  = opts.y or 0, z  = opts.z or 0,
        vx = opts.vx or 0, vy = opts.vy or 0, vz = opts.vz or 0,
        ax = opts.ax or 0, ay = opts.ay or 0, az = opts.az or 0,
        life        = life,
        max_life    = life,
        ad_left     = opts.ad_left or 0,
        ad_right    = opts.ad_right or 1,
        scale       = opts.scale or 1,
        dscale      = opts.dscale or 0,
        rot         = opts.rot or 0,
        spin        = opts.spin or 0,
        alpha       = opts.alpha or 1,
        tint_r      = opts.tint_r or 1,
        tint_g      = opts.tint_g or 1,
        tint_b      = opts.tint_b or 1,
        alive       = true,
    }, Particle)
    if opts.sprite_anim then
        sprite.play_flipbook(p.sprite_url, hash(opts.sprite_anim))
    end
    return p
end

-- ---------------------------------------------------------------------------
-- Composite spawners
-- ---------------------------------------------------------------------------

-- Single smoke puff for missile trails.
function M.create_smoke_puff(particle_factory_url, x, y, z, world)
    local rand = math.random
    local angle = rand() * math.pi * 2
    local speed = 8 + rand() * 12
    world.entities[#world.entities + 1] = M.create_particle(particle_factory_url, {
        x = x, y = y, z = z,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        vz = -0.3,
        ay = 30,
        life = 0.5,
        scale = 0.6, dscale = 0.4,
        spin = (rand() - 0.5) * 1.5,
        sprite_anim = (rand() < 0.5) and "smoke" or "smoke_2",
        tint_r = 0.6, tint_g = 0.6, tint_b = 0.5,
        alpha = 0.6, ad_left = 0.1, ad_right = 0.6,
    })
end

-- Source's Explosion: 0.1s burst of 20 particles. 1 Flame + mix of Sparks/Smokes.
function M.create_explosion(particle_factory_url, x, y, z, world)
    local rand = math.random
    local function add(opts) world.entities[#world.entities + 1] = M.create_particle(particle_factory_url, opts) end

    -- Flame: bright red flash, fast shrink
    add({
        x = x, y = y, z = z,
        vx = 0, vy = 0, vz = -2,
        life = 0.18,
        scale = 1.6, dscale = -3,
        sprite_anim = "spark",
        tint_r = 1.0, tint_g = 0.4, tint_b = 0.3,
    })
    -- 11 sparks
    for _ = 1, 11 do
        local angle = rand() * math.pi * 2
        local speed = 80 + rand() * 60
        add({
            x = x, y = y, z = z,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            vz = -1 - rand() * 2,
            ay = -200,
            life = 0.3 + rand() * 0.3,
            scale = 1, dscale = -0.4,
            spin = (rand() - 0.5) * 8,
            sprite_anim = (rand() < 0.5) and "spark" or "spark2",
            tint_r = 1.0, tint_g = 0.8, tint_b = 0.5,
            ad_right = 0.7,
        })
    end
    -- 8 smokes
    for _ = 1, 8 do
        local angle = rand() * math.pi * 2
        local speed = 20 + rand() * 30
        add({
            x = x, y = y, z = z,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            vz = -1,
            ay = 50,
            life = 0.5,
            scale = 1, dscale = 0.6,
            spin = (rand() - 0.5) * 2,
            sprite_anim = (rand() < 0.5) and "smoke" or "smoke_2",
            tint_r = 0.6, tint_g = 0.5, tint_b = 0.4,
            alpha = 0.8, ad_left = 0.1, ad_right = 0.6,
        })
    end
end

return M
