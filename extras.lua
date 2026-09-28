-- extras.lua - Health guard, Blocking, Muzan finder, Souls, Auto-train
local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[ToRung/EXT] Core chưa chạy") end
if not S2.Features then return warn("[ToRung/EXT] Features chưa chạy") end

local Runtime = S2.Core.Runtime
local GameAPI = S2.Core.GameAPI
local MobIndex = S2.Core.MobIndex
local Movement = S2.Core.Movement
local log = S2.Core.log
local spawnJob = S2.Core.spawnJob
local stopJob = S2.Core.stopJob
local Webhook = S2.Webhook

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Extras = {
    HealthGuard = false,
    GuardPct = 0.45,
    Flying = false,
    OriginalCF = nil,
    AutoSouls = false,
    SoulsRate = 0.5,
    TrainStation = "Boulder Push",
    MuzanRoute = {
        Vector3.new(55.0, 826.5, 781.5),
        Vector3.new(197.2, 871.4, 812.2),
        Vector3.new(330.0, 873.0, 824.0),
        Vector3.new(182.4, 873.0, 703.7),
        Vector3.new(187.6, 914.8, 558.3),
        Vector3.new(237.8, 940.5, 389.6),
        Vector3.new(227.8, 963.5, 250.1),
        Vector3.new(98.9, 963.5, 210.2),
        Vector3.new(232.7, 963.5, 267.0),
        Vector3.new(212.2, 940.5, 452.1),
        Vector3.new(181.8, 909.0, 590.1),
        Vector3.new(183.6, 873.0, 714.7),
        Vector3.new(115.8, 826.5, 808.6),
        Vector3.new(1920.6, 599.0, -881.0),
        Vector3.new(-687.0, 1380.5, -2606.5),
    },
}

-- Health guard: fly up when HP drops below threshold, come back when healed
function Extras:StartHealthGuard()
    if self.GuardJob then return end
    self.HealthGuard = true
    self.GuardJob = spawnJob("HealthGuard", function(tok)
        while tok.Active and Runtime.Alive do
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                local ratio = hum.Health / math.max(hum.MaxHealth, 1)
                if ratio < self.GuardPct and not self.Flying then
                    self.Flying = true
                    self.OriginalCF = root.CFrame
                    root.CFrame = root.CFrame + Vector3.new(0, 200, 0)
                    root.AssemblyLinearVelocity = Vector3.zero
                    log("[EXT] HealthGuard UP (HP=" .. math.floor(ratio * 100) .. "%)")
                    if Webhook then
                        Webhook:Notify("Error", "Health Guard Triggered",
                            "HP dropped to " .. math.floor(ratio * 100) .. "% - flying up to heal", 0xCE9246)
                    end
                elseif self.Flying then
                    root.AssemblyLinearVelocity = Vector3.zero
                    if ratio >= 0.95 then
                        self.Flying = false
                        if self.OriginalCF then
                            root.CFrame = self.OriginalCF
                            self.OriginalCF = nil
                        end
                        log("[EXT] HealthGuard DOWN (healed)")
                    end
                end
            end
            task.wait(0.2)
        end
    end)
end

function Extras:StopHealthGuard()
    self.HealthGuard = false
    self.Flying = false
    self.OriginalCF = nil
    stopJob("HealthGuard")
    self.GuardJob = nil
end

-- Target blocking detection (used by combat)
function Extras:IsTargetBlocking(model)
    if not model then return false end
    local ok, b = pcall(function() return model:FindFirstChild("Blocking") end)
    return ok and b ~= nil
end

-- Muzan finder
function Extras:FindMuzan()
    local deb = workspace:FindFirstChild("Debree")
    local reg = deb and deb:FindFirstChild("Regions")
    if not reg then return nil end
    for _, region in ipairs(reg:GetChildren()) do
        for _, setName in ipairs({ "ActiveNpcs", "StationaryNpcs" }) do
            local folder = region:FindFirstChild(setName)
            if folder then
                for _, npc in ipairs(folder:GetChildren()) do
                    if npc.Name:lower():find("muzan") then
                        local model = npc:FindFirstChildOfClass("Model") or npc
                        local root = model:FindFirstChild("HumanoidRootPart")
                        if root then
                            return root.Position, region.Name
                        end
                    end
                end
            end
        end
    end
    return nil
end

function Extras:TeleportToMuzan()
    local pos, region = self:FindMuzan()
    if pos then
        GameAPI:Teleport(CFrame.new(pos + Vector3.new(5, 3, 0)))
        log("[EXT] TP Muzan at", region or "?")
        return true, region
    end
    local root = GameAPI:GetRoot()
    if root then
        local nearest, dist = nil, math.huge
        for _, p in ipairs(self.MuzanRoute) do
            local d = (p - root.Position).Magnitude
            if d < dist then nearest, dist = p, d end
        end
        if nearest then
            GameAPI:Teleport(CFrame.new(nearest + Vector3.new(0, 3, 0)))
            log("[EXT] Muzan off-map, TP'd to nearest patrol point")
            return true, "patrol"
        end
    end
    return false
end

-- Soul collection
function Extras:StartAutoSouls()
    if self.SoulsJob then return end
    self.AutoSouls = true
    self.SoulsJob = spawnJob("AutoSouls", function(tok)
        while tok.Active and Runtime.Alive do
            local root = GameAPI:GetRoot()
            local deb = workspace:FindFirstChild("Debree")
            if root and deb then
                for _, child in ipairs(deb:GetChildren()) do
                    if not tok.Active then break end
                    local name = child.Name:lower()
                    if name:match("soul$") and not name:find("host") and not name:find("grab") then
                        local part = child
                        if child.ClassName ~= "Part" and child.ClassName ~= "MeshPart" then
                            part = child:FindFirstChild("Root") or child:FindFirstChildWhichIsA("BasePart")
                        end
                        if part then
                            local dist = (part.Position - root.Position).Magnitude
                            if dist < 200 then
                                root.CFrame = part.CFrame * CFrame.new(0, 0, 2)
                                root.AssemblyLinearVelocity = Vector3.zero
                                task.wait(0.1)
                                for _, d in ipairs(child:GetDescendants()) do
                                    if d:IsA("ProximityPrompt") then
                                        pcall(fireproximityprompt, d)
                                        break
                                    end
                                end
                                task.wait(0.3)
                            end
                        end
                    end
                end
            end
            task.wait(self.SoulsRate)
        end
    end)
end

function Extras:StopAutoSouls()
    self.AutoSouls = false
    stopJob("AutoSouls")
    self.SoulsJob = nil
end

-- Auto-train
function Extras:StartAutoTrain(station)
    if self.TrainJob then self:StopAutoTrain() end
    self.TrainStation = station or self.TrainStation or "Boulder Push"
    self.TrainJob = spawnJob("AutoTrain", function(tok)
        while tok.Active and Runtime.Alive do
            local trainingFolder = workspace:FindFirstChild("Training")
            local stationModel = trainingFolder and trainingFolder:FindFirstChild(self.TrainStation)
            if stationModel then
                local part = stationModel:FindFirstChildWhichIsA("BasePart", true)
                local prompt = stationModel:FindFirstChildWhichIsA("ProximityPrompt", true)
                if part and prompt then
                    local root = GameAPI:GetRoot()
                    if root and (root.Position - part.Position).Magnitude > 15 then
                        GameAPI:Teleport(part.CFrame * CFrame.new(0, 3, 0))
                        task.wait(1)
                    end
                    if prompt.Enabled then
                        pcall(fireproximityprompt, prompt)
                    end
                end
            end
            task.wait(1)
        end
    end)
end

function Extras:StopAutoTrain()
    stopJob("AutoTrain")
    self.TrainJob = nil
end

S2.Extras = Extras
print("[ToRung/EXT] ready")
