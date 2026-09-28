-- ToRung HUB Loader
local REPO = "torung1404/bakhi/main"
local BASE = "https://raw.githubusercontent.com/" .. REPO .. "/"
local files = {
    "cleanup.lua",   -- ← PHẢI đứng đầu
    "core.lua", "features.lua", "ui.lua",
    "webhook.lua", "config.lua", "extras.lua", "ui_extras.lua",
    "performance.lua", "ui_perf.lua",
    "vip.lua", "lobby.lua",
    "crowquest.lua",
}
local CACHE_BUST = "?t=" .. tostring(math.floor(os.time()))

local function fetch(url)
    print("[ToRung] GET " .. url)
    do
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and type(res) == "string" and #res > 10 then return res end
    end
    if type(request) == "function" then
        local ok, res = pcall(function()
            local r = request({ Url = url, Method = "GET" })
            return r and (r.Body or r.body)
        end)
        if ok and type(res) == "string" and #res > 10 then return res end
    end
    if type(http_request) == "function" then
        local ok, res = pcall(function()
            local r = http_request({ Url = url, Method = "GET" })
            return r and (r.Body or r.body)
        end)
        if ok and type(res) == "string" and #res > 10 then return res end
    end
    do
        local ok, res = pcall(function()
            return game:GetService("HttpService"):GetAsync(url)
        end)
        if ok and type(res) == "string" and #res > 10 then return res end
    end
    return nil
end

local failed = {}
for _, f in ipairs(files) do
    print("[ToRung] loading: " .. f)
    local url = BASE .. f .. CACHE_BUST
    local code = fetch(url)
    if not code then
        warn("[ToRung] FETCH FAILED: " .. f)
        table.insert(failed, f .. " (fetch)")
    elseif not (code:find("local") or code:find("function") or code:find("return")) then
        warn("[ToRung] NOT LUA: " .. f)
        table.insert(failed, f .. " (not lua)")
    else
        local fn, err = loadstring(code, "@" .. f)
        if not fn then
            warn("[ToRung] COMPILE ERR " .. f .. ": " .. tostring(err))
            table.insert(failed, f .. " (compile)")
        else
            local ok, rerr = pcall(fn)
            if not ok then
                warn("[ToRung] RUNTIME ERR " .. f .. ": " .. tostring(rerr))
                table.insert(failed, f .. " (runtime)")
            end
        end
    end
    task.wait(0.3)
end

if #failed > 0 then
    warn("[ToRung] FAILED FILES:")
    for _, f in ipairs(failed) do warn("  - " .. f) end
else
    print("[ToRung] ALL DONE (" .. #files .. " files)")
end
