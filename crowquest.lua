-- crowquest.lua - Crow Quest v3 (fixed menu open + scan + click)
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

-- ============ Config ============
CrowQuest.Cfg = CrowQuest.Cfg or {
    CrowSlot = 3,
    WeaponSlot = 1,
    Priority = "HighestExp",
    MaxHuntLevel = 125,
    RetryDelay = 2.0,
    AutoLootBoss = false,
}

-- ============ Quest runtime helpers ============
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

-- ============ Input helpers ============
local function pressKeyVK(vk)
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
    pressKeyVK(48 + slot)
    log("[Crow] pressed slot " .. slot)
end

local function pressEquals()
    pressKeyVK(Enum.KeyCode.Equals.Value)
end

local function clickMidScreen()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local vu = game:GetService("VirtualUser")
    local cx = camera.ViewportSize.X * 0.5
    local cy = camera.ViewportSize.Y * 0.5
    pcall(function()
        if setrobloxinput then setrobloxinput(true) end
        vu:CaptureController()
        vu:ClickButton1(Vector2.new(cx, cy))
        vu:ReleaseController()
    end)
end

local function moveMouseTo(x, y)
    local mouse = LP:GetMouse()
    if not mouse or not mousemoverel then return end
    pcall(function()
        if setrobloxinput then setrobloxinput(true) end
        mousemoverel(x - mouse.X, y - mouse.Y)
    end)
    task.wait(0.15)
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

local function findContainer(obj, minW)
    minW = minW or 200
    local p = obj
    for _ = 1, 8 do
        if not p then break end
        local ok, size = pcall(function() return p.AbsoluteSize end)
        if ok and size and size.X >= minW and size.Y >= 50 then return p end
        p = p.Parent
    end
    return nil
end

-- ============ Scan menu ============
local function getDialogueUI()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local holder = pg:FindFirstChild("ComponentsHolder")
    if not holder then return nil end
    local frame = holder:FindFirstChild("DialogueFrame")
    if not frame then return nil end
    local actual = frame:FindFirstChild("Actual")
    return actual or frame
end

function CrowQuest:ScanMenu()
    local actual = getDialogueUI()
    if not actual then return {} end

    local choices = {}
    local seen = {}

    -- Scan all descendants for text with "Defeat"
    for _, d in ipairs(actual:GetDescendants()) do
        if not (d:IsA("TextLabel") or d:IsA("TextButton")) then
            continue
        end
        local txt = d.Text or ""
        if not txt:find("Defeat", 1, true) then
            continue
        end

        -- Extract boss name
        local cleaned = txt:gsub("^%s*Defeat%s+", ""):gsub("%s+$", "")
        local bossData = findBossByText(cleaned) or findBossByText(txt)
        if not bossData then
            continue
        end

        -- Dedupe: same boss at similar Y
        local okAP, ap = pcall(function() return d.AbsolutePosition end)
        if not okAP or not ap then continue end
        local key = bossData.name .. "@" .. math.floor(ap.Y / 40)
        if seen[key] then continue end
        seen[key] = true

        -- Container = frame
        local container = findContainer(d, 200)

        -- Parse exp + wen from container
        local exp, wen = 0, 0
        if container then
            local allNums = {}
            for _, n in ipairs(container:GetDescendants()) do
                if n:IsA("TextLabel") or n:IsA("TextButton") then
                    for _, v in ipairs(parseAllNumbers(n.Text)) do
                        table.insert(allNums, v)
                    end
                end
            end
            table.sort(allNums, function(a, b) return a > b end)
            if allNums[1] and allNums[1] >= 1000 then exp = allNums[1] end
            if allNums[2] and allNums[2] >= 100 then wen = allNums[2] end
        end

        -- Find clickable button
        local btn = d
        for _ = 1, 8 do
            if not btn then break end
            if btn:IsA("TextButton") or btn:IsA("ImageButton") then break end
            btn = btn.Parent
        end
        if not btn then btn = d end

        -- Get button screen position
        local okBAP, bap = pcall(function() return btn.AbsolutePosition end)
        local okBAS, bas = pcall(function() return btn.AbsoluteSize end)
        local bx = (okBAP and bap and bap.X or ap.X) + (okBAS and bas and bas.X * 0.5 or 100)
        local by = (okBAP and bap and bap.Y or ap.Y) + (okBAS and bas and bas.Y * 0.5 or 20)

        table.insert(choices, {
            Boss = bossData,
            Exp = exp,
            Wen = wen,
            Button = btn,
            Label = d,
            X = bx,
            Y = by,
        })
    end

    return choices
end

-- ============ Pick best mission ============
function CrowQuest:PickBestMission(choices)
    if #choices == 0 then return nil end
    local priority = self.Cfg.Priority or "HighestExp"

    if priority == "Random" then
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

-- ============ Click mission (multiple strategies) ============
local function pickMission(choice)
    -- Strategy 1: hover mouse + press "="
    moveMouseTo(choice.X, choice.Y)
    task.wait(0.1)
    pressEquals()
    task.wait(0.4)

    -- Check if menu still exists
    if #CrowQuest:ScanMenu() == 0 then
        log("[Crow] picked via mouse+equals")
        return true
    end

    -- Strategy 2: firesignal on button
    if choice.Button and firesignal then
        pcall(firesignal, choice.Button.MouseButton1Click)
        task.wait(0.5)
        if #CrowQuest:ScanMenu() == 0 then
            log("[Crow] picked via firesignal")
            return true
        end
    end

    -- Strategy 3: VirtualUser click
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton1(Vector2.new(choice.X, choice.Y))
        vu:ReleaseController()
    end)
    task.wait(0.5)
    if #CrowQuest:ScanMenu() == 0 then
        log("[Crow] picked via VirtualUser")
        return true
    end

    return false
end

-- ============ Wait helper ============
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
            log("[Crow] continuing existing quest: " .. existing.name)
            self:FightBoss(tok, existing)
            task.wait(retry)
            continue
        end

        -- Check if menu is already open
        local existingMenu = self:ScanMenu()
        if #existingMenu > 0 then
            log("[Crow] menu already open, " .. #existingMenu .. " missions")
            -- skip to pick
        else
            -- Phase 1: equip crow
            log("[Crow] equipping crow (slot " .. tostring(cfg.CrowSlot) .. ")")
            pressSlot(cfg.CrowSlot)
            task.wait(0.8)

            -- Phase 1.5: try to open menu
            local opened = false

            -- Check if menu auto-opened
            if #self:ScanMenu() > 0 then
                opened = true
                log("[Crow] menu auto-opened")
            end

            -- Try "=" key
            if not opened then
                log("[Crow] trying = key to open menu")
                pressEquals()
                task.wait(1.2)
                if #self:ScanMenu() > 0 then opened = true end
            end

            -- Try mid-screen click
            if not opened then
                log("[Crow] trying mid-screen click")
                clickMidScreen()
                task.wait(1)
                if #self:ScanMenu() > 0 then opened = true end
            end

            if not opened then
                log("[Crow] menu didn't open, retry in " .. retry .. "s")
                pressSlot(cfg.WeaponSlot)
                task.wait(retry)
                continue
            end
        end

        -- Phase 2: scan and pick
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
        local picked = pickMission(best)
        if not picked then
            log("[Crow] pick failed, retry")
            pressSlot(cfg.WeaponSlot)
            task.wait(retry)
            continue
        end

        -- Phase 3: wait for quest active
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

print("[ToRung/CROW] v3 loaded")
