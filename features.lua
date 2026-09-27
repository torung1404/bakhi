-- ============================================================
-- Slayers 2 Delta - Features (Fixed v2)
-- ============================================================

local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[S2/FEAT] Core chưa chạy") end

local Runtime = S2.Core.Runtime
local GameAPI = S2.Core.GameAPI
local Combat = S2.Core.Combat
local MobIndex = S2.Core.MobIndex
local Movement = S2.Core.Movement
local log = S2.Core.log
local fail = S2.Core.fail
local spawnJob = S2.Core.spawnJob
local stopJob = S2.Core.stopJob

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local VirtualInputManager
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local function pressKey(k)
    if not VirtualInputManager or not Enum.KeyCode[k] then return false end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[k], false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[k], false, game)
    end)
    return true
end
local function holdStart(k)
    if not VirtualInputManager or not Enum.KeyCode[k] then return end
    pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[k], false, game) end)
end
local function holdStop(k)
    if not VirtualInputManager or not Enum.KeyCode[k] then return end
    pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[k], false, game) end)
end

local Features = {}
Features.Config = {
    MobFarm = { Target = "Nearest Mob", Mode = "Below", Distance = 6.5, OffsetX = 0, OffsetY = 2, OffsetZ = 0, Weapon = "Combat", EquipSlot = 0, SearchRange = 5000 },
    BossFarm = { Target = "All Bosses", Mode = "Below", Distance = 6.5, OffsetX = 0, OffsetY = 2, OffsetZ = 0, Weapon = "Combat", EquipSlot = 0, SearchRange = 10000 },
}

-- ========== QuestEngine ==========
local QuestEngine = {}

function QuestEngine:GetData()
    local u = GameAPI.Utility
    if type(u) ~= "table" or type(u.GetData) ~= "function" then return nil end
    local ok, d = pcall(u.GetData, LocalPlayer)
    return ok and d or nil
end

function QuestEngine:GetQuestRuntime(name)
    local q = GameAPI.Quests
    local d = self:GetData()
    if type(q) ~= "table" or type(q.Holder) ~= "table" then return nil end
    if type(d) ~= "table" or not d.Quests or not d.Quests:FindFirstChild("Holder") then return nil end
    local def = q.Holder[name]
    if type(def) ~= "table" or not def.QuestInstance then return nil end
    return d.Quests.Holder:FindFirstChild(def.QuestInstance.Name)
end

function QuestEngine:GetTaskValue(t)
    if not t then return 0, 1 end
    local v = t:FindFirstChild("Value")
    local m = t:FindFirstChild("Max")
    return (v and v.Value or 0), (m and m.Value or 1)
end

function QuestEngine:IsTaskComplete(qn, tn)
    local rq = self:GetQuestRuntime(qn)
    local ts = rq and rq:FindFirstChild("Tasks") and rq.Tasks:FindFirstChild(tn)
    if not ts then return true end
    local v, m = self:GetTaskValue(ts)
    return v >= m
end

function QuestEngine:GetNextIncomplete(qn, rq)
    local q = GameAPI.Quests
    if not q or not q.Holder then return nil end
    local ts = rq and rq:FindFirstChild("Tasks")
    if not ts then return nil end
    local def = q.Holder[qn]
    if type(def) ~= "table" or not def.QuestInstance then return nil end
    local td = def.QuestInstance:FindFirstChild("Tasks")
    if not td then return nil end
    for _, c in ipairs(ts:GetChildren()) do
        if not self:IsTaskComplete(qn, c.Name) then
            local need = td:FindFirstChild(c.Name)
            need = need and need:FindFirstChild("Need")
            if not need or self:IsTaskComplete(qn, need.Value) then return c end
        end
    end
    return nil
end

-- ========== FinalSelection ==========
local FinalSelection = {
    Active = false, CurrentTarget = nil,
    QuestOrder = { "Locate Rem","Help Rem","Find Vael","Defeat Demons for Vael","Find Klien","Speak with Klien","Find Rika","Treat Klien","Find Mizuto","Defeat Lost","The Dungeon","Find Lavato","Mountain Survival","Rescue and Hold the Zone","Find Steve","Defeat the Hand Demon" },
    TaskMobCodes = { LesserDemon = "Lesser Demon", Lost = "Lost", HandDemon = "Hand Demon" },
    MountainFallbacks = { Vector3.new(-6617,39,2518), Vector3.new(-5500,39,1607), Vector3.new(-3821,39,1628), Vector3.new(-5191,39,1011) },
    ParkourArrival = Vector3.new(-68,890,4076),
    ParkourFinal = Vector3.new(124.2,1042.3,2990.3),
    CombatConfig = { Mode = "Below", Distance = 6.5, OffsetX = 0, OffsetY = 2, OffsetZ = 0, Weapon = "Combat" },
}

function FinalSelection:IsInside()
    local p = RS:FindFirstChild("Minigames Place")
    local c = p and p:FindFirstChild("Content")
    return c ~= nil and c:FindFirstChild("Final Selection") ~= nil
end

function FinalSelection:GetNpcModules()
    local p = RS:FindFirstChild("Minigames Place")
    local c = p and p:FindFirstChild("Content")
    local s = c and c:FindFirstChild("Final Selection")
    return s and s:FindFirstChild("Npcs")
end

function FinalSelection:GetInventoryCount(item)
    local d = QuestEngine:GetData()
    local inv = d and d.Inventory and d.Inventory:FindFirstChild("Inventory")
    local it = inv and inv:FindFirstChild(item)
    if not it then return 0 end
    local a = it:FindFirstChild("Amount")
    return a and a.Value or 1
end

function FinalSelection:WaitUntil(tok, pred, timeout)
    local rem = tonumber(timeout) or 8
    while tok.Active and Runtime.Alive and rem > 0 do
        local ok, r = pcall(pred)
        if ok and r then return true end
        task.wait(0.25); rem -= 0.25
    end
    local ok, r = pcall(pred)
    return ok and r == true
end

function FinalSelection:SetDirect(pos, lookAt)
    if typeof(pos) ~= "Vector3" then return false end
    local cf = (typeof(lookAt) == "Vector3") and CFrame.new(pos, lookAt) or CFrame.new(pos)
    return Movement:SetIntent("FinalSelection", { Target = nil, Fallback = cf, Config = self.CombatConfig, Attack = false })
end

function FinalSelection:MoveFor(tok, pos, lookAt, secs)
    self:SetDirect(pos, lookAt)
    local t = os.clock() + (tonumber(secs) or 1.5)
    while tok.Active and Runtime.Alive and os.clock() < t do task.wait(0.05) end
end

function FinalSelection:FirePrompt(p)
    if not p or not p:IsA("ProximityPrompt") then return false end
    local ok = pcall(function()
        if type(firesignal) == "function" and p.HoldDuration > 0 then
            firesignal(p.PromptButtonHoldBegan, LocalPlayer)
            task.wait(p.HoldDuration + 0.3)
            fireproximityprompt(p)
            task.wait(0.2)
            firesignal(p.PromptButtonHoldEnded, LocalPlayer)
        else
            fireproximityprompt(p)
        end
    end)
    return ok
end

function FinalSelection:GetRuntimeQuest()
    for _, qn in ipairs(self.QuestOrder) do
        local rq = QuestEngine:GetQuestRuntime(qn)
        if rq then return qn, rq end
    end
    return nil
end

function FinalSelection:RequireNpcModule(name)
    local n = self:GetNpcModules()
    local m = n and n:FindFirstChild(name)
    if not m or not m:IsA("ModuleScript") then return nil end
    local ok, r = pcall(require, m)
    return ok and type(r) == "table" and r or nil
end

function FinalSelection:GetNpcSpawn(name)
    local d = self:RequireNpcModule(name)
    local s = d and d.Spawns and d.Spawns[1]
    if typeof(s) == "CFrame" then return s.Position end
    if typeof(s) == "Vector3" then return s end
end

function FinalSelection:FindStationaryRoot(name)
    local db = workspace:FindFirstChild("Debree")
    local reg = db and db:FindFirstChild("Regions")
    if not reg then return nil end
    for _, r in ipairs(reg:GetChildren()) do
        local s = r:FindFirstChild("StationaryNpcs")
        s = s and s:FindFirstChild(name)
        local root = s and s:FindFirstChild("HumanoidRootPart")
        if root then return root end
    end
    return nil
end

function FinalSelection:TalkToNpc(tok, name)
    local sp = self:GetNpcSpawn(name)
    if not sp then return false end
    self:MoveFor(tok, sp + Vector3.new(4, 5, 0), nil, 2.5)
    local root
    self:WaitUntil(tok, function() root = self:FindStationaryRoot(name); return root ~= nil end, 8)
    if not root then return false end
    self:MoveFor(tok, root.Position + root.CFrame.LookVector * 4, root.Position, 1)
    for _, c in ipairs(root:GetChildren()) do
        if c:IsA("ProximityPrompt") and c.ActionText == "Chat" then self:FirePrompt(c) end
    end
    task.wait(2.5)
    return true
end

function FinalSelection:IsAlive(m)
    if not m or not m.Parent or not m:IsA("Model") then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    local r = m:FindFirstChild("HumanoidRootPart")
    return h ~= nil and h.Health > 0 and r ~= nil
end

function FinalSelection:FindMob(name, origin, radius)
    local h = workspace:FindFirstChild("Humanoids")
    if not h then return nil end
    local best, bd = nil, radius or math.huge
    for _, d in ipairs(h:GetDescendants()) do
        if d:IsA("Model") and d.Name == name and self:IsAlive(d) then
            local r = d.HumanoidRootPart
            local dist = (r.Position - origin).Magnitude
            if dist < bd then bd = dist; best = d end
        end
    end
    return best
end

function FinalSelection:RunKillTask(tok, mobName, marker, donePred)
    if typeof(marker) == "Vector3" then self:MoveFor(tok, marker, nil, 2) end
    local miss = 0
    while tok.Active and Runtime.Alive and not donePred() do
        local r = GameAPI:GetRoot()
        if r then
            local rogue = self:FindMob("Rogue Demon", r.Position, 150)
            if not self:IsAlive(self.CurrentTarget) or (rogue and self.CurrentTarget.Name ~= "Rogue Demon") then
                self.CurrentTarget = rogue or self:FindMob(mobName, r.Position, 400)
            end
        end
        if self.CurrentTarget then
            miss = 0
            Movement:SetIntent("FinalSelection", { Target = self.CurrentTarget, Fallback = nil, Config = self.CombatConfig, Attack = true })
        else
            miss += 0.25
            if miss >= 8 and typeof(marker) == "Vector3" then
                self:MoveFor(tok, marker, nil, 2); miss = 0
            end
        end
        task.wait(0.25)
    end
    self.CurrentTarget = nil
    Movement:SetIntent("FinalSelection", { Target = nil, Fallback = nil, Config = self.CombatConfig, Attack = false })
end

function FinalSelection:HandleDeliver(tok, qn, task, spec)
    if spec.RequiredItem and self:GetInventoryCount(spec.RequiredItem) < 1 then
        local mods = self:GetNpcModules()
        if mods then
            for _, c in ipairs(mods:GetChildren()) do
                if c:IsA("ModuleScript") then
                    local d = self:RequireNpcModule(c.Name)
                    if type(d) == "table" and type(d.Shop) == "table" and d.Shop[spec.RequiredItem] and self:TalkToNpc(tok, c.Name) then
                        GameAPI:ToServer("PurchaseFromShop", spec.RequiredItem, 1)
                        self:WaitUntil(tok, function() return self:GetInventoryCount(spec.RequiredItem) > 0 end, 5)
                        break
                    end
                end
            end
        end
    end
    for _ = 1, 3 do
        if spec.TargetNpc and self:TalkToNpc(tok, spec.TargetNpc) then
            GameAPI:ToServer("QuestProgress", qn, task.Name)
        end
        if self:WaitUntil(tok, function() return QuestEngine:IsTaskComplete(qn, task.Name) end, 5) then return end
    end
end

function FinalSelection:HandlePickup(tok, qn, task, spec)
    local pos = type(spec.Positions) == "table" and spec.Positions or {}
    for i, p in ipairs(pos) do
        if not tok.Active or QuestEngine:IsTaskComplete(qn, task.Name) then return end
        if typeof(p) == "Vector3" then
            self:MoveFor(tok, p + Vector3.new(2, 3, 0), p, 1.5)
            local old = QuestEngine:GetTaskValue(task)
            GameAPI:ToServer("QuestProgress", qn, task.Name, i)
            self:WaitUntil(tok, function()
                if not task.Parent then return true end
                return QuestEngine:GetTaskValue(task) > old
            end, 3)
        end
    end
end

function FinalSelection:HandleRescue(tok, qn)
    local zonePos
    self:WaitUntil(tok, function()
        zonePos = LocalPlayer:GetAttribute("RescueZonePos")
        return typeof(zonePos) == "Vector3"
    end, 10)
    if typeof(zonePos) ~= "Vector3" then return end

    if not QuestEngine:IsTaskComplete(qn, "Capture the Zone") then
        Movement:SetIntent("FinalSelection", {
            Target = nil,
            Fallback = CFrame.new(zonePos + Vector3.new(0, 45, 0)),
            Config = self.CombatConfig, Attack = false,
        })
        self:WaitUntil(tok, function()
            return QuestEngine:IsTaskComplete(qn, "Capture the Zone")
        end, 90)
    end

    if not QuestEngine:IsTaskComplete(qn, "Rescue the Civilian") then
        local civ
        self:WaitUntil(tok, function()
            local db = workspace:FindFirstChild("Debree")
            civ = db and db:FindFirstChild("RescueCivilian")
            return civ ~= nil
        end, 8)
        if civ then
            local pos = civ:GetPivot().Position
            self:MoveFor(tok, pos + Vector3.new(3, 1, 0), pos, 1.2)
            local p = civ:FindFirstChildWhichIsA("ProximityPrompt", true)
            if p then self:FirePrompt(p) end
            self:WaitUntil(tok, function()
                return QuestEngine:IsTaskComplete(qn, "Rescue the Civilian")
            end, 5)
        end
    end

    if QuestEngine:IsTaskComplete(qn, "Rescue the Civilian") then
        local levi = self:GetNpcSpawn("Levi")
        if levi then
            self:MoveFor(tok, levi + Vector3.new(4, 3, 0), levi, 1)
            self:WaitUntil(tok, function()
                return QuestEngine:GetQuestRuntime(qn) == nil
            end, 10)
        end
    end
end

function FinalSelection:HandleTask(tok, qn, task)
    local q = GameAPI.Quests
    if not q or not q.Holder then return end
    local def = q.Holder[qn]
    if type(def) ~= "table" then return end
    local spec = type(def.TaskSpecs) == "table" and def.TaskSpecs[task.Name] or nil
    local mark = type(def.Markers) == "table" and def.Markers[task.Name] or nil
    local marker = type(mark) == "table" and typeof(mark.Position) == "Vector3" and mark.Position or nil
    local co = task:FindFirstChild("Code")
    local code = co and co.Value or nil
    log("FS:", qn, "->", task.Name)

    if qn == "Rescue and Hold the Zone" then
        return self:HandleRescue(tok, qn)
    end
    if task.Name == "Checkpoints" then
        if not LocalPlayer:GetAttribute("MountainTrialEndsAt") then
            GameAPI:ToServer("StartMountainTrial")
            self:WaitUntil(tok, function() return LocalPlayer:GetAttribute("MountainTrialEndsAt") ~= nil end, 5)
        end
        for i = 1, 4 do
            if not tok.Active or not task.Parent then return end
            local old = QuestEngine:GetTaskValue(task)
            if old < i then
                local p = self.MountainFallbacks[i]
                self:MoveFor(tok, p + Vector3.new(0, 3, 0), nil, 1.2)
                GameAPI:ToServer("MountainCheckpoint", i)
                self:WaitUntil(tok, function()
                    if not task.Parent then return true end
                    return QuestEngine:GetTaskValue(task) > old
                end, 3)
            end
        end
        return
    end
    if spec and spec.Type == "Dungeon" then return end
    if spec and spec.Type == "Deliver" then return self:HandleDeliver(tok, qn, task, spec) end
    if spec and spec.Type == "Pickup" then return self:HandlePickup(tok, qn, task, spec) end
    local mn = self.TaskMobCodes[code]
    if mn then
        self:RunKillTask(tok, mn, marker, function()
            return QuestEngine:IsTaskComplete(qn, task.Name)
        end)
    end
end

function FinalSelection:Run(tok)
    if not self:IsInside() then return false, "not inside FS" end
    if not Movement:Acquire("FinalSelection") then return false, "movement busy" end
    self.Active = true
    if not self:GetRuntimeQuest() then
        GameAPI:ToServer("AddQuest", "Locate Rem")
        self:WaitUntil(tok, function() return self:GetRuntimeQuest() ~= nil end, 3)
    end
    local stuck = 0
    while tok.Active and Runtime.Alive do
        local qn, rq = self:GetRuntimeQuest()
        if not qn then
            self.Active = false; Movement:Release("FinalSelection"); return true
        end
        local task = QuestEngine:GetNextIncomplete(qn, rq)
        if not task then
            local old = qn
            self:WaitUntil(tok, function() return self:GetRuntimeQuest() ~= old end, 10)
        else
            self:HandleTask(tok, qn, task)
            if QuestEngine:IsTaskComplete(qn, task.Name) or select(1, self:GetRuntimeQuest()) ~= qn then
                stuck = 0
            else
                stuck += 1
                if stuck >= 5 then
                    self.Active = false; Movement:Release("FinalSelection")
                    return false, "stuck on "..task.Name
                end
            end
        end
        task.wait(0.5)
    end
    self.Active = false; Movement:Release("FinalSelection")
    return false, "stopped"
end

-- ========== Crow Quest ==========
local CrowQuest = {
    Active = false,
    BossData = {
        { name = "Mother Bear", cf = CFrame.new(540,1121,-1024) },
        { name = "Hoyuzo", cf = CFrame.new(746,1001,-1413) },
        { name = "Soryu Trainee Goki", cf = CFrame.new(-427,288,543) },
        { name = "Reaper Trainee Kuzan", cf = CFrame.new(-1220,1373,-3035) },
        { name = "Datai", cf = CFrame.new(-166,1043,-1138) },
        { name = "Domae", cf = CFrame.new(-297,1350,-3452) },
        { name = "Sumari", cf = CFrame.new(396,1018,-621) },
        { name = "Yahari", cf = CFrame.new(825,1019,-642) },
        { name = "Enru", cf = CFrame.new(821,800,543) },
        { name = "Nezura", cf = CFrame.new(-1460,275,935) },
        { name = "Gyutai", cf = CFrame.new(-267,1043,-1140) },
        { name = "Akazo", cf = CFrame.new(-1132,1380,-1747) },
        { name = "Reaper", cf = CFrame.new(98,1043,-574) },
    },
}

function CrowQuest:FindActive()
    local d = QuestEngine:GetData()
    if not d or not d.Quests or not d.Quests.Holder then return nil end
    for _, b in ipairs(self.BossData) do
        local qn = "Eliminate "..b.name
        if d.Quests.Holder:FindFirstChild(qn) then return b, qn end
    end
end

function CrowQuest:IsAlive(m)
    if not m or not m.Parent or not m:IsA("Model") then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    local r = m:FindFirstChild("HumanoidRootPart")
    return h ~= nil and h.Health > 0 and r ~= nil
end

function CrowQuest:FindMob(name, origin, radius)
    local h = workspace:FindFirstChild("Humanoids")
    if not h then return nil end
    local best, bd = nil, radius or math.huge
    for _, d in ipairs(h:GetDescendants()) do
        if d:IsA("Model") and d.Name == name and self:IsAlive(d) then
            local r = d.HumanoidRootPart
            local dist = (r.Position - origin).Magnitude
            if dist < bd then bd = dist; best = d end
        end
    end
    return best
end

function CrowQuest:CollectLoot(position, radius)
    radius = radius or 120
    local CS = game:GetService("CollectionService")
    local r = GameAPI:GetRoot()
    if not r then return end
    for _, o in ipairs(CS:GetTagged("LootDrop")) do
        if not self.Active then return end
        local p = o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart")
        if p and (p.Position - position).Magnitude < radius then
            r.CFrame = p.CFrame * CFrame.new(0, 0, 2)
            r.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.2)
            for _, d in ipairs(o:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    pcall(fireproximityprompt, d); break
                end
            end
            task.wait(0.3)
        end
    end
end

function CrowQuest:Run(tok)
    GameAPI:Teleport(CFrame.new(55, 826.5, 781.5))
    task.wait(2)
    local r = GameAPI:GetRoot()
    local ml = workspace.Debree and workspace.Debree:FindFirstChild("MuzanLairModel")
    if ml and r then
        local mr = ml:FindFirstChild("HumanoidRootPart")
        if mr then
            r.CFrame = mr.CFrame * CFrame.new(0, 0, 3)
            r.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.3)
            local p = mr:FindFirstChildOfClass("ProximityPrompt")
            if p and p.Enabled then pcall(fireproximityprompt, p) end
        end
    end
    task.wait(1)
    local g = LocalPlayer:FindFirstChild("PlayerGui")
    local h = g and g:FindFirstChild("ComponentsHolder")
    if h then
        local df = h:FindFirstChild("DialogueFrame")
        if df then
            local bh = df.Actual:FindFirstChild("ButtonHolder")
            if bh then
                local gt = bh:FindFirstChild("Give me a task")
                if gt then
                    local b = gt:FindFirstChildOfClass("TextButton")
                    if b then pcall(firesignal, b.MouseButton1Click) end
                end
            end
        end
    end
    task.wait(1)
    local dc = h and h:FindFirstChild("DialogueContent")
    if dc then
        local hs = {}
        for _, d in ipairs(dc:GetDescendants()) do
            if d.Name == "Claim" and d:IsA("TextButton") then
                local p = d.Parent
                if p and p.Name:match("^Hunt%d+$") then
                    local lc = p:FindFirstChild("LevelCover", true)
                    if not lc or not lc.Visible then table.insert(hs, d) end
                end
            end
        end
        if #hs > 0 then pcall(firesignal, hs[math.random(1, #hs)].MouseButton1Click) end
    end
    task.wait(1)
    local boss, qn
    local tries = 0
    while tok.Active and tries < 20 do
        boss, qn = self:FindActive()
        if boss then break end
        task.wait(0.5); tries += 1
    end
    if not boss then return false, "no quest" end
    GameAPI:Teleport(boss.cf)
    task.wait(0.3)
    local bm, miss = nil, 0
    while tok.Active and Runtime.Alive do
        if not QuestEngine:GetQuestRuntime(qn) then break end
        if not bm or not self:IsAlive(bm) then
            local r2 = GameAPI:GetRoot()
            if r2 then bm = self:FindMob(boss.name, r2.Position, 300) end
        end
        if bm then
            miss = 0
            local br = bm:FindFirstChild("HumanoidRootPart")
            if br then
                local r2 = GameAPI:GetRoot()
                if r2 then
                    r2.CFrame = CFrame.lookAt(br.Position - Vector3.new(0, 6.5, 0), br.Position)
                    r2.AssemblyLinearVelocity = Vector3.zero
                    Combat:Swing("Combat")
                end
            end
        else
            miss += 0.25
            if miss >= 6 then GameAPI:Teleport(boss.cf); miss = 0 end
        end
        task.wait(0.25)
    end
    self:CollectLoot(boss.cf.Position, 120)
    return true
end

-- ========== Muzan Quest ==========
local MuzanQuest = { Active = false, BellSlot = 1 }
MuzanQuest.BossData = {
    { name = "Flame Trainee", cf = CFrame.new(-1129,1029,994) },
    { name = "Thunder Trainee", cf = CFrame.new(2425,1073,-557) },
    { name = "Water Trainee Sabito", cf = CFrame.new(815,1018,101) },
    { name = "Wind Trainee", cf = CFrame.new(-942,1381,-2636) },
    { name = "Stone Trainee", cf = CFrame.new(2685,1073,-569) },
    { name = "Serpent Trainee", cf = CFrame.new(-272,1292,-1536) },
    { name = "Insect Trainee", cf = CFrame.new(-1396,261,69) },
    { name = "Sound Trainee", cf = CFrame.new(192,1349,-2582) },
    { name = "Tai Chi Trainee Suzume", cf = CFrame.new(2360,601,-643) },
    { name = "Obari", cf = CFrame.new(770,1121,-1048) },
    { name = "Tengai", cf = CFrame.new(-134,1349,-2632) },
    { name = "Shinora", cf = CFrame.new(-453,964,2) },
    { name = "Rengu", cf = CFrame.new(-713,965,883) },
    { name = "Saneri", cf = CFrame.new(-380,1093,-423) },
    { name = "Gyorei", cf = CFrame.new(2574,1089,-743) },
    { name = "Zentaro", cf = CFrame.new(1332,821,-1018) },
    { name = "Giyen", cf = CFrame.new(388,1018,-86) },
    { name = "Gyutai", cf = CFrame.new(-267,1043,-1140) },
    { name = "Datai", cf = CFrame.new(-166,1043,-1138) },
}

function MuzanQuest:FindActive()
    local d = QuestEngine:GetData()
    if not d or not d.Quests or not d.Quests.Holder then return nil end
    for _, b in ipairs(self.BossData) do
        local qn = "Eliminate "..b.name
        if d.Quests.Holder:FindFirstChild(qn) then return b, qn end
    end
end

function MuzanQuest:Run(tok)
    pcall(function()
        local i = LocalPlayer:FindFirstChild("Items_Config")
        if i then i.Equipped.Value = self.BellSlot end
    end)
    task.wait(0.3)
    GameAPI:Teleport(CFrame.new(55, 826.5, 781.5))
    task.wait(2)
    local r = GameAPI:GetRoot()
    local ml = workspace.Debree and workspace.Debree:FindFirstChild("MuzanLairModel")
    if ml and r then
        local mr = ml:FindFirstChild("HumanoidRootPart")
        if mr then
            r.CFrame = mr.CFrame * CFrame.new(0, 0, 3)
            r.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.15)
            local p = mr:FindFirstChildOfClass("ProximityPrompt")
            if p and p.Enabled then pcall(fireproximityprompt, p) end
        end
    end
    task.wait(1)
    local g = LocalPlayer:FindFirstChild("PlayerGui")
    local h = g and g:FindFirstChild("ComponentsHolder")
    if h then
        local df = h:FindFirstChild("DialogueFrame")
        if df then
            local bh = df.Actual:FindFirstChild("ButtonHolder")
            if bh then
                local gt = bh:FindFirstChild("Give me a task")
                if gt then
                    local b = gt:FindFirstChildOfClass("TextButton")
                    if b then pcall(firesignal, b.MouseButton1Click) end
                end
            end
        end
    end
    task.wait(1)
    local dc = h and h:FindFirstChild("DialogueContent")
    if dc then
        local hs = {}
        for _, d in ipairs(dc:GetDescendants()) do
            if d.Name == "Claim" and d:IsA("TextButton") then
                local p = d.Parent
                if p and p.Name:match("^Hunt%d+$") then
                    local lc = p:FindFirstChild("LevelCover", true)
                    if not lc or not lc.Visible then table.insert(hs, d) end
                end
            end
        end
        if #hs > 0 then pcall(firesignal, hs[math.random(1, #hs)].MouseButton1Click) end
    end
    task.wait(1)
    local boss, qn
    local tries = 0
    while tok.Active and tries < 20 do
        boss, qn = self:FindActive()
        if boss then break end
        task.wait(0.5); tries += 1
    end
    if not boss then return false, "no quest" end
    GameAPI:Teleport(boss.cf)
    task.wait(0.3)
    local bm, miss = nil, 0
    while tok.Active and Runtime.Alive do
        if not QuestEngine:GetQuestRuntime(qn) then break end
        if not bm or not CrowQuest:IsAlive(bm) then
            local r2 = GameAPI:GetRoot()
            if r2 then bm = CrowQuest:FindMob(boss.name, r2.Position, 300) end
        end
        if bm then
            miss = 0
            local br = bm:FindFirstChild("HumanoidRootPart")
            if br then
                local r2 = GameAPI:GetRoot()
                if r2 then
                    r2.CFrame = CFrame.lookAt(br.Position - Vector3.new(0, 6.5, 0), br.Position)
                    r2.AssemblyLinearVelocity = Vector3.zero
                    Combat:Swing("Combat")
                end
            end
        else
            miss += 0.25
            if miss >= 6 then GameAPI:Teleport(boss.cf); miss = 0 end
        end
        task.wait(0.25)
    end
    CrowQuest:CollectLoot(boss.cf.Position, 120)
    return true
end

-- ========== Mastery ==========
local Mastery = {
    Active = false, Targets = {},
    Weapon = "Combat", Mode = "Below", Distance = 6.5,
    OffX = 0, OffY = 2, OffZ = 0,
    HpThreshold = 60,
    SkillKeys = {}, HoldKeys = {},
    SkillRate = 1.5, HoldDuration = 3,
    EquipSlot = 0,
    BossList = {
        { name = "Mother Bear", cf = CFrame.new(540,1121,-1024) },
        { name = "Hoyuzo", cf = CFrame.new(746,1001,-1413) },
        { name = "Soryu Trainee Goki", cf = CFrame.new(-427,288,543) },
        { name = "Reaper Trainee Kuzan", cf = CFrame.new(-1220,1373,-3035) },
        { name = "Datai", cf = CFrame.new(-166,1043,-1138) },
        { name = "Domae", cf = CFrame.new(-297,1350,-3452) },
        { name = "Sumari", cf = CFrame.new(396,1018,-621) },
        { name = "Yahari", cf = CFrame.new(825,1019,-642) },
        { name = "Enru", cf = CFrame.new(821,800,543) },
        { name = "Nezura", cf = CFrame.new(-1460,275,935) },
        { name = "Gyutai", cf = CFrame.new(-267,1043,-1140) },
        { name = "Akazo", cf = CFrame.new(-1132,1380,-1747) },
        { name = "Reaper", cf = CFrame.new(98,1043,-574) },
        { name = "Flame Trainee", cf = CFrame.new(-1129,1029,994) },
        { name = "Thunder Trainee", cf = CFrame.new(2425,1073,-557) },
        { name = "Water Trainee Sabito", cf = CFrame.new(815,1018,101) },
        { name = "Wind Trainee", cf = CFrame.new(-942,1381,-2636) },
        { name = "Stone Trainee", cf = CFrame.new(2685,1073,-569) },
        { name = "Serpent Trainee", cf = CFrame.new(-272,1292,-1536) },
        { name = "Insect Trainee", cf = CFrame.new(-1396,261,69) },
        { name = "Sound Trainee", cf = CFrame.new(192,1349,-2582) },
        { name = "Tai Chi Trainee Suzume", cf = CFrame.new(2360,601,-643) },
        { name = "Obari", cf = CFrame.new(770,1121,-1048) },
        { name = "Tengai", cf = CFrame.new(-134,1349,-2632) },
        { name = "Shinora", cf = CFrame.new(-453,964,2) },
        { name = "Rengu", cf = CFrame.new(-713,965,883) },
        { name = "Saneri", cf = CFrame.new(-380,1093,-423) },
        { name = "Gyorei", cf = CFrame.new(2574,1089,-743) },
        { name = "Zentaro", cf = CFrame.new(1332,821,-1018) },
        { name = "Giyen", cf = CFrame.new(388,1018,-86) },
        { name = "Kaiden", cf = CFrame.new(585,1146,-1315) },
        { name = "Zuko", cf = CFrame.new(-297,1224,-1023) },
    },
}

function Mastery:Pick(root)
    local all = next(self.Targets) == nil or self.Targets["All Bosses"]
    for _, b in ipairs(self.BossList) do
        if all or self.Targets[b.name] then
            local m = CrowQuest:FindMob(b.name, root.Position, 800)
            if m then return m, b end
        end
    end
end

function Mastery:Run(tok)
    local lastSkill = 0
    local cur, miss = nil, 0
    while tok.Active and Runtime.Alive do
        local r = GameAPI:GetRoot()
        if not r then task.wait(0.25); continue end
        if self.EquipSlot > 0 then
            pcall(function()
                local i = LocalPlayer:FindFirstChild("Items_Config")
                if i then i.Equipped.Value = self.EquipSlot end
            end)
        end
        if not cur or not CrowQuest:IsAlive(cur) then
            cur = self:Pick(r)
            if not cur then
                miss += 0.25
                if miss >= 8 then
                    for _, b in ipairs(self.BossList) do
                        if next(self.Targets) == nil or self.Targets["All Bosses"] or self.Targets[b.name] then
                            local r2 = GameAPI:GetRoot()
                            if r2 and (r2.Position - b.cf.Position).Magnitude > 500 then
                                GameAPI:Teleport(b.cf); break
                            end
                        end
                    end
                    miss = 0
                end
                task.wait(0.25); continue
            end
            miss = 0
        end
        local cr = cur:FindFirstChild("HumanoidRootPart")
        local hum = cur:FindFirstChildOfClass("Humanoid")
        if not cr or not hum or hum.Health <= 0 then cur = nil; task.wait(0.25); continue end

        local cfg = { Mode = self.Mode, Distance = self.Distance, OffsetX = self.OffX, OffsetY = self.OffY, OffsetZ = self.OffZ }
        r.CFrame = CFrame.lookAt(Movement:FarmPosition(cr, cfg), cr.Position)
        r.AssemblyLinearVelocity = Vector3.zero

        if hum.Health > self.HpThreshold then
            Combat:Swing(self.Weapon)
        else
            local now = os.clock()
            if now - lastSkill >= self.SkillRate then
                lastSkill = now
                for _, k in ipairs(self.SkillKeys) do pressKey(k); task.wait(0.1) end
            end
            for _, k in ipairs(self.HoldKeys) do holdStart(k) end
            task.wait(self.HoldDuration)
            for _, k in ipairs(self.HoldKeys) do holdStop(k) end
        end
        task.wait(0.15)
    end
end

-- ========== GenericQuest ==========
local GenericQuest = { Active = false, BreathingPick = "Serpent", FightingPick = nil }

local QUEST_NPCS = {
    Krue = CFrame.new(-425.5,1244,-952.5),
    Kazu = CFrame.new(-626,1245,-1138),
    Kona = CFrame.new(-792,1260,-1131),
    Noote = CFrame.new(-515.5,1245,-1251),
    MoldySugar = CFrame.new(-702,1245,-983),
    Raze = CFrame.new(-594,1245,-1095),
    Rika = CFrame.new(-497,1249,-1177),
    Lucy = CFrame.new(-615.5,1258,-1177),
    Tom = CFrame.new(507,1121,-970),
    Chaka = CFrame.new(471,1146,-1260),
    Betty = CFrame.new(714,1121,-808),
    Wagwan = CFrame.new(723.7,1019,-802),
    Shiori = CFrame.new(-1814.3,312,-101.1),
    Ren = CFrame.new(-1795,312,-85),
    ["Blacksmith Togane"] = CFrame.new(1732.1,694,-764.6),
    ["Stonemason Tobei"] = CFrame.new(1876,659,-206),
    ["Serpent Trainer"] = CFrame.new(37,1311,-1179.5),
    ["Flame Trainer"] = CFrame.new(-967.6,1029,1188.2),
    ["Water Trainer"] = CFrame.new(667.2,1023,-228.2),
    ["Thunder Trainer"] = CFrame.new(1970.2,1660,-609.8),
    ["Wind Trainer"] = CFrame.new(-275.6,1187,-3436.7),
    ["Stone Trainer"] = CFrame.new(2578.6,1096,-828.4),
    ["Insect Trainer"] = CFrame.new(-1799,348,-189.3),
    ["Sound Trainer"] = CFrame.new(464.9,1491,-3272.8),
    ["Soryu Expert Kazuma"] = CFrame.new(-769.5,909,303.3),
    ["Tai Chi Expert Renjiro"] = CFrame.new(1883.1,687,-761),
}

function GenericQuest:TalkToNpc(name)
    local cf = QUEST_NPCS[name]
    if not cf then return false end
    GameAPI:Teleport(cf + Vector3.new(0, 0, 5))
    task.wait(0.8)
    local db = workspace:FindFirstChild("Debree")
    if db then
        for _, r in ipairs(db:GetChildren()) do
            local s = r:FindFirstChild("StationaryNpcs")
            local npc = s and s:FindFirstChild(name)
            if npc and npc:FindFirstChild("HumanoidRootPart") then
                local nr = npc.HumanoidRootPart
                local root = GameAPI:GetRoot()
                if root then
                    root.CFrame = nr.CFrame * CFrame.new(0, 0, 3)
                    root.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.3)
                end
                for _, c in ipairs(nr:GetChildren()) do
                    if c:IsA("ProximityPrompt") and c.ActionText == "Chat" then
                        pcall(fireproximityprompt, c); task.wait(1.5); return true
                    end
                end
            end
        end
    end
    task.wait(1)
    return false
end

function GenericQuest:ClickDialogue(name)
    local g = LocalPlayer:FindFirstChild("PlayerGui")
    local h = g and g:FindFirstChild("ComponentsHolder")
    local df = h and h:FindFirstChild("DialogueFrame")
    local bh = df and df.Actual:FindFirstChild("ButtonHolder")
    if not bh then return false end
    local t = bh:FindFirstChild(name)
    if t then
        local b = t:FindFirstChildOfClass("TextButton")
        if b then pcall(firesignal, b.MouseButton1Click); return true end
    end
    for _, f in ipairs(bh:GetChildren()) do
        if f:IsA("Frame") and f.Name:lower():find(name:lower(), 1, true) then
            local b = f:FindFirstChildOfClass("TextButton")
            if b then pcall(firesignal, b.MouseButton1Click); return true end
        end
    end
    return false
end

function GenericQuest:AcceptQuest(qn)
    GameAPI:ToServer("AddQuest", qn)
    task.wait(1.5)
    return QuestEngine:GetQuestRuntime(qn) ~= nil
end

function GenericQuest:RunDelivery(tok)
    local list = {
        { key="Ill take 3 bandits", npc="Krue", mob="Bandit" },
        { key="Ill help clear them out", npc="Kazu", mob="*Civilian*" },
        { key="Ill take the bandit boss(Lv 7)", npc="Krue", mob="Zuko" },
        { key="Ill drive the bears back(Lv 10)", npc="Tom", mob="Bear Cub" },
        { key="Ill restock the pantry(Lv 10)", npc="Lucy", mob="Bear Cub" },
        { key="Ill fell the Mother Bear(Lv 18)", npc="Tom", mob="Mother Bear" },
        { key="Ill clear out his subordinates(Lv 26)", npc="Chaka", mob="Kaiden Subordinate" },
        { key="Ill deal with Kaiden(Lv 34)", npc="Chaka", mob="Kaiden" },
        { key="I will clear out his guards(Lv 40)", npc="Wagwan", mob="Hoyuzo Subordinate" },
        { key="I will take care of Hoyuzo(Lv 50)", npc="Wagwan", mob="Hoyuzo" },
    }
    while tok.Active and Runtime.Alive do
        local d = QuestEngine:GetData()
        if not d or not d.Quests then break end
        local act, mob
        for _, e in ipairs(list) do
            if d.Quests.Holder:FindFirstChild(e.key) then act = e.key; mob = e.mob; break end
        end
        if not act then
            for _, e in ipairs(list) do
                if tok.Active and self:TalkToNpc(e.npc) and self:ClickDialogue(e.key) then
                    task.wait(1); break
                end
            end
            task.wait(2)
        elseif mob then
            local r = GameAPI:GetRoot()
            if r then
                local m = CrowQuest:FindMob(mob, r.Position, 500)
                if m then
                    local mr = m:FindFirstChild("HumanoidRootPart")
                    if mr then
                        r.CFrame = CFrame.lookAt(mr.Position - Vector3.new(0, 6.5, 0), mr.Position)
                        r.AssemblyLinearVelocity = Vector3.zero
                        Combat:Swing("Combat")
                    end
                end
            end
            task.wait(0.3)
        else
            task.wait(1)
        end
    end
end

-- ========== Features API ==========
function Features:StartMobFarm(cfg)
    self:StopMobFarm()
    if not Movement:Acquire("MobFarm") then return false, "movement busy" end
    cfg = cfg or self.Config.MobFarm
    self.Config.MobFarm = cfg
    spawnJob("MobFarm", function(tok)
        while tok.Active and Runtime.Alive do
            local r = GameAPI:GetRoot()
            if r then
                if cfg.EquipSlot and cfg.EquipSlot > 0 then
                    pcall(function()
                        local i = LocalPlayer:FindFirstChild("Items_Config")
                        if i then i.Equipped.Value = cfg.EquipSlot end
                    end)
                end
                local m = MobIndex:Nearest(cfg.Target, r.Position, cfg.SearchRange or 5000)
                local sp = GameAPI:GetMobSpawns(cfg.Target)
                local fb = (sp and sp[1]) or nil
                Movement:SetIntent("MobFarm", { Target = m, Fallback = m and nil or fb, Config = cfg, Attack = true })
            end
            task.wait(0.25)
        end
        Movement:Release("MobFarm")
    end)
    log("MobFarm ON:", cfg.Target)
    return true
end

function Features:StopMobFarm()
    stopJob("MobFarm")
    Movement:Release("MobFarm")
end

function Features:StartBossFarm(cfg)
    self:StopBossFarm()
    if not Movement:Acquire("BossFarm") then return false, "movement busy" end
    cfg = cfg or self.Config.BossFarm
    self.Config.BossFarm = cfg
    spawnJob("BossFarm", function(tok)
        while tok.Active and Runtime.Alive do
            local r = GameAPI:GetRoot()
            if r then
                local m = MobIndex:Nearest(cfg.Target, r.Position, cfg.SearchRange or 10000)
                Movement:SetIntent("BossFarm", { Target = m, Fallback = nil, Config = cfg, Attack = true })
            end
            task.wait(0.25)
        end
        Movement:Release("BossFarm")
    end)
    log("BossFarm ON:", cfg.Target)
    return true
end

function Features:StopBossFarm()
    stopJob("BossFarm")
    Movement:Release("BossFarm")
end

function Features:StartFinalSelection()
    self:StopFinalSelection()
    if not FinalSelection:IsInside() then return false, "not inside Final Selection" end
    if Movement.Owner and Movement.Owner ~= "FinalSelection" then
        return false, "movement busy: "..tostring(Movement.Owner)
    end
    spawnJob("FinalSelection", function(tok)
        local ok, res = xpcall(function()
            return FinalSelection:Run(tok)
        end, debug.traceback)
        if not ok then fail("FinalSelection", res) end
        FinalSelection.Active = false
        Movement:Release("FinalSelection")
    end)
    log("FinalSelection ON")
    return true
end

function Features:StopFinalSelection()
    stopJob("FinalSelection")
    FinalSelection.Active = false
    Movement:Release("FinalSelection")
end

function Features:StartCrowQuest()
    self:StopCrowQuest()
    if not Movement:Acquire("CrowQuest") then return false, "movement busy" end
    CrowQuest.Active = true
    spawnJob("CrowQuest", function(tok)
        while tok.Active and Runtime.Alive do
            pcall(function() CrowQuest:Run(tok) end)
            task.wait(1)
        end
        CrowQuest.Active = false
        Movement:Release("CrowQuest")
    end)
    log("CrowQuest ON")
    return true
end

function Features:StopCrowQuest()
    CrowQuest.Active = false
    stopJob("CrowQuest")
    Movement:Release("CrowQuest")
end

function Features:StartMuzanQuest()
    self:StopMuzanQuest()
    if not Movement:Acquire("MuzanQuest") then return false, "movement busy" end
    MuzanQuest.Active = true
    spawnJob("MuzanQuest", function(tok)
        while tok.Active and Runtime.Alive do
            pcall(function() MuzanQuest:Run(tok) end)
            task.wait(1)
        end
        MuzanQuest.Active = false
        Movement:Release("MuzanQuest")
    end)
    log("MuzanQuest ON")
    return true
end

function Features:StopMuzanQuest()
    MuzanQuest.Active = false
    stopJob("MuzanQuest")
    Movement:Release("MuzanQuest")
end

function Features:StartMastery()
    self:StopMastery()
    if not Movement:Acquire("Mastery") then return false, "movement busy" end
    Mastery.Active = true
    spawnJob("Mastery", function(tok)
        pcall(function() Mastery:Run(tok) end)
        Mastery.Active = false
        Movement:Release("Mastery")
    end)
    log("Mastery ON")
    return true
end

function Features:StopMastery()
    Mastery.Active = false
    stopJob("Mastery")
    Movement:Release("Mastery")
end

function Features:StartGenericQuest(mode, opts)
    self:StopGenericQuest()
    if not Movement:Acquire("GenericQuest") then return false, "movement busy" end
    GenericQuest.Active = true
    if opts then
        if opts.BreathingPick then GenericQuest.BreathingPick = opts.BreathingPick end
        if opts.FightingPick then GenericQuest.FightingPick = opts.FightingPick end
    end
    spawnJob("GenericQuest", function(tok)
        if mode == "Delivery" then
            pcall(function() GenericQuest:RunDelivery(tok) end)
        end
        GenericQuest.Active = false
        Movement:Release("GenericQuest")
    end)
    log("GenericQuest ON:", mode)
    return true
end

function Features:StopGenericQuest()
    GenericQuest.Active = false
    stopJob("GenericQuest")
    Movement:Release("GenericQuest")
end

function Features:StartKillAura(w)
    self:StopKillAura()
    spawnJob("KillAura", function(tok)
        while tok.Active and Runtime.Alive do
            Combat:Swing(w or "Combat")
            task.wait()
        end
    end)
    log("KillAura ON")
end

function Features:StopKillAura() stopJob("KillAura") end

function Features:StartPickupAura(radius)
    self:StopPickupAura()
    radius = tonumber(radius) or 120
    spawnJob("PickupAura", function(tok)
        while tok.Active and Runtime.Alive do
            local r = GameAPI:GetRoot()
            local ld = workspace:FindFirstChild("LootDrops")
            if r and ld and type(fireproximityprompt) == "function" then
                for _, c in ipairs(ld:GetChildren()) do
                    if not tok.Active then break end
                    local p = c:IsA("BasePart") and c or c:FindFirstChildWhichIsA("BasePart")
                    if p and (p.Position - r.Position).Magnitude < radius then
                        for _, d in ipairs(c:GetDescendants()) do
                            if d:IsA("ProximityPrompt") then pcall(fireproximityprompt, d); break end
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
    log("PickupAura ON")
end

function Features:StopPickupAura() stopJob("PickupAura") end

function Features:TeleportToNPC(name)
    local cf = GameAPI:GetNPCSpawn(name)
    if not cf then return false, "no NPC spawn: "..tostring(name) end
    return GameAPI:Teleport(cf * CFrame.new(0, 0, 3))
end

function Features:TeleportToMob(name)
    local r = GameAPI:GetRoot()
    if r then
        local live = MobIndex:Nearest(name, r.Position, math.huge)
        if live then
            local lr = live:FindFirstChild("HumanoidRootPart")
            if lr then return GameAPI:Teleport(lr.CFrame * CFrame.new(0, 0, 3)) end
        end
    end
    local sp = GameAPI:GetMobSpawns(name)
    if sp and sp[1] then return GameAPI:Teleport(sp[1]) end
    return false, "not found"
end

function Features:StopAll()
    self:StopFinalSelection()
    self:StopCrowQuest()
    self:StopMuzanQuest()
    self:StopMastery()
    self:StopGenericQuest()
    self:StopMobFarm()
    self:StopBossFarm()
    self:StopKillAura()
    self:StopPickupAura()
    Movement.Owner = nil
    Movement.Intent = nil
end

S2.Features = {
    Features = Features,
    QuestEngine = QuestEngine,
    FinalSelection = FinalSelection,
    CrowQuest = CrowQuest,
    MuzanQuest = MuzanQuest,
    Mastery = Mastery,
    GenericQuest = GenericQuest,
    QUEST_NPCS = QUEST_NPCS,
    pressKey = pressKey,
    holdKeyStart = holdStart,
    holdKeyStop = holdStop,
}

print("======================================================")
print("[S2/FEAT] READY - Execute ui.lua next")
print("======================================================")
