-- Entity tween helpers. Yield via tween, so call only from a Sequence
-- (wave body coroutine).

local M = {}

-- Tween entity position toward (x, y, z) over t seconds. Any of x/y/z may be
-- nil to leave that axis unchanged.
function M.move_to(e, x, y, z, t)
    if not e or not e.alive then return end
    t = t or 0.5
    local target = {}
    if x then target.x = x end
    if y then target.y = y end
    if z then target.z = z end
    tween(e, t, target)
end

-- Convenience: tween z only.
function M.move_to_z(e, z, t)
    if not e or not e.alive then return end
    t = t or 0.5
    tween(e, t, { z = z })
end

return M
