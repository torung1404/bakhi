-- crow.lua - v5 (multi-pos click + debug + safe BossData)
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[Crow] core missing") end
if not S2.Features then return warn("[Crow] features missing") end

local Runtime = S2.Core.Runtime
local GameAPI = S2.Core.GameAPI
local Combat = S2.Core.Combat
local log = S2.Core.log

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")

local CrowQuest = S2.Features.CrowQuest
if not CrowQuest then return warn("[Crow] no CrowQuest table") end

-- ============ FIX 1: Fallback BossData nếu features.lua rỗng ============
if not CrowQuest.BossData or #CrowQuest.BossData == 0 then
    warn("[Crow] CrowQuest.BossData empty! Creating fallback...")
    CrowQuest.BossData = {
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
    }
    log("[Crow] fallback BossData: " .. #CrowQuest.BossData .. " bosses")
end

CrowQuest.Cfg = {
    CrowSlot = 5,
    WeaponSlot = 1,
    Priority = "HighestExp",
    MaxHuntLevel = 125,
    RetryDelay = 2.0,
    CrowCooldown = 5.0,
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

-- FIX 3: match cả "Defeat X" và "Defeat Boss X" + "Defeat  X" (nhiều space)
local function findBossByText(text)
    if not text or type(text) ~= "string" then return nil end
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

-- FIX 2: walk-up Visible check
local function isVisibleChain(obj)
    local p = obj
    for _ = 1, 10 do
        if not p then return true end
        local okV, v = pcall(function() return p.Visible end)
        if okV and v == false then return false end
        p = p.Parent
    end
    return true
end

-- ============ Slot switching ============
local SLOT_VK = { 49, 50, 51, 52, 53 }
local SLOT_KC = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

local function equipSlot(slotNum)
    slotNum = math.clamp(tonumber(slotNum) or 1, 1, 5)

    if type(keypress) == "function" then
        local vk = SLOT_VK[slotNum]
        pcall(function()
            if type(keyrelease) == "function" then keyrelease(vk) end
            keypress(vk)
            task.wait(0.15)
            if type(keyrelease) == "function" then keyrelease(vk) end
        end)
        log("[Crow] slot " .. slotNum .. " via keypress(" .. vk .. ")")
        return true
    end

    local kc = SLOT_KC[slotNum]
    if kc then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, kc, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, kc, false, game)
        end)
        log("[Crow] slot " .. slotNum .. " via VIM")
        return true
    end
    return false
end

-- ============ FIX 4: Click crow at multiple positions ============
local function clickCrow()
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local mouse = LP:GetMouse()

    -- Crow flies from character → try center, then a few offsets
    local positions = {
        { vs.X * 0.5, vs.Y * 0.5 },
        { vs.X * 0.5, vs.Y * 0.4 },
        { vs.X * 0.6, vs.Y * 0.45 },
        { vs.X * 0.4, vs.Y * 0.45 },
        { vs.X * 0.75, vs.Y * 0.5 },
    }

    for i, p in ipairs(positions) do
        if mouse and type(mousemoverel) == "function" then
            pcall(function()
                mousemoverel(p[1] - mouse.X, p[2] - mouse.Y)
            end)
            task.wait(0.15)
        end

        if type(mouse1click) == "function" then
            pcall(mouse1click)
        elseif type(mouse1press) == "function" then
            pcall(function()
                mouse1press()
                task.wait(0.08)
                if type(mouse1release) == "function" then mouse1release() end
            end)
        else
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(p[1], p[2], 0, true, game, 0)
                task.wait(0.08)
                VirtualInputManager:SendMouseButtonEvent(p[1], p[2], 0, false, game, 0)
            end)
        end
        log("[Crow] click #" .. i .. " at " .. math.floor(p[1]) .. "," .. math.floor(p[2]))
        task.wait(0.35)
    end
end

-- ============ ScanMenu with debug ============
function CrowQuest:ScanMenu()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return {} end

    local choices = {}
    local seen = {}
    local defeatCount = 0
    local visibleCount = 0
    local matchedCount = 0

    for _, d in ipairs(pg:GetDescendants()) do
        if not (d:IsA("TextLabel") or d:IsA("TextButton")) then continue end
        local txt = d.Text or ""
        if not txt:find("Defeat", 1, true) then continue end
        defeatCount = defeatCount + 1

        -- FIX 2: check ancestor visibility
        if not isVisibleChain(d) then continue end
        visibleCount = visibleCount + 1

        local bossData = findBossByText(txt)
        if not bossData then continue end
        matchedCount = matchedCount + 1

        -- Container
        local frame = d
        for _ = 1, 6 do
            if not frame or not frame.Parent then break end
            frame = frame.Parent
            if frame:IsA("Frame") then
                local okS, sz = pcall(function() return frame.AbsoluteSize end)
                if okS and sz and sz.X >= 100 and sz.Y >= 40 then break end
            end
        end
        if not frame then continue end

        -- Dedupe
        local okP, ap = pcall(function() return d.AbsolutePosition end)
        if not okP or not ap then continue end
        local key = bossData.name .. "@" .. math.floor(ap.Y / 30)
        if seen[key] then continue end
        seen[key] = true

        -- Parse exp/wen from container's grandparent (HuntN frame)
        local parseRoot = frame
        for _ = 1, 2 do
            if parseRoot and parseRoot.Parent and parseRoot.Parent:IsA("Frame") then
                parseRoot = parseRoot.Parent
            end
        end
        local allNums = {}
        for _, x in ipairs(parseRoot:GetDescendants()) do
            if x:IsA("TextLabel") or x:IsA("TextButton") then
                for numStr in (x.Text or ""):gmatch("([%d,]+)") do
                    local n = tonumber(numStr:gsub(",", ""))
                    if n and n >= 100 then table.insert(allNums, n) end
                end
            end
        end
        table.sort(allNums, function(a, b) return a > b end)
        local exp, wen = 0, 0
        for _, n in ipairs(allNums) do
            if n >= 1000 and exp == 0 then exp = n
            elseif n >= 100 and n < 10000 and wen == 0 and n ~= exp then wen = n end
        end

        local cx = ap.X + (d.AbsoluteSize.X or 100) * 0.5
        local cy = ap.Y + (d.AbsoluteSize.Y or 20) * 0.5

        table.insert(choices, {
            Boss = bossData, Exp = exp, Wen = wen,
            Frame = frame, Label = d,
            X = cx, Y = cy,
        })
    end

    -- Debug output (chỉ log khi có Defeat nhưng scan fail)
    if defeatCount > 0 and #choices == 0 then
        log("[Crow] DEBUG: Defeat=" .. defeatCount .. " visible=" .. visibleCount .. " matched=" .. matchedCount .. " choices=0")
        -- Log first few texts
        local n = 0
        for _, d in ipairs(pg:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text:find("Defeat", 1, true) then
                n = n + 1
                if n <= 3 then
                    log("[Crow] DEBUG text: '" .. d.Text .. "' vis=" .. tostring(d.Visible))
                end
            end
        end
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

-- ============ Click mission ============
local function clickMission(choice)
    local mouse = LP:GetMouse()
    if mouse and type(mousemoverel) == "function" then
        pcall(function()
            mousemoverel(choice.X - mouse.X, choice.Y - mouse.Y)
        end)
        task.wait(0.2)
    end

    if type(mouse1click) == "function" then
        pcall(mouse1click)
    end
    task.wait(0.1)
    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        pcall(function()
            mouse1press()
            task.wait(0.08)
            mouse1release()
        end)
    end
    task.wait(0.1)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(choice.X, choice.Y, 0, true, game, 0)
        task.wait(0.08)
        VirtualInputManager:SendMouseButtonEvent(choice.X, choice.Y, 0, false, game, 0)
    end)

    log("[Crow] mission clicked at " .. math.floor(choice.X) .. "," .. math.floor(choice.Y))
end

-- ============ Wait ============
local function waitFor(tok, pred, timeout)
    local t = 0
    while tok.Active and Runtime.Alive and t < timeout do
        local ok, r = pcall(pred)
        if ok and r then return true end
        task.wait(0.25)
        t = t + 0.25
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
    local cooldown = tonumber(cfg.CrowCooldown) or 5.0
    local lastCrowUse = -999

    while tok.Active and Runtime.Alive do
        local existing = getActiveQuestBoss()
        if existing then
            log("[Crow] continuing quest: " .. existing.name)
            self:FightBoss(tok, existing)
            task.wait(retry)
            continue
        end

        local choices = self:ScanMenu()

        if #choices == 0 then
            local now = os.clock()
            local elapsed = now - lastCrowUse
            if elapsed < cooldown then
                local wait = cooldown - elapsed
                log("[Crow] cooldown: " .. string.format("%.1f", wait) .. "s")
                task.wait(wait)
            end

            log("[Crow] equipping crow slot " .. tostring(cfg.CrowSlot))
            equipSlot(cfg.CrowSlot)
            lastCrowUse = os.clock()
            task.wait(0.7)

            clickCrow()

            local gotMenu = waitFor(tok, function()
                return #self:ScanMenu() > 0
            end, 15)

            if not gotMenu then
                log("[Crow] no menu after 15s, retry")
                task.wait(retry)
                continue
            end
            choices = self:ScanMenu()
        else
            log("[Crow] menu already open, " .. #choices .. " missions")
        end

        log("[Crow] scanned " .. #choices .. " missions")
        for _, c in ipairs(choices) do
            log("  -> " .. c.Boss.name .. " | Exp=" .. c.Exp .. " | Wen=" .. c.Wen)
        end

        local best = self:PickBestMission(choices)
        if not best then
            log("[Crow] no valid pick")
            task.wait(retry)
            continue
        end

        log("[Crow] picking: " .. best.Boss.name .. " (Exp=" .. best.Exp .. ")")
        clickMission(best)
        task.wait(1)

        local gotQuest = waitFor(tok, function()
            return getActiveQuestBoss() ~= nil
        end, 12)

        if not gotQuest then
            log("[Crow] quest not registered, retry")
            task.wait(retry)
            continue
        end

        local actual = getActiveQuestBoss()
        local target = actual or best.Boss
        log("[Crow] quest active: " .. target.name .. " — switch to weapon slot " .. tostring(cfg.WeaponSlot))
        task.wait(0.3)
        equipSlot(cfg.WeaponSlot)
        task.wait(0.4)

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
    window:AddSlider(crowGB, "_CrowCd", {
        Text = "Crow Cooldown",
        Min = 1, Max = 15, Default = 5.0, Decimals = 1,
        Callback = function(v) CrowQuest.Cfg.CrowCooldown = v end,
    })
    window:AddToggle(crowGB, "_CrowAutoLoot", {
        Text = "Auto Loot Boss",
        Default = false,
        Callback = function(on) CrowQuest.Cfg.AutoLootBoss = on end,
    })
    log("[Crow] UI added")
end)

print("[ToRung/CROW] v5.0 | multi-click + walk-vis + debug")
