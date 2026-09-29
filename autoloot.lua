-- autoloot.lua - Background auto-loot (Delta only)
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[Loot] core missing") end

local Runtime = S2.Core.Runtime
local GameAPI = S2.Core.GameAPI
local log = S2.Core.log
local spawnJob = S2.Core.spawnJob
local stopJob = S2.Core.stopJob

local CS = game:GetService("CollectionService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local AutoLoot = {
    Enabled = false,
    Radius = 250,
    HoldTDuration = 2.0,
    ScanInterval = 3.0,
}

local function holdT(d)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.T, false, game)
    end)
    task.wait(d)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.T, false, game)
    end)
end

local function lootNear(pos)
    local radius = AutoLoot.Radius
    local root = GameAPI:GetRoot()
    if not root then return false end
    local found = false

    pcall(function()
        for _, obj in ipairs(CS:GetTagged("LootDrop")) do
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part and (part.Position - pos).Magnitude < radius then
                found = true
                root.CFrame = part.CFrame * CFrame.new(0, 0, 2)
                root.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.15)
                holdT(0.3)
                for _, d in ipairs(obj:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        pcall(fireproximityprompt, d)
                    end
                end
                task.wait(0.25)
            end
        end
    end)

    pcall(function()
        for _, obj in ipairs(CS:GetTagged("Chest")) do
            local rp = obj:FindFirstChild("RootPart") or obj:FindFirstChildWhichIsA("BasePart")
            if rp and (rp.Position - pos).Magnitude < radius then
                found = true
                root.CFrame = rp.CFrame * CFrame.new(0, 0, 3)
                root.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.3)
                holdT(AutoLoot.HoldTDuration)
                task.wait(0.3)
            end
        end
    end)

    pcall(function()
        local ld = workspace:FindFirstChild("LootDrops")
        if not ld then return end
        for _, child in ipairs(ld:GetChildren()) do
            local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
            if part and (part.Position - pos).Magnitude < radius then
                found = true
                root.CFrame = part.CFrame * CFrame.new(0, 0, 2)
                root.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.15)
                holdT(0.3)
                for _, d in ipairs(child:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then pcall(fireproximityprompt, d) end
                end
                task.wait(0.25)
            end
        end
    end)

    pcall(function()
        local ch = workspace:FindFirstChild("Chests")
        if not ch then return end
        for _, child in ipairs(ch:GetChildren()) do
            local rp = child:FindFirstChild("RootPart") or child:FindFirstChildWhichIsA("BasePart")
            if rp and (rp.Position - pos).Magnitude < radius then
                found = true
                root.CFrame = rp.CFrame * CFrame.new(0, 0, 3)
                root.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.3)
                holdT(AutoLoot.HoldTDuration)
                task.wait(0.3)
            end
        end
    end)

    return found
end

function AutoLoot:Start()
    if Runtime.Tasks.AutoLoot then return false end
    AutoLoot.Enabled = true
    spawnJob("AutoLoot", function(tok)
        while tok.Active and Runtime.Alive do
            if AutoLoot.Enabled then
                local root = GameAPI:GetRoot()
                if root then pcall(lootNear, root.Position) end
            end
            task.wait(AutoLoot.ScanInterval)
        end
    end)
    log("[Loot] ON")
    return true
end

function AutoLoot:Stop()
    AutoLoot.Enabled = false
    stopJob("AutoLoot")
    log("[Loot] OFF")
end

S2.AutoLoot = AutoLoot
print("[ToRung/LOOT] ready")
