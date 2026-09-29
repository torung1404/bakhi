-- lobby.lua - VIP tab for HUD (dedup)
local S2 = getgenv().S2
if not S2 or not S2.UI or not S2.VIP then
    return warn("[Lobby] deps missing")
end
if S2._VipTabAdded then return end
S2._VipTabAdded = true

local window = S2.UI.Window
local VIP = S2.VIP
local Themes = S2.UI.Themes
if not window then return end
for _, tab in ipairs(window.Tabs) do
    if tab.Name == "VIP Server" then return end
end

local vipTab = window:AddTab("VIP Server")
local mainGB = window:AddGroupbox(vipTab, "Private Server")

window:AddToggle(mainGB, "_VipEnabled", {
    Text = "Enable VIP Server",
    Description = "Join the configured private server on launch",
    Default = VIP.Enabled,
    Callback = function(on) VIP.Enabled = on and true or false; VIP:Save() end,
})
window:AddDropdown(mainGB, "_VipMode", {
    Text = "Mode",
    Description = "How to identify the VIP server",
    Values = { "MyPS", "ServerID", "Link" },
    Default = VIP.Mode,
    Callback = function(v) VIP.Mode = v or "MyPS"; VIP:Save() end,
})
window:AddButton(mainGB, {
    Text = "Capture Current Server",
    Description = "Read the current PS info and save it",
    Func = function()
        local ok = VIP:CaptureCurrent()
        if ok then
            window:Notify({ Title = "VIP Server",
                Description = "Captured: " .. tostring(VIP.ServerId):sub(1, 16) .. "...",
                Color = Themes.Success })
        else
            window:Notify({ Title = "VIP Server",
                Description = "Capture failed - not in a PS",
                Color = Themes.Danger })
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
                window:Notify({ Title = "VIP Server",
                    Description = "Invalid link: " .. tostring(code or "parse failed"),
                    Color = Themes.Danger })
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
            window:Notify({ Title = "VIP Server",
                Description = "Teleporting to VIP...",
                Color = Themes.Success })
        else
            window:Notify({ Title = "VIP Server",
                Description = "Join failed: " .. tostring(err),
                Color = Themes.Danger })
        end
    end,
})

local autoGB = window:AddGroupbox(vipTab, "Auto Behaviors")
window:AddToggle(autoGB, "_VipAutoJoin", {
    Text = "Auto-Join on Startup",
    Default = VIP.AutoJoinOnStart,
    Callback = function(on) VIP.AutoJoinOnStart = on and true or false; VIP:Save() end,
})
window:AddToggle(autoGB, "_VipAutoRejoin", {
    Text = "Auto-Rejoin on Kick",
    Default = VIP.AutoRejoinOnKick,
    Callback = function(on)
        VIP.AutoRejoinOnKick = on and true or false
        if on then VIP:StartAutoRejoin() else VIP:StopAutoRejoin() end
        VIP:Save()
    end,
})

print("[ToRung/Lobby] VIP tab added")
