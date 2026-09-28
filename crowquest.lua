-- crowquest.lua - Crow Quest rewrite for ToRung HUB
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

-- ============ Menu scanner ============
local function getDialogueFrame()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local holder = pg:FindFirstChild("ComponentsHolder")
    if not holder then return nil end
    local frame = holder:FindFirstChild("DialogueFrame")
    if not frame then return nil end
    return frame
end

local function parseExpFromText(text)
    if not text then return 0 end
    local s = text:gsub(",", "")
    local n = tonumber(s:match("(%d+)"))
    return n or 0
end

-- Scan current menu, return list of mission frames
function CrowQuest:ScanMenu()
    local df = getDialogueFrame()
    if not df then return {} end
    local actual = df:FindFirstChild("Actual")
    if not actual then return {} end

    -- Primary path: ButtonHolder with mission frames
    local bh = actual:FindFirstChild("ButtonHolder")
    local choices = {}
    if bh then
        for _, frame in ipairs(bh:GetChildren()) do
            if frame:IsA("Frame") then
                local tb = frame:FindFirstChild("TextButton")
                local btn = tb or frame

                -- Extract boss name from descendant text
                local bossName = nil
                local exp = 0
                local level = 0
                local fullText = ""

                for _, d in ipairs(frame:GetDescendants()) do
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        local txt = d.Text or ""
                        fullText = fullText .. " " .. txt
                        if txt:find("Defeat", 1, true) then
                            local b = findBossByText(txt)
                            if b then bossName = b end
                        end
                        -- Extract exp (number before multiplier or in standalone)
                        local e = txt:match("([%d,]+)%s*%(")
                        if e and e:len() > 2 then
                            exp = math.max(exp, parseExpFromText(e))
                        end
                        -- Extract level from text
                        local lv = txt:match("Lv%s*(%d+)")
                        if lv then level = tonumber(lv) or 0 end
                    end
                end

                if not bossName then
                    local b = findBossByText(fullText)
                    if b then bossName = b end
                end

                if bossName then
                    local ap = btn.AbsolutePosition or Vector2.new(0, 0)
                    local as = btn.AbsoluteSize or Vector2.new(100, 30)
                    choices[#choices + 1] = {
                        Boss = bossName,
                        Exp = exp,
                        Level = level,
                        Button = btn,
                        Frame = frame,
                        X = ap.X + as.X * 0.5,
                        Y = ap.Y + as.Y * 0.5,
                    }
                end
            end
        end
    end

    -- Fallback: scan whole PlayerGui for TextButtons with "Defeat"
    if #choices == 0 then
        local pg = LP:FindFirstChild("PlayerGui")
        if pg then
            for _, d in ipairs(pg:GetDescendants()) do
                if d:IsA("TextButton") or d:IsA("TextLabel") then
                    local txt = d.Text or ""
                    if txt:find("Defeat", 1, true) then
                        local b = findBossByText(txt)
                        if b then
                            local ap = d.AbsolutePosition or Vector2.new(0, 0)
                            local as = d.AbsoluteSize or Vector2.new(100, 30)
                            choices[#choices + 1] = {
                                Boss = b,
                                Exp = parseExpFromText(txt),
                                Level = 0,
                                Button = d,
                                Frame = d.Parent,
                                X = ap.X + as.X * 0.5,
                                Y = ap.Y + as.Y * 0.5,
                            }
                        end
                    end
                end
            end
        end
    end

    return choices
end

-- ============ Pick best mission ============
function CrowQuest:PickBestMission(choices)
    local cfg = self.Cfg
    local maxLvl = tonumber(cfg.MaxHuntLevel) or 125
    local priority = cfg.Priority or "HighestExp"

    local valid = {}
    for _, c in ipairs(choices) do
        if c.Level == 0 or c.Level <= maxLvl then
            table.insert(valid, c)
        end
    end

    if #valid == 0 then return nil end
    if priority == "Random" then
        return valid[math.random(1, #valid)]
    end

    table.sort(valid, function(a, b)
        if priority == "HighestExp" then
            if a.Exp ~= b.Exp then return a.Exp > b.Exp end
            return a.Level > b.Level
        else -- HighestLevel
            if a.Level ~= b.Level then return a.Level > b.Level end
            return a.Exp > b.Exp
        end
    end)

    return valid[1]
end

-- ============ Click mission ============
local function clickAt(x, y)
    -- Try "=" key first
    if keypress and Enum.KeyCode.Equals then
        -- Move mouse to position then press "="
        if mousemoverel then
            local mouse = LP:GetMouse()
            if mouse then
                local dx = x - mouse.X
                local dy = y - mouse.Y
                pcall(function()
                    if setrobloxinput then setrobloxinput(true) end
                    mousemoverel(dx, dy)
                end)
                task.wait(0.05)
            end
        end
        pcall(function() keypress(Enum.KeyCode.Equals) end)
        task.wait(0.08)
        pcall(function() keyrelease(Enum.KeyCode.Equals) end)
        return
    end

    -- Fallback: virtual click
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton1(Vector2.new(x, y))
        vu:ReleaseController()
    end)
end

-- ============ Wait helpers ============
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

-- ============ New Run ============
function CrowQuest:Run(tok)
    local cfg = self.Cfg
    local retry = tonumber(cfg.RetryDelay) or 2.0

    while tok.Active and Runtime.Alive do
        -- ============ PHASE 0: Check existing quest ============
        local existing, existingQuest = getActiveQuestBoss()
        if existing then
            log("[Crow] already have quest:", existing.name)
            -- jump to fight phase
            local ok = self:FightBoss(tok, existing)
            if ok then
                task.wait(retry)
                continue
            end
        end

        -- ============ PHASE 1: Summon crow ============
        log("[Crow] summoning crow (slot " .. tostring(cfg.CrowSlot) .. ")")
        pressSlot(cfg.CrowSlot)

        -- Wait for menu
        local gotMenu = waitFor(tok, function()
            local choices = self:ScanMenu()
            return #choices > 0
        end, 8)

        if not gotMenu then
            log("[Crow] menu didn't appear, retry in " .. tostring(retry) .. "s")
            pressSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        -- ============ PHASE 2: Pick best mission ============
        local choices = self:ScanMenu()
        log("[Crow] scanned " .. tostring(#choices) .. " missions")

        local best = self:PickBestMission(choices)
        if not best then
            log("[Crow] no valid mission - retry")
            pressSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        log("[Crow] picking:", best.Boss.name, "Exp=" .. best.Exp, "Lv=" .. best.Level)
        clickAt(best.X, best.Y)
        task.wait(0.8)

        -- ============ PHASE 3: Wait for quest active ============
        local targetBoss = best.Boss
        local gotQuest = waitFor(tok, function()
            local b = getActiveQuestBoss()
            return b ~= nil
        end, 10)

        if not gotQuest then
            log("[Crow] quest didn't register, retry")
            pressSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        -- Re-read actual target
        local actual, _ = getActiveQuestBoss()
        if actual then targetBoss = actual end
        log("[Crow] quest active:", targetBoss.name)

        -- ============ PHASE 4: Switch to weapon ============
        task.wait(0.4)
        pressSlot(cfg.WeaponSlot)
        task.wait(0.3)

        -- ============ PHASE 5: Fight boss ============
        local fightOk = self:FightBoss(tok, targetBoss)
        if not fightOk then
            log("[Crow] fight failed, retry")
        end

        -- ============ PHASE 6: Loot (if enabled) ============
        if cfg.AutoLootBoss and self.CollectLoot then
            pcall(function() self:CollectLoot(targetBoss.cf.Position, 200) end)
        end

        -- ============ PHASE 7: Turn in + wait ============
        task.wait(retry)
    end
end

-- ============ Fight boss ============
function CrowQuest:FightBoss(tok, boss)
    -- TP to boss spawn
    if boss.cf then
        GameAPI:Teleport(boss.cf + Vector3.new(0, 3, 0))
        task.wait(0.5)
    end

    local deathTimer = 0
    while tok.Active and Runtime.Alive do
        -- Check quest complete
        local active = getActiveQuestBoss()
        if not active then
            log("[Crow] quest done")
            return true
        end

        -- Check death
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            deathTimer = deathTimer + 0.5
            if deathTimer > 10 then
                log("[Crow] player dead too long, abort fight")
                return false
            end
            task.wait(0.5)
            continue
        end
        deathTimer = 0

        -- Find boss model
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then task.wait(0.3); continue end

        local bossModel = nil
        if self.FindMob then
            bossModel = self:FindMob(boss.name, root.Position, 500)
        end

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
            -- Boss not found, TP to spawn and wait
            if boss.cf then
                GameAPI:Teleport(boss.cf + Vector3.new(0, 3, 0))
            end
            task.wait(1)
        end

        task.wait(0.3)
    end

    return false
end

-- ============ UI Settings ============
task.spawn(function()
    task.wait(1)
    local window = S2.UI and S2.UI.Window
    if not window then return end

    -- Find Quests tab
    local questTab = nil
    for _, tab in ipairs(window.Tabs) do
        if tab.Name == "Quests" then questTab = tab break end
    end
    if not questTab then
        warn("[Crow] no Quests tab found")
        return
    end

    local Themes = S2.UI.Themes
    local crowGB = window:AddGroupbox(questTab, "Crow Quest")

    window:AddDropdown(crowGB, "_CrowSlot", {
        Text = "Crow Tool Slot",
        Description = "Which toolbar slot holds your crow item",
        Values = { "1", "2", "3", "4", "5" },
        Default = tostring(CrowQuest.Cfg.CrowSlot or 3),
        Callback = function(v)
            CrowQuest.Cfg.CrowSlot = tonumber(v) or 3
        end,
    })

    window:AddDropdown(crowGB, "_CrowWeapSlot", {
        Text = "Weapon Slot",
        Description = "Which toolbar slot holds your main weapon",
        Values = { "1", "2", "3", "4", "5" },
        Default = tostring(CrowQuest.Cfg.WeaponSlot or 1),
        Callback = function(v)
            CrowQuest.Cfg.WeaponSlot = tonumber(v) or 1
        end,
    })

    window:AddDropdown(crowGB, "_CrowPriority", {
        Text = "Priority Mode",
        Description = "Which mission to pick from the crow menu",
        Values = { "HighestExp", "HighestLevel", "Random" },
        Default = CrowQuest.Cfg.Priority or "HighestExp",
        Callback = function(v)
            CrowQuest.Cfg.Priority = v or "HighestExp"
        end,
    })

    window:AddSlider(crowGB, "_CrowMaxLvl", {
        Text = "Max Hunt Level",
        Description = "Skip missions above this level",
        Min = 1, Max = 200, Default = CrowQuest.Cfg.MaxHuntLevel or 125,
        Callback = function(v)
            CrowQuest.Cfg.MaxHuntLevel = v
        end,
    })

    window:AddSlider(crowGB, "_CrowRetry", {
        Text = "Retry Delay",
        Description = "Wait time between crow cycles (seconds)",
        Min = 0.5, Max = 10, Default = CrowQuest.Cfg.RetryDelay or 2.0,
        Decimals = 1,
        Callback = function(v)
            CrowQuest.Cfg.RetryDelay = v
        end,
    })

    window:AddToggle(crowGB, "_CrowAutoLoot", {
        Text = "Auto Loot Boss",
        Description = "Auto-collect chests and items after boss dies",
        Default = CrowQuest.Cfg.AutoLootBoss or false,
        Callback = function(on)
            CrowQuest.Cfg.AutoLootBoss = on and true or false
        end,
    })

    log("[Crow] UI settings added")
end)

print("[ToRung/CROW] rewrite loaded")
