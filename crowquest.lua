-- crowquest.lua - Crow Quest v5 (added mouse click for summon)
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[Crow] core missing") end
if not S2.Features then return warn("[Crow] features missing") end

local Runtime = S2.Core.Runtime
local GameAPI = S2.Core.GameAPI
local Combat = S2.Core.Combat
local log = S2.Core.log

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local CrowQuest = S2.Features.CrowQuest
if not CrowQuest then return warn("[Crow] no CrowQuest table") end

CrowQuest.Cfg = CrowQuest.Cfg or {
    CrowSlot = 3, WeaponSlot = 1, Priority = "HighestExp",
    MaxHuntLevel = 125, RetryDelay = 2.0, AutoLootBoss = false,
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

local function pressSlot(slot)
    if not keypress or not keyrelease then return end
    slot = math.clamp(tonumber(slot) or 1, 1, 5)
    local vk = 48 + slot
    pcall(function()
        if setrobloxinput then setrobloxinput(true) end
        keyrelease(vk)
        task.wait(0.05)
        keypress(vk)
        task.wait(0.1)
        keyrelease(vk)
    end)
    log("[Crow] pressed slot " .. slot)
end

-- FIX: thêm mouse click sau keypress
local function summonCrow(slot)
    pressSlot(slot)
    task.wait(0.5)

    pcall(function()
        if setrobloxinput then setrobloxinput(true) end
        if mouse1click then
            mouse1click()
        elseif mouse1press and mouse1release then
            mouse1press()
            task.wait(0.06)
            mouse1release()
        else
            local vu = game:GetService("VirtualUser")
            local cam = workspace.CurrentCamera
            vu:CaptureController()
            vu:ClickButton1(Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5))
            vu:ReleaseController()
        end
    end)
    log("[Crow] clicked to summon")
    task.wait(0.6)
end

-- ============ Menu scanner ============
local function getDialogueFrame()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local holder = pg:FindFirstChild("ComponentsHolder")
    if not holder then return nil end
    return holder:FindFirstChild("DialogueFrame")
end

local function parseNumbers(text)
    local nums = {}
    if not text then return nums end
    for numStr in text:gmatch("([%d,]+)") do
        local clean = numStr:gsub(",", "")
        local n = tonumber(clean)
        if n and n > 0 then table.insert(nums, n) end
    end
    return nums
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
        if not frame:IsA("Frame") then continue end

        local btn = frame:FindFirstChild("TextButton") or frame
        local bossName = nil
        local fullText = ""
        for _, d in ipairs(frame:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = d.Text or ""
                fullText = fullText .. " " .. t
                if not bossName and t:find("Defeat", 1, true) then
                    local b = findBossByText(t)
                    if b then bossName = b end
                end
            end
        end
        if not bossName then
            local b = findBossByText(fullText)
            if b then bossName = b end
        end
        if not bossName then continue end

        local allNums = {}
        for _, d in ipairs(frame:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                for _, v in ipairs(parseNumbers(d.Text)) do
                    table.insert(allNums, v)
                end
            end
        end
        table.sort(allNums, function(a, b) return a > b end)
        local exp, wen = 0, 0
        for _, n in ipairs(allNums) do
            if n >= 1000 and exp == 0 then
                exp = n
            elseif n >= 100 and n < 10000 and wen == 0 and n ~= exp then
                wen = n
            end
        end

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

local function clickMission(choice)
    if choice.Button and firesignal then
        local ok = pcall(firesignal, choice.Button.MouseButton1Click)
        if ok then
            log("[Crow] clicked via firesignal")
            return true
        end
    end
    local mouse = LP:GetMouse()
    if mouse and mousemoverel then
        pcall(function()
            if setrobloxinput then setrobloxinput(true) end
            mousemoverel(choice.X - mouse.X, choice.Y - mouse.Y)
        end)
        task.wait(0.15)
        if mouse1click then
            pcall(function()
                if setrobloxinput then setrobloxinput(true) end
                mouse1click()
            end)
            log("[Crow] clicked via mouse1click")
            return true
        end
    end
    return false
end

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

        -- FIX: dùng summonCrow (keypress + click)
        log("[Crow] summoning crow (slot " .. tostring(cfg.CrowSlot) .. ")")
        summonCrow(cfg.CrowSlot)

        local gotMenu = waitFor(tok, function()
            return #self:ScanMenu() > 0
        end, 8)

        if not gotMenu then
            log("[Crow] no menu, retry")
            pressSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        local choices = self:ScanMenu()
        log("[Crow] scanned " .. #choices .. " missions")
        for _, c in ipairs(choices) do
            log("  -> " .. c.Boss.name .. " | Exp=" .. c.Exp .. " | Wen=" .. c.Wen)
        end

        local best = self:PickBestMission(choices)
        if not best then
            log("[Crow] no valid pick")
            pressSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        log("[Crow] picking: " .. best.Boss.name .. " (Exp=" .. best.Exp .. ")")
        clickMission(best)
        task.wait(0.8)

        local gotQuest = waitFor(tok, function()
            return getActiveQuestBoss() ~= nil
        end, 10)

        if not gotQuest then
            log("[Crow] quest didn't register, retry")
            pressSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        local actual = getActiveQuestBoss()
        local target = actual or best.Boss
        log("[Crow] quest active: " .. target.name)

        task.wait(0.4)
        pressSlot(cfg.WeaponSlot)
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
        Text = "Priority",
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

print("[ToRung/CROW] v5 loaded")
