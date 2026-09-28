-- Hold T (VK 84) for opening chests
local function holdT(duration)
    duration = tonumber(duration) or 2.0
    local VIM = game:GetService("VirtualInputManager")
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.T, false, game)
    end)
    task.wait(duration)
    pcall(function()
        VIM:SendKeyEvent(false, Enum.KeyCode.T, false, game)
    end)
end

function CrowQuest:CollectLoot(position, radius)
    radius = radius or 200
    local CS = game:GetService("CollectionService")
    local r = GameAPI:GetRoot()
    if not r then return end

    task.wait(1.5)

    for _ = 1, 3 do
        local foundAny = false

        -- Nguồn 1: tag LootDrop
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

        -- Nguồn 2: tag Chest — HOLD T để mở
        pcall(function()
            for _, obj in ipairs(CS:GetTagged("Chest")) do
                if not self.Active then return end
                local rootPart = obj:FindFirstChild("RootPart") or obj:FindFirstChildWhichIsA("BasePart")
                if rootPart and (rootPart.Position - position).Magnitude < radius then
                    foundAny = true
                    r.CFrame = rootPart.CFrame * CFrame.new(0, 0, 3)
                    r.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.4)
                    holdT(2.0)   -- Hold T 2s để mở rương
                    task.wait(0.5)
                end
            end
        end)

        -- Nguồn 3: workspace.LootDrops
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

        -- Nguồn 4: workspace.Chests — HOLD T
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

        -- Nguồn 5: Debree
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
end
