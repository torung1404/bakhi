-- ToRung HUB Loader
local REPO = "torung1404/bakhi/main"
local BASE = "https://raw.githubusercontent.com/" .. REPO .. "/"
local files = {
    "core.lua", "features.lua", "ui.lua",
    "webhook.lua", "config.lua", "extras.lua", "ui_extras.lua",
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

for _, f in ipairs(files) do
    print("[ToRung] loading: " .. f)
    local url = BASE .. f .. CACHE_BUST
    local code = fetch(url)
    if not code then warn("[ToRung] fetch failed: " .. f); return end
    if not (code:find("local") or code:find("function") or code:find("return")) then
        warn("[ToRung] not Lua: " .. f); return
    end
    local fn, err = loadstring(code, "@" .. f)
    if not fn then warn("[ToRung] compile err " .. f .. ": " .. tostring(err)); return end
    local ok, rerr = pcall(fn)
    if not ok then warn("[ToRung] runtime err " .. f .. ": " .. tostring(rerr)); return end
    task.wait(0.4)
end
print("[ToRung] ALL DONE")
