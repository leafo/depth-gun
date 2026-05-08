-- UI actions — text-reveal box and confirmation prompts used by the tutorial.
--
-- M9 phase A (current): stubs that print + wait. The real implementation
-- (M9 phase C) wires these to a GUI that displays an animated text box.

local M = {}

function M.show_box(text)
    print(string.format("[ui/show_box] %s", text))
end

function M.hide_box() end

-- Wait either 3 seconds OR until the player presses confirm. The real
-- implementation (M10) will check a player.has_confirmed flag; for now we
-- just wait the full duration.
function M.wait_or_confirm()
    wait(3)
end

return M
