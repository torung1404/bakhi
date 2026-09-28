-- crow.lua - Crow Quest v3.1 (scan-all + cooldown + hold-T + safe-weapon-swap)
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

-- ============ Equip ============
local function equipSlot(slotNum)
    slotNum = math.clamp(tonumber(slotNum) or 1, 1, 5)
    local ok = pcall(function()
        local items = LP:FindFirstChild("Items_Config")
        if items and items:FindFirstChild("Equipped") then
            items.Equipped.Value = slotNum
        end
    end)
    if ok then log("[Crow] equipped slot " .. slotNum)
    else log("[Crow] equip failed slot " .. slotNum) end
    return ok
end

local function clickCenter()
    local vu = game:GetService("VirtualUser")
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
    pcall(function()
        vu:CaptureController()
        vu:ClickButton1(Vector2.new(vs.X * 0.5, vs.Y * 0.5))
        vu:ReleaseController()
    end)
end

-- ============ Hold T ============
local VirtualInputManager = game:GetService("VirtualInputManager")
local function holdT(duration)
    duration = tonumber(duration) or 2.0
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.T, false, game)
    end)
    task.wait(duration)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.T, false, game)
    end)
end

-- ============ ScanMenu ============
function CrowQuest:ScanMenu()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return {} end

    local choices = {}
    local seen = {}

    for _, d in ipairs(pg:GetDescendants()) do
        if not (d:IsA("TextLabel") or d:IsA("TextButton")) then continue end
        local txt = d.Text or ""
        if not txt:find("Defeat", 1, true) then continue end

        local bossData = findBossByText(txt)
        if not bossData then continue end

        local okV, vis = pcall(function() return d.Visible end)
        if okV and not vis then continue end

        local frame = d
        for _ = 1, 6 do
            if not frame or not frame.Parent then break end
            frame = frame.Parent
            if frame:IsA("Frame") then
                local okS, sz = pcall(function() return frame.AbsoluteSize end)
                if okS and sz and sz.X >= 200 and sz.Y >= 40 then break end
            end
        end
        if not frame then continue end

        local okP, ap = pcall(function() return d.AbsolutePosition end)
        if not okP or not ap then continue end
        local key = bossData.name .. "@" .. math.floor(ap.Y / 30)
        if seen[key] then continue end
        seen[key] = true

        local allNums = {}
        for _, x in ipairs(frame:GetDescendants()) do
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

        local btn = d
        for _ = 1, 6 do
            if not btn then break end
            if btn:IsA("TextButton") or btn:IsA("ImageButton") then break end
            btn = btn.Parent
        end
        if not btn then btn = d end

        local okB, bap = pcall(function() return btn.AbsolutePosition end)
        local okBS, bas = pcall(function() return btn.AbsoluteSize end)
        local bx = (okB and bap and bap.X or ap.X) + (okBS and bas and bas.X * 0.5 or 100)
        local by = (okB and bap and bap.Y or ap.Y) + (okBS and bas and bas.Y * 0.5 or 20)

        table.insert(choices, {
            Boss = bossData, Exp = exp, Wen = wen,
            Button = btn, Frame = frame,
            X = bx, Y = by,
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
        pcall(firesignal, choice.Button.MouseButton1Click)
    end
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton1(Vector2.new(choice.X, choice.Y))
        vu:ReleaseController()
    end)
    log("[Crow] clicked at " .. math.floor(choice.X) .. "," .. math.floor(choice.Y))
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

-- ============ OVERRIDE CollectLoot ============
function CrowQuest:CollectLoot(position, radius)
    radius = radius or 200
    local CS = game:GetService("CollectionService")
    local r = GameAPI:GetRoot()
    if not r then return end

    task.wait(1.5)

    for _ = 1, 3 do
        local foundAny = false

        pcall(function()
            for _, obj in ipairs(CS:GetTagged("LootDrop")) do
                if not self.Active then return end
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part and (part.Position - position).Magnitude < radius then
                    foundAny = true
                    r.CFrame = part.CFrame * CFrame.new(0, 0, 2)
                    r.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.2)
                    holdT(0.3)
                    for _, desc in ipairs(obj:GetDescendants()) do
                        if desc:IsA("ProximityPrompt") and desc.Enabled then
                            pcall(fireproximityprompt, desc)
                        end
                    end
                    task.wait(0.4)
                end
            end
        end)

        pcall(function()
            for _, obj in ipairs(CS:GetTagged("Chest")) do
                if not self.Active then return end
                local rootPart = obj:FindFirstChild("RootPart") or obj:FindFirstChildWhichIsA("BasePart")
                if rootPart and (rootPart.Position - position).Magnitude < radius then
                    foundAny = true
                    r.CFrame = rootPart.CFrame * CFrame.new(0, 0, 3)
                    r.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.4)
                    holdT(2.0)
                    task.wait(0.5)
                end
            end
        end)

        pcall(function()
            local ld = workspace:FindFirstChild("LootDrops")
            if not ld then return end
            for _, child in ipairs(ld:GetChildren()) do
                if not self.Active then return end
                local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
                if part and (part.Position - position).Magnitude < radius then
                    foundAny = true
                    r.CFrame = part.CFrame * CFrame.new(0, 0, 2)
                    r.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.2)
                    holdT(0.4)
                    for _, desc in ipairs(child:GetDescendants()) do
                        if desc:IsA("ProximityPrompt") then
                            pcall(fireproximityprompt, desc)
                        end
                    end
                    task.wait(0.3)
                end
            end
        end)

        pcall(function()
            local ch = workspace:FindFirstChild("Chests")
            if not ch then return end
            for _, child in ipairs(ch:GetChildren()) do
                if not self.Active then return end
                local rootPart = child:FindFirstChild("RootPart") or child:FindFirstChildWhichIsA("BasePart")
                if rootPart and (rootPart.Position - position).Magnitude < radius then
                    foundAny = true
                    r.CFrame = rootPart.CFrame * CFrame.new(0, 0, 3)
                    r.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.4)
                    holdT(2.0)
                    task.wait(0.5)
                end
            end
        end)

        pcall(function()
            local db = workspace:FindFirstChild("Debree")
            if not db then return end
            for _, child in ipairs(db:GetChildren()) do
                if not self.Active then return end
                local name = child.Name:lower()
                if name:find("loot") or name:find("drop") or name:find("chest") or name:find("reward") then
                    local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
                    if part and (part.Position - position).Magnitude < radius then
                        foundAny = true
                        r.CFrame = part.CFrame * CFrame.new(0, 0, 2)
                        r.AssemblyLinearVelocity = Vector3.zero
                        task.wait(0.3)
                        holdT(1.5)
                        for _, desc in ipairs(child:GetDescendants()) do
                            if desc:IsA("ProximityPrompt") and desc.Enabled then
                                pcall(fireproximityprompt, desc)
                            end
                        end
                        task.wait(0.4)
                    end
                end
            end
        end)

        if not foundAny then break end
        task.wait(0.5)
    end
    log("[Crow] loot collected")
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

-- ============ Run ============
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

            log("[Crow] summoning crow (slot " .. tostring(cfg.CrowSlot) .. ")")
            equipSlot(cfg.CrowSlot)
            lastCrowUse = os.clock()
            task.wait(0.5)
            clickCenter()
            log("[Crow] clicked center to summon")

            local gotMenu = waitFor(tok, function()
                return #self:ScanMenu() > 0
            end, 8)

            if not gotMenu then
                log("[Crow] no menu, retry")
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
        end, 10)

        if not gotQuest then
            log("[Crow] quest not registered, retry (weapon unchanged)")
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

print("[ToRung/CROW] v3.1 | scan-all + cooldown + hold-T + safe-weapon-swap")
