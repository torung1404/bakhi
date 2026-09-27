-- ============================================================
-- Slayers 2 Delta - Core (File 1/3)
-- Modules + Spawns + Combat + MobIndex + Movement
-- ============================================================

if getgenv().S2 and getgenv().S2.Core and getgenv().S2.Core.Unload then
    pcall(getgenv().S2.Core.Unload)
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

if not game:IsLoaded() then game.Loaded:Wait() end

-- ==================== Runtime ====================
local Runtime = { Alive = true, Conns = {}, Tasks = {}, Errors = {} }

local function log(...) print("[S2/CORE]", ...) end
local function fail(name, err) Runtime.Errors[name] = tostring(err); warn("[S2/CORE]["..name.."]", err) end
local function connect(sig, fn)
    local c = sig:Connect(fn)
    Runtime.Conns[#Runtime.Conns+1] = c
    return c
end
local function spawnJob(name, fn)
    local tok = { Active = true }
    Runtime.Tasks[name] = tok
    task.spawn(function()
        local ok, err = xpcall(function() fn(tok) end, debug.traceback)
        if not ok then fail(name, err) end
        if Runtime.Tasks[name] == tok then Runtime.Tasks[name] = nil end
    end)
    return tok
end
local function stopJob(name)
    local tok = Runtime.Tasks[name]
    if tok then tok.Active = false; Runtime.Tasks[name] = nil end
end

-- ==================== Constants ====================
local V84 = {
    [8]="RunService",[33]="Humanoid",[34]="Frame",[47]="Name",
    [49]="Utility",[52]="RootPart",[54]="ScreenGui",[64]="TextLabel",
    [101]="Debree",[127]="Players",[135]="Workspace",[137]="HttpService",
    [139]="UIListLayout",[161]="UIGradient",[165]="Highlight",[167]="HumanoidRootPart",
    [183]="ReplicatedStorage",[197]="Health",
}

local FALLBACK_MOBS = {
    ["*Civilian*"] = { CFrame.new(-687, 1260, -1023) },
    Bandit = { CFrame.new(-297, 1224, -1023) },
    ["Bear Cub"] = { CFrame.new(540, 1121, -1024) },
    ["Beast Born Demon"] = { CFrame.new(170, 888, 603) },
    ["Blood Hounded Demon"] = { CFrame.new(858.391, 823.5, 936.479) },
    ["Fire Profound Demon"] = { CFrame.new(-916, 1374, -2431) },
    ["Greater Demon"] = { CFrame.new(-499, 284, 528) },
    ["High Demon"] = { CFrame.new(388, 1253, -1928) },
    ["Hand Demon"] = { CFrame.new(-1741, 311, 881) },
    ["Hoyuzo Subordinate"] = { CFrame.new(533, 1001, -1357) },
    ["Ice Profound Demon"] = { CFrame.new(-954.433, 1381.989, -2543.049) },
    Kaiden = { CFrame.new(585, 1146, -1315) },
    ["Lesser Demon"] = { CFrame.new(-715.64, 219.39, 456.22) },
    ["Mizunoe Demon Slayer"] = { CFrame.new(-1835, 31, 487) },
    Mizunoto = { CFrame.new(-887.885, 964, -25.963) },
    Hoyuzo = { CFrame.new(746, 1001, -1413) },
    ["Mother Bear"] = { CFrame.new(540, 1121, -1024) },
    Zuko = { CFrame.new(-282, 1227, -1031) },
    Fujiko = { CFrame.new(-1835, 31, 1119) },
    Akazo = { CFrame.new(-1132, 1380, -1746) },
    Datai = { CFrame.new(-165, 1043, -1137) },
    Domae = { CFrame.new(-296, 1350, -3452) },
    Enru = { CFrame.new(821, 800, 543) },
    ["Flame Trainee"] = { CFrame.new(-1128, 1029, 994) },
    Giyen = { CFrame.new(388, 1018, -85) },
    Gyorei = { CFrame.new(2574, 1089, -742) },
    Gyutai = { CFrame.new(-266, 1043, -1139) },
    ["Insect Trainee"] = { CFrame.new(-1395, 261, 69) },
    Nezura = { CFrame.new(-1459, 275, 935) },
    Obari = { CFrame.new(770, 1121, -1047) },
    ["Reaper Trainee Kuzan"] = { CFrame.new(-1219, 1373, -3034) },
    Reaper = { CFrame.new(98, 1043, -573) },
    Rengu = { CFrame.new(-712, 965, 883) },
    Saneri = { CFrame.new(-379, 1093, -422) },
    ["Serpent Trainee"] = { CFrame.new(-271, 1292, -1535) },
    Shinora = { CFrame.new(-452, 964, 2) },
    ["Soryu Trainee Goki"] = { CFrame.new(-426, 288, 543) },
    ["Sound Trainee"] = { CFrame.new(192, 1349, -2581) },
    ["Stone Trainee"] = { CFrame.new(2685, 1073, -568) },
    Sumari = { CFrame.new(396, 1018, -620) },
    ["Tai Chi Trainee Suzume"] = { CFrame.new(2360, 601, -642) },
    Tengai = { CFrame.new(-133, 1349, -2631) },
    ["Thunder Trainee"] = { CFrame.new(2425, 1073, -556) },
    ["Water Trainee Sabito"] = { CFrame.new(815, 1018, 101) },
    ["Wind Trainee"] = { CFrame.new(-941, 1381, -2635) },
    Yahari = { CFrame.new(825, 1019, -641) },
    Zentaro = { CFrame.new(1332, 821, -1017) },
}

-- ==================== GameAPI ====================
local GameAPI = { Modules = {}, MobSpawns = {}, NPCSpawns = {} }

local function safeRequire(name, inst)
    if not inst or not inst:IsA("ModuleScript") then
        fail(name, "ModuleScript missing")
        return nil
    end
    local ok, res = pcall(require, inst)
    if not ok then fail(name, res); return nil end
    GameAPI.Modules[name] = res
    log("module OK:", name)
    return res
end

function GameAPI:ResolveModules()
    local comm = RS:FindFirstChild("Communication")
    local sac = comm and comm:FindFirstChild("ServerAndClient")
    local sig = sac and sac:FindFirstChild("Signals")
    self.SignalEvent = safeRequire("SignalEvent", sig and sig:FindFirstChild("SignalEvent"))

    local cam = RS:FindFirstChild("CAM")
    local glob = cam and cam:FindFirstChild("Global")
    self.Utility = safeRequire("Utility", glob and glob:FindFirstChild("Utility"))
    self.MuzanSettings = safeRequire("MuzanSettings", glob and glob:FindFirstChild("MuzanSettings"))
    self.Series = safeRequire("Series", glob and glob:FindFirstChild("Series"))

    local subs = glob and glob:FindFirstChild("Subsets")
    local gp = subs and subs:FindFirstChild("Gameplay")
    self.Quests = safeRequire("Quests", gp and gp:FindFirstChild("Quests"))

    local cli = cam and cam:FindFirstChild("Client")
    local ctrl = cli and cli:FindFirstChild("Controllers")
    self.SimonSaysController = safeRequire("SimonSaysController", ctrl and ctrl:FindFirstChild("SimonSaysController"))
end

local function addSpawn(target, name, val)
    if type(name) ~= "string" or name == "" then return end
    local cf
    if typeof(val) == "CFrame" then cf = val
    elseif typeof(val) == "Vector3" then cf = CFrame.new(val)
    elseif type(val) == "table" then
        local n = val.CFrame or val.cframe or val[1]
        if typeof(n) == "CFrame" then cf = n
        elseif typeof(n) == "Vector3" then cf = CFrame.new(n) end
    end
    if not cf then return end
    target[name] = target[name] or {}
    target[name][#target[name]+1] = cf
end

function GameAPI:DiscoverMobSpawns()
    table.clear(self.MobSpawns)
    local regionsMod = RS:FindFirstChild("Regions")
    if regionsMod and regionsMod:IsA("ModuleScript") then
        local ok, data = pcall(require, regionsMod)
        if ok and type(data) == "table" then
            data = data.Regions or data
            if type(data) == "table" then
                for _, region in pairs(data) do
                    if type(region) == "table" then
                        local npcs = region.Npcs or region.npcs
                        if type(npcs) == "table" then
                            for key, npc in pairs(npcs) do
                                if type(npc) == "table" then
                                    local orig = npc
                                    local sd = (npc.SendOver or npc)
                                    sd = sd and (sd.Spawning or sd.spawning)
                                    if sd then
                                        local name = orig.Name or key
                                        addSpawn(self.MobSpawns, name, sd.Center or sd.center)
                                        local locs = sd.Locations or sd.locations
                                        if type(locs) == "table" then
                                            for _, loc in ipairs(locs) do
                                                addSpawn(self.MobSpawns, name, loc)
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
    end

    local ouw = RS:FindFirstChild("Ouwland")
    local content = ouw and ouw:FindFirstChild("Content")
    if content then
        for _, regionFolder in ipairs(content:GetChildren()) do
            local npcs = regionFolder:FindFirstChild("Npcs")
            if npcs then
                for _, ms in ipairs(npcs:GetChildren()) do
                    if ms:IsA("ModuleScript") then
                        local ok, res = pcall(require, ms)
                        if ok and type(res) == "table" then
                            local name = res.Name or ms.Name
                            local spawns = res.Spawns or res.spawns
                            if type(spawns) == "table" then
                                for _, s in ipairs(spawns) do addSpawn(self.MobSpawns, name, s) end
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
    local content = ouw and ouw:FindFirstChild("Content")
    if not content then return end
    for _, regionFolder in ipairs(content:GetChildren()) do
        local npcs = regionFolder:FindFirstChild("Npcs")
        if npcs then
            for _, ms in ipairs(npcs:GetChildren()) do
                if ms:IsA("ModuleScript") then
                    local ok, res = pcall(require, ms)
                    if ok and type(res) == "table" then
                        local name = res.Name or ms.Name
                        local spawns = res.Spawns or res.spawns
                        if type(spawns) == "table" and #spawns > 0 then
                            local f = spawns[1]
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
    if type(s) ~= "table" or type(s.ToServer) ~= "function" then
        return false, "no ToServer"
    end
    local ok, err = pcall(s.ToServer, ...)
    return ok, err
end

function GameAPI:GetMobSpawns(name) return self.MobSpawns[name] end
function GameAPI:GetNPCSpawn(name) return self.NPCSpawns[name] end

-- ==================== Combat ====================
local Combat = {
    Combo = 0,
    Remote = nil,
    Weapons = {
        "Combat","Regular Katana","Sickles","Obi Manipulation","Insect Katana",
        "Axe and Mace","Sound Katanas","Scythe","Claws","Tai Chi","Bear",
        "Shotgun","Tanto","Bladed Wagasa","Spear","War Fans","Gauntlet","Blood Manipulation",
    },
}

function Combat:Resolve()
    local comm = RS:FindFirstChild("Communication")
    local sac = comm and comm:FindFirstChild("ServerAndClient")
    local sig = sac and sac:FindFirstChild("Signals")
    local se = sig and sig:FindFirstChild("SignalEvent")
    local rem = se and se:FindFirstChild("Event")
    if rem and rem:IsA("RemoteEvent") then
        self.Remote = rem
        log("Combat remote OK")
        return true
    end
    fail("Combat", "SignalEvent.Event missing")
    return false
end

function Combat:Swing(weapon)
    if not self.Remote and not self:Resolve() then return false end
    self.Combo = (self.Combo % 5) + 1
    local ok, err = pcall(function()
        self.Remote:FireServer("Combat_Service", weapon or "Combat", self.Combo, true, 0, true, nil)
    end)
    if not ok then fail("Swing", err); return false end
    return true
end

-- ==================== MobIndex ====================
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
    for _, set in pairs(self.ByName) do set[m] = nil end
end

function MobIndex:InitialScan()
    table.clear(self.ByModel)
    table.clear(self.ByName)
    local h = workspace:FindFirstChild("Humanoids") or workspace
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
    local best, bestD = nil, maxD
    local function consider(m)
        if not self:IsAlive(m) then self:Remove(m); return end
        local r = m:FindFirstChild("HumanoidRootPart")
        if not r then return end
        local d = (r.Position - origin).Magnitude
        if d < bestD then bestD = d; best = m end
    end
    if name and name ~= "" and name ~= "Nearest Mob" and name ~= "All Bosses" then
        local set = self.ByName[name]
        if set then for m in pairs(set) do consider(m) end end
    else
        for m in pairs(self.ByModel) do consider(m) end
    end
    return best, bestD
end

-- ==================== Movement ====================
local Movement = { Owner = nil, Intent = nil, Conn = nil }

function Movement:Acquire(owner)
    if self.Owner == nil or self.Owner == owner then
        self.Owner = owner; return true
    end
    return false
end

function Movement:Release(owner)
    if self.Owner ~= owner then return end
    self.Owner = nil; self.Intent = nil
end

function Movement:SetIntent(owner, intent)
    if self.Owner ~= owner then return false end
    self.Intent = intent; return true
end

function Movement:FarmPosition(targetRoot, cfg)
    local pos = targetRoot.Position
    local cf = targetRoot.CFrame
    local d = tonumber(cfg.Distance) or 6.5
    local base
    if cfg.Mode == "Above" then base = pos + Vector3.new(0, d, 0)
    elseif cfg.Mode == "In Front" then base = pos + cf.LookVector * d
    elseif cfg.Mode == "Behind" then base = pos - cf.LookVector * d
    else base = pos - Vector3.new(0, d, 0) end
    return base + cf.RightVector * (tonumber(cfg.OffsetX) or 0)
        + Vector3.new(0, tonumber(cfg.OffsetY) or 2, 0)
        + cf.LookVector * (tonumber(cfg.OffsetZ) or 0)
end

function Movement:Step()
    local intent = self.Intent
    if not intent then return end
    local root = GameAPI:GetRoot()
    if not root then return end
    local target = intent.Target
    if target and MobIndex:IsAlive(target) then
        local tr = target:FindFirstChild("HumanoidRootPart")
        if tr then
            root.Anchored = false
            root.CFrame = CFrame.lookAt(self:FarmPosition(tr, intent.Config), tr.Position)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            if intent.Attack and intent.Config and intent.Config.Weapon then
                Combat:Swing(intent.Config.Weapon)
            end
            return
        end
    end
    if intent.Fallback and typeof(intent.Fallback) == "CFrame" then
        root.Anchored = false
        root.CFrame = intent.Fallback
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

function Movement:Start()
    if self.Conn then return end
    self.Conn = connect(RunService.Heartbeat, function()
        if Runtime.Alive then Movement:Step() end
    end)
end

-- ==================== Startup ====================
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
    -- Export
    getgenv().S2 = getgenv().S2 or {}
    getgenv().S2.Core = {
        Runtime = Runtime, V84 = V84, GameAPI = GameAPI,
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