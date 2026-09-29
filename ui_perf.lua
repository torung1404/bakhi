-- ui_perf.lua - Performance tab (dedup)
local S2 = getgenv().S2
if not S2 or not S2.UI or not S2.Performance then
    return warn("[ui_perf] missing deps")
end
if S2._PerfTabAdded then return end
S2._PerfTabAdded = true

local window = S2.UI.Window
local Perf = S2.Performance
local Themes = S2.UI.Themes
if not window then return end
for _, tab in ipairs(window.Tabs) do
    if tab.Name == "Performance" then return end
end

local perfTab = window:AddTab("Performance")
local mainGB = window:AddGroupbox(perfTab, "Performance Mode")

window:AddToggle(mainGB, "_PerfMaster", {
    Text = "Master Toggle",
    Description = "Enable all performance tweaks below",
    Default = Perf.Master,
    Callback = function(on) Perf:SetMaster(on) end,
})
window:AddToggle(mainGB, "_PerfFB", {
    Text = "FullBright", Default = Perf.FullBright,
    Callback = function(on) Perf.FullBright = on; Perf:Apply(); Perf:Save() end,
})
window:AddToggle(mainGB, "_PerfFog", {
    Text = "No Fog", Default = Perf.NoFog,
    Callback = function(on) Perf.NoFog = on; Perf:Apply(); Perf:Save() end,
})
window:AddToggle(mainGB, "_PerfAtm", {
    Text = "No Atmosphere", Default = Perf.NoAtmosphere,
    Callback = function(on) Perf.NoAtmosphere = on; Perf:Apply(); Perf:Save() end,
})
window:AddToggle(mainGB, "_PerfTime", {
    Text = "Force Time of Day", Default = Perf.ForceTime,
    Callback = function(on) Perf.ForceTime = on; Perf:Apply(); Perf:Save() end,
})
window:AddSlider(mainGB, "_PerfHour", {
    Text = "Time (hour)", Min = 0, Max = 24, Default = Perf.TimeOfDay,
    Callback = function(v) Perf.TimeOfDay = v; Perf:Apply(); Perf:Save() end,
})
window:AddToggle(mainGB, "_PerfMap", {
    Text = "Hide Map", Default = Perf.HideMap,
    Callback = function(on) Perf.HideMap = on; Perf:Apply(); Perf:Save() end,
})
window:AddToggle(mainGB, "_PerfOthers", {
    Text = "Hide Other Players", Default = Perf.HideOthers,
    Callback = function(on) Perf.HideOthers = on; Perf:Apply(); Perf:Save() end,
})
window:AddToggle(mainGB, "_PerfSelf", {
    Text = "Hide Character", Default = Perf.HideSelf,
    Callback = function(on) Perf.HideSelf = on; Perf:Apply(); Perf:Save() end,
})
window:AddToggle(mainGB, "_Perf3D", {
    Text = "No 3D Render", Default = Perf.No3D,
    Callback = function(on) Perf.No3D = on; Perf:Apply(); Perf:Save() end,
})
window:AddSlider(mainGB, "_PerfFPS", {
    Text = "FPS Cap (0 = unlimited)", Min = 0, Max = 360, Default = Perf.FPSCap,
    Callback = function(v) Perf.FPSCap = v; Perf:Apply(); Perf:Save() end,
})

if Perf.Master then Perf:Apply() end
print("[ToRung/UI-PERF] tab added")
