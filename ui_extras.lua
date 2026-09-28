-- ui_extras.lua - Webhook, Config, Extras tabs + ToRung branding
local S2 = getgenv().S2
if not S2 or not S2.UI then return warn("[UIX] UI missing") end
if not S2.Webhook then return warn("[UIX] Webhook missing") end
if not S2.Config then return warn("[UIX] Config missing") end
if not S2.Extras then return warn("[UIX] Extras missing") end

local window = S2.UI.Window
local Webhook = S2.Webhook
local Config = S2.Config
local Extras = S2.Extras
local Themes = S2.UI.Themes
if not window then return warn("[UIX] no window") end

pcall(function()
    if window.TopBar then
        for _, c in ipairs(window.TopBar:GetChildren()) do
            if c:IsA("TextLabel") then
                c.Text = "ToRung HUB  |  v1.0"
                break
            end
        end
    end
end)

local hookTab = window:AddTab("Webhook")
local hookGB = window:AddGroupbox(hookTab, "Discord Webhook")

window:AddInput(hookGB, "_WhUrl", {
    Text = "Webhook URL",
    Default = Webhook.URL,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(v)
        Webhook.URL = v or ""
        Webhook:Save()
    end,
})

window:AddToggle(hookGB, "_WhEnabled", {
    Text = "Enable Webhook",
    Default = Webhook.Enabled,
    Callback = function(on)
        Webhook.Enabled = on and true or false
        Webhook:Save()
    end,
})

window:AddButton(hookGB, {
    Text = "Test Webhook",
    Func = function()
        Webhook:Test()
        window:Notify({ Title = "Webhook", Description = "Test sent", Color = Themes.Success })
    end,
})

local evGB = window:AddGroupbox(hookTab, "Notify Events")

window:AddToggle(evGB, "_WhBossKill", {
    Text = "Boss Killed", Default = Webhook.Events.BossKilled,
    Callback = function(on) Webhook.Events.BossKilled = on; Webhook:Save() end,
})
window:AddToggle(evGB, "_WhQuest", {
    Text = "Quest Accepted", Default = Webhook.Events.QuestAccepted,
    Callback = function(on) Webhook.Events.QuestAccepted = on; Webhook:Save() end,
})
window:AddToggle(evGB, "_WhItem", {
    Text = "Item Drop", Default = Webhook.Events.ItemDrop,
    Callback = function(on) Webhook.Events.ItemDrop = on; Webhook:Save() end,
})
window:AddToggle(evGB, "_WhError", {
    Text = "Errors", Default = Webhook.Events.Error,
    Callback = function(on) Webhook.Events.Error = on; Webhook:Save() end,
})
window:AddToggle(evGB, "_WhFish", {
    Text = "Fish Caught", Default = Webhook.Events.FishCaught,
    Callback = function(on) Webhook.Events.FishCaught = on; Webhook:Save() end,
})
window:AddToggle(evGB, "_WhSoul", {
    Text = "Soul Grabbed", Default = Webhook.Events.SoulGrabbed,
    Callback = function(on) Webhook.Events.SoulGrabbed = on; Webhook:Save() end,
})

local cfgTab = window:AddTab("Config")
local cfgGB = window:AddGroupbox(cfgTab, "Save / Load")

window:AddInput(cfgGB, "_CfgName", {
    Text = "Config Name",
    Default = "",
    Placeholder = "my_config",
})

local cfgDropdown = window:AddDropdown(cfgGB, "_CfgList", {
    Text = "Saved Configs",
    Values = Config:List(),
    Default = nil,
    Callback = function() end,
})

window:AddButton(cfgGB, {
    Text = "Save Current",
    Func = function()
        local name = window.Flags._CfgName
        if not name or name == "" then
            window:Notify({ Title = "Config", Description = "Enter a name", Color = Themes.Danger })
            return
        end
        local ok, err = Config:Save(name)
        window:Notify({
            Title = "Config",
            Description = ok and ("Saved: " .. name) or ("Failed: " .. tostring(err)),
            Color = ok and Themes.Success or Themes.Danger,
        })
        if ok and cfgDropdown then cfgDropdown:SetValues(Config:List()) end
    end,
})

window:AddButton(cfgGB, {
    Text = "Load Selected",
    Func = function()
        local name = window.Flags._CfgList
        if not name or name == "" then
            window:Notify({ Title = "Config", Description = "Select a config", Color = Themes.Danger })
            return
        end
        local ok, err = Config:Load(name)
        window:Notify({
            Title = "Config",
            Description = ok and ("Loaded: " .. name) or ("Failed: " .. tostring(err)),
            Color = ok and Themes.Success or Themes.Danger,
        })
    end,
})

window:AddButton(cfgGB, {
    Text = "Delete Selected",
    Color = Themes.Danger,
    Func = function()
        local name = window.Flags._CfgList
        if name then
            Config:Delete(name)
            if cfgDropdown then cfgDropdown:SetValues(Config:List()) end
            window:Notify({ Title = "Config", Description = "Deleted: " .. name, Color = Themes.Success })
        end
    end,
})

window:AddButton(cfgGB, {
    Text = "Refresh List",
    Func = function()
        if cfgDropdown then cfgDropdown:SetValues(Config:List()) end
    end,
})

local autoGB = window:AddGroupbox(cfgTab, "Auto-Load on Startup")

window:AddInput(autoGB, "_CfgAutoName", {
    Text = "Auto-Load Config",
    Default = Config:GetAutoLoad(),
    Placeholder = "config name or empty",
})

window:AddButton(autoGB, {
    Text = "Set Auto-Load",
    Func = function()
        local name = window.Flags._CfgAutoName or ""
        Config:SetAutoLoad(name)
        window:Notify({ Title = "Auto-Load", Description = "Set: " .. (name ~= "" and name or "none"), Color = Themes.Success })
    end,
})

window:AddButton(autoGB, {
    Text = "Clear Auto-Load",
    Func = function()
        Config:SetAutoLoad("")
        if window.Flags then window.Flags._CfgAutoName = "" end
        window:Notify({ Title = "Auto-Load", Description = "Cleared", Color = Themes.Success })
    end,
})

local extTab = window:AddTab("Extras")
local guardGB = window:AddGroupbox(extTab, "Health Guard")

window:AddToggle(guardGB, "_HgEnabled", {
    Text = "Enable Health Guard",
    Description = "Fly up when HP low, return when healed",
    Default = false,
    Callback = function(on)
        if on then Extras:StartHealthGuard() else Extras:StopHealthGuard() end
    end,
})

window:AddSlider(guardGB, "_HgPct", {
    Text = "Trigger at HP %",
    Min = 10, Max = 90, Default = 45,
    Callback = function(v) Extras.GuardPct = v / 100 end,
})

local soulGB = window:AddGroupbox(extTab, "Soul Collection")

window:AddToggle(soulGB, "_SoulsEnabled", {
    Text = "Auto Collect Souls",
    Description = "Automatically grab souls from Debree",
    Default = false,
    Callback = function(on)
        if on then Extras:StartAutoSouls() else Extras:StopAutoSouls() end
    end,
})

window:AddSlider(soulGB, "_SoulsRate", {
    Text = "Check Rate (s)",
    Min = 0.2, Max = 3, Default = 0.5, Decimals = 1,
    Callback = function(v) Extras.SoulsRate = v end,
})

local muzanGB = window:AddGroupbox(extTab, "Muzan Finder")

window:AddButton(muzanGB, {
    Text = "Find / TP to Muzan",
    Func = function()
        local ok, where = Extras:TeleportToMuzan()
        window:Notify({
            Title = "Muzan",
            Description = ok and ("At " .. tostring(where)) or "Not on map",
            Color = ok and Themes.Success or Themes.Danger,
        })
    end,
})

local trainGB = window:AddGroupbox(extTab, "Auto-Train")

window:AddDropdown(trainGB, "_TrainStation", {
    Text = "Station",
    Values = { "Boulder Push", "Squat Rack", "Aim Training", "Boulder Split", "Cup Game", "Meditation", "Pushups" },
    Default = Extras.TrainStation,
    Callback = function(v) Extras.TrainStation = v end,
})

window:AddToggle(trainGB, "_TrainEnabled", {
    Text = "Enable Auto-Train",
    Default = false,
    Callback = function(on)
        if on then
            Extras:StartAutoTrain(window.Flags._TrainStation or Extras.TrainStation)
        else
            Extras:StopAutoTrain()
        end
    end,
})

task.spawn(function()
    task.wait(3)
    local name = Config:GetAutoLoad()
    if name ~= "" then
        local ok = Config:Load(name)
        if ok then
            window:Notify({ Title = "Auto-Load", Description = "Loaded: " .. name, Color = Themes.Success, Duration = 4 })
        else
            warn("[ToRung] Auto-load failed: " .. name)
        end
    end
end)

print("[ToRung/UIX] ready - ToRung HUB branded")
