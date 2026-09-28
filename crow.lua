-- crow.lua - Crow Quest for Delta (Roblox API only)
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[Crow] core missing") end
if not S2.Features then return warn("[Crow] features missing") end

local Runtime = S2.Core.Runtime
local GameAPI = S2.Core.GameAPI
local Combat = S2.Core.Combat
local log = S2.Core.log

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local CrowQuest = S2.Features.CrowQuest
if not CrowQuest then return warn("[Crow] no CrowQuest table") end

CrowQuest.Cfg = {
    CrowSlot = 5,
    WeaponSlot = 1,
    Priority = "HighestExp",
    MaxHuntLevel = 125,
    RetryDelay = 2.0,
    AutoLootBoss = false,
}

-- ============ Quest helpers ============
local function getQuestRuntime()
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
    local holder = getQuestRuntime()
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

-- ============ ROBLOX-ONLY Input ============
local VirtualUser = game:GetService("VirtualUser")

-- Click at screen position using VirtualUser (works on Delta)
local function clickScreen(x, y)
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(Vector2.new(x, y))
        VirtualUser:ReleaseController()
    end)
end

-- Find hotbar button for a given slot (1-5)
local function getHotbarButton(slotNum)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end

    -- Common hotbar paths in Slayers 2
    local candidates = {
        pg:FindFirstChild("Hotbar"),
        pg:FindFirstChild("ComponentsHolder") and pg.ComponentsHolder:FindFirstChild("Hotbar"),
        pg:FindFirstChild("BackpackGui"),
    }

    -- Also scan deeper for frame named "Slot1".."Slot5" or "Hotbar"
    local function findIn(root)
        if not root then return nil end
        for _, d in ipairs(root:GetDescendants()) do
            local n = d.Name
            if n == "Slot" .. slotNum
               or n == "Slot_" .. slotNum
               or n == "Toolbar" .. slotNum
               or n == "Item" .. slotNum then
                if d:IsA("TextButton") or d:IsA("ImageButton") then
                    return d
                end
                for _, c in ipairs(d:GetChildren()) do
                    if c:IsA("TextButton") or c:IsA("ImageButton") then
                        return c
                    end
                end
            end
        end
        return nil
    end

    for _, root in ipairs(candidates) do
        if root then
            local btn = findIn(root)
            if btn then return btn end
        end
    end

    -- Fallback: scan whole PlayerGui
    local btn = findIn(pg)
    return btn
end

-- Equip slot by tapping hotbar button
local function equipSlot(slotNum)
    slotNum = math.clamp(tonumber(slotNum) or 1, 1, 5)

    local btn = getHotbarButton(slotNum)
    if btn then
        local ap = btn.AbsolutePosition
        local as = btn.AbsoluteSize
        if ap and as then
            local cx = ap.X + as.X * 0.5
            local cy = ap.Y + as.Y * 0.5
            clickScreen(cx, cy)
            log("[Crow] tapped hotbar slot " .. slotNum .. " at " .. math.floor(cx) .. "," .. math.floor(cy))
            task.wait(0.4)
            return true
        end
    end

    -- Fallback: try firekey via UserInputService (works only if Delta hooks UIS)
    pcall(function()
        local keyCode = Enum.KeyCode["One"]
        local keys = {
            Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
            Enum.KeyCode.Four, Enum.KeyCode.Five
        }
        local kc = keys[slotNum]
        if kc then
            UIS:SetKeyThrottleEnabled(kc, false)
            -- not reliable but try
        end
    end)

    log("[Crow] couldn't find hotbar slot " .. slotNum)
    return false
end

-- Summon crow: equip crow + click chuột giữa màn hình
local function summonCrow(slotNum)
    equipSlot(slotNum)
    task.wait(0.6)

    -- Click giữa màn hình để triệu hồi quạ
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
    clickScreen(vs.X * 0.5, vs.Y * 0.5)
    log("[Crow] clicked center to summon")
    task.wait(0.8)
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
    local bh = actual:FindFirstChild("ButtonHolder")
    if not bh then return {} end

    local choices = {}
    for _, frame in ipairs(bh:GetChildren()) do
        if not (frame:IsA("Frame") or frame:IsA("TextButton")) then continue end

        local bossName = nil
        local fullText = ""
        local allNums = {}

        for _, d in ipairs(frame:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local txt = d.Text or ""
                fullText = fullText .. " " .. txt
                if not bossName and txt:find("Defeat", 1, true) then
                    local b = findBossByText(txt)
                    if b then bossName = b end
                end
                for numStr in txt:gmatch("([%d,]+)") do
                    local n = tonumber(numStr:gsub(",", ""))
                    if n and n >= 100 then table.insert(allNums, n) end
                end
            end
        end
        if not bossName then
            local b = findBossByText(fullText)
            if b then bossName = b end
        end
        if not bossName then continue end

        table.sort(allNums, function(a, b) return a > b end)
        local exp, wen = 0, 0
        for _, n in ipairs(allNums) do
            if n >= 1000 and exp == 0 then exp = n
            elseif n >= 100 and n < 10000 and wen == 0 and n ~= exp then wen = n end
        end

        local btn = frame:FindFirstChild("TextButton") or frame
        local ap = btn.AbsolutePosition or Vector2.new(0, 0)
        local as = btn.AbsoluteSize or Vector2.new(100, 30)

        table.insert(choices, {
            Boss = bossName, Exp = exp, Wen = wen,
            Button = btn, Frame = frame,
            X = ap.X + as.X * 0.5, Y = ap.Y + as.Y * 0.5,
        })
    end
    return choices
end

function CrowQuest:PickBestMission(choices)
    if #choices == 0 then return nil end
    if (self.Cfg.Priority or "HighestExp") == "Random" then
        return choices[math.random(1, #choices)]
    end
    local sorted = {}
    for _, c in ipairs(choices) do table.insert(sorted, c) end
    table.sort(sorted, function(a, b)
        if a.Exp ~= b.Exp then return a.Exp > b.Exp end
        return a.Wen > b.Wen
    end)
    return sorted[1]
end

-- Click mission (Roblox-only)
local function clickMission(choice)
    -- Primary: VirtualUser click
    clickScreen(choice.X, choice.Y)

    -- Backup: firesignal (Delta has this)
    if choice.Button and firesignal then
        pcall(firesignal, choice.Button.MouseButton1Click)
    end

    log("[Crow] clicked mission at " .. math.floor(choice.X) .. "," .. math.floor(choice.Y))
end

-- ============ Wait ============
local function waitFor(tok, pred, timeout)
    local t = 0
    while tok.Active and Runtime.Alive and t < timeout do
        local ok, r = pcall(pred)
        if ok and r then return true end
        task.wait(0.2)
        t = t + 0.2
    end
    return false
end

-- ============ Fight ============
function CrowQuest:FightBoss(tok, boss)
    if boss.cf then
        GameAPI:Teleport(boss.cf + Vector3.new(0, 3, 0))
        task.wait(0.5)
    end
    local deathTimer = 0
    while tok.Active and Runtime.Alive do
        if not getActiveQuestBoss() then return true end
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
                root.CFrame = CFrame.lookAt(bossRoot.Position - Vector3.new(0, 6.5, 0), bossRoot.Position)
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

-- ============ Main ============
function CrowQuest:Run(tok)
    local cfg = self.Cfg
    local retry = tonumber(cfg.RetryDelay) or 2.0

    while tok.Active and Runtime.Alive do
        local existing = getActiveQuestBoss()
        if existing then
            log("[Crow] continuing quest: " .. existing.name)
            self:FightBoss(tok, existing)
            task.wait(retry)
            continue
        end

        if #self:ScanMenu() > 0 then
            log("[Crow] menu already open")
        else
            log("[Crow] summoning crow (slot " .. tostring(cfg.CrowSlot) .. ")")
            summonCrow(cfg.CrowSlot)

            local gotMenu = waitFor(tok, function()
                return #self:ScanMenu() > 0
            end, 10)

            if not gotMenu then
                log("[Crow] no menu, retry")
                equipSlot(cfg.WeaponSlot)
                task.wait(retry)
                continue
            end
        end

        local choices = self:ScanMenu()
        log("[Crow] scanned " .. #choices .. " missions")
        for _, c in ipairs(choices) do
            log("  -> " .. c.Boss.name .. " | Exp=" .. c.Exp .. " | Wen=" .. c.Wen)
        end

        local best = self:PickBestMission(choices)
        if not best then
            log("[Crow] no valid pick")
            equipSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        log("[Crow] picking: " .. best.Boss.name .. " (Exp=" .. best.Exp .. ")")
        clickMission(best)
        task.wait(1)

        local gotQuest = waitFor(tok, function()
            return getActiveQuestBoss() ~= nil
        end, 10)

        if not gotQuest then
            log("[Crow] quest not registered, retry")
            equipSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        local actual = getActiveQuestBoss()
        local target = actual or best.Boss
        log("[Crow] quest active: " .. target.name)

        task.wait(0.4)
        equipSlot(cfg.WeaponSlot)
        task.wait(0.3)

        self:FightBoss(tok, target)

        if cfg.AutoLootBoss and self.CollectLoot then
            pcall(function() self:CollectLoot(target.cf.Position, 200) end)
        end
        task.wait(retry)
    end
end

-- ============ UI ============
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
        Text = "Crow Slot",
        Values = { "1", "2", "3", "4", "5" },
        Default = "5",
        Callback = function(v) CrowQuest.Cfg.CrowSlot = tonumber(v) or 5 end,
    })
    window:AddDropdown(crowGB, "_CrowWeapSlot", {
        Text = "Weapon Slot",
        Values = { "1", "2", "3", "4", "5" },
        Default = "1",
        Callback = function(v) CrowQuest.Cfg.WeaponSlot = tonumber(v) or 1 end,
    })
    window:AddDropdown(crowGB, "_CrowPriority", {
        Text = "Priority",
        Values = { "HighestExp", "HighestLevel", "Random" },
        Default = "HighestExp",
        Callback = function(v) CrowQuest.Cfg.Priority = v end,
    })
    window:AddSlider(crowGB, "_CrowRetry", {
        Text = "Retry Delay",
        Min = 0.5, Max = 10, Default = 2.0, Decimals = 1,
        Callback = function(v) CrowQuest.Cfg.RetryDelay = v end,
    })
    window:AddToggle(crowGB, "_CrowAutoLoot", {
        Text = "Auto Loot Boss",
        Default = false,
        Callback = function(on) CrowQuest.Cfg.AutoLootBoss = on end,
    })
    log("[Crow] UI added")
end)

print("[ToRung/CROW] Delta-ready loaded")
