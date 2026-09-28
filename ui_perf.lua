-- ui_perf.lua - Performance tab
local S2 = getgenv().S2
if not S2 or not S2.UI or not S2.Performance then
    return warn("[ui_perf] missing deps")
end

local window = S2.UI.Window
local Perf = S2.Performance
local Themes = S2.UI.Themes
if not window then return end

local perfTab = window:AddTab("Performance")
local mainGB = window:AddGroupbox(perfTab, "Performance Mode")

window:AddToggle(mainGB, "_PerfMaster", {
    Text = "Master Toggle",
    Description = "Enable all performance tweaks below",
    Default = Perf.Master,
    Callback = function(on) Perf:SetMaster(on) end,
})

window:AddToggle(mainGB, "_PerfFB", {
    Text = "FullBright",
    Description = "Maximize lighting brightness",
    Default = Perf.FullBright,
    Callback = function(on) Perf.FullBright = on; Perf:Apply(); Perf:Save() end,
})

window:AddToggle(mainGB, "_PerfFog", {
    Text = "No Fog",
    Description = "Remove all fog",
    Default = Perf.NoFog,
    Callback = function(on) Perf.NoFog = on; Perf:Apply(); Perf:Save() end,
})

window:AddToggle(mainGB, "_PerfAtm", {
    Text = "No Atmosphere",
    Description = "Disable bloom, blur, sun rays",
    Default = Perf.NoAtmosphere,
    Callback = function(on) Perf.NoAtmosphere = on; Perf:Apply(); Perf:Save() end,
})

window:AddToggle(mainGB, "_PerfTime", {
    Text = "Force Time of Day",
    Description = "Lock in-game clock",
    Default = Perf.ForceTime,
    Callback = function(on) Perf.ForceTime = on; Perf:Apply(); Perf:Save() end,
})

window:AddSlider(mainGB, "_PerfHour", {
    Text = "Time (hour)",
    Min = 0, Max = 24, Default = Perf.TimeOfDay,
    Callback = function(v) Perf.TimeOfDay = v; Perf:Apply(); Perf:Save() end,
})

window:AddToggle(mainGB, "_PerfMap", {
    Text = "Hide Map",
    Description = "Make map parts invisible",
    Default = Perf.HideMap,
    Callback = function(on) Perf.HideMap = on; Perf:Apply(); Perf:Save() end,
})

window:AddToggle(mainGB, "_PerfOthers", {
    Text = "Hide Other Players",
    Description = "Invisible other players",
    Default = Perf.HideOthers,
    Callback = function(on) Perf.HideOthers = on; Perf:Apply(); Perf:Save() end,
})

window:AddToggle(mainGB, "_PerfSelf", {
    Text = "Hide Character",
    Description = "Invisible yourself",
    Default = Perf.HideSelf,
    Callback = function(on) Perf.HideSelf = on; Perf:Apply(); Perf:Save() end,
})

window:AddToggle(mainGB, "_Perf3D", {
    Text = "No 3D Render",
    Description = "Disable 3D rendering (UI only)",
    Default = Perf.No3D,
    Callback = function(on) Perf.No3D = on; Perf:Apply(); Perf:Save() end,
})

window:AddSlider(mainGB, "_PerfFPS", {
    Text = "FPS Cap (0 = unlimited)",
    Min = 0, Max = 360, Default = Perf.FPSCap,
    Callback = function(v) Perf.FPSCap = v; Perf:Apply(); Perf:Save() end,
})

-- Apply saved state on load
if Perf.Master then Perf:Apply() end

print("[ToRung/UI-PERF] tab added")
