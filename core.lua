-- ============================================================
-- Slayers 2 Delta - Core
-- ============================================================

if getgenv().S2 and getgenv().S2.Core and getgenv().S2.Core.Unload then
    pcall(getgenv().S2.Core.Unload)
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not game:IsLoaded() then game.Loaded:Wait() end
if not Players.LocalPlayer then
    local t = tick() + 15
    while not Players.LocalPlayer and tick() < t do task.wait(0.1) end
end
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return warn("[S2/CORE] LocalPlayer missing") end

local Runtime = { Alive = true, Conns = {}, Tasks = {}, Errors = {} }
local function log(...) print("[S2/CORE]", ...) end
local function fail(n, e) Runtime.Errors[n] = tostring(e); warn("[S2/CORE]["..n.."]", e) end
local function connect(s, f) local c = s:Connect(f); Runtime.Conns[#Runtime.Conns+1] = c; return c end
local function spawnJob(n, f)
    local t = { Active = true }
    Runtime.Tasks[n] = t
    task.spawn(function()
        local ok, err = xpcall(function() f(t) end, debug.traceback)
        if not ok then fail(n, err) end
        if Runtime.Tasks[n] == t then Runtime.Tasks[n] = nil end
    end)
    return t
end
local function stopJob(n)
    local t = Runtime.Tasks[n]
    if t then t.Active = false; Runtime.Tasks[n] = nil end
end

local FALLBACK_MOBS = {
    ["*Civilian*"] = { CFrame.new(-687,1260,-1023) },
    Bandit = { CFrame.new(-297,1224,-1023) },
    ["Bear Cub"] = { CFrame.new(540,1121,-1024) },
    ["Beast Born Demon"] = { CFrame.new(170,888,603) },
    ["Blood Hounded Demon"] = { CFrame.new(858.391,823.5,936.479) },
    ["Fire Profound Demon"] = { CFrame.new(-916,1374,-2431) },
    ["Greater Demon"] = { CFrame.new(-499,284,528) },
    ["High Demon"] = { CFrame.new(388,1253,-1928) },
    ["Hand Demon"] = { CFrame.new(-1741,311,881) },
    ["Hoyuzo Subordinate"] = { CFrame.new(533,1001,-1357) },
    ["Ice Profound Demon"] = { CFrame.new(-954.433,1381.989,-2543.049) },
    Kaiden = { CFrame.new(585,1146,-1315) },
    ["Lesser Demon"] = { CFrame.new(-715.64,219.39,456.22) },
    ["Mizunoe Demon Slayer"] = { CFrame.new(-1835,31,487) },
    Mizunoto = { CFrame.new(-887.885,964,-25.963) },
    Hoyuzo = { CFrame.new(746,1001,-1413) },
    ["Mother Bear"] = { CFrame.new(540,1121,-1024) },
    Zuko = { CFrame.new(-282,1227,-1031) },
    Fujiko = { CFrame.new(-1835,31,1119) },
    Akazo = { CFrame.new(-1132,1380,-1746) },
    Datai = { CFrame.new(-165,1043,-1137) },
    Domae = { CFrame.new(-296,1350,-3452) },
    Enru = { CFrame.new(821,800,543) },
    ["Flame Trainee"] = { CFrame.new(-1128,1029,994) },
    Giyen = { CFrame.new(388,1018,-85) },
    Gyorei = { CFrame.new(2574,1089,-742) },
    Gyutai = { CFrame.new(-266,1043,-1139) },
    ["Insect Trainee"] = { CFrame.new(-1395,261,69) },
    Nezura = { CFrame.new(-1459,275,935) },
    Obari = { CFrame.new(770,1121,-1047) },
    ["Reaper Trainee Kuzan"] = { CFrame.new(-1219,1373,-3034) },
    Reaper = { CFrame.new(98,1043,-573) },
    Rengu = { CFrame.new(-712,965,883) },
    Saneri = { CFrame.new(-379,1093,-422) },
    ["Serpent Trainee"] = { CFrame.new(-271,1292,-1535) },
    Shinora = { CFrame.new(-452,964,2) },
    ["Soryu Trainee Goki"] = { CFrame.new(-426,288,543) },
    ["Sound Trainee"] = { CFrame.new(192,1349,-2581) },
    ["Stone Trainee"] = { CFrame.new(2685,1073,-568) },
    Sumari = { CFrame.new(396,1018,-620) },
    ["Tai Chi Trainee Suzume"] = { CFrame.new(2360,601,-642) },
    Tengai = { CFrame.new(-133,1349,-2631) },
    ["Thunder Trainee"] = { CFrame.new(2425,1073,-556) },
    ["Water Trainee Sabito"] = { CFrame.new(815,1018,101) },
    ["Wind Trainee"] = { CFrame.new(-941,1381,-2635) },
    Yahari = { CFrame.new(825,1019,-641) },
    Zentaro = { CFrame.new(1332,821,-1017) },
}

local GameAPI = { Modules = {}, MobSpawns = {}, NPCSpawns = {} }

local function safeRequire(n, i)
    if not i or not i:IsA("ModuleScript") then fail(n, "Module missing"); return nil end
    local ok, r = pcall(require, i)
    if not ok then fail(n, r); return nil end
    GameAPI.Modules[n] = r
    log("module OK:", n)
    return r
end

function GameAPI:ResolveModules()
    local c = RS:FindFirstChild("Communication")
    local s = c and c:FindFirstChild("ServerAndClient")
    local g = s and s:FindFirstChild("Signals")
    self.SignalEvent = safeRequire("SignalEvent", g and g:FindFirstChild("SignalEvent"))
    local cam = RS:FindFirstChild("CAM")
    local gl = cam and cam:FindFirstChild("Global")
    self.Utility = safeRequire("Utility", gl and gl:FindFirstChild("Utility"))
    self.MuzanSettings = safeRequire("MuzanSettings", gl and gl:FindFirstChild("MuzanSettings"))
    self.Series = safeRequire("Series", gl and gl:FindFirstChild("Series"))
    local sub = gl and gl:FindFirstChild("Subsets")
    local gp = sub and sub:FindFirstChild("Gameplay")
    self.Quests = safeRequire("Quests", gp and gp:FindFirstChild("Quests"))
end

local function addSpawn(t, n, v)
    if type(n) ~= "string" or n == "" then return end
    local cf
    if typeof(v) == "CFrame" then cf = v
    elseif typeof(v) == "Vector3" then cf = CFrame.new(v)
    elseif type(v) == "table" then
        local x = v.CFrame or v.cframe or v[1]
        if typeof(x) == "CFrame" then cf = x
        elseif typeof(x) == "Vector3" then cf = CFrame.new(x) end
    end
    if not cf then return end
    t[n] = t[n] or {}
    t[n][#t[n]+1] = cf
end

function GameAPI:DiscoverMobSpawns()
    table.clear(self.MobSpawns)
    local rm = RS:FindFirstChild("Regions")
    if rm and rm:IsA("ModuleScript") then
        local ok, d = pcall(require, rm)
        if ok and type(d) == "table" then
            d = d.Regions or d
            if type(d) == "table" then
                for _, r in pairs(d) do
                    if type(r) == "table" then
                        local ns = r.Npcs or r.npcs
                        if type(ns) == "table" then
                            for k, n in pairs(ns) do
                                if type(n) == "table" then
                                    local o = n
                                    local sd = (n.SendOver or n)
                                    sd = sd and (sd.Spawning or sd.spawning)
                                    if sd then
                                        local name = o.Name or k
                                        addSpawn(self.MobSpawns, name, sd.Center or sd.center)
                                        local ls = sd.Locations or sd.locations
                                        if type(ls) == "table" then
                                            for _, l in ipairs(ls) do addSpawn(self.MobSpawns, name, l) end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    local ouw = RS:FindFirstChild("Ouwland")
    local ct = ouw and ouw:FindFirstChild("Content")
    if ct then
        for _, rf in ipairs(ct:GetChildren()) do
            local ns = rf:FindFirstChild("Npcs")
            if ns then
                for _, ms in ipairs(ns:GetChildren()) do
                    if ms:IsA("ModuleScript") then
                        local ok, r = pcall(require, ms)
                        if ok and type(r) == "table" then
                            local name = r.Name or ms.Name
                            local sp = r.Spawns or r.spawns
                            if type(sp) == "table" then
                                for _, s in ipairs(sp) do addSpawn(self.MobSpawns, name, s) end
                            end
                        end
                    end
                end
            end
        end
    end
    if next(self.MobSpawns) == nil then
        for k, v in pairs(FALLBACK_MOBS) do self.MobSpawns[k] = table.clone(v) end
        log("using fallback mobs")
    else
        log("dynamic mob discovery OK")
    end
end

function GameAPI:DiscoverNPCSpawns()
    table.clear(self.NPCSpawns)
    local ouw = RS:FindFirstChild("Ouwland")
    local ct = ouw and ouw:FindFirstChild("Content")
    if not ct then return end
    for _, rf in ipairs(ct:GetChildren()) do
        local ns = rf:FindFirstChild("Npcs")
        if ns then
            for _, ms in ipairs(ns:GetChildren()) do
                if ms:IsA("ModuleScript") then
                    local ok, r = pcall(require, ms)
                    if ok and type(r) == "table" then
                        local name = r.Name or ms.Name
                        local sp = r.Spawns or r.spawns
                        if type(sp) == "table" and #sp > 0 then
                            local f = sp[1]
                            if type(f) == "table" then f = f.CFrame or f.cframe or f[1] end
                            if typeof(f) == "Vector3" then f = CFrame.new(f) end
                            if typeof(f) == "CFrame" then self.NPCSpawns[name] = f end
                        end
                    end
                end
            end
        end
    end
end

function GameAPI:GetRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function GameAPI:Teleport(cf)
    local r = self:GetRoot()
    if not r then return false, "no HRP" end
    if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
    if typeof(cf) ~= "CFrame" then return false, "invalid" end
    r.CFrame = cf
    r.AssemblyLinearVelocity = Vector3.zero
    r.AssemblyAngularVelocity = Vector3.zero
    return true
end

function GameAPI:ToServer(...)
    local s = self.SignalEvent
    if type(s) ~= "table" or type(s.ToServer) ~= "function" then return false, "no ToServer" end
    local ok, e = pcall(s.ToServer, ...)
    return ok, e
end

function GameAPI:GetMobSpawns(n) return self.MobSpawns[n] end
function GameAPI:GetNPCSpawn(n) return self.NPCSpawns[n] end

local Combat = {
    Combo = 0, Remote = nil,
    Weapons = { "Combat","Regular Katana","Sickles","Obi Manipulation","Insect Katana","Axe and Mace","Sound Katanas","Scythe","Claws","Tai Chi","Bear","Shotgun","Tanto","Bladed Wagasa","Spear","War Fans","Gauntlet","Blood Manipulation" },
}

function Combat:Resolve()
    local c = RS:FindFirstChild("Communication")
    local s = c and c:FindFirstChild("ServerAndClient")
    local g = s and s:FindFirstChild("Signals")
    local se = g and g:FindFirstChild("SignalEvent")
    local r = se and se:FindFirstChild("Event")
    if r and r:IsA("RemoteEvent") then
        self.Remote = r
        log("Combat remote OK")
        return true
    end
    fail("Combat", "SignalEvent.Event missing")
    return false
end

function Combat:Swing(w)
    if not self.Remote and not self:Resolve() then return false end
    self.Combo = (self.Combo % 5) + 1
    local ok, e = pcall(function()
        self.Remote:FireServer("Combat_Service", w or "Combat", self.Combo, true, 0, true, nil)
    end)
    if not ok then fail("Swing", e); return false end
    return true
end

local MobIndex = { ByModel = {}, ByName = {}, Started = false }

function MobIndex:IsAlive(m)
    if not m or not m.Parent or not m:IsA("Model") then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    local r = m:FindFirstChild("HumanoidRootPart")
    return h ~= nil and h.Health > 0 and r ~= nil
end

function MobIndex:Add(m)
    if self.ByModel[m] or not self:IsAlive(m) then return end
    self.ByModel[m] = true
    local names = { m.Name }
    local p = m.Parent
    if p and p:IsA("Folder") then
        local pn = p.Name
        if pn ~= "ActiveNpcs" and pn ~= "StationaryNpcs" and pn ~= "Humanoids" and pn ~= "Regions" then
            names[#names+1] = pn
        end
    end
    for _, n in ipairs(names) do
        self.ByName[n] = self.ByName[n] or {}
        self.ByName[n][m] = true
    end
end

function MobIndex:Remove(m)
    if not self.ByModel[m] then return end
    self.ByModel[m] = nil
    for _, s in pairs(self.ByName) do s[m] = nil end
end

function MobIndex:InitialScan()
    table.clear(self.ByModel)
    table.clear(self.ByName)
    local h = workspace:FindFirstChild("Humanoids")
    if not h then return end
    for _, o in ipairs(h:GetDescendants()) do
        if o:IsA("Model") then self:Add(o) end
    end
end

function MobIndex:Start()
    if self.Started then return end
    self.Started = true
    self:InitialScan()
    connect(workspace.DescendantAdded, function(o)
        if o:IsA("Model") then
            task.defer(function() if Runtime.Alive then MobIndex:Add(o) end end)
        end
    end)
    connect(workspace.DescendantRemoving, function(o)
        if o:IsA("Model") then MobIndex:Remove(o) end
    end)
    log("MobIndex started")
end

function MobIndex:Nearest(name, origin, maxD)
    maxD = maxD or math.huge
    local best, bd = nil, maxD
    local function cons(m)
        if not self:IsAlive(m) then self:Remove(m); return end
        local r = m:FindFirstChild("HumanoidRootPart")
        if not r then return end
        local d = (r.Position - origin).Magnitude
        if d < bd then bd = d; best = m end
    end
    if name and name ~= "" and name ~= "Nearest Mob" and name ~= "All Bosses" then
        local s = self.ByName[name]
        if s then for m in pairs(s) do cons(m) end end
    else
        for m in pairs(self.ByModel) do cons(m) end
    end
    return best, bd
end

local Movement = { Owner = nil, Intent = nil, Conn = nil }

function Movement:Acquire(o)
    if self.Owner == nil or self.Owner == o then self.Owner = o; return true end
    return false
end

function Movement:Release(o)
    if self.Owner ~= o then return end
    self.Owner = nil; self.Intent = nil
end

function Movement:SetIntent(o, i)
    if self.Owner ~= o then return false end
    self.Intent = i; return true
end

-- ✅ FIXED: FarmPosition with "Far" mode
function Movement:FarmPosition(tr, cfg)
    local p = tr.Position
    local c = tr.CFrame
    local d = tonumber(cfg.Distance) or 6.5
    local b
    if cfg.Mode == "Above" then
        b = p + Vector3.new(0, d, 0)
    elseif cfg.Mode == "In Front" then
        b = p + c.LookVector * d
    elseif cfg.Mode == "Behind" then
        b = p - c.LookVector * d
    elseif cfg.Mode == "Far" then
        local lookXZ = Vector3.new(c.LookVector.X, 0, c.LookVector.Z)
        if lookXZ.Magnitude < 0.01 then lookXZ = Vector3.new(0, 0, -1) end
        lookXZ = lookXZ.Unit
        b = p - lookXZ * d + Vector3.new(0, 3, 0)
    else
        b = p - Vector3.new(0, d, 0)
    end
    return b
        + c.RightVector * (tonumber(cfg.OffsetX) or 0)
        + Vector3.new(0, tonumber(cfg.OffsetY) or 2, 0)
        + c.LookVector * (tonumber(cfg.OffsetZ) or 0)
end

function Movement:Step()
    local i = self.Intent
    if not i then return end
    local r = GameAPI:GetRoot()
    if not r then return end
    local t = i.Target
    if t and MobIndex:IsAlive(t) then
        local tr = t:FindFirstChild("HumanoidRootPart")
        if tr then
            r.Anchored = false
            r.CFrame = CFrame.lookAt(self:FarmPosition(tr, i.Config), tr.Position)
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            if i.Attack and i.Config and i.Config.Weapon then
                Combat:Swing(i.Config.Weapon)
            end
            return
        end
    end
    if i.Fallback and typeof(i.Fallback) == "CFrame" then
        r.Anchored = false
        r.CFrame = i.Fallback
        r.AssemblyLinearVelocity = Vector3.zero
    end
end

function Movement:Start()
    if self.Conn then return end
    self.Conn = connect(RunService.Heartbeat, function()
        if Runtime.Alive then Movement:Step() end
    end)
end

local ok, err = xpcall(function()
    log("resolving modules...")
    GameAPI:ResolveModules()
    log("discovering spawns...")
    GameAPI:DiscoverMobSpawns()
    GameAPI:DiscoverNPCSpawns()
    Combat:Resolve()
    MobIndex:Start()
    Movement:Start()
end, debug.traceback)

if not ok then
    warn("[S2/CORE] STARTUP FAILED:", err)
else
    getgenv().S2 = getgenv().S2 or {}
    getgenv().S2.Core = {
        Runtime = Runtime, GameAPI = GameAPI,
        Combat = Combat, MobIndex = MobIndex, Movement = Movement,
        FALLBACK_MOBS = FALLBACK_MOBS,
        log = log, fail = fail, connect = connect,
        spawnJob = spawnJob, stopJob = stopJob,
        Unload = function()
            Runtime.Alive = false
            for _, c in ipairs(Runtime.Conns) do pcall(function() c:Disconnect() end) end
            for n in pairs(Runtime.Tasks) do stopJob(n) end
        end,
    }
    print("======================================================")
    print("[S2/CORE] READY - Execute features.lua next")
    print("======================================================")
end
