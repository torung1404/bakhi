-- crowquest.lua - Crow Quest rewrite v2 (fixed parsing + clicking)
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[Crow] core missing") end
if not S2.Features then return warn("[Crow] features missing") end

local Runtime = S2.Core.Runtime
local GameAPI = S2.Core.GameAPI
local Combat = S2.Core.Combat
local Movement = S2.Core.Movement
local log = S2.Core.log
local spawnJob = S2.Core.spawnJob
local stopJob = S2.Core.stopJob

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local CrowQuest = S2.Features.CrowQuest
if not CrowQuest then return warn("[Crow] no CrowQuest table") end

-- ============ Config ============
CrowQuest.Cfg = CrowQuest.Cfg or {
    CrowSlot = 3,
    WeaponSlot = 1,
    Priority = "HighestExp",
    MaxHuntLevel = 125,
    RetryDelay = 2.0,
    AutoLootBoss = false,
}

-- ============ Helpers ============
local function getQuestHolder()
    local q = S2.Features.QuestEngine
    if not q then return nil end
    local d = q:GetData()
    if not d or not d.Quests or not d.Quests:FindFirstChild("Holder") then return nil end
    return d.Quests.Holder
end

local function findBossByText(text)
    if not text then return nil end
    local lower = text:lower()
    for _, b in ipairs(CrowQuest.BossData or {}) do
        if lower:find(b.name:lower(), 1, true) then return b end
    end
    return nil
end

local function getActiveQuestBoss()
    local holder = getQuestHolder()
    if not holder then return nil end
    for _, q in ipairs(holder:GetChildren()) do
        local name = q.Name:lower()
        for _, b in ipairs(CrowQuest.BossData or {}) do
            if name:find(b.name:lower(), 1, true) then return b, q end
        end
        local qs = q:FindFirstChild("QuestString")
        if qs and type(qs.Value) == "string" then
            local qsl = qs.Value:lower()
            for _, b in ipairs(CrowQuest.BossData or {}) do
                if qsl:find(b.name:lower(), 1, true) then return b, q end
            end
        end
    end
    return nil
end

local function pressKey(vk)
    if not keypress or not keyrelease then return end
    pcall(function()
        if setrobloxinput then setrobloxinput(true) end
        keyrelease(vk)
        task.wait(0.05)
        keypress(vk)
        task.wait(0.1)
        keyrelease(vk)
    end)
end

local function pressSlot(slot)
    slot = math.clamp(tonumber(slot) or 1, 1, 5)
    pressKey(48 + slot)
end

-- ============ Parse helpers ============
local function parseAllNumbers(text)
    local nums = {}
    if not text then return nums end
    for numStr in text:gmatch("([%d,]+)") do
        local clean = numStr:gsub(",", "")
        local n = tonumber(clean)
        if n and n > 0 then table.insert(nums, n) end
    end
    return nums
end

-- Find container frame (walk up until size > threshold)
local function findContainer(obj, minW)
    minW = minW or 100
    local p = obj
    for _ = 1, 6 do
        if not p then return nil end
        local ok, size = pcall(function() return p.AbsoluteSize end)
        if ok and size and size.X >= minW then return p end
        p = p.Parent
    end
    return obj and obj.Parent or nil
end

-- ============ Menu scanner ============
local function getDialogueFrame()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local holder = pg:FindFirstChild("ComponentsHolder")
    if not holder then return nil end
    return holder:FindFirstChild("DialogueFrame")
end

function CrowQuest:ScanMenu()
    local df = getDialogueFrame()
    if not df then return {} end
    local actual = df:FindFirstChild("Actual")
    if not actual then return {} end

    local choices = {}
    local seen = {}

    -- Find all labels containing "Defeat"
    for _, d in ipairs(actual:GetDescendants()) do
        if not (d:IsA("TextLabel") or d:IsA("TextButton")) then continue end
        local txt = d.Text or ""
        if not txt:find("Defeat", 1, true) then continue end

        -- Boss name from this label
        local bossName = txt:gsub("^%s*Defeat%s+", ""):gsub("%s+$", "")
        local bossData = findBossByText(bossName) or findBossByText(txt)
        if not bossData then continue end

        -- Skip if we already processed this boss area (dedupe by Y ~20px)
        local ok, ap = pcall(function() return d.AbsolutePosition end)
        if not ok or not ap then continue end
        local key = bossData.name .. "@" .. math.floor(ap.Y / 30)
        if seen[key] then continue end
        seen[key] = true

        -- Container = frame holding name + exp + wen
        local container = findContainer(d, 200)

        -- Parse all numbers in container
        local exp, wen = 0, 0
        if container then
            local nums = {}
            for _, n in ipairs(container:GetDescendants()) do
                if n:IsA("TextLabel") or n:IsA("TextButton") then
                    for _, v in ipairs(parseAllNumbers(n.Text)) do
                        table.insert(nums, v)
                    end
                end
            end
            -- exp = largest number >= 1000, wen = next
            table.sort(nums, function(a, b) return a > b end)
            if nums[1] and nums[1] >= 1000 then exp = nums[1] end
            if nums[2] and nums[2] >= 100 then wen = nums[2] end
        end

        -- Click target = TextButton ancestor
        local btn = d
        for _ = 1, 6 do
            if not btn then break end
            if btn:IsA("TextButton") or btn:IsA("ImageButton") then break end
            btn = btn.Parent
        end
        if not btn then btn = d end

        local ok2, bap = pcall(function() return btn.AbsolutePosition end)
        local ok3, bas = pcall(function() return btn.AbsoluteSize end)
        local bx = (ok2 and bap and bap.X or 0) + (ok3 and bas and bas.X * 0.5 or 100)
        local by = (ok2 and bap and bap.Y or 0) + (ok3 and bas and bas.Y * 0.5 or 20)

        choices[#choices + 1] = {
            Boss = bossData,
            Exp = exp,
            Wen = wen,
            Button = btn,
            Label = d,
            Frame = container or d.Parent,
            X = bx,
            Y = by,
        }
    end

    return choices
end

-- ============ Pick best mission ============
function CrowQuest:PickBestMission(choices)
    local cfg = self.Cfg
    local priority = cfg.Priority or "HighestExp"

    if #choices == 0 then return nil end
    if priority == "Random" then
        return choices[math.random(1, #choices)]
    end

    local sorted = {}
    for _, c in ipairs(choices) do table.insert(sorted, c) end

    table.sort(sorted, function(a, b)
        if priority == "HighestExp" then
            if a.Exp ~= b.Exp then return a.Exp > b.Exp end
            return a.Wen > b.Wen
        else -- HighestLevel
            return a.Exp > b.Exp
        end
    end)

    return sorted[1]
end

-- ============ Robust click ============
local function clickButton(choice)
    local btn = choice.Button

    -- Strategy 1: firesignal on MouseButton1Click
    if btn and firesignal then
        local ok = pcall(firesignal, btn.MouseButton1Click)
        if ok then
            log("[Crow] clicked via firesignal")
            return true
        end
    end

    -- Strategy 2: mouse move + click with setrobloxinput
    local mouse = LP:GetMouse()
    if mouse and mousemoverel then
        pcall(function()
            if setrobloxinput then setrobloxinput(true) end
            mousemoverel(choice.X - mouse.X, choice.Y - mouse.Y)
        end)
        task.wait(0.12)

        if mouse1click then
            pcall(function()
                if setrobloxinput then setrobloxinput(true) end
                mouse1click()
            end)
            task.wait(0.15)
            log("[Crow] clicked via mouse1click")
            return true
        end

        if mouse1press and mouse1release then
            pcall(function()
                if setrobloxinput then setrobloxinput(true) end
                mouse1press()
                task.wait(0.1)
                mouse1release()
            end)
            task.wait(0.15)
            log("[Crow] clicked via mouse1press/release")
            return true
        end
    end

    -- Strategy 3: VirtualUser
    local ok = pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton1(Vector2.new(choice.X, choice.Y))
        vu:ReleaseController()
    end)
    if ok then
        log("[Crow] clicked via VirtualUser")
        return true
    end

    return false
end

-- ============ Wait helper ============
local function waitFor(tok, pred, timeout)
    local t = 0
    timeout = timeout or 8
    while tok.Active and Runtime.Alive and t < timeout do
        local ok, r = pcall(pred)
        if ok and r then return true end
        task.wait(0.2)
        t = t + 0.2
    end
    return false
end

-- ============ Fight boss ============
function CrowQuest:FightBoss(tok, boss)
    if boss.cf then
        GameAPI:Teleport(boss.cf + Vector3.new(0, 3, 0))
        task.wait(0.5)
    end

    local deathTimer = 0
    while tok.Active and Runtime.Alive do
        local active = getActiveQuestBoss()
        if not active then return true end

        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            deathTimer = deathTimer + 0.5
            if deathTimer > 10 then return false end
            task.wait(0.5)
            continue
        end
        deathTimer = 0

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then task.wait(0.3); continue end

        local bossModel = self.FindMob and self:FindMob(boss.name, root.Position, 500)
        if bossModel then
            local bossRoot = bossModel:FindFirstChild("HumanoidRootPart")
            if bossRoot then
                root.CFrame = CFrame.lookAt(
                    bossRoot.Position - Vector3.new(0, 6.5, 0),
                    bossRoot.Position
                )
                root.AssemblyLinearVelocity = Vector3.zero
                Combat:Swing("Combat")
            end
        else
            if boss.cf then GameAPI:Teleport(boss.cf + Vector3.new(0, 3, 0)) end
            task.wait(1)
        end

        task.wait(0.3)
    end
    return false
end

-- ============ Main Run ============
function CrowQuest:Run(tok)
    local cfg = self.Cfg
    local retry = tonumber(cfg.RetryDelay) or 2.0

    while tok.Active and Runtime.Alive do
        -- Phase 0: existing quest?
        local existing = getActiveQuestBoss()
        if existing then
            log("[Crow] existing quest:", existing.name)
            self:FightBoss(tok, existing)
            task.wait(retry)
            continue
        end

        -- Phase 1: summon crow
        log("[Crow] summoning crow (slot " .. tostring(cfg.CrowSlot) .. ")")
        pressSlot(cfg.CrowSlot)

        local gotMenu = waitFor(tok, function()
            return #self:ScanMenu() > 0
        end, 8)

        if not gotMenu then
            log("[Crow] no menu, retry")
            pressSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        -- Phase 2: pick mission
        local choices = self:ScanMenu()
        log("[Crow] scanned " .. #choices .. " missions")
        for _, c in ipairs(choices) do
            log("  - " .. c.Boss.name .. " Exp=" .. c.Exp .. " Wen=" .. c.Wen)
        end

        local best = self:PickBestMission(choices)
        if not best then
            log("[Crow] no valid pick")
            pressSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        log("[Crow] picking: " .. best.Boss.name .. " Exp=" .. best.Exp)
        clickButton(best)
        task.wait(0.8)

        -- Phase 3: wait for quest
        local gotQuest = waitFor(tok, function()
            return getActiveQuestBoss() ~= nil
        end, 10)

        if not gotQuest then
            log("[Crow] quest not registered, retry")
            pressSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        local actual = getActiveQuestBoss()
        local target = actual or best.Boss
        log("[Crow] quest active: " .. target.name)

        -- Phase 4: weapon
        task.wait(0.4)
        pressSlot(cfg.WeaponSlot)
        task.wait(0.3)

        -- Phase 5: fight
        self:FightBoss(tok, target)

        -- Phase 6: loot
        if cfg.AutoLootBoss and self.CollectLoot then
            pcall(function() self:CollectLoot(target.cf.Position, 200) end)
        end

        task.wait(retry)
    end
end

-- ============ UI Settings ============
task.spawn(function()
    task.wait(1.5)
    local window = S2.UI and S2.UI.Window
    if not window then return end

    local questTab = nil
    for _, tab in ipairs(window.Tabs) do
        if tab.Name == "Quests" then questTab = tab break end
    end
    if not questTab then return end

    local crowGB = window:AddGroupbox(questTab, "Crow Quest")

    window:AddDropdown(crowGB, "_CrowSlot", {
        Text = "Crow Tool Slot",
        Values = { "1", "2", "3", "4", "5" },
        Default = tostring(CrowQuest.Cfg.CrowSlot),
        Callback = function(v) CrowQuest.Cfg.CrowSlot = tonumber(v) or 3 end,
    })

    window:AddDropdown(crowGB, "_CrowWeapSlot", {
        Text = "Weapon Slot",
        Values = { "1", "2", "3", "4", "5" },
        Default = tostring(CrowQuest.Cfg.WeaponSlot),
        Callback = function(v) CrowQuest.Cfg.WeaponSlot = tonumber(v) or 1 end,
    })

    window:AddDropdown(crowGB, "_CrowPriority", {
        Text = "Priority Mode",
        Values = { "HighestExp", "HighestLevel", "Random" },
        Default = CrowQuest.Cfg.Priority,
        Callback = function(v) CrowQuest.Cfg.Priority = v end,
    })

    window:AddSlider(crowGB, "_CrowRetry", {
        Text = "Retry Delay",
        Min = 0.5, Max = 10, Default = CrowQuest.Cfg.RetryDelay, Decimals = 1,
        Callback = function(v) CrowQuest.Cfg.RetryDelay = v end,
    })

    window:AddToggle(crowGB, "_CrowAutoLoot", {
        Text = "Auto Loot Boss",
        Default = CrowQuest.Cfg.AutoLootBoss,
        Callback = function(on) CrowQuest.Cfg.AutoLootBoss = on end,
    })

    log("[Crow] UI settings added")
end)

print("[ToRung/CROW] v2 loaded")
