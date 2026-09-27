-- Slayers 2 Delta Loader
-- Repo: torung1404/bakhi

local REPO = "torung1404/bakhi/main"
local BASE = "https://raw.githubusercontent.com/" .. REPO .. "/"
local files = { "core.lua", "features.lua", "ui.lua" }

for _, f in ipairs(files) do
    print("[S2 LOADER] Loading: " .. f)

    local ok, code = pcall(function()
        return game:HttpGet(BASE .. f, true)
    end)

    if not ok or not code or #code < 10 then
        warn("[S2 LOADER] Failed to fetch " .. f)
        if code then warn("[S2 LOADER] Response: " .. tostring(code):sub(1, 200)) end
        return
    end

    local fn, err = loadstring(code, "@" .. f)
    if not fn then
        warn("[S2 LOADER] Compile error in " .. f .. ": " .. tostring(err))
        return
    end

    local rOk, rErr = pcall(fn)
    if not rOk then
        warn("[S2 LOADER] Runtime error in " .. f .. ": " .. tostring(rErr))
        return
    end

    task.wait(0.5)
end

print("[S2 LOADER] All files loaded.")
