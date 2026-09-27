-- Slayers 2 Delta Loader
-- Chạy file này trong Delta. Không chứa logic game.

local REPO = "YOUR_USERNAME/slayers2-delta/main"  -- <-- SỬA DÒNG NÀY
local BASE = "https://raw.githubusercontent.com/" .. REPO .. "/"

local files = { "core.lua", "features.lua", "ui.lua" }

for _, f in ipairs(files) do
    print("[S2 LOADER] Loading: " .. f)

    local ok, code = pcall(function()
        return game:HttpGet(BASE .. f, true)
    end)

    if not ok or not code or #code < 10 then
        warn("[S2 LOADER] Failed to fetch " .. f)
        return
    end

    local fn, err = loadstring(code, "@" .. f)
    if not fn then
        warn("[S2 LOADER] Compile error in " .. f .. ": " .. tostring(err))
        return
    end

    local runOk, runErr = pcall(fn)
    if not runOk then
        warn("[S2 LOADER] Runtime error in " .. f .. ": " .. tostring(runErr))
        return
    end

    task.wait(0.5)
end

print("[S2 LOADER] All files loaded.")