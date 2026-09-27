-- ============================================================
-- Slayers 2 Delta - UI (Fixed v3)
-- ============================================================

local S2 = getgenv().S2
if not S2 or not S2.Core then return warn("[S2/UI] Core chưa chạy") end
if not S2.Features then return warn("[S2/UI] Features chưa chạy") end

local Core = S2.Core
local Feat = S2.Features

local Runtime = Core.Runtime
local GameAPI = Core.GameAPI
local Combat = Core.Combat
local MobIndex = Core.MobIndex
local Movement = Core.Movement

local Features = Feat.Features
local QuestEngine = Feat.QuestEngine
local FinalSelection = Feat.FinalSelection
local CrowQuest = Feat.CrowQuest
local MuzanQuest = Feat.MuzanQuest
local Mastery = Feat.Mastery
local GenericQuest = Feat.GenericQuest

local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Themes = {
    Background = Color3.fromRGB(14,14,18),
    Panel = Color3.fromRGB(20,20,26),
    Stroke = Color3.fromRGB(36,36,44),
    Accent = Color3.fromRGB(138,121,231),
    AccentText = Color3.fromRGB(180,165,245),
    Text = Color3.fromRGB(200,200,210),
    SubText = Color3.fromRGB(130,130,145),
    ElementBg = Color3.fromRGB(16,16,22),
    ElementStroke = Color3.fromRGB(30,30,38),
    ToggleOn = Color3.fromRGB(138,121,231),
    ToggleOff = Color3.fromRGB(40,40,50),
    Danger = Color3.fromRGB(206,51,66),
    Success = Color3.fromRGB(56,186,91),
}

local UI = {}
UI.__index = UI

local function new(cls, props, children)
    local i = Instance.new(cls)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then i[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = i end
    if props and props.Parent then i.Parent = props.Parent end
    return i
end

local function tw(inst, time, goal)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
    t:Play()
    return t
end

function UI.CreateWindow(title, version)
    local parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    local sg = new("ScreenGui", {
        Name = "S2DeltaUI", ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 9999,
        Parent = parent,
    })
    local main = new("Frame", {
        Name = "Main", Parent = sg,
        BackgroundColor3 = Themes.Background, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(580, 440),
    })
    new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = main })
    new("UIStroke", { Color = Themes.Stroke, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = main })

    local topBar = new("Frame", {
        Parent = main, BackgroundColor3 = Themes.Panel, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 40),
    })
    new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = topBar })
    new("TextLabel", {
        Parent = topBar, BackgroundTransparency = 1,
        Text = title.."  |  "..(version or ""),
        TextColor3 = Themes.Text, TextSize = 15, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -50, 1, 0),
    })
    local closeBtn = new("TextButton", {
        Parent = topBar, BackgroundTransparency = 1, Text = "X",
        TextColor3 = Themes.SubText, TextSize = 16, Font = Enum.Font.GothamBold,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
    })
    closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

    local tabHolder = new("Frame", {
        Parent = main, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 40), Size = UDim2.new(0, 140, 1, -40),
    })
    local tabScroll = new("ScrollingFrame", {
        Parent = tabHolder, BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0,
    })
    new("UIListLayout", { Parent = tabScroll, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
    new("UIPadding", { Parent = tabScroll, PaddingTop = UDim.new(0, 8) })

    local contentHolder = new("Frame", {
        Parent = main, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(140, 40), Size = UDim2.new(1, -140, 1, -40),
    })
    new("Frame", {
        Parent = main, BackgroundColor3 = Themes.Stroke, BorderSizePixel = 0,
        Position = UDim2.fromOffset(140, 40), Size = UDim2.new(0, 1, 1, -40),
    })

    local dragging, dragStart, startPos = false, nil, nil
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, main.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)

    if UIS.TouchEnabled and not UIS.KeyboardEnabled then
        local mb = new("TextButton", {
            Parent = sg, BackgroundColor3 = Themes.Accent, BorderSizePixel = 0,
            Text = "S2", TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold,
            TextSize = 16, AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(48, 48), ZIndex = 9998,
        })
        new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = mb })
        mb.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)
    end

    local w = setmetatable({
        Screen = sg, Main = main, TopBar = topBar,
        TabHolder = tabScroll, ContentHolder = contentHolder,
        Tabs = {}, ActiveTab = nil, Flags = {}, Options = {},
    }, UI)
    w.ToggleKey = Enum.KeyCode.RightShift
    UIS.InputBegan:Connect(function(input, proc)
        if not proc and input.KeyCode == w.ToggleKey then
            main.Visible = not main.Visible
        end
    end)
    return w
end

function UI:AddTab(name)
    local btn = new("TextButton", {
        Parent = self.TabHolder, BackgroundColor3 = Themes.Panel, BorderSizePixel = 0,
        Text = name, TextColor3 = Themes.SubText, TextSize = 14, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -8, 0, 32),
    })
    new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = btn })
    new("UIPadding", { Parent = btn, PaddingLeft = UDim.new(0, 10) })

    local page = new("ScrollingFrame", {
        Parent = self.ContentHolder, BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
        ScrollBarImageColor3 = Themes.Stroke, Visible = false,
    })
    new("UIListLayout", { Parent = page, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
    new("UIPadding", { Parent = page, PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })

    local tab = { Button = btn, Page = page, Window = self, Name = name }
    btn.MouseButton1Click:Connect(function()
        if self.ActiveTab == tab then return end
        if self.ActiveTab then
            self.ActiveTab.Page.Visible = false
            tw(self.ActiveTab.Button, 0.15, { TextColor3 = Themes.SubText, BackgroundColor3 = Themes.Panel })
        end
        self.ActiveTab = tab
        page.Visible = true
        tw(btn, 0.15, { TextColor3 = Themes.AccentText, BackgroundColor3 = Themes.ElementBg })
    end)
    btn.MouseEnter:Connect(function()
        if self.ActiveTab ~= tab then tw(btn, 0.1, { TextColor3 = Themes.Text }) end
    end)
    btn.MouseLeave:Connect(function()
        if self.ActiveTab ~= tab then tw(btn, 0.15, { TextColor3 = Themes.SubText }) end
    end)

    table.insert(self.Tabs, tab)
    if not self.ActiveTab then
        self.ActiveTab = tab
        page.Visible = true
        btn.TextColor3 = Themes.AccentText
        btn.BackgroundColor3 = Themes.ElementBg
    end
    return tab
end

function UI:AddGroupbox(tab, name)
    local gb = new("Frame", {
        Parent = tab.Page, BackgroundColor3 = Themes.Panel, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
    })
    new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = gb })
    new("UIStroke", { Color = Themes.Stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = gb })
    new("TextLabel", {
        Parent = gb, BackgroundTransparency = 1, Text = name,
        TextColor3 = Themes.AccentText, TextSize = 15, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 24),
    })
    local cont = new("Frame", {
        Parent = gb, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 30),
        AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
    })
    new("UIListLayout", { Parent = cont, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
    new("UIPadding", { Parent = cont, PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
    return { Frame = gb, Container = cont, Tab = tab }
end

-- ============ AddToggle (FIXED) ============
function UI:AddToggle(gb, flag, cfg)
    local window = gb.Tab.Window       -- ← FIX
    cfg = cfg or {}
    local h = new("Frame", { Parent = gb.Container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32) })
    new("TextLabel", {
        Parent = h, BackgroundTransparency = 1, Text = cfg.Text or "Toggle",
        TextColor3 = Themes.Text, TextSize = 14, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -60, 1, 0),
    })
    local box = new("Frame", {
        Parent = h, BackgroundColor3 = Themes.ToggleOff, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(36, 18),
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = box })
    local knob = new("Frame", {
        Parent = box, BackgroundColor3 = Color3.fromRGB(200,200,210), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 9, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

    local st = { Value = cfg.Default or false, Callback = cfg.Callback, Type = "Toggle", Flag = flag }
    local function render()
        if st.Value then
            tw(box, 0.15, { BackgroundColor3 = Themes.ToggleOn })
            tw(knob, 0.15, { Position = UDim2.new(1, -9, 0.5, 0) })
        else
            tw(box, 0.15, { BackgroundColor3 = Themes.ToggleOff })
            tw(knob, 0.15, { Position = UDim2.new(0, 9, 0.5, 0) })
        end
    end
    st.SetValue = function(_, v, silent)
        st.Value = v and true or false
        if flag then window.Flags[flag] = st.Value end    -- ← FIX
        render()
        if not silent and type(st.Callback) == "function" then task.spawn(st.Callback, st.Value) end
    end
    local click = new("TextButton", { Parent = h, BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 3 })
    click.MouseButton1Click:Connect(function() st:SetValue(not st.Value) end)
    if flag then window.Flags[flag] = st.Value; window.Options[flag] = st end   -- ← FIX
    render()
    return st
end

-- ============ AddSlider (FIXED) ============
function UI:AddSlider(gb, flag, cfg)
    local window = gb.Tab.Window       -- ← FIX
    cfg = cfg or {}
    local min, max = cfg.Min or 0, cfg.Max or 100
    local suffix = cfg.Suffix or ""
    local dec = cfg.Decimals or 0

    local h = new("Frame", { Parent = gb.Container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44) })
    new("TextLabel", {
        Parent = h, BackgroundTransparency = 1, Text = cfg.Text or "Slider",
        TextColor3 = Themes.Text, TextSize = 14, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.6, 0, 0, 16),
    })
    local vl = new("TextLabel", {
        Parent = h, BackgroundTransparency = 1, Text = "0"..suffix,
        TextColor3 = Themes.AccentText, TextSize = 13, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4),
        Size = UDim2.new(0.4, 0, 0, 16),
    })
    local track = new("Frame", {
        Parent = h, BackgroundColor3 = Themes.ElementBg, BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 6),
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    local fill = new("Frame", { Parent = track, BackgroundColor3 = Themes.Accent, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0) })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
    local knob = new("Frame", {
        Parent = track, BackgroundColor3 = Color3.fromRGB(230,230,240), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(12, 12),
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

    local st = { Value = cfg.Default or min, Callback = cfg.Callback, Type = "Slider", Flag = flag }
    local function round(v)
        if dec <= 0 then return math.floor(v + 0.5) end
        local m = 10 ^ dec
        return math.floor(v * m + 0.5) / m
    end
    local function render()
        local r = (st.Value - min) / (max - min)
        fill.Size = UDim2.new(r, 0, 1, 0)
        knob.Position = UDim2.new(r, 0, 0.5, 0)
        vl.Text = tostring(st.Value)..suffix
    end
    local dragging = false
    local function setX(x)
        local r = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        st:SetValue(round(min + (max - min) * r))
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; setX(input.Position.X)
        end
    end)
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setX(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    st.SetValue = function(_, v, silent)
        st.Value = round(math.clamp(v, min, max))
        if flag then window.Flags[flag] = st.Value end    -- ← FIX
        render()
        if not silent and type(st.Callback) == "function" then task.spawn(st.Callback, st.Value) end
    end
    if flag then window.Flags[flag] = st.Value; window.Options[flag] = st end   -- ← FIX
    render()
    return st
end

function UI:AddButton(gb, cfg)
    cfg = cfg or {}
    local btn = new("TextButton", {
        Parent = gb.Container, BackgroundColor3 = cfg.Color or Themes.ElementBg,
        BorderSizePixel = 0, Text = cfg.Text or "Button",
        TextColor3 = Themes.Text, TextSize = 14, Font = Enum.Font.Gotham,
        Size = UDim2.new(1, -10, 0, 30),
    })
    new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = btn })
    new("UIStroke", { Color = Themes.ElementStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn })
    btn.MouseEnter:Connect(function() tw(btn, 0.1, { BackgroundColor3 = Themes.Panel }) end)
    btn.MouseLeave:Connect(function() tw(btn, 0.15, { BackgroundColor3 = cfg.Color or Themes.ElementBg }) end)
    btn.MouseButton1Click:Connect(function()
        if type(cfg.Func) == "function" then task.spawn(cfg.Func) end
    end)
    return {
        Type = "Button",
        SetText = function(_, t) btn.Text = t end,
        SetColor = function(_, c) btn.BackgroundColor3 = c end,
    }
end

-- ============ AddDropdown (FIXED) ============
function UI:AddDropdown(gb, flag, cfg)
    local window = gb.Tab.Window       -- ← FIX
    cfg = cfg or {}
    local values = cfg.Values or {}
    local multi = cfg.Multi or false

    local h = new("Frame", { Parent = gb.Container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34) })
    new("TextLabel", {
        Parent = h, BackgroundTransparency = 1, Text = cfg.Text or "Dropdown",
        TextColor3 = Themes.Text, TextSize = 14, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.4, 0, 1, 0),
    })
    local box = new("TextButton", {
        Parent = h, BackgroundColor3 = Themes.ElementBg, BorderSizePixel = 0,
        Text = "--", TextColor3 = Themes.SubText, TextSize = 13, Font = Enum.Font.Gotham,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0.55, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left,
    })
    new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })
    new("UIStroke", { Color = Themes.ElementStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = box })
    new("UIPadding", { Parent = box, PaddingLeft = UDim.new(0, 8) })

    local st = {
        Value = multi and (type(cfg.Default) == "table" and cfg.Default or {}) or cfg.Default,
        Values = values, Multi = multi, Callback = cfg.Callback,
        Type = "Dropdown", Flag = flag, Open = false, Menu = nil, Catcher = nil,
    }

    local function render()
        if multi then
            local parts = {}
            for _, v in ipairs(st.Value or {}) do table.insert(parts, tostring(v)) end
            box.Text = #parts > 0 and table.concat(parts, ", ") or "--"
        else
            box.Text = st.Value and tostring(st.Value) or "--"
        end
    end
    local function close()
        if not st.Open then return end
        st.Open = false
        if st.Catcher then st.Catcher:Destroy(); st.Catcher = nil end
        if st.Menu then st.Menu:Destroy(); st.Menu = nil end
    end
    local function isSel(v)
        if multi then
            for _, x in ipairs(st.Value) do if x == v then return true end end
            return false
        end
        return st.Value == v
    end
    local function open()
        close()
        st.Open = true
        local screen = window.Screen
        st.Catcher = new("TextButton", {
            Parent = screen, Text = "", BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 99,
        })
        st.Catcher.MouseButton1Click:Connect(close)
        local menu = new("ScrollingFrame", {
            Parent = screen, BackgroundColor3 = Themes.Panel, BorderSizePixel = 0,
            Position = UDim2.fromOffset(box.AbsolutePosition.X, box.AbsolutePosition.Y + box.AbsoluteSize.Y + 4),
            Size = UDim2.fromOffset(math.max(box.AbsoluteSize.X, 180), math.min(#values * 26 + 8, 240)),
            CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Themes.Stroke, ZIndex = 100,
        })
        new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = menu })
        new("UIStroke", { Color = Themes.Stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = menu })
        new("UIListLayout", { Parent = menu, SortOrder = Enum.SortOrder.LayoutOrder })
        new("UIPadding", { Parent = menu, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) })
        st.Menu = menu
        for i, v in ipairs(values) do
            local item = new("TextButton", {
                Parent = menu, LayoutOrder = i, BackgroundColor3 = Themes.Panel, BorderSizePixel = 0,
                Text = tostring(v), TextColor3 = isSel(v) and Themes.AccentText or Themes.Text,
                TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, 0, 0, 26), ZIndex = 101,
            })
            new("UIPadding", { Parent = item, PaddingLeft = UDim.new(0, 8) })
            item.MouseEnter:Connect(function() item.BackgroundColor3 = Themes.ElementBg end)
            item.MouseLeave:Connect(function() item.BackgroundColor3 = Themes.Panel end)
            item.MouseButton1Click:Connect(function()
                if multi then
                    local found
                    for k, x in ipairs(st.Value) do
                        if x == v then table.remove(st.Value, k); found = true; break end
                    end
                    if not found then table.insert(st.Value, v) end
                    render()
                    if flag then window.Flags[flag] = st.Value end    -- ← FIX
                    if type(st.Callback) == "function" then task.spawn(st.Callback, st.Value) end
                else
                    st.Value = v
                    render()
                    if flag then window.Flags[flag] = st.Value end    -- ← FIX
                    if type(st.Callback) == "function" then task.spawn(st.Callback, st.Value) end
                    close()
                end
            end)
        end
    end
    box.MouseButton1Click:Connect(function() if st.Open then close() else open() end end)
    st.SetValue = function(_, v, silent)
        st.Value = v
        if flag then window.Flags[flag] = v end    -- ← FIX
        render()
        if not silent and type(st.Callback) == "function" then task.spawn(st.Callback, v) end
    end
    st.SetValues = function(_, nv)
        st.Values = nv; values = nv; close()
    end
    if flag then window.Flags[flag] = st.Value; window.Options[flag] = st end   -- ← FIX
    render()
    return st
end

-- ============ AddInput (FIXED) ============
function UI:AddInput(gb, flag, cfg)
    local window = gb.Tab.Window       -- ← FIX
    cfg = cfg or {}
    local h = new("Frame", { Parent = gb.Container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32) })
    new("TextLabel", {
        Parent = h, BackgroundTransparency = 1, Text = cfg.Text or "Input",
        TextColor3 = Themes.Text, TextSize = 14, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.4, 0, 1, 0),
    })
    local box = new("TextBox", {
        Parent = h, BackgroundColor3 = Themes.ElementBg, BorderSizePixel = 0,
        Text = cfg.Default or "", TextColor3 = Themes.Text,
        PlaceholderText = cfg.Placeholder or "Write...", PlaceholderColor3 = Themes.SubText,
        TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0.55, 0, 0, 26), ClearTextOnFocus = false,
    })
    new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = box })
    new("UIStroke", { Color = Themes.ElementStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = box })
    new("UIPadding", { Parent = box, PaddingLeft = UDim.new(0, 8) })

    local st = { Value = cfg.Default or "", Callback = cfg.Callback, Type = "Input", Flag = flag }
    box.FocusLost:Connect(function()
        st.Value = box.Text
        if flag then window.Flags[flag] = st.Value end    -- ← FIX
        if type(st.Callback) == "function" then task.spawn(st.Callback, st.Value) end
    end)
    st.SetValue = function(_, v, silent)
        st.Value = v; box.Text = tostring(v)
        if flag then window.Flags[flag] = v end    -- ← FIX
        if not silent and type(st.Callback) == "function" then task.spawn(st.Callback, v) end
    end
    if flag then window.Flags[flag] = st.Value; window.Options[flag] = st end   -- ← FIX
    return st
end

function UI:Notify(cfg)
    cfg = cfg or {}
    local dur = cfg.Duration or 4
    local color = cfg.Color or Themes.Accent
    local h = new("Frame", {
        Parent = self.Screen, BackgroundColor3 = Themes.Panel, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10),
        Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y,
    })
    new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = h })
    new("UIStroke", { Color = color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = h })
    new("UIPadding", { Parent = h, PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
    new("TextLabel", {
        Parent = h, BackgroundTransparency = 1, Text = cfg.Title or "Notification",
        TextColor3 = color, TextSize = 14, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18),
    })
    if cfg.Description then
        new("TextLabel", {
            Parent = h, BackgroundTransparency = 1, Text = cfg.Description,
            TextColor3 = Themes.SubText, TextSize = 12, Font = Enum.Font.Gotham,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        })
    end
    local origin = h.Position
    h.Position = origin + UDim2.fromOffset(300, 0)
    tw(h, 0.25, { Position = origin })
    task.delay(dur, function()
        tw(h, 0.25, { Position = origin + UDim2.fromOffset(300, 0) })
        task.wait(0.3); h:Destroy()
    end)
    return h
end

local Win

local function buildUI()
    local w = UI.CreateWindow("ZERO HUB", "Delta v9")
    Win = w

    local farmTab = w:AddTab("Farm")
    local mobGB = w:AddGroupbox(farmTab, "Mob Farm")
    local mobCfgGB = w:AddGroupbox(farmTab, "Mob Config")
    local bossGB = w:AddGroupbox(farmTab, "Boss Farm")

    local mobNames = { "Nearest Mob" }
    for n in pairs(GameAPI.MobSpawns) do table.insert(mobNames, n) end
    table.sort(mobNames)

    w:AddDropdown(mobGB, "_MobSelect", {
        Text = "Target Mob", Values = mobNames,
        Default = "Nearest Mob", Multi = false,
        Callback = function(v) Features.Config.MobFarm.Target = v end,
    })
    w:AddToggle(mobGB, "_MobFarm", {
        Text = "Mob Farm", Default = false,
        Callback = function(on)
            if on then Features:StartMobFarm() else Features:StopMobFarm() end
        end,
    })
    w:AddToggle(mobGB, "_KillAura", {
        Text = "Kill Aura", Default = false,
        Callback = function(on)
            if on then Features:StartKillAura() else Features:StopKillAura() end
        end,
    })

    w:AddDropdown(mobCfgGB, "_MobEquip", { Text = "Equip Slot",
        Values = { "0","1","2","3","4","5" }, Default = "0",
        Callback = function(v) Features.Config.MobFarm.EquipSlot = tonumber(v) or 0 end })
    w:AddDropdown(mobCfgGB, "_MobWeapon", { Text = "Weapon",
        Values = Combat.Weapons, Default = "Combat",
        Callback = function(v) Features.Config.MobFarm.Weapon = v end })
    w:AddDropdown(mobCfgGB, "_MobMode", { Text = "Position",
        Values = { "Above","Below","In Front","Behind" }, Default = "Below",
        Callback = function(v) Features.Config.MobFarm.Mode = v end })
    w:AddSlider(mobCfgGB, "_MobDist", { Text = "Distance", Min = 0, Max = 50, Default = 6.5,
        Callback = function(v) Features.Config.MobFarm.Distance = v end })

    w:AddToggle(bossGB, "_PickupAura", {
        Text = "Pickup Aura", Default = false,
        Callback = function(on)
            if on then Features:StartPickupAura() else Features:StopPickupAura() end
        end,
    })

    local questTab = w:AddTab("Quests")
    local crowGB = w:AddGroupbox(questTab, "Crow")
    local muzGB = w:AddGroupbox(questTab, "Muzan")
    local fsGB = w:AddGroupbox(questTab, "Final Selection")
    local dlvGB = w:AddGroupbox(questTab, "Delivery")

    w:AddToggle(crowGB, "_Crow", {
        Text = "Auto Crow Quest", Default = false,
        Callback = function(on)
            if on then Features:StartCrowQuest() else Features:StopCrowQuest() end
        end,
    })
    w:AddToggle(muzGB, "_Muzan", {
        Text = "Auto Muzan Quest", Default = false,
        Callback = function(on)
            if on then Features:StartMuzanQuest() else Features:StopMuzanQuest() end
        end,
    })
    w:AddSlider(muzGB, "_BellSlot", { Text = "Biwa Bell Slot", Min = 1, Max = 8, Default = 1,
        Callback = function(v) MuzanQuest.BellSlot = v end })

    w:AddToggle(fsGB, "_FinalSelection", {
        Text = "Auto Final Selection", Default = false,
        Callback = function(on)
            if on then
                local ok, err = Features:StartFinalSelection()
                if not ok and err then
                    Win:Notify({ Title = "FS", Description = tostring(err), Color = Themes.Danger })
                end
            else
                Features:StopFinalSelection()
            end
        end,
    })

    w:AddToggle(dlvGB, "_Delivery", {
        Text = "Auto Delivery Quests", Default = false,
        Callback = function(on)
            if on then Features:StartGenericQuest("Delivery") else Features:StopGenericQuest() end
        end,
    })

    local mastTab = w:AddTab("Mastery")
    local mastGB = w:AddGroupbox(mastTab, "Auto Mastery")
    local mastCfgGB = w:AddGroupbox(mastTab, "Config")
    local mastSkillGB = w:AddGroupbox(mastTab, "Skill Finisher")

    local bossValues = { "All Bosses" }
    for _, b in ipairs(Mastery.BossList) do table.insert(bossValues, b.name) end

    w:AddDropdown(mastGB, "_MastTargets", {
        Text = "Target Bosses", Values = bossValues,
        Default = { "All Bosses" }, Multi = true,
        Callback = function(vals)
            Mastery.Targets = {}
            if type(vals) == "table" then
                for k, v in pairs(vals) do
                    if type(k) == "string" and v == true then Mastery.Targets[k] = true
                    elseif type(v) == "string" then Mastery.Targets[v] = true end
                end
            end
        end,
    })
    w:AddToggle(mastGB, "_Mastery", {
        Text = "Auto Mastery", Default = false,
        Callback = function(on)
            if on then Features:StartMastery() else Features:StopMastery() end
        end,
    })

    w:AddDropdown(mastCfgGB, "_MastEquip", { Text = "Equip Slot",
        Values = { "0","1","2","3","4","5" }, Default = "0",
        Callback = function(v) Mastery.EquipSlot = tonumber(v) or 0 end })
    w:AddDropdown(mastCfgGB, "_MastWeapon", { Text = "Weapon",
        Values = Combat.Weapons, Default = "Combat",
        Callback = function(v) Mastery.Weapon = v end })
    w:AddDropdown(mastCfgGB, "_MastMode", { Text = "Position",
        Values = { "Above","Below","In Front","Behind" }, Default = "Below",
        Callback = function(v) Mastery.Mode = v end })
    w:AddSlider(mastCfgGB, "_MastDist", { Text = "Distance", Min = 0, Max = 50, Default = 6.5,
        Callback = function(v) Mastery.Distance = v end })
    w:AddSlider(mastCfgGB, "_MastHP", { Text = "Switch at HP", Min = 1, Max = 500, Default = 60,
        Callback = function(v) Mastery.HpThreshold = v end })

    local keys = { "Z","X","C","V","B","R","Q","E","G","T" }
    w:AddDropdown(mastSkillGB, "_MastKeys", { Text = "Skills to press",
        Values = keys, Default = {}, Multi = true,
        Callback = function(vals)
            Mastery.SkillKeys = {}
            if type(vals) == "table" then
                for k, v in pairs(vals) do
                    if type(k) == "string" and v == true then table.insert(Mastery.SkillKeys, k)
                    elseif type(v) == "string" then table.insert(Mastery.SkillKeys, v) end
                end
            end
        end,
    })
    w:AddSlider(mastSkillGB, "_MastRate", { Text = "Seconds between skills", Min = 0.2, Max = 10, Default = 1.5, Decimals = 1,
        Callback = function(v) Mastery.SkillRate = v end })
    w:AddDropdown(mastSkillGB, "_MastHold", { Text = "Skills to hold",
        Values = keys, Default = {}, Multi = true,
        Callback = function(vals)
            Mastery.HoldKeys = {}
            if type(vals) == "table" then
                for k, v in pairs(vals) do
                    if type(k) == "string" and v == true then table.insert(Mastery.HoldKeys, k)
                    elseif type(v) == "string" then table.insert(Mastery.HoldKeys, v) end
                end
            end
        end,
    })
    w:AddSlider(mastSkillGB, "_MastHoldDur", { Text = "Hold duration", Min = 0.5, Max = 15, Default = 3, Decimals = 1,
        Callback = function(v) Mastery.HoldDuration = v end })

    local playerTab = w:AddTab("Player")
    local tpGB = w:AddGroupbox(playerTab, "Teleport")
    local npcNames = {}
    for n in pairs(GameAPI.NPCSpawns) do table.insert(npcNames, n) end
    table.sort(npcNames)
    w:AddDropdown(tpGB, "_NPCSelect", { Text = "NPC", Values = npcNames, Default = nil })
    w:AddButton(tpGB, { Text = "Teleport to NPC",
        Func = function()
            local v = Win.Flags._NPCSelect
            if v then
                local ok, err = Features:TeleportToNPC(v)
                Win:Notify({ Title = ok and "TP OK" or "TP Fail",
                    Description = ok and ("to "..v) or tostring(err),
                    Color = ok and Themes.Success or Themes.Danger })
            end
        end,
    })
    w:AddButton(tpGB, { Text = "Refresh NPC List",
        Func = function()
            GameAPI:DiscoverNPCSpawns()
            local names = {}
            for n in pairs(GameAPI.NPCSpawns) do table.insert(names, n) end
            table.sort(names)
            Win.Options._NPCSelect:SetValues(names)
            Win:Notify({ Title = "Refreshed", Color = Themes.Success })
        end,
    })

    local settingsTab = w:AddTab("Settings")
    local stGB = w:AddGroupbox(settingsTab, "Menu")
    w:AddButton(stGB, { Text = "Unload Script", Color = Themes.Danger,
        Func = function()
            if S2.Unload then S2.Unload() end
        end,
    })
    return w
end

local SelfTest = { Pass = 0, Fail = 0, Warn = 0 }

local function record(n, s, d)
    if s == "PASS" then SelfTest.Pass += 1; print(string.format("  [+] %-38s %s", n, d or ""))
    elseif s == "FAIL" then SelfTest.Fail += 1; warn(string.format("  [x] %-38s %s", n, d or ""))
    else SelfTest.Warn += 1; warn(string.format("  [!] %-38s %s", n, d or "")) end
end

local function T(n, fn)
    local ok, r = pcall(fn)
    if not ok then record(n, "FAIL", tostring(r)); return false end
    if r == true or r == nil then record(n, "PASS", ""); return true end
    if r == false then record(n, "FAIL", ""); return false end
    if type(r) == "table" and r.warn then record(n, "WARN", r.detail); return true end
    record(n, "PASS", tostring(r))
    return true
end

function SelfTest:RunAll()
    print("")
    print("======================================================")
    print("[S2/UI] RUNTIME SELF-TEST")
    print("======================================================")
    T("Runtime alive", function() assert(Runtime.Alive == true); return true end)
    T("SignalEvent", function() assert(type(GameAPI.SignalEvent) == "table"); return true end)
    T("Utility", function() assert(type(GameAPI.Utility) == "table"); return true end)
    T("Quests", function() assert(type(GameAPI.Quests) == "table"); return true end)
    T("Combat remote", function() assert(Combat.Remote ~= nil); return true end)
    T("LocalPlayer", function() assert(LocalPlayer ~= nil); return true end)
    T("Character", function()
        if not LocalPlayer.Character then return { warn = true, detail = "not spawned" } end
        return true
    end)
    T("HRP", function()
        if not GameAPI:GetRoot() then return { warn = true, detail = "missing" } end
        return true
    end)
    T("Mob spawns", function()
        local c = 0; for _ in pairs(GameAPI.MobSpawns) do c += 1 end
        assert(c > 0); return c .. " mobs"
    end)
    T("NPC spawns", function()
        local c = 0; for _ in pairs(GameAPI.NPCSpawns) do c += 1 end
        if c == 0 then return { warn = true, detail = "empty" } end
        return c .. " NPCs"
    end)
    T("MobIndex", function() assert(MobIndex.Started); return true end)
    T("Movement", function() assert(Movement.Conn ~= nil); return true end)
    T("Window", function() assert(Win ~= nil); return true end)
    T("UI tabs", function() assert(#Win.Tabs >= 5); return #Win.Tabs .. " tabs" end)
    T("Feature methods", function()
        for _, m in ipairs({ "StartMobFarm","StopMobFarm","StartCrowQuest","StartMuzanQuest","StartFinalSelection","StartMastery","StartGenericQuest","StartKillAura","StartPickupAura" }) do
            assert(type(Features[m]) == "function", "missing "..m)
        end
        return true
    end)
    print("")
    print("======================================================")
    print(string.format("[S2/UI] PASS: %d  FAIL: %d  WARN: %d", SelfTest.Pass, SelfTest.Fail, SelfTest.Warn))
    print("======================================================")
    return SelfTest.Fail == 0
end

local ok, err = xpcall(function()
    buildUI()
    S2.UI = { Lib = UI, Window = Win, Themes = Themes }
    S2.Unload = function()
        if Core.Unload then Core.Unload() end
        pcall(function() Win.Screen:Destroy() end)
        getgenv().S2 = nil
    end
    task.wait(0.3)
    local passed = SelfTest:RunAll()
    Win:Notify({
        Title = passed and "Loaded" or "Loaded with warnings",
        Description = string.format("%d features ready. %d PASS, %d FAIL.", #Win.Tabs, SelfTest.Pass, SelfTest.Fail),
        Color = passed and Themes.Success or Themes.Danger,
        Duration = 6,
    })
end, debug.traceback)

if not ok then
    warn("[S2/UI] STARTUP FAILED:", err)
else
    print("======================================================")
    print("[S2/UI] READY - Press RightShift to toggle menu")
    print("======================================================")
end
