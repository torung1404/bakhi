-- crow.lua - v6 (single-click + correct parse + timeout + quest-confirm)
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[Crow] core missing") end
if not S2.Features then return warn("[Crow] features missing") end

local Runtime = S2.Core.Runtime
local GameAPI = S2.Core.GameAPI
local Combat = S2.Core.Combat
local log = S2.Core.log

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local CrowQuest = S2.Features.CrowQuest
if not CrowQuest then return warn("[Crow] no CrowQuest table") end

-- FIX #8: KHÔNG overwrite BossData — chỉ fallback nếu rỗng
if type(CrowQuest.BossData) ~= "table" or #CrowQuest.BossData == 0 then
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
    log("[Crow] fallback BossData installed")
end

-- FIX #8: merge config, không overwrite
CrowQuest.Cfg = CrowQuest.Cfg or {}
local function getCfg(key, default) 
    local v = CrowQuest.Cfg[key]
    if v == nil then CrowQuest.Cfg[key] = default; return default end
    return v
end

getCfg("CrowSlot", 5)
getCfg("WeaponSlot", 1)
getCfg("Priority", "HighestExp")
getCfg("MaxHuntLevel", 125)
getCfg("RetryDelay", 2.0)
getCfg("CrowCooldown", 5.0)
getCfg("AutoLootBoss", false)

-- ============ Helpers ============
local function getQuestRuntime()
    local q = S2.Features.QuestEngine
    if not q then return nil end
    local d = q:GetData()
    if not d or not d.Quests or not d.Quests:FindFirstChild("Holder") then return nil end
    return d.Quests.Holder
end

-- Trả về boss + quest_instance (unique object)
local function getActiveQuestBoss()
    local holder = getQuestRuntime()
    if not holder then return nil, nil end
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
    return nil, nil
end

local function findBossByName(name)
    if type(name) ~= "string" then return nil end
    local lower = name:lower()
    for _, b in ipairs(CrowQuest.BossData or {}) do
        if lower:find(b.name:lower(), 1, true) or b.name:lower():find(lower, 1, true) then return b end
    end
    return nil
end

-- FIX #14: check ScreenGui.Enabled + walk up
local function isFullyVisible(obj)
    local p = obj
    for _ = 1, 12 do
        if not p then return true end
        if p:IsA("ScreenGui") then
            local ok, en = pcall(function() return p.Enabled end)
            if ok and en == false then return false end
            return true
        end
        local okV, v = pcall(function() return p.Visible end)
        if okV and v == false then return false end
        p = p.Parent
    end
    return true
end

-- ============ Slot equip (FIX #7) ============
local SLOT_VK = { 49, 50, 51, 52, 53 }
local SLOT_KC = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

local function equipSlot(slotNum)
    slotNum = math.clamp(tonumber(slotNum) or 1, 1, 5)
    local attempted = false

    if type(keypress) == "function" then
        local ok = pcall(function()
            if type(keyrelease) == "function" then keyrelease(SLOT_VK[slotNum]) end
            keypress(SLOT_VK[slotNum])
            task.wait(0.12)
            if type(keyrelease) == "function" then keyrelease(SLOT_VK[slotNum]) end
        end)
        if ok then
            log("[Crow] slot " .. slotNum .. " via keypress")
            return true
        end
        attempted = true
    end

    if VIM and SLOT_KC[slotNum] then
        local ok = pcall(function()
            VIM:SendKeyEvent(true, SLOT_KC[slotNum], false, game)
            task.wait(0.1)
            VIM:SendKeyEvent(false, SLOT_KC[slotNum], false, game)
        end)
        if ok then
            log("[Crow] slot " .. slotNum .. " via VIM")
            return true
        end
        attempted = true
    end

    if not attempted then
        log("[Crow] slot " .. slotNum .. " FAILED (no API)")
    end
    return false
end

-- ============ Mouse helpers ============
local function moveMouseTo(x, y)
    local mouse = LP:GetMouse()
    if not mouse or type(mousemoverel) ~= "function" then return false end
    pcall(function()
        mousemoverel(x - mouse.X, y - mouse.Y)
    end)
    return true
end

-- FIX #1 + #5: 1 click duy nhất
local function singleClick(x, y)
    if x and y then
        if not moveMouseTo(x, y) then
            -- Không move được thì dùng VIM click tại vị trí
            if VIM then
                pcall(function()
                    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
                    task.wait(0.06)
                    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
                end)
                return true
            end
            return false
        end
        task.wait(0.15)
    end

    if type(mouse1click) == "function" then
        pcall(mouse1click)
        return true
    end
    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        pcall(function()
            mouse1press()
            task.wait(0.07)
            mouse1release()
        end)
        return true
    end
    if VIM then
        local cam = workspace.CurrentCamera
        local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local cx, cy = x or vs.X * 0.5, y or vs.Y * 0.5
        pcall(function()
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            task.wait(0.06)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
        end)
        return true
    end
    return false
end

-- ============ ScanMenu (FIX #3 #14) ============
function CrowQuest:ScanMenu(verbose)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return {} end

    local choices = {}
    local seen = {}
    local nDefeat, nVisible, nMatched = 0, 0, 0

    for _, d in ipairs(pg:GetDescendants()) do
        if not (d:IsA("TextLabel") or d:IsA("TextButton")) then continue end
        local txt = d.Text
        if type(txt) ~= "string" or not txt:find("Defeat", 1, true) then continue end
        nDefeat = nDefeat + 1

        if not isFullyVisible(d) then continue end
        nVisible = nVisible + 1

        local bossData = findBossByName(txt)
        if not bossData then continue end
        nMatched = nMatched + 1

        -- Find HuntN (parent chain tối đa 3 cấp đến Frame có size > 100x40)
        local huntFrame = d
        for _ = 1, 4 do
            if not huntFrame or not huntFrame.Parent then break end
            huntFrame = huntFrame.Parent
            if huntFrame:IsA("Frame") then
                local ok, sz = pcall(function() return huntFrame.AbsoluteSize end)
                if ok and sz and sz.X >= 100 and sz.Y >= 40 then break end
            end
        end
        if not huntFrame then continue end

        local okP, ap = pcall(function() return huntFrame.AbsolutePosition end)
        local okS, as = pcall(function() return huntFrame.AbsoluteSize end)
        if not okP or not okS then continue end

        local key = bossData.name .. "@" .. math.floor(ap.Y / 30)
        if seen[key] then continue end
        seen[key] = true

        -- FIX #3: parse exp/wen dựa vào label text cụ thể
        local exp, wen, level = nil, nil, nil
        for _, x in ipairs(huntFrame:GetDescendants()) do
            if x:IsA("TextLabel") or x:IsA("TextButton") then
                local t = x.Text or ""
                -- EXP pattern: "N,NNN (1.25x)" or contains "(1"
                local numMult = t:match("([%d,]+)%s*%(")
                if numMult and not exp then
                    exp = tonumber(numMult:gsub(",", ""))
                end
                -- Level pattern: "Lv 123"
                local lvMatch = t:match("Lv%s*(%d+)")
                if lvMatch then level = tonumber(lvMatch) end
            end
        end
        -- Wen: tìm label số thuần còn lại (>= 100, không phải exp)
        if exp then
            for _, x in ipairs(huntFrame:GetDescendants()) do
                if x:IsA("TextLabel") and x.Text ~= "" then
                    local t = x.Text
                    local clean = t:match("^([%d,]+)$")
                    if clean then
                        local n = tonumber(clean:gsub(",", ""))
                        if n and n >= 100 and n ~= exp and (not wen or n > wen) then
                            wen = n
                        end
                    end
                end
            end
        end

        local cx = ap.X + as.X * 0.5
        local cy = ap.Y + as.Y * 0.5

        table.insert(choices, {
            Boss = bossData, Exp = exp, Wen = wen, Level = level,
            Frame = huntFrame, Label = d,
            X = cx, Y = cy,
        })
    end

    -- FIX #6: log chẩn đoán khi có Defeat nhưng không match
    if verbose or (#choices == 0 and nDefeat > 0) then
        log("[Crow] scan: defeat=" .. nDefeat .. " visible=" .. nVisible
            .. " matched=" .. nMatched .. " picked=" .. #choices)
    end

    return choices
end

-- ============ Pick best (FIX #15 #16) ============
function CrowQuest:PickBestMission(choices)
    if #choices == 0 then return nil end
    local cfg = self.Cfg
    local priority = cfg.Priority or "HighestExp"
    local maxLvl = tonumber(cfg.MaxHuntLevel) or 125

    -- FIX #16: filter MaxHuntLevel
    local valid = {}
    for _, c in ipairs(choices) do
        if not c.Level or c.Level <= maxLvl then
            table.insert(valid, c)
        end
    end
    if #valid == 0 then
        log("[Crow] no mission under Lv" .. maxLvl .. " — using all")
        valid = choices
    end

    if priority == "Random" then
        return valid[math.random(1, #valid)]
    end

    local sorted = {}
    for _, c in ipairs(valid) do table.insert(sorted, c) end

    -- FIX #15: HighestLevel có branch riêng
    if priority == "HighestLevel" then
        table.sort(sorted, function(a, b)
            local la, lb = a.Level or 0, b.Level or 0
            if la ~= lb then return la > lb end
            return (a.Exp or 0) > (b.Exp or 0)
        end)
    else -- HighestExp (default)
        table.sort(sorted, function(a, b)
            local ea, eb = a.Exp or 0, b.Exp or 0
            if ea ~= eb then return ea > eb end
            return (a.Wen or 0) > (b.Wen or 0)
        end)
    end
    return sorted[1]
end

-- FIX #2: 1 click mission + verify menu đóng
local function clickMission(choice)
    local ok = singleClick(choice.X, choice.Y)
    log("[Crow] mission click @ " .. math.floor(choice.X) .. "," .. math.floor(choice.Y)
        .. " ok=" .. tostring(ok))
    return ok
end

-- ============ Wait helpers (FIX #7) ============
local function waitUntil(tok, pred, timeout)
    local deadline = os.clock() + (tonumber(timeout) or 5)
    while tok.Active and Runtime.Alive and os.clock() < deadline do
        local ok, r = pcall(pred)
        if ok and r then return true end
        task.wait(0.2)
    end
    return false
end

-- ============ FightBoss (FIX #5 #9 #10) ============
-- Return: "completed" | "timeout" | "cancelled"
function CrowQuest:FightBoss(tok, boss, questInstance)
    if boss.cf then
        GameAPI:Teleport(boss.cf + Vector3.new(0, 3, 0))
        task.wait(0.5)
    end

    local lastSeen = os.clock()
    local lastProgress = os.clock()
    local lastHealth = nil
    local MAX_NO_BOSS = 30
    local MAX_NO_PROGRESS = 60

    while tok.Active and Runtime.Alive do
        -- FIX #9: chỉ "completed" khi quest thực sự biến mất VÀ instance cũ không còn
        local _, curInstance = getActiveQuestBoss()
        if not curInstance or (questInstance and curInstance ~= questInstance) then
            return "completed"
        end

        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            lastSeen = os.clock()
            task.wait(0.5)
            if os.clock() - lastSeen > 15 then return "timeout" end
            continue
        end

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then task.wait(0.3); continue end

        local bossModel = self.FindMob and self:FindMob(boss.name, root.Position, 500)
        if bossModel then
            lastSeen = os.clock()
            local bossRoot = bossModel:FindFirstChild("HumanoidRootPart")
            local bossHum = bossModel:FindFirstChildOfClass("Humanoid")
            if bossRoot and bossHum then
                -- Track HP progress
                if lastHealth and bossHum.Health < lastHealth - 1 then
                    lastProgress = os.clock()
                end
                lastHealth = bossHum.Health

                root.CFrame = CFrame.lookAt(bossRoot.Position - Vector3.new(0, 6.5, 0), bossRoot.Position)
                root.AssemblyLinearVelocity = Vector3.zero
                Combat:Swing("Combat")
            end
        else
            -- FIX #5: timeout nếu không tìm thấy boss
            if os.clock() - lastSeen > MAX_NO_BOSS then
                log("[Crow] boss not found for " .. MAX_NO_BOSS .. "s")
                return "timeout"
            end
            if boss.cf then GameAPI:Teleport(boss.cf + Vector3.new(0, 3, 0)) end
            task.wait(1)
        end

        -- FIX #5: timeout nếu không tiến triển HP
        if os.clock() - lastProgress > MAX_NO_PROGRESS then
            log("[Crow] no HP progress for " .. MAX_NO_PROGRESS .. "s")
            return "timeout"
        end

        task.wait(0.3)
    end

    return "cancelled"
end

-- ============ Main Run (FIX #3 #4 #8 #11 #18) ============
function CrowQuest:Run(tok)
    local lastCrowUse = -999

    while tok.Active and Runtime.Alive do
        -- FIX #8: đọc config mỗi vòng
        local retry = tonumber(CrowQuest.Cfg.RetryDelay) or 2.0
        local cooldown = tonumber(CrowQuest.Cfg.CrowCooldown) or 5.0
        local crowSlot = tonumber(CrowQuest.Cfg.CrowSlot) or 5
        local wepSlot = tonumber(CrowQuest.Cfg.WeaponSlot) or 1
        local autoLoot = CrowQuest.Cfg.AutoLootBoss

        -- FIX #4: check quest tiếp tục — equip weapon trước khi fight
        local existingBoss, existingInstance = getActiveQuestBoss()
        if existingBoss and existingInstance then
            log("[Crow] continuing quest: " .. existingBoss.name)
            equipSlot(wepSlot)
            local status = self:FightBoss(tok, existingBoss, existingInstance)
            log("[Crow] fight status: " .. status)
            if status == "completed" and autoLoot and self.CollectLoot then
                pcall(function() self:CollectLoot(existingBoss.cf.Position, 200) end)
            end
            task.wait(retry)
            continue
        end

        -- Scan menu
        local choices = self:ScanMenu()

        if #choices == 0 then
            local now = os.clock()
            if now - lastCrowUse < cooldown then
                task.wait(cooldown - (now - lastCrowUse))
            end

            log("[Crow] equip slot " .. crowSlot)
            equipSlot(crowSlot)
            lastCrowUse = os.clock()
            task.wait(0.6)

            -- FIX #1: 1 click center
            local cam = workspace.CurrentCamera
            local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
            singleClick(vs.X * 0.5, vs.Y * 0.5)
            log("[Crow] clicked center")

            local gotMenu = waitUntil(tok, function()
                return #self:ScanMenu() > 0
            end, 12)

            if not gotMenu then
                log("[Crow] no menu after 12s, retry")
                task.wait(retry)
                continue
            end
            choices = self:ScanMenu()
        else
            log("[Crow] menu already open, " .. #choices)
        end

        -- Log choices
        log("[Crow] scanned " .. #choices)
        for _, c in ipairs(choices) do
            log("  -> " .. c.Boss.name
                .. " | Exp=" .. tostring(c.Exp)
                .. " | Wen=" .. tostring(c.Wen)
                .. " | Lv=" .. tostring(c.Level))
        end

        local best = self:PickBestMission(choices)
        if not best then
            log("[Crow] no valid pick")
            task.wait(retry)
            continue
        end

        log("[Crow] picking: " .. best.Boss.name)
        clickMission(best)

        -- FIX #2: verify quest mới với đúng boss
        local gotQuest = waitUntil(tok, function()
            local b = getActiveQuestBoss()
            return b and b.name == best.Boss.name
        end, 10)

        if not gotQuest then
            log("[Crow] wrong quest or not registered, retry")
            task.wait(retry)
            continue
        end

        -- FIX #4: switch weapon SAU khi quest confirmed
        local actualBoss, actualInstance = getActiveQuestBoss()
        log("[Crow] quest active: " .. actualBoss.name .. " — switch weapon")
        task.wait(0.3)
        equipSlot(wepSlot)
        task.wait(0.3)

        local status = self:FightBoss(tok, actualBoss, actualInstance)
        log("[Crow] fight status: " .. status)

        -- FIX #18: chỉ loot khi completed
        if status == "completed" and autoLoot and self.CollectLoot then
            pcall(function() self:CollectLoot(actualBoss.cf.Position, 200) end)
        end

        task.wait(retry)
    end
end

-- ============ UI (FIX #19: guard duplicate) ============
if not S2._CrowUIAdded then
    S2._CrowUIAdded = true
    task.spawn(function()
        task.wait(2)
        local window = S2.UI and S2.UI.Window
        if not window then
            warn("[Crow] UI not ready after 2s, skip tab")
            return
        end
        local questTab
        for _, tab in ipairs(window.Tabs) do
            if tab.Name == "Quests" then questTab = tab; break end
        end
        if not questTab then return end

        local crowGB = window:AddGroupbox(questTab, "Crow Quest")
        window:AddDropdown(crowGB, "_CrowSlot", {
            Text = "Crow Slot",
            Values = { "1", "2", "3", "4", "5" },
            Default = tostring(CrowQuest.Cfg.CrowSlot),
            Callback = function(v) CrowQuest.Cfg.CrowSlot = tonumber(v) or 5 end,
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
        window:AddSlider(crowGB, "_CrowCd", {
            Text = "Crow Cooldown",
            Min = 1, Max = 15, Default = CrowQuest.Cfg.CrowCooldown, Decimals = 1,
            Callback = function(v) CrowQuest.Cfg.CrowCooldown = v end,
        })
        window:AddToggle(crowGB, "_CrowAutoLoot", {
            Text = "Auto Loot Boss",
            Default = CrowQuest.Cfg.AutoLootBoss,
            Callback = function(on) CrowQuest.Cfg.AutoLootBoss = on end,
        })
        log("[Crow] UI added")
    end)
end

print("[ToRung/CROW] v6.0 | single-click + parse-fix + timeout + quest-confirm")
