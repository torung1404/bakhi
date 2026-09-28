-- lobby.lua - VIP Server tab for main HUD (same style)
local S2 = getgenv().S2
if not S2 or not S2.UI or not S2.VIP then
    return warn("[Lobby] deps missing")
end

local window = S2.UI.Window
local VIP = S2.VIP
local Themes = S2.UI.Themes
if not window then return warn("[Lobby] no window") end

-- ============ VIP Server tab ============
local vipTab = window:AddTab("VIP Server")
local mainGB = window:AddGroupbox(vipTab, "Private Server")

window:AddToggle(mainGB, "_VipEnabled", {
    Text = "Enable VIP Server",
    Description = "Join the configured private server on launch",
    Default = VIP.Enabled,
    Callback = function(on)
        VIP.Enabled = on and true or false
        VIP:Save()
    end,
})

window:AddDropdown(mainGB, "_VipMode", {
    Text = "Mode",
    Description = "How to identify the VIP server",
    Values = { "MyPS", "ServerID", "Link" },
    Default = VIP.Mode,
    Callback = function(v)
        VIP.Mode = v or "MyPS"
        VIP:Save()
        if window.Options._VipInfo then
            window.Options._VipInfo:SetText("")
        end
    end,
})

local infoLabel = window:AddInput(mainGB, "_VipInfoDummy", {
    Text = "Current Info",
    Default = "",
    Placeholder = "No server configured",
    Callback = function() end,
})
infoLabel.Type = "InfoLabel"

-- Override: make it read-only display
if infoLabel.Holder then
    local box = infoLabel.Holder:FindFirstChildWhichIsA("TextBox", true)
    if box then
        box.TextEditable = false
        box.BackgroundTransparency = 1
    end
end

window:AddButton(mainGB, {
    Text = "Capture Current Server",
    Description = "Read the current PS info and save it",
    Func = function()
        local ok = VIP:CaptureCurrent()
        if ok then
            window:Notify({
                Title = "VIP Server",
                Description = "Captured: " .. tostring(VIP.ServerId):sub(1, 16) .. "...",
                Color = Themes.Success,
            })
        else
            window:Notify({
                Title = "VIP Server",
                Description = "Capture failed - you may not be in a PS",
                Color = Themes.Danger,
            })
        end
    end,
})

window:AddInput(mainGB, "_VipServerID", {
    Text = "Server ID / Link",
    Description = "Paste PrivateServerId, JobId, or full PS link",
    Default = VIP.ServerId or VIP.LinkCode or "",
    Placeholder = "Paste here...",
    Callback = function(v)
        if VIP.Mode == "ServerID" then
            VIP.ServerId = v or ""
            VIP.PlaceId = game.PlaceId
            VIP:Save()
        elseif VIP.Mode == "Link" then
            local pid, code = VIP:ParseLink(v)
            if pid and code then
                VIP.PlaceId = pid
                VIP.LinkCode = code
                VIP:Save()
            else
                window:Notify({
                    Title = "VIP Server",
                    Description = "Invalid link: " .. tostring(code or "parse failed"),
                    Color = Themes.Danger,
                })
            end
        end
    end,
})

window:AddButton(mainGB, {
    Text = "Join VIP Now",
    Color = Themes.Accent,
    Func = function()
        local ok, err = VIP:Join()
        if ok then
            window:Notify({
                Title = "VIP Server",
                Description = "Teleporting to VIP...",
                Color = Themes.Success,
            })
        else
            window:Notify({
                Title = "VIP Server",
                Description = "Join failed: " .. tostring(err),
                Color = Themes.Danger,
            })
        end
    end,
})

-- ============ Auto behaviors ============
local autoGB = window:AddGroupbox(vipTab, "Auto Behaviors")

window:AddToggle(autoGB, "_VipAutoJoin", {
    Text = "Auto-Join on Startup",
    Description = "Join the VIP server automatically when script loads",
    Default = VIP.AutoJoinOnStart,
    Callback = function(on)
        VIP.AutoJoinOnStart = on and true or false
        VIP:Save()
    end,
})

window:AddToggle(autoGB, "_VipAutoRejoin", {
    Text = "Auto-Rejoin on Kick",
    Description = "Rejoin the VIP server if disconnected",
    Default = VIP.AutoRejoinOnKick,
    Callback = function(on)
        VIP.AutoRejoinOnKick = on and true or false
        if on then
            VIP:StartAutoRejoin()
        else
            VIP:StopAutoRejoin()
        end
        VIP:Save()
    end,
})

-- ============ Status ============
local statusGB = window:AddGroupbox(vipTab, "Status")

local function refreshStatus()
    local lines = {}
    table.insert(lines, "PlaceId: " .. tostring(VIP.PlaceId))
    table.insert(lines, "ServerId: " .. tostring(VIP.ServerId ~= "" and VIP.ServerId:sub(1, 24) or "N/A"))
    table.insert(lines, "OwnerId: " .. tostring(VIP.OwnerId))
    table.insert(lines, "Mode: " .. tostring(VIP.Mode))
    table.insert(lines, "Enabled: " .. tostring(VIP.Enabled))
    return table.concat(lines, "   |   ")
end

window:AddInput(statusGB, "_VipStatusDummy", {
    Text = "Info",
    Default = refreshStatus(),
    Placeholder = "",
    Callback = function() end,
})

window:AddButton(statusGB, {
    Text = "Refresh Status",
    Func = function()
        local d = window.Options and window.Options._VipStatusDummy
        if d and d.SetValue then d:SetValue(refreshStatus(), true) end
        window:Notify({ Title = "VIP", Description = "Status refreshed", Color = Themes.Success })
    end,
})

-- ============ First-launch auto flow ============
local SHOW_FLAG = "ToRungHub/lobby_shown.txt"
local firstLaunch = true
if not isfolder("ToRungHub") then makefolder("ToRungHub") end
if isfile(SHOW_FLAG) then firstLaunch = false end

task.spawn(function()
    task.wait(2)
    if firstLaunch then
        -- Switch to VIP tab + notify
        for _, tab in ipairs(window.Tabs) do
            if tab.Name == "VIP Server" then
                -- emulate tab click via visible switch
                if window.ActiveTab and window.ActiveTab.Button then
                    window.ActiveTab.Page.Visible = false
                end
                window.ActiveTab = tab
                tab.Page.Visible = true
                if tab.Button then
                    tab.Button.TextColor3 = Themes.AccentText
                    tab.Button.BackgroundColor3 = Themes.ElementBg
                end
                break
            end
        end
        pcall(function() writefile(SHOW_FLAG, "1") end)
        window:Notify({
            Title = "Welcome to ToRung HUB",
            Description = "Configure your VIP server in this tab if needed.",
            Color = Themes.Accent,
            Duration = 8,
        })
    elseif VIP.AutoJoinOnStart and VIP.Enabled then
        task.wait(1)
        VIP:Join()
    end
    if VIP.AutoRejoinOnKick then
        VIP:StartAutoRejoin()
    end
end)

print("[ToRung/Lobby] VIP tab added to main HUD")
