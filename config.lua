-- config.lua - Save/load hub configuration
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[ToRung/CFG] Core chưa chạy") end

local HttpService = game:GetService("HttpService")
local log = S2.Core.log
local FOLDER = "ToRungHub/configs"
local AUTOLOAD = "ToRungHub/autoload.txt"

local Config = { Current = "" }

local function ensureFolder()
    if not isfolder("ToRungHub") then makefolder("ToRungHub") end
    if not isfolder(FOLDER) then makefolder(FOLDER) end
end

function Config:List()
    ensureFolder()
    local list = {}
    local ok, files = pcall(listfiles, FOLDER)
    if ok and type(files) == "table" then
        for _, f in ipairs(files) do
            local name = tostring(f):match("([^/\\]+)%.json$")
            if name then table.insert(list, name) end
        end
    end
    table.sort(list)
    return list
end

local function snapshot()
    local data = { Version = "1.0", Webhook = {}, Extras = {}, Features = {} }
    if S2.Webhook then
        data.Webhook.URL = S2.Webhook.URL
        data.Webhook.Enabled = S2.Webhook.Enabled
        data.Webhook.Events = S2.Webhook.Events
    end
    if S2.Extras then
        data.Extras.HealthGuard = S2.Extras.HealthGuard
        data.Extras.GuardPct = S2.Extras.GuardPct
        data.Extras.AutoSouls = S2.Extras.AutoSouls
        data.Extras.SoulsRate = S2.Extras.SoulsRate
        data.Extras.TrainStation = S2.Extras.TrainStation
    end
    if S2.Features and S2.Features.Features and S2.Features.Features.Config then
        data.Features = S2.Features.Features.Config
    end
    return data
end

function Config:Save(name)
    if not name or name == "" then return false, "name required" end
    ensureFolder()
    local data = snapshot()
    data.Name = name
    local path = FOLDER .. "/" .. name .. ".json"
    local ok, err = pcall(function()
        writefile(path, HttpService:JSONEncode(data))
    end)
    if ok then
        Config.Current = name
        log("[CFG] saved:", name)
        return true
    end
    return false, err
end

function Config:Load(name)
    if not name or name == "" then return false, "name required" end
    ensureFolder()
    local path = FOLDER .. "/" .. name .. ".json"
    if not isfile(path) then return false, "not found" end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(data) ~= "table" then return false, "invalid json" end

    if S2.Webhook and type(data.Webhook) == "table" then
        S2.Webhook.URL = data.Webhook.URL or ""
        S2.Webhook.Enabled = data.Webhook.Enabled or false
        if type(data.Webhook.Events) == "table" then
            S2.Webhook.Events = data.Webhook.Events
        end
        S2.Webhook:Save()
    end

    if S2.Extras and type(data.Extras) == "table" then
        S2.Extras.GuardPct = data.Extras.GuardPct or S2.Extras.GuardPct
        S2.Extras.SoulsRate = data.Extras.SoulsRate or S2.Extras.SoulsRate
        S2.Extras.TrainStation = data.Extras.TrainStation or S2.Extras.TrainStation
    end

    if S2.Features and S2.Features.Features and type(data.Features) == "table" then
        for k, v in pairs(data.Features) do
            S2.Features.Features.Config[k] = v
        end
    end

    Config.Current = name
    log("[CFG] loaded:", name)
    return true
end

function Config:Delete(name)
    if not name or name == "" then return false end
    local path = FOLDER .. "/" .. name .. ".json"
    if isfile(path) then
        pcall(delfile, path)
        log("[CFG] deleted:", name)
        return true
    end
    return false
end

function Config:SetAutoLoad(name)
    ensureFolder()
    pcall(function() writefile(AUTOLOAD, name or "") end)
end

function Config:GetAutoLoad()
    ensureFolder()
    if isfile(AUTOLOAD) then
        local ok, name = pcall(readfile, AUTOLOAD)
        if ok and name and name ~= "" then return name end
    end
    return ""
end

ensureFolder()
S2.Config = Config

print("[ToRung/CFG] ready")
