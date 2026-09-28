-- lobby.lua - Separate Lobby HUD for server selection
local S2 = getgenv().S2
if not S2 or not S2.Core or not S2.VIP then
    return warn("[Lobby] deps missing")
end

local VIP = S2.VIP
local log = S2.Core.log
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local SHOW_KEY = "ToRungHub/lobby_shown.txt"

local Themes = {
    Bg = Color3.fromRGB(14, 14, 18),
    Panel = Color3.fromRGB(20, 20, 26),
    Stroke = Color3.fromRGB(36, 36, 44),
    Accent = Color3.fromRGB(138, 121, 231),
    Text = Color3.fromRGB(200, 200, 210),
    SubText = Color3.fromRGB(130, 130, 145),
    ElementBg = Color3.fromRGB(16, 16, 22),
    ElementStroke = Color3.fromRGB(30, 30, 38),
    Success = Color3.fromRGB(56, 186, 91),
    Danger = Color3.fromRGB(206, 51, 66),
}

local function new(cls, props, children)
    local i = Instance.new(cls)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then i[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = i end
    if props and props.Parent then i.Parent = props.Parent end
    return i
end

local Lobby = {}
Lobby.Window = nil
Lobby.Flags = {}

local function wasShownBefore()
    if not isfolder("ToRungHub") then makefolder("ToRungHub") end
    return isfile(SHOW_KEY)
end

local function markShown()
    if not isfolder("ToRungHub") then makefolder("ToRungHub") end
    pcall(function() writefile(SHOW_KEY, "1") end)
end

local function makeLabel(parent, text, size, pos, color)
    return new("TextLabel", {
        Parent = parent, BackgroundTransparency = 1,
        Text = text, TextColor3 = color or Themes.Text,
        TextSize = size or 13, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = pos or UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 16),
    })
end

function Lobby:Build()
    if self.Window then return end

    local parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    local sg = new("ScreenGui", {
        Name = "ToRungLobby",
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 9998, Parent = parent,
    })

    local main = new("Frame", {
        Name = "LobbyMain", Parent = sg,
        BackgroundColor3 = Themes.Bg, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(360, 440),
        Visible = true,
    })
    new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = main })
    new("UIStroke", { Color = Themes.Stroke, Thickness = 1.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = main })

    -- Top bar
    local top = new("Frame", {
        Parent = main, BackgroundColor3 = Themes.Panel,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 36),
    })
    new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = top })
    makeLabel(top, "  Server Lobby", 14, UDim2.new(0, 8, 0, 8), Themes.Text)
    local close = new("TextButton", {
        Parent = top, BackgroundTransparency = 1,
        Text = "X", TextColor3 = Themes.SubText, TextSize = 14,
        Font = Enum.Font.GothamBold,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
    })
    close.MouseButton1Click:Connect(function() main.Visible = false end)

    -- Enable toggle
    local enableRow = new("Frame", {
        Parent = main, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 48),
        Size = UDim2.new(1, -24, 0, 24),
    })
    makeLabel(enableRow, "Enable VIP Server", 13, UDim2.new(0, 0, 0, 4))
    local enableBtn = new("TextButton", {
        Parent = enableRow, BackgroundColor3 = VIP.Enabled and Themes.Success or Themes.ElementBg,
        BorderSizePixel = 0, Text = VIP.Enabled and "ON" or "OFF",
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 12,
        Font = Enum.Font.GothamBold,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 2),
        Size = UDim2.fromOffset(50, 20),
    })
    new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = enableBtn })
    enableBtn.MouseButton1Click:Connect(function()
        VIP.Enabled = not VIP.Enabled
        enableBtn.Text = VIP.Enabled and "ON" or "OFF"
        enableBtn.BackgroundColor3 = VIP.Enabled and Themes.Success or Themes.ElementBg
        VIP:Save()
    end)

    -- Mode dropdown (simple 3-button toggle)
    makeLabel(main, "Mode:", 13, UDim2.fromOffset(12, 82))
    local modes = { "MyPS", "ServerID", "Link" }
    local modeButtons = {}
    for i, mode in ipairs(modes) do
        local btn = new("TextButton", {
            Parent = main, BackgroundColor3 = VIP.Mode == mode and Themes.Accent or Themes.ElementBg,
            BorderSizePixel = 0, Text = mode,
            TextColor3 = VIP.Mode == mode and Color3.fromRGB(255, 255, 255) or Themes.Text,
            TextSize = 11, Font = Enum.Font.Gotham,
            Position = UDim2.fromOffset(60 + (i - 1) * 92, 80),
            Size = UDim2.fromOffset(86, 22),
        })
        new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = btn })
        modeButtons[mode] = btn
        btn.MouseButton1Click:Connect(function()
            VIP.Mode = mode
            for m, b in pairs(modeButtons) do
                local sel = (m == mode)
                b.BackgroundColor3 = sel and Themes.Accent or Themes.ElementBg
                b.TextColor3 = sel and Color3.fromRGB(255, 255, 255) or Themes.Text
            end
            VIP:Save()
        end)
    end

    -- Info line
    local info = makeLabel(main, "", 11, UDim2.fromOffset(12, 112), Themes.SubText)
    info.Size = UDim2.new(1, -24, 0, 16)

    local function refreshInfo()
        if VIP.Mode == "MyPS" or VIP.Mode == "ServerID" then
            if VIP.ServerId ~= "" then
                info.Text = "PlaceId: " .. tostring(VIP.PlaceId)
                    .. "  Server: " .. tostring(VIP.ServerId):sub(1, 16) .. "..."
            else
                info.Text = "Not configured. Capture or paste server ID below."
            end
        elseif VIP.Mode == "Link" then
            info.Text = VIP.LinkCode ~= "" and ("LinkCode: " .. VIP.LinkCode:sub(1, 20) .. "...") or "No link set."
        end
    end

    -- Input box
    local inputHolder = new("Frame", {
        Parent = main, BackgroundColor3 = Themes.ElementBg,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 136),
        Size = UDim2.new(1, -24, 0, 28),
    })
    new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = inputHolder })
    new("UIStroke", { Color = Themes.ElementStroke,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inputHolder })

    local input = new("TextBox", {
        Parent = inputHolder, BackgroundTransparency = 1,
        Text = "", TextColor3 = Themes.Text, TextSize = 12,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        PlaceholderText = "Paste server ID or link URL...",
        PlaceholderColor3 = Themes.SubText,
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -16, 1, 0),
        ClearTextOnFocus = false,
    })

    input.FocusLost:Connect(function()
        local v = input.Text
        if VIP.Mode == "ServerID" then
            VIP.ServerId = v
            VIP.PlaceId = game.PlaceId
            VIP:Save()
        elseif VIP.Mode == "Link" then
            local pid, code = VIP:ParseLink(v)
            if pid and code then
                VIP.PlaceId = pid
                VIP.LinkCode = code
                VIP:Save()
            else
                warn("[Lobby] Link parse failed:", code or pid)
            end
        end
        refreshInfo()
    end)

    -- Buttons
    local function makeBtn(text, y, color, cb)
        local b = new("TextButton", {
            Parent = main, BackgroundColor3 = color or Themes.ElementBg,
            BorderSizePixel = 0, Text = text,
            TextColor3 = Themes.Text, TextSize = 12,
            Font = Enum.Font.Gotham,
            Position = UDim2.fromOffset(12, y),
            Size = UDim2.new(1, -24, 0, 28),
        })
        new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = b })
        new("UIStroke", { Color = Themes.ElementStroke,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
        b.MouseButton1Click:Connect(cb)
        return b
    end

    makeBtn("Capture Current Server", 174, Themes.ElementBg, function()
        local ok = VIP:CaptureCurrent()
        if ok then
            input.Text = ""
            refreshInfo()
        end
    end)

    makeBtn("Join VIP Now", 210, Themes.Accent, function()
        local ok, err = VIP:Join()
        if not ok then warn("[Lobby] Join failed:", err) end
    end)

    -- Auto toggles
    local autoJoin = new("TextButton", {
        Parent = main, BackgroundTransparency = 1,
        Text = (VIP.AutoJoinOnStart and "[X] " or "[ ] ") .. "Auto-join on startup",
        TextColor3 = Themes.Text, TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 250),
        Size = UDim2.new(1, -24, 0, 20),
    })
    autoJoin.MouseButton1Click:Connect(function()
        VIP.AutoJoinOnStart = not VIP.AutoJoinOnStart
        autoJoin.Text = (VIP.AutoJoinOnStart and "[X] " or "[ ] ") .. "Auto-join on startup"
        VIP:Save()
    end)

    local autoRejoin = new("TextButton", {
        Parent = main, BackgroundTransparency = 1,
        Text = (VIP.AutoRejoinOnKick and "[X] " or "[ ] ") .. "Auto-rejoin on kick",
        TextColor3 = Themes.Text, TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 274),
        Size = UDim2.new(1, -24, 0, 20),
    })
    autoRejoin.MouseButton1Click:Connect(function()
        VIP.AutoRejoinOnKick = not VIP.AutoRejoinOnKick
        autoRejoin.Text = (VIP.AutoRejoinOnKick and "[X] " or "[ ] ") .. "Auto-rejoin on kick"
        if VIP.AutoRejoinOnKick then VIP:StartAutoRejoin() else VIP:StopAutoRejoin() end
        VIP:Save()
    end)

    -- Mode hint
    local hint = makeLabel(main, "", 10, UDim2.fromOffset(12, 302), Themes.SubText)
    hint.Size = UDim2.new(1, -24, 0, 60)
    hint.TextWrapped = true
    hint.TextYAlignment = Enum.TextYAlignment.Top

    local function updateHint()
        if VIP.Mode == "MyPS" then
            hint.Text = "Join your own private server. Click 'Capture Current Server' while you are inside your PS."
        elseif VIP.Mode == "ServerID" then
            hint.Text = "Paste your PrivateServerId or JobId above. PlaceId uses current game."
        elseif VIP.Mode == "Link" then
            hint.Text = "Paste full URL: roblox.com/games/.../...?privateServerLinkCode=XXX"
        end
    end

    -- Toggle buttons
    local function updateModeUI()
        refreshInfo()
        updateHint()
    end

    for _, btn in pairs(modeButtons) do
        local old = btn.MouseButton1Click
        btn.MouseButton1Click:Connect(updateModeUI)
    end

    updateModeUI()

    -- Dismiss / Confirm
    local dismiss = makeBtn("Dismiss", 380, Themes.ElementBg, function()
        main.Visible = false
    end)
    dismiss.Size = UDim2.new(0.45, -14, 0, 30)
    dismiss.Position = UDim2.fromOffset(12, 380)

    local confirm = makeBtn("Confirm & Start", 380, Themes.Success, function()
        VIP:Save()
        if VIP.AutoJoinOnStart and VIP.Enabled then
            VIP:Join()
        end
        main.Visible = false
    end)
    confirm.Size = UDim2.new(0.45, -14, 0, 30)
    confirm.Position = UDim2.new(0.5, 2, 0, 380)

    -- Draggable
    local dragging, dragStart, startPos = false, nil, nil
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    self.Window = sg
    self.Main = main
    self._refresh = refreshInfo
end

function Lobby:Show()
    self:Build()
    if self.Main then self.Main.Visible = true end
    if self._refresh then self._refresh() end
end

function Lobby:Hide()
    if self.Main then self.Main.Visible = false end
end

function Lobby:AutoStart()
    local firstTime = not wasShownBefore()
    if firstTime then
        task.wait(2)
        self:Show()
        markShown()
    elseif VIP.AutoJoinOnStart and VIP.Enabled then
        task.wait(3)
        VIP:Join()
    end
    if VIP.AutoRejoinOnKick then
        VIP:StartAutoRejoin()
    end
end

S2.Lobby = Lobby
task.spawn(function() Lobby:AutoStart() end)

print("[ToRung/Lobby] ready")
