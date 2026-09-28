-- cleanup.lua - Destroy all old HUDs before loading new
local NAMES = {
    "S2DeltaUI",       -- HUD cũ chính
    "ToRungHUB",       -- HUD mới
    "ToRungLobby",     -- Lobby cũ
    "ZERO HUB",        -- Alternative cũ
    "ZeroLoader",      -- Loader cũ
    "EthosNotifications",
}

local cleaned = 0

local function cleanIn(parent, label)
    if not parent then return end
    for _, child in ipairs(parent:GetChildren()) do
        for _, name in ipairs(NAMES) do
            if child.Name == name then
                pcall(function() child:Destroy() end)
                cleaned = cleaned + 1
                print("[Cleanup] destroyed " .. name .. " (" .. label .. ")")
                break
            end
        end
    end
end

pcall(function()
    cleanIn(game:GetService("CoreGui"), "CoreGui")
end)

pcall(function()
    local lp = game:GetService("Players").LocalPlayer
    if lp and lp:FindFirstChild("PlayerGui") then
        cleanIn(lp.PlayerGui, "PlayerGui")
    end
end)

if type(gethui) == "function" then
    pcall(function()
        local h = gethui()
        if h then cleanIn(h, "gethui") end
    end)
end

if type(get_hidden_gui) == "function" then
    pcall(function()
        local h = get_hidden_gui()
        if h then cleanIn(h, "hidden_gui") end
    end)
end

print("[ToRung/Cleanup] cleared " .. tostring(cleaned) .. " old HUD(s)")
