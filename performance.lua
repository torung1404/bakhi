-- performance.lua - Performance Mode for ToRung HUB
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[Perf] core missing") end

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
local log = S2.Core.log
local PATH = "ToRungHub/performance.json"

local Perf = {
    Master = false,
    FullBright = true,
    NoFog = true,
    NoAtmosphere = true,
    ForceTime = true,
    TimeOfDay = 12,
    HideMap = false,
    HideOthers = true,
    HideSelf = false,
    No3D = false,
    FPSCap = 60,
    _saved = nil,
    _mapSaved = nil,
    _transpConns = {},
}

local function ensure()
    if not isfolder("ToRungHub") then makefolder("ToRungHub") end
end

function Perf:Save()
    ensure()
    pcall(function()
        writefile(PATH, HttpService:JSONEncode({
            Master = self.Master, FullBright = self.FullBright,
            NoFog = self.NoFog, NoAtmosphere = self.NoAtmosphere,
            ForceTime = self.ForceTime, TimeOfDay = self.TimeOfDay,
            HideMap = self.HideMap, HideOthers = self.HideOthers,
            HideSelf = self.HideSelf, No3D = self.No3D,
            FPSCap = self.FPSCap,
        }))
    end)
end

function Perf:Load()
    ensure()
    if not isfile(PATH) then return end
    local ok, d = pcall(function() return HttpService:JSONDecode(readfile(PATH)) end)
    if ok and type(d) == "table" then
        for k, v in pairs(d) do if self[k] ~= nil then self[k] = v end end
    end
end

-- ========== Lighting helpers ==========
local function saveLighting()
    if Perf._saved then return end
    Perf._saved = {
        ClockTime = Lighting.ClockTime,
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        FogColor = Lighting.FogColor,
        GlobalShadows = Lighting.GlobalShadows,
    }
end

local function restoreLighting()
    if not Perf._saved then return end
    for k, v in pairs(Perf._saved) do pcall(function() Lighting[k] = v end) end
    Perf._saved = nil
end

local function setFullBright(on)
    if on then
        pcall(function()
            Lighting.Brightness = 3
            Lighting.ClockTime = 12
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(180, 180, 180)
            Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        end)
    end
end

local function setNoFog(on)
    pcall(function()
        if on then
            Lighting.FogEnd = 1e6
            Lighting.FogStart = 1e6
        end
    end)
end

local function setNoAtmosphere(on)
    pcall(function()
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") then e.Enabled = not on end
        end
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm and on then atm.Density = 0; atm.Haze = 0; atm.Glare = 0 end
    end)
end

local function setTime(on, hour)
    if on then pcall(function() Lighting.ClockTime = hour end) end
end

-- ========== Map hide ==========
local function setHideMap(on)
    if on then
        local map = workspace:FindFirstChild("Map")
        if not map then return end
        if not Perf._mapSaved then
            Perf._mapSaved = {}
            for _, p in ipairs(map:GetDescendants()) do
                if p:IsA("BasePart") then
                    Perf._mapSaved[p] = p.LocalTransparencyModifier
                    pcall(function() p.LocalTransparencyModifier = 1 end)
                end
            end
        end
    else
        if Perf._mapSaved then
            for p, orig in pairs(Perf._mapSaved) do
                if p.Parent then
                    pcall(function() p.LocalTransparencyModifier = orig end)
                end
            end
            Perf._mapSaved = nil
        end
    end
end

-- ========== Player transparency ==========
local function setCharTransp(char, on)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") or p:IsA("Decal") then
            pcall(function()
                p.LocalTransparencyModifier = on and 1 or 0
            end)
        end
    end
end

local function clearConns()
    for _, c in ipairs(Perf._transpConns) do
        pcall(function() c:Disconnect() end)
    end
    Perf._transpConns = {}
end

local function setHideOthers(on)
    clearConns()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then setCharTransp(plr.Character, on) end
    end
    if on then
        table.insert(Perf._transpConns, Players.PlayerAdded:Connect(function(plr)
            plr.CharacterAdded:Connect(function(char)
                task.wait(0.5)
                if Perf.Master and Perf.HideOthers then setCharTransp(char, true) end
            end)
        end))
        table.insert(Perf._transpConns, workspace.DescendantAdded:Connect(function(d)
            if not (Perf.Master and Perf.HideOthers) then return end
            if d:IsA("BasePart") and d.Parent and d.Parent:FindFirstAncestorOfClass("Model") then
                local model = d.Parent:FindFirstAncestorOfClass("Model")
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LP then
                    pcall(function() d.LocalTransparencyModifier = 1 end)
                end
            end
        end))
    end
end

local function setHideSelf(on)
    if LP.Character then setCharTransp(LP.Character, on) end
end

-- ========== 3D render ==========
local function setNo3D(on)
    pcall(function() RunService:Set3dRenderingEnabled(not on) end)
end

-- ========== FPS ==========
local function setFPS(cap)
    pcall(function()
        if setfpscap then setfpscap(cap > 0 and cap or 999999) end
    end)
end

-- ========== Apply / Unapply ==========
function Perf:Apply()
    if self.Master then
        saveLighting()
        setFullBright(self.FullBright)
        setNoFog(self.NoFog)
        setNoAtmosphere(self.NoAtmosphere)
        setTime(self.ForceTime, self.TimeOfDay)
        setHideMap(self.HideMap)
        setHideOthers(self.HideOthers)
        setHideSelf(self.HideSelf)
        setNo3D(self.No3D)
        setFPS(self.FPSCap)
    else
        restoreLighting()
        setHideMap(false)
        setHideOthers(false)
        setHideSelf(false)
        setNo3D(false)
        setFPS(0)
        pcall(function()
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") then e.Enabled = true end
            end
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then atm.Density = 0.3; atm.Haze = 1.5; atm.Glare = 0.5 end
        end)
    end
    log("[PERF] master=" .. tostring(self.Master))
end

function Perf:SetMaster(on)
    self.Master = on
    self:Apply()
    self:Save()
end

-- Live character reapply
LP.CharacterAdded:Connect(function(char)
    task.wait(0.6)
    if Perf.Master and Perf.HideSelf then setCharTransp(char, true) end
end)

Perf:Load()
S2.Performance = Perf
print("[ToRung/PERF] ready | master=" .. tostring(Perf.Master))
