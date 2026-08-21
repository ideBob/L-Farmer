--[[
    L Farmer v1.2.0
    Pure AFK + L Esp + L Plr Esp + Spectate + FullBright + Anti-AFK + Auto Run + Spotify
    Refined: stable lock, clean connections, modular systems, no teleport fighting
]]

local VERSION = "1.2.0"

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- ======================
-- CONFIG
-- ======================
local TELEPORT_POSITION = Vector3.new(0, 15000, 0)
local PLATFORM_SIZE = Vector3.new(60, 2, 60)
local LOCK_THRESHOLD = 6

local isEnabled = false
local espEnabled = false
local plrEspEnabled = false
local spectateEnabled = false
local selectedSpectatePlayer = nil

local platform = nil
local lockedCFrame = nil

local connections = {
    fullBright = nil,
    antiAfkIdled = nil,
    antiAfkPulse = nil,
    autoRun = nil,
    lockLoop = nil,
    espLoop = nil,
    spectateLoop = nil,
    characterAdded = nil,
    playerAdded = nil,
    playerRemoving = nil,
    spotifyPoll = nil,
}

-- ======================
-- LOAD SPOTIFY MODULE
-- ======================
local SpotifyAPI
do
    local ok, src = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/SpotifyAPI.lua")
    end)
    if ok and type(src) == "string" and #src > 50 then
        local fn, err = loadstring(src)
        if fn then
            local modOk, mod = pcall(fn)
            if modOk and type(mod) == "table" then
                SpotifyAPI = mod
            end
        end
    end
end

local spotify = SpotifyAPI and SpotifyAPI.new() or nil

-- ======================
-- UTILITY
-- ======================
local function cleanupConnections()
    for name, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        elseif typeof(conn) == "thread" then
            pcall(task.cancel, conn)
        end
        connections[name] = nil
    end
end

local function safeGetHumanoid(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function safeGetRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- ======================
-- FULLBRIGHT
-- ======================
local function enableFullBright()
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end

local function InitializeFullBright()
    enableFullBright()
    if connections.fullBright then connections.fullBright:Disconnect() end
    connections.fullBright = RunService.Heartbeat:Connect(function()
        if Lighting.Brightness < 1.5 or Lighting.FogEnd < 50000 then
            enableFullBright()
        end
    end)
end

-- ======================
-- ANTI-AFK
-- ======================
local function InitializeAntiAFK()
    if connections.antiAfkIdled then connections.antiAfkIdled:Disconnect() end
    connections.antiAfkIdled = player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    if connections.antiAfkPulse then pcall(task.cancel, connections.antiAfkPulse) end
    connections.antiAfkPulse = task.spawn(function()
        while true do
            task.wait(45 + math.random(0, 15))
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end)
end

-- ======================
-- AUTO RUN
-- ======================
local function InitializeAutoRun()
    if connections.autoRun then pcall(task.cancel, connections.autoRun) end
    connections.autoRun = task.spawn(function()
        while true do
            task.wait(12 + math.random() * 6)
            if isEnabled then continue end
            local char = player.Character
            local humanoid = safeGetHumanoid(char)
            if humanoid and humanoid.Health > 0 and humanoid.WalkSpeed > 0 then
                humanoid:Move(Vector3.new(0.008, 0, 0), true)
                task.wait(0.04)
                humanoid:Move(Vector3.zero, true)
            end
        end
    end)
end

-- ======================
-- PLATFORM + LOCK
-- ======================
local function createPlatform()
    if platform and platform.Parent then platform:Destroy() end
    platform = Instance.new("Part")
    platform.Name = "LFarmerPlatform"
    platform.Size = PLATFORM_SIZE
    platform.Position = TELEPORT_POSITION
    platform.Anchored = true
    platform.CanCollide = true
    platform.Material = Enum.Material.SmoothPlastic
    platform.Color = Color3.fromRGB(25, 25, 25)
    platform.Transparency = 0.2
    platform.Parent = workspace
    lockedCFrame = CFrame.new(TELEPORT_POSITION + Vector3.new(0, 4, 0))
end

local function teleportAndLock()
    local char = player.Character
    local root = safeGetRoot(char)
    local humanoid = safeGetHumanoid(char)
    if not root or not humanoid then return end
    if not platform or not platform.Parent then createPlatform() end
    root.CFrame = lockedCFrame
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.JumpHeight = 0
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end

local function unlock()
    local char = player.Character
    local humanoid = safeGetHumanoid(char)
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        humanoid.JumpHeight = 7.2
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
end

local function InitializeLockLoop()
    if connections.lockLoop then connections.lockLoop:Disconnect() end
    connections.lockLoop = RunService.Heartbeat:Connect(function()
        if not isEnabled then return end
        local char = player.Character
        local root = safeGetRoot(char)
        local humanoid = safeGetHumanoid(char)
        if not root or not humanoid or not lockedCFrame then return end
        local distance = (root.Position - lockedCFrame.Position).Magnitude
        if distance > LOCK_THRESHOLD then
            root.CFrame = lockedCFrame
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if humanoid.WalkSpeed ~= 0 then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            humanoid.JumpHeight = 0
        end
    end)
end

-- ======================
-- SPECTATE
-- ======================
local function StopSpectating()
    spectateEnabled = false
    selectedSpectatePlayer = nil
    local myHum = safeGetHumanoid(player.Character)
    if myHum then
        camera.CameraSubject = myHum
    elseif player.Character then
        camera.CameraSubject = player.Character
    end
    if camera.CameraType ~= Enum.CameraType.Custom then
        camera.CameraType = Enum.CameraType.Custom
    end
end

local function StartSpectating(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then
        StopSpectating()
        return
    end
    selectedSpectatePlayer = targetPlayer
    spectateEnabled = true
    local hum = safeGetHumanoid(targetPlayer.Character)
    if hum then camera.CameraSubject = hum end
end

local function InitializeSpectate()
    if connections.spectateLoop then connections.spectateLoop:Disconnect() end
    connections.spectateLoop = RunService.RenderStepped:Connect(function()
        if not spectateEnabled or not selectedSpectatePlayer then return end
        if not selectedSpectatePlayer.Parent then
            StopSpectating()
            return
        end
        local hum = safeGetHumanoid(selectedSpectatePlayer.Character)
        if hum and camera.CameraSubject ~= hum then
            camera.CameraSubject = hum
        end
    end)
end

-- ======================
-- UI CORE
-- ======================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LFarmerGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local function createButtonFrame(name, size, position, buttonText)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = size
    frame.Position = position
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 12))
    })
    gradient.Rotation = 90
    gradient.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.3
    stroke.Parent = frame

    local button = Instance.new("TextButton")
    button.Name = "Button"
    button.Size = UDim2.new(1, -10, 1, -10)
    button.Position = UDim2.new(0, 5, 0, 5)
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.TextSize = 14
    button.Font = Enum.Font.GothamBold
    button.Text = buttonText
    button.AutoButtonColor = false
    button.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = button

    return frame, button
end

local mainFrame, toggleButton = createButtonFrame("Main", UDim2.new(0, 160, 0, 48), UDim2.new(0.05, 0, 0.12, 0), "L Farmer: OFF")
local espFrame, espButton = createButtonFrame("EspFrame", UDim2.new(0, 110, 0, 40), UDim2.new(0.05, 0, 0.21, 0), "L Esp: OFF")
local plrEspFrame, plrEspButton = createButtonFrame("PlrEspFrame", UDim2.new(0, 130, 0, 40), UDim2.new(0.05, 0, 0.30, 0), "L Plr Esp: OFF")
local spectateFrame, spectateButton = createButtonFrame("SpectateFrame", UDim2.new(0, 140, 0, 40), UDim2.new(0.05, 0, 0.39, 0), "Spectate: OFF")
local turnOffSpectateFrame, turnOffSpectateButton = createButtonFrame("TurnOffSpectateFrame", UDim2.new(0, 170, 0, 40), UDim2.new(0.05, 0, 0.48, 0), "Turn Off Spectate")
local spotifyBtnFrame, spotifyButton = createButtonFrame("SpotifyBtnFrame", UDim2.new(0, 130, 0, 40), UDim2.new(0.05, 0, 0.57, 0), "Spotify")

-- Spectate Dropdown
local dropdownFrame = Instance.new("Frame")
dropdownFrame.Name = "Dropdown"
dropdownFrame.Size = UDim2.new(0, 180, 0, 0)
dropdownFrame.Position = UDim2.new(0, 150, 0, 0)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
dropdownFrame.BorderSizePixel = 0
dropdownFrame.ClipsDescendants = true
dropdownFrame.Visible = false
dropdownFrame.Parent = spectateFrame

local dropCorner = Instance.new("UICorner")
dropCorner.CornerRadius = UDim.new(0, 8)
dropCorner.Parent = dropdownFrame

local dropStroke = Instance.new("UIStroke")
dropStroke.Color = Color3.fromRGB(60, 60, 60)
dropStroke.Thickness = 1
dropStroke.Parent = dropdownFrame

local dropScroll = Instance.new("ScrollingFrame")
dropScroll.Size = UDim2.new(1, -6, 1, -6)
dropScroll.Position = UDim2.new(0, 3, 0, 3)
dropScroll.BackgroundTransparency = 1
dropScroll.BorderSizePixel = 0
dropScroll.ScrollBarThickness = 4
dropScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
dropScroll.Parent = dropdownFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 3)
listLayout.Parent = dropScroll

local function makeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

makeDraggable(mainFrame, toggleButton)
makeDraggable(espFrame, espButton)
makeDraggable(plrEspFrame, plrEspButton)
makeDraggable(spectateFrame, spectateButton)
makeDraggable(turnOffSpectateFrame, turnOffSpectateButton)
makeDraggable(spotifyBtnFrame, spotifyButton)

-- ======================
-- SPECTATE DROPDOWN LOGIC
-- ======================
local function RefreshPlayerList()
    for _, child in pairs(dropScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local ySize = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 28)
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            btn.TextColor3 = Color3.fromRGB(220, 220, 220)
            btn.Text = plr.Name
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 13
            btn.AutoButtonColor = false
            btn.Parent = dropScroll
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = btn
            btn.MouseButton1Click:Connect(function()
                selectedSpectatePlayer = plr
                spectateButton.Text = "Spectate: " .. plr.Name
                dropdownFrame.Visible = false
                dropdownFrame.Size = UDim2.new(0, 180, 0, 0)
                StartSpectating(plr)
                spectateButton.BackgroundColor3 = Color3.fromRGB(0, 140, 60)
            end)
            ySize = ySize + 31
        end
    end
    dropScroll.CanvasSize = UDim2.new(0, 0, 0, ySize)
end

local function toggleSpectateUI()
    if dropdownFrame.Visible then
        dropdownFrame.Visible = false
        dropdownFrame.Size = UDim2.new(0, 180, 0, 0)
    else
        RefreshPlayerList()
        dropdownFrame.Visible = true
        local height = math.clamp(#Players:GetPlayers() * 32, 40, 200)
        TweenService:Create(dropdownFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 180, 0, height)
        }):Play()
    end
end

spectateButton.MouseButton1Click:Connect(toggleSpectateUI)

spectateButton.MouseButton2Click:Connect(function()
    if spectateEnabled then
        StopSpectating()
        spectateButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        spectateButton.Text = "Spectate: OFF"
    elseif selectedSpectatePlayer then
        StartSpectating(selectedSpectatePlayer)
        spectateButton.BackgroundColor3 = Color3.fromRGB(0, 140, 60)
        spectateButton.Text = "Spectate: " .. selectedSpectatePlayer.Name
    else
        StarterGui:SetCore("SendNotification", { Title = "Spectate", Text = "Select a player first!", Duration = 3 })
    end
end)

turnOffSpectateButton.MouseButton1Click:Connect(function()
    StopSpectating()
    spectateButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    spectateButton.Text = "Spectate: OFF"
    if dropdownFrame.Visible then
        dropdownFrame.Visible = false
        dropdownFrame.Size = UDim2.new(0, 180, 0, 0)
    end
    turnOffSpectateButton.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
    task.delay(0.25, function()
        if turnOffSpectateButton and turnOffSpectateButton.Parent then
            turnOffSpectateButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)
end)

-- ======================
-- SPOTIFY UI PANEL
-- ======================
local spotifyPanel = Instance.new("Frame")
spotifyPanel.Name = "SpotifyPanel"
spotifyPanel.Size = UDim2.new(0, 340, 0, 480)
spotifyPanel.Position = UDim2.new(0.5, -170, 0.5, -240)
spotifyPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
spotifyPanel.BorderSizePixel = 0
spotifyPanel.Visible = false
spotifyPanel.ClipsDescendants = true
spotifyPanel.Parent = screenGui

local spCorner = Instance.new("UICorner")
spCorner.CornerRadius = UDim.new(0, 12)
spCorner.Parent = spotifyPanel

local spStroke = Instance.new("UIStroke")
spStroke.Color = Color3.fromRGB(60, 60, 60)
spStroke.Thickness = 1.2
spStroke.Transparency = 0.3
spStroke.Parent = spotifyPanel

local spGradient = Instance.new("UIGradient")
spGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 28, 28)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 14))
})
spGradient.Rotation = 90
spGradient.Parent = spotifyPanel

-- Header
local spHeader = Instance.new("TextLabel")
spHeader.Size = UDim2.new(1, -50, 0, 36)
spHeader.Position = UDim2.new(0, 14, 0, 8)
spHeader.BackgroundTransparency = 1
spHeader.Text = "Spotify API"
spHeader.TextColor3 = Color3.fromRGB(30, 215, 96)
spHeader.Font = Enum.Font.GothamBold
spHeader.TextSize = 18
spHeader.TextXAlignment = Enum.TextXAlignment.Left
spHeader.Parent = spotifyPanel

local spClose = Instance.new("TextButton")
spClose.Size = UDim2.new(0, 32, 0, 32)
spClose.Position = UDim2.new(1, -40, 0, 8)
spClose.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
spClose.Text = "X"
spClose.TextColor3 = Color3.fromRGB(220, 220, 220)
spClose.Font = Enum.Font.GothamBold
spClose.TextSize = 14
spClose.AutoButtonColor = false
spClose.Parent = spotifyPanel
local spCloseCorner = Instance.new("UICorner")
spCloseCorner.CornerRadius = UDim.new(0, 8)
spCloseCorner.Parent = spClose

spClose.MouseButton1Click:Connect(function()
    spotifyPanel.Visible = false
    spotifyButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
end)

-- Status label
local spStatus = Instance.new("TextLabel")
spStatus.Size = UDim2.new(1, -28, 0, 20)
spStatus.Position = UDim2.new(0, 14, 0, 42)
spStatus.BackgroundTransparency = 1
spStatus.Text = spotify and "Not connected" or "Spotify module unavailable"
spStatus.TextColor3 = Color3.fromRGB(160, 160, 160)
spStatus.Font = Enum.Font.Gotham
spStatus.TextSize = 12
spStatus.TextXAlignment = Enum.TextXAlignment.Left
spStatus.Parent = spotifyPanel

-- Token input area
local tokenBox = Instance.new("TextBox")
tokenBox.Name = "TokenBox"
tokenBox.Size = UDim2.new(1, -28, 0, 34)
tokenBox.Position = UDim2.new(0, 14, 0, 68)
tokenBox.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
tokenBox.Text = ""
tokenBox.PlaceholderText = "Paste Access Token"
tokenBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
tokenBox.TextColor3 = Color3.fromRGB(220, 220, 220)
tokenBox.Font = Enum.Font.Gotham
tokenBox.TextSize = 13
tokenBox.ClearTextOnFocus = false
tokenBox.TextXAlignment = Enum.TextXAlignment.Left
tokenBox.Parent = spotifyPanel

local tokenPad = Instance.new("UIPadding")
tokenPad.PaddingLeft = UDim.new(0, 10)
tokenPad.Parent = tokenBox

local tokenCorner = Instance.new("UICorner")
tokenCorner.CornerRadius = UDim.new(0, 8)
tokenCorner.Parent = tokenBox

local applyBtn = Instance.new("TextButton")
applyBtn.Size = UDim2.new(1, -28, 0, 32)
applyBtn.Position = UDim2.new(0, 14, 0, 108)
applyBtn.BackgroundColor3 = Color3.fromRGB(30, 215, 96)
applyBtn.Text = "Apply Key"
applyBtn.TextColor3 = Color3.fromRGB(10, 10, 10)
applyBtn.Font = Enum.Font.GothamBold
applyBtn.TextSize = 14
applyBtn.AutoButtonColor = false
applyBtn.Parent = spotifyPanel

local applyCorner = Instance.new("UICorner")
applyCorner.CornerRadius = UDim.new(0, 8)
applyCorner.Parent = applyBtn

-- Dashboard scroll (hidden until connected)
local dashScroll = Instance.new("ScrollingFrame")
dashScroll.Name = "Dashboard"
dashScroll.Size = UDim2.new(1, -16, 1, -155)
dashScroll.Position = UDim2.new(0, 8, 0, 148)
dashScroll.BackgroundTransparency = 1
dashScroll.BorderSizePixel = 0
dashScroll.ScrollBarThickness = 4
dashScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
dashScroll.Visible = false
dashScroll.Parent = spotifyPanel

local dashLayout = Instance.new("UIListLayout")
dashLayout.Padding = UDim.new(0, 10)
dashLayout.Parent = dashScroll

local function clearDashboard()
    for _, c in pairs(dashScroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function sectionLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -8, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(30, 215, 96)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = dashScroll
    return lbl
end

local function infoRow(text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -8, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = dashScroll
    return lbl
end

local function makeTrackRow(title, artist, album, duration, imageUrl)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 52)
    row.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    row.BorderSizePixel = 0
    row.Parent = dashScroll

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 8)
    rc.Parent = row

    local art = Instance.new("ImageLabel")
    art.Size = UDim2.new(0, 44, 0, 44)
    art.Position = UDim2.new(0, 4, 0, 4)
    art.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    art.BorderSizePixel = 0
    art.ScaleType = Enum.ScaleType.Crop
    if imageUrl then art.Image = imageUrl end
    art.Parent = row
    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(0, 6)
    ac.Parent = art

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -60, 0, 16)
    t.Position = UDim2.new(0, 54, 0, 6)
    t.BackgroundTransparency = 1
    t.Text = title or "Unknown"
    t.TextColor3 = Color3.fromRGB(230, 230, 230)
    t.Font = Enum.Font.GothamBold
    t.TextSize = 12
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextTruncate = Enum.TextTruncate.AtEnd
    t.Parent = row

    local a = Instance.new("TextLabel")
    a.Size = UDim2.new(1, -60, 0, 14)
    a.Position = UDim2.new(0, 54, 0, 22)
    a.BackgroundTransparency = 1
    a.Text = (artist or "Unknown") .. (album and (" · " .. album) or "")
    a.TextColor3 = Color3.fromRGB(150, 150, 150)
    a.Font = Enum.Font.Gotham
    a.TextSize = 11
    a.TextXAlignment = Enum.TextXAlignment.Left
    a.TextTruncate = Enum.TextTruncate.AtEnd
    a.Parent = row

    if duration then
        local d = Instance.new("TextLabel")
        d.Size = UDim2.new(0, 40, 0, 14)
        d.Position = UDim2.new(1, -48, 0, 34)
        d.BackgroundTransparency = 1
        d.Text = duration
        d.TextColor3 = Color3.fromRGB(120, 120, 120)
        d.Font = Enum.Font.Gotham
        d.TextSize = 11
        d.TextXAlignment = Enum.TextXAlignment.Right
        d.Parent = row
    end

    return row
end

local function updateCanvas()
    task.defer(function()
        dashScroll.CanvasSize = UDim2.new(0, 0, 0, dashLayout.AbsoluteContentSize.Y + 20)
    end)
end

local function setStatus(text, color)
    spStatus.Text = text
    spStatus.TextColor3 = color or Color3.fromRGB(160, 160, 160)
end

local function buildNowPlaying(data)
    sectionLabel("Now Playing")

    if not data or not data.item then
        infoRow("Nothing is currently playing", Color3.fromRGB(140, 140, 140))
        return
    end

    local item = data.item
    local title = item.name or "Unknown"
    local artists = {}
    if item.artists then
        for _, ar in ipairs(item.artists) do
            table.insert(artists, ar.name or "?")
        end
    end
    local artistStr = table.concat(artists, ", ")
    local albumName = item.album and item.album.name or ""
    local img = SpotifyAPI and SpotifyAPI.bestImage(item.album and item.album.images)
    local progress = data.progress_ms or 0
    local duration = item.duration_ms or 0
    local isPlaying = data.is_playing

    makeTrackRow(title, artistStr, albumName, SpotifyAPI.formatMs(duration), img)

    local state = isPlaying and "▶ Playing" or "⏸ Paused"
    infoRow(state .. "  ·  " .. SpotifyAPI.formatMs(progress) .. " / " .. SpotifyAPI.formatMs(duration))

    -- Simple progress bar
    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -8, 0, 6)
    barBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    barBg.BorderSizePixel = 0
    barBg.Parent = dashScroll
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = barBg

    local fill = Instance.new("Frame")
    local pct = duration > 0 and math.clamp(progress / duration, 0, 1) or 0
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(30, 215, 96)
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = fill
end

local function buildRecentlyPlayed(data)
    sectionLabel("Recently Played")
    if not data or not data.items or #data.items == 0 then
        infoRow("No recent tracks", Color3.fromRGB(140, 140, 140))
        return
    end
    for _, entry in ipairs(data.items) do
        local t = entry.track
        if t then
            local artists = {}
            if t.artists then
                for _, ar in ipairs(t.artists) do table.insert(artists, ar.name or "?") end
            end
            local img = SpotifyAPI and SpotifyAPI.bestImage(t.album and t.album.images, 64)
            makeTrackRow(t.name, table.concat(artists, ", "), t.album and t.album.name, SpotifyAPI.formatMs(t.duration_ms), img)
        end
    end
end

local function buildPlaylists(data)
    sectionLabel("Your Playlists")
    if not data or not data.items or #data.items == 0 then
        infoRow("No playlists found", Color3.fromRGB(140, 140, 140))
        return
    end

    for _, pl in ipairs(data.items) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -8, 0, 48)
        row.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = dashScroll

        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 8)
        rc.Parent = row

        local art = Instance.new("ImageLabel")
        art.Size = UDim2.new(0, 40, 0, 40)
        art.Position = UDim2.new(0, 4, 0, 4)
        art.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        art.BorderSizePixel = 0
        art.ScaleType = Enum.ScaleType.Crop
        local imgUrl = SpotifyAPI and SpotifyAPI.bestImage(pl.images, 64)
        if imgUrl then art.Image = imgUrl end
        art.Parent = row
        local ac = Instance.new("UICorner")
        ac.CornerRadius = UDim.new(0, 6)
        ac.Parent = art

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -56, 0, 18)
        nameLbl.Position = UDim2.new(0, 50, 0, 6)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = pl.name or "Untitled"
        nameLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 12
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row

        local meta = Instance.new("TextLabel")
        meta.Size = UDim2.new(1, -56, 0, 14)
        meta.Position = UDim2.new(0, 50, 0, 26)
        meta.BackgroundTransparency = 1
        meta.Text = (pl.tracks and pl.tracks.total or 0) .. " tracks"
        meta.TextColor3 = Color3.fromRGB(140, 140, 140)
        meta.Font = Enum.Font.Gotham
        meta.TextSize = 11
        meta.TextXAlignment = Enum.TextXAlignment.Left
        meta.Parent = row

        row.MouseButton1Click:Connect(function()
            if not spotify or not spotify.connected then return end
            setStatus("Loading playlist…", Color3.fromRGB(200, 200, 100))
            task.spawn(function()
                local tracks, err = spotify:getPlaylistTracks(pl.id, 30, 0)
                clearDashboard()
                sectionLabel(pl.name or "Playlist")
                if pl.description and pl.description ~= "" then
                    infoRow(pl.description, Color3.fromRGB(150, 150, 150))
                end
                if not tracks then
                    infoRow(err or "Failed to load tracks", Color3.fromRGB(220, 80, 80))
                elseif not tracks.items or #tracks.items == 0 then
                    infoRow("Empty playlist", Color3.fromRGB(140, 140, 140))
                else
                    for _, entry in ipairs(tracks.items) do
                        local t = entry.track
                        if t and t.name then
                            local artists = {}
                            if t.artists then
                                for _, ar in ipairs(t.artists) do table.insert(artists, ar.name or "?") end
                            end
                            local img = SpotifyAPI and SpotifyAPI.bestImage(t.album and t.album.images, 64)
                            makeTrackRow(t.name, table.concat(artists, ", "), t.album and t.album.name, SpotifyAPI.formatMs(t.duration_ms), img)
                        end
                    end
                end
                -- Back button
                local back = Instance.new("TextButton")
                back.Size = UDim2.new(1, -8, 0, 30)
                back.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
                back.Text = "← Back to dashboard"
                back.TextColor3 = Color3.fromRGB(220, 220, 220)
                back.Font = Enum.Font.Gotham
                back.TextSize = 12
                back.AutoButtonColor = false
                back.Parent = dashScroll
                local bc = Instance.new("UICorner")
                bc.CornerRadius = UDim.new(0, 6)
                bc.Parent = back
                back.MouseButton1Click:Connect(function()
                    refreshDashboard()
                end)
                updateCanvas()
                setStatus("Connected", Color3.fromRGB(30, 215, 96))
            end)
        end)
    end
end

local function buildSaved(data)
    sectionLabel("Liked Songs")
    if not data or not data.items or #data.items == 0 then
        infoRow("No liked songs (or missing scope)", Color3.fromRGB(140, 140, 140))
        return
    end
    for _, entry in ipairs(data.items) do
        local t = entry.track
        if t then
            local artists = {}
            if t.artists then
                for _, ar in ipairs(t.artists) do table.insert(artists, ar.name or "?") end
            end
            local img = SpotifyAPI and SpotifyAPI.bestImage(t.album and t.album.images, 64)
            makeTrackRow(t.name, table.concat(artists, ", "), t.album and t.album.name, SpotifyAPI.formatMs(t.duration_ms), img)
        end
    end
end

function refreshDashboard()
    if not spotify or not spotify.connected then return end
    clearDashboard()
    setStatus("Refreshing…", Color3.fromRGB(200, 200, 100))

    task.spawn(function()
        local now = spotify:getCurrentlyPlaying()
        buildNowPlaying(now)

        local recent = spotify:getRecentlyPlayed(8)
        buildRecentlyPlayed(recent)

        local playlists = spotify:getPlaylists(15, 0)
        buildPlaylists(playlists)

        local liked = spotify:getSavedTracks(10, 0)
        buildSaved(liked)

        updateCanvas()
        setStatus("Connected · " .. (spotify.profile and (spotify.profile.display_name or spotify.profile.id) or ""), Color3.fromRGB(30, 215, 96))
    end)
end

-- Apply Key handler
applyBtn.MouseButton1Click:Connect(function()
    if not spotify then
        setStatus("Spotify module failed to load", Color3.fromRGB(220, 80, 80))
        return
    end

    local raw = tokenBox.Text
    if not spotify:setToken(raw) then
        setStatus(spotify.lastError or "Invalid token", Color3.fromRGB(220, 80, 80))
        dashScroll.Visible = false
        return
    end

    -- Never leave the token visible longer than needed
    tokenBox.Text = ""
    tokenBox.PlaceholderText = "Token stored for this session"

    setStatus("Validating…", Color3.fromRGB(200, 200, 100))
    applyBtn.Text = "…"
    applyBtn.Active = false

    task.spawn(function()
        local ok, profileOrErr = spotify:validate()
        applyBtn.Text = "Apply Key"
        applyBtn.Active = true

        if not ok then
            setStatus(tostring(profileOrErr), Color3.fromRGB(220, 80, 80))
            dashScroll.Visible = false
            return
        end

        setStatus("Connected", Color3.fromRGB(30, 215, 96))
        dashScroll.Visible = true
        refreshDashboard()

        -- Gentle poll for now-playing (every 12s)
        if connections.spotifyPoll then pcall(task.cancel, connections.spotifyPoll) end
        connections.spotifyPoll = task.spawn(function()
            while spotify and spotify.connected do
                task.wait(12)
                if not spotify.connected then break end
                -- Only refresh now-playing section lightly by full refresh
                refreshDashboard()
            end
        end)
    end)
end)

-- Open / close panel
spotifyButton.MouseButton1Click:Connect(function()
    spotifyPanel.Visible = not spotifyPanel.Visible
    if spotifyPanel.Visible then
        spotifyButton.BackgroundColor3 = Color3.fromRGB(30, 215, 96)
        spotifyButton.TextColor3 = Color3.fromRGB(10, 10, 10)
    else
        spotifyButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        spotifyButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    end
end)

makeDraggable(spotifyPanel, spHeader)

-- ======================
-- ESP
-- ======================
local ticketEspFolder = Instance.new("Folder")
ticketEspFolder.Name = "TicketEspFolder"
ticketEspFolder.Parent = screenGui

local plrEspFolder = Instance.new("Folder")
plrEspFolder.Name = "PlrEspFolder"
plrEspFolder.Parent = screenGui

local function clearTicketESP()
    for _, v in pairs(ticketEspFolder:GetChildren()) do v:Destroy() end
end
local function clearPlrESP()
    for _, v in pairs(plrEspFolder:GetChildren()) do v:Destroy() end
end

local function createTicketESP(model)
    if not model or not model.Parent then return end
    local adornee = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")) or model
    if not adornee then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TicketESP"
    billboard.Adornee = adornee
    billboard.Size = UDim2.new(0, 80, 0, 25)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = ticketEspFolder
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "TICKET"
    label.TextColor3 = Color3.fromRGB(0, 255, 120)
    label.TextStrokeTransparency = 0.4
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Parent = billboard
end

local function createPlayerESP(plr)
    if not plr or plr == player then return end
    local char = plr.Character
    if not char then return end
    local root = safeGetRoot(char)
    if not root then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerESP"
    billboard.Adornee = root
    billboard.Size = UDim2.new(0, 120, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = plrEspFolder
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = plr.Name
    label.TextColor3 = Color3.fromRGB(0, 200, 255)
    label.TextStrokeTransparency = 0.3
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard
end

local function InitializeESP()
    if connections.espLoop then connections.espLoop:Disconnect() end
    local lastUpdate = 0
    connections.espLoop = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - lastUpdate < 0.25 then return end
        lastUpdate = now
        if espEnabled then
            clearTicketESP()
            local ticketFolder = workspace:FindFirstChild("Effects") and workspace.Effects:FindFirstChild("Tickets")
            if ticketFolder then
                for _, ticket in pairs(ticketFolder:GetChildren()) do createTicketESP(ticket) end
            end
        else
            clearTicketESP()
        end
        if plrEspEnabled then
            clearPlrESP()
            for _, plr in pairs(Players:GetPlayers()) do createPlayerESP(plr) end
        else
            clearPlrESP()
        end
    end)
end

-- ======================
-- TOGGLES
-- ======================
toggleButton.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    if isEnabled then
        toggleButton.Text = "L Farmer: ON"
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 140, 60)
        createPlatform()
        teleportAndLock()
    else
        toggleButton.Text = "L Farmer: OFF"
        toggleButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        unlock()
        if platform then platform:Destroy() platform = nil end
        lockedCFrame = nil
    end
end)

espButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        espButton.Text = "L Esp: ON"
        espButton.BackgroundColor3 = Color3.fromRGB(0, 140, 60)
    else
        espButton.Text = "L Esp: OFF"
        espButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        clearTicketESP()
    end
end)

plrEspButton.MouseButton1Click:Connect(function()
    plrEspEnabled = not plrEspEnabled
    if plrEspEnabled then
        plrEspButton.Text = "L Plr Esp: ON"
        plrEspButton.BackgroundColor3 = Color3.fromRGB(0, 140, 60)
    else
        plrEspButton.Text = "L Plr Esp: OFF"
        plrEspButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        clearPlrESP()
    end
end)

-- ======================
-- CHARACTER / PLAYERS
-- ======================
local function onCharacterAdded(char)
    task.wait(0.8)
    if isEnabled then teleportAndLock() end
    if spectateEnabled and selectedSpectatePlayer then
        local hum = safeGetHumanoid(selectedSpectatePlayer.Character)
        if hum then camera.CameraSubject = hum end
    else
        local myHum = safeGetHumanoid(char)
        if myHum and not spectateEnabled then camera.CameraSubject = myHum end
    end
end

connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

connections.playerAdded = Players.PlayerAdded:Connect(function()
    if dropdownFrame.Visible then RefreshPlayerList() end
end)

connections.playerRemoving = Players.PlayerRemoving:Connect(function(leaving)
    if selectedSpectatePlayer == leaving then
        StopSpectating()
        spectateButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        spectateButton.Text = "Spectate: OFF"
    end
    if dropdownFrame.Visible then RefreshPlayerList() end
end)

-- ======================
-- INIT
-- ======================
print("L Farmer v" .. VERSION .. " Initialized")

StarterGui:SetCore("SendNotification", {
    Title = "L Farmer v" .. VERSION,
    Text = "Get A Life Loser",
    Duration = 5
})

InitializeFullBright()
InitializeAntiAFK()
InitializeAutoRun()
InitializeLockLoop()
InitializeSpectate()
InitializeESP()

screenGui.Destroying:Connect(function()
    cleanupConnections()
    if platform then platform:Destroy() end
    clearTicketESP()
    clearPlrESP()
    StopSpectating()
    unlock()
    if spotify then spotify:clearToken() end
end)
