--[[
    L Farmer v1.3.1
    Pure AFK + L Esp + L Plr Esp + Spectate + FullBright + Anti-AFK + Auto Run
    + Spotify + YouTube Player By L + Player Media
]]

local VERSION = "1.3.1"

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
    fullBright = nil, antiAfkIdled = nil, antiAfkPulse = nil, autoRun = nil,
    lockLoop = nil, espLoop = nil, spectateLoop = nil, characterAdded = nil,
    playerAdded = nil, playerRemoving = nil, spotifyPoll = nil,
}

local function loadModule(url)
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if ok and type(src) == "string" and #src > 50 then
        local fn = loadstring(src)
        if fn then
            local mOk, mod = pcall(fn)
            if mOk then return mod end
        end
    end
    return nil
end

local SpotifyAPI = loadModule("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/SpotifyAPI.lua")
local YouTubeAPI = loadModule("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/YouTubeAPI.lua")
local installPlayerMedia = loadModule("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/PlayerMediaUI.lua")

local spotify = SpotifyAPI and SpotifyAPI.new and SpotifyAPI.new() or nil
local youtube = YouTubeAPI and YouTubeAPI.new and YouTubeAPI.new() or nil

local function cleanupConnections()
    for name, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then conn:Disconnect()
        elseif typeof(conn) == "thread" then pcall(task.cancel, conn) end
        connections[name] = nil
    end
end

local function safeGetHumanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end
local function safeGetRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

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
        if Lighting.Brightness < 1.5 or Lighting.FogEnd < 50000 then enableFullBright() end
    end)
end

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

local function InitializeAutoRun()
    if connections.autoRun then pcall(task.cancel, connections.autoRun) end
    connections.autoRun = task.spawn(function()
        while true do
            task.wait(12 + math.random() * 6)
            if isEnabled then continue end
            local humanoid = safeGetHumanoid(player.Character)
            if humanoid and humanoid.Health > 0 and humanoid.WalkSpeed > 0 then
                humanoid:Move(Vector3.new(0.008, 0, 0), true)
                task.wait(0.04)
                humanoid:Move(Vector3.zero, true)
            end
        end
    end)
end

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
    local root = safeGetRoot(player.Character)
    local humanoid = safeGetHumanoid(player.Character)
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
    local humanoid = safeGetHumanoid(player.Character)
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
        local root = safeGetRoot(player.Character)
        local humanoid = safeGetHumanoid(player.Character)
        if not root or not humanoid or not lockedCFrame then return end
        if (root.Position - lockedCFrame.Position).Magnitude > LOCK_THRESHOLD then
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

local function StopSpectating()
    spectateEnabled = false
    selectedSpectatePlayer = nil
    local myHum = safeGetHumanoid(player.Character)
    if myHum then camera.CameraSubject = myHum
    elseif player.Character then camera.CameraSubject = player.Character end
    if camera.CameraType ~= Enum.CameraType.Custom then
        camera.CameraType = Enum.CameraType.Custom
    end
end

local function StartSpectating(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then StopSpectating() return end
    selectedSpectatePlayer = targetPlayer
    spectateEnabled = true
    local hum = safeGetHumanoid(targetPlayer.Character)
    if hum then camera.CameraSubject = hum end
end

local function InitializeSpectate()
    if connections.spectateLoop then connections.spectateLoop:Disconnect() end
    connections.spectateLoop = RunService.RenderStepped:Connect(function()
        if not spectateEnabled or not selectedSpectatePlayer then return end
        if not selectedSpectatePlayer.Parent then StopSpectating() return end
        local hum = safeGetHumanoid(selectedSpectatePlayer.Character)
        if hum and camera.CameraSubject ~= hum then camera.CameraSubject = hum end
    end)
end

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
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
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
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
    return frame, button
end

local mainFrame, toggleButton = createButtonFrame("Main", UDim2.new(0, 160, 0, 48), UDim2.new(0.05, 0, 0.10, 0), "L Farmer: OFF")
local espFrame, espButton = createButtonFrame("EspFrame", UDim2.new(0, 110, 0, 40), UDim2.new(0.05, 0, 0.19, 0), "L Esp: OFF")
local plrEspFrame, plrEspButton = createButtonFrame("PlrEspFrame", UDim2.new(0, 130, 0, 40), UDim2.new(0.05, 0, 0.28, 0), "L Plr Esp: OFF")
local spectateFrame, spectateButton = createButtonFrame("SpectateFrame", UDim2.new(0, 140, 0, 40), UDim2.new(0.05, 0, 0.37, 0), "Spectate: OFF")
local turnOffSpectateFrame, turnOffSpectateButton = createButtonFrame("TurnOffSpectateFrame", UDim2.new(0, 170, 0, 40), UDim2.new(0.05, 0, 0.46, 0), "Turn Off Spectate")
local spotifyBtnFrame, spotifyButton = createButtonFrame("SpotifyBtnFrame", UDim2.new(0, 130, 0, 40), UDim2.new(0.05, 0, 0.55, 0), "Spotify")
local ytBtnFrame, ytButton = createButtonFrame("YouTubeBtnFrame", UDim2.new(0, 150, 0, 40), UDim2.new(0.05, 0, 0.64, 0), "YouTube")

local dropdownFrame = Instance.new("Frame")
dropdownFrame.Name = "Dropdown"
dropdownFrame.Size = UDim2.new(0, 180, 0, 0)
dropdownFrame.Position = UDim2.new(0, 150, 0, 0)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
dropdownFrame.BorderSizePixel = 0
dropdownFrame.ClipsDescendants = true
dropdownFrame.Visible = false
dropdownFrame.Parent = spectateFrame
Instance.new("UICorner", dropdownFrame).CornerRadius = UDim.new(0, 8)
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
Instance.new("UIListLayout", dropScroll).Padding = UDim.new(0, 3)

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
makeDraggable(ytBtnFrame, ytButton)

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
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
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

spectateButton.MouseButton1Click:Connect(function()
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
end)

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

local function makePanel(name, title, accent)
    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = UDim2.new(0, 340, 0, 480)
    panel.Position = UDim2.new(0.5, -170, 0.5, -240)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.ClipsDescendants = true
    panel.Parent = screenGui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.3
    stroke.Parent = panel
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 28, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 14))
    })
    grad.Rotation = 90
    grad.Parent = panel
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -50, 0, 36)
    header.Position = UDim2.new(0, 14, 0, 8)
    header.BackgroundTransparency = 1
    header.Text = title
    header.TextColor3 = accent
    header.Font = Enum.Font.GothamBold
    header.TextSize = 18
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = panel
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -40, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = panel
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -28, 0, 20)
    status.Position = UDim2.new(0, 14, 0, 42)
    status.BackgroundTransparency = 1
    status.Text = "Not connected"
    status.TextColor3 = Color3.fromRGB(160, 160, 160)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = panel
    makeDraggable(panel, header)
    return panel, header, closeBtn, status
end

-- Spotify
local spotifyPanel, spHeader, spClose, spStatus = makePanel("SpotifyPanel", "Spotify API", Color3.fromRGB(30, 215, 96))
local spTokenBox = Instance.new("TextBox")
spTokenBox.Size = UDim2.new(1, -28, 0, 34)
spTokenBox.Position = UDim2.new(0, 14, 0, 68)
spTokenBox.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
spTokenBox.PlaceholderText = "Paste Access Token"
spTokenBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
spTokenBox.TextColor3 = Color3.fromRGB(220, 220, 220)
spTokenBox.Font = Enum.Font.Gotham
spTokenBox.TextSize = 13
spTokenBox.ClearTextOnFocus = false
spTokenBox.TextXAlignment = Enum.TextXAlignment.Left
spTokenBox.Text = ""
spTokenBox.Parent = spotifyPanel
Instance.new("UIPadding", spTokenBox).PaddingLeft = UDim.new(0, 10)
Instance.new("UICorner", spTokenBox).CornerRadius = UDim.new(0, 8)
local spApply = Instance.new("TextButton")
spApply.Size = UDim2.new(1, -28, 0, 32)
spApply.Position = UDim2.new(0, 14, 0, 108)
spApply.BackgroundColor3 = Color3.fromRGB(30, 215, 96)
spApply.Text = "Apply Key"
spApply.TextColor3 = Color3.fromRGB(10, 10, 10)
spApply.Font = Enum.Font.GothamBold
spApply.TextSize = 14
spApply.AutoButtonColor = false
spApply.Parent = spotifyPanel
Instance.new("UICorner", spApply).CornerRadius = UDim.new(0, 8)
spClose.MouseButton1Click:Connect(function()
    spotifyPanel.Visible = false
    spotifyButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    spotifyButton.TextColor3 = Color3.fromRGB(220, 220, 220)
end)
spApply.MouseButton1Click:Connect(function()
    if not spotify then spStatus.Text = "Spotify module unavailable" spStatus.TextColor3 = Color3.fromRGB(220, 80, 80) return end
    if not spotify:setToken(spTokenBox.Text) then spStatus.Text = spotify.lastError or "Invalid token" spStatus.TextColor3 = Color3.fromRGB(220, 80, 80) return end
    spTokenBox.Text = ""
    spTokenBox.PlaceholderText = "Token stored for this session"
    spStatus.Text = "Validating…"
    spStatus.TextColor3 = Color3.fromRGB(200, 200, 100)
    task.spawn(function()
        local ok, err = spotify:validate()
        if not ok then spStatus.Text = tostring(err) spStatus.TextColor3 = Color3.fromRGB(220, 80, 80) return end
        spStatus.Text = "Connected · " .. (spotify.profile and (spotify.profile.display_name or "") or "")
        spStatus.TextColor3 = Color3.fromRGB(30, 215, 96)
    end)
end)
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

-- YouTube Player By L
local ytPanel, ytHeader, ytClose, ytStatus = makePanel("YouTubePanel", "YouTube Player By L", Color3.fromRGB(255, 0, 0))

local ytKeyBox = Instance.new("TextBox")
ytKeyBox.Name = "ApiKeyBox"
ytKeyBox.Size = UDim2.new(1, -28, 0, 34)
ytKeyBox.Position = UDim2.new(0, 14, 0, 68)
ytKeyBox.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
ytKeyBox.PlaceholderText = "Paste API Key"
ytKeyBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
ytKeyBox.TextColor3 = Color3.fromRGB(220, 220, 220)
ytKeyBox.Font = Enum.Font.Gotham
ytKeyBox.TextSize = 13
ytKeyBox.ClearTextOnFocus = false
ytKeyBox.TextXAlignment = Enum.TextXAlignment.Left
ytKeyBox.Text = ""
ytKeyBox.Parent = ytPanel
Instance.new("UIPadding", ytKeyBox).PaddingLeft = UDim.new(0, 10)
Instance.new("UICorner", ytKeyBox).CornerRadius = UDim.new(0, 8)

local ytApply = Instance.new("TextButton")
ytApply.Name = "ApplyButton"
ytApply.Size = UDim2.new(1, -28, 0, 32)
ytApply.Position = UDim2.new(0, 14, 0, 108)
ytApply.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
ytApply.Text = "Apply"
ytApply.TextColor3 = Color3.fromRGB(255, 255, 255)
ytApply.Font = Enum.Font.GothamBold
ytApply.TextSize = 14
ytApply.AutoButtonColor = false
ytApply.Parent = ytPanel
Instance.new("UICorner", ytApply).CornerRadius = UDim.new(0, 8)

local ytPlayerFrame = Instance.new("Frame")
ytPlayerFrame.Name = "PlayerArea"
ytPlayerFrame.Size = UDim2.new(1, -16, 1, -155)
ytPlayerFrame.Position = UDim2.new(0, 8, 0, 148)
ytPlayerFrame.BackgroundTransparency = 1
ytPlayerFrame.Visible = false
ytPlayerFrame.Parent = ytPanel

local ytSearchBox = Instance.new("TextBox")
ytSearchBox.Size = UDim2.new(1, -90, 0, 32)
ytSearchBox.Position = UDim2.new(0, 0, 0, 0)
ytSearchBox.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
ytSearchBox.PlaceholderText = "Search YouTube…"
ytSearchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
ytSearchBox.TextColor3 = Color3.fromRGB(220, 220, 220)
ytSearchBox.Font = Enum.Font.Gotham
ytSearchBox.TextSize = 13
ytSearchBox.ClearTextOnFocus = false
ytSearchBox.TextXAlignment = Enum.TextXAlignment.Left
ytSearchBox.Text = ""
ytSearchBox.Parent = ytPlayerFrame
Instance.new("UIPadding", ytSearchBox).PaddingLeft = UDim.new(0, 10)
Instance.new("UICorner", ytSearchBox).CornerRadius = UDim.new(0, 8)

local ytSearchBtn = Instance.new("TextButton")
ytSearchBtn.Size = UDim2.new(0, 80, 0, 32)
ytSearchBtn.Position = UDim2.new(1, -80, 0, 0)
ytSearchBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
ytSearchBtn.Text = "Search"
ytSearchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ytSearchBtn.Font = Enum.Font.GothamBold
ytSearchBtn.TextSize = 13
ytSearchBtn.AutoButtonColor = false
ytSearchBtn.Parent = ytPlayerFrame
Instance.new("UICorner", ytSearchBtn).CornerRadius = UDim.new(0, 8)

local ytResults = Instance.new("ScrollingFrame")
ytResults.Size = UDim2.new(1, 0, 1, -42)
ytResults.Position = UDim2.new(0, 0, 0, 40)
ytResults.BackgroundTransparency = 1
ytResults.BorderSizePixel = 0
ytResults.ScrollBarThickness = 4
ytResults.CanvasSize = UDim2.new(0, 0, 0, 0)
ytResults.Parent = ytPlayerFrame
local ytResultsLayout = Instance.new("UIListLayout")
ytResultsLayout.Padding = UDim.new(0, 8)
ytResultsLayout.Parent = ytResults

-- Install Player Media (Place URL / Apply / media card)
if type(installPlayerMedia) == "function" then
    pcall(installPlayerMedia, ytPanel, ytStatus, YouTubeAPI, StarterGui)
end

local function clearYtResults()
    for _, c in pairs(ytResults:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function addYtResult(item)
    local id = item.id and item.id.videoId
    local sn = item.snippet
    if not id or not sn then return end
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 72)
    row.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    row.BorderSizePixel = 0
    row.Parent = ytResults
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local thumb = Instance.new("ImageLabel")
    thumb.Size = UDim2.new(0, 100, 0, 56)
    thumb.Position = UDim2.new(0, 8, 0, 8)
    thumb.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    thumb.BorderSizePixel = 0
    thumb.ScaleType = Enum.ScaleType.Crop
    local img = YouTubeAPI and YouTubeAPI.bestThumbnail and YouTubeAPI.bestThumbnail(sn)
    if img then thumb.Image = img end
    thumb.Parent = row
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 6)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -120, 0, 32)
    title.Position = UDim2.new(0, 116, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = sn.title or "Untitled"
    title.TextColor3 = Color3.fromRGB(230, 230, 230)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Top
    title.TextWrapped = true
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Parent = row
    local channel = Instance.new("TextLabel")
    channel.Size = UDim2.new(1, -120, 0, 16)
    channel.Position = UDim2.new(0, 116, 0, 42)
    channel.BackgroundTransparency = 1
    channel.Text = sn.channelTitle or ""
    channel.TextColor3 = Color3.fromRGB(150, 150, 150)
    channel.Font = Enum.Font.Gotham
    channel.TextSize = 11
    channel.TextXAlignment = Enum.TextXAlignment.Left
    channel.TextTruncate = Enum.TextTruncate.AtEnd
    channel.Parent = row
    local openBtn = Instance.new("TextButton")
    openBtn.Size = UDim2.new(0, 52, 0, 22)
    openBtn.Position = UDim2.new(1, -60, 1, -28)
    openBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    openBtn.Text = "Open"
    openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    openBtn.Font = Enum.Font.GothamBold
    openBtn.TextSize = 11
    openBtn.AutoButtonColor = false
    openBtn.Parent = row
    Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 6)
    openBtn.MouseButton1Click:Connect(function()
        local url = "https://www.youtube.com/watch?v=" .. id
        local copied = false
        pcall(function() if setclipboard then setclipboard(url) copied = true end end)
        pcall(function() if toclipboard then toclipboard(url) copied = true end end)
        StarterGui:SetCore("SendNotification", {
            Title = "YouTube Player By L",
            Text = copied and "Link copied to clipboard" or url,
            Duration = 4
        })
        ytStatus.Text = "Selected: " .. (sn.title or id)
        ytStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
    end)
end

local function runYtSearch()
    if not youtube or not youtube.connected then return end
    local q = ytSearchBox.Text
    if not q or q:match("^%s*$") then
        ytStatus.Text = "Enter a search query"
        ytStatus.TextColor3 = Color3.fromRGB(220, 80, 80)
        return
    end
    ytStatus.Text = "Searching…"
    ytStatus.TextColor3 = Color3.fromRGB(200, 200, 100)
    clearYtResults()
    task.spawn(function()
        local data, err = youtube:search(q, 12)
        if not data then
            ytStatus.Text = tostring(err or "Search failed")
            ytStatus.TextColor3 = Color3.fromRGB(220, 80, 80)
            return
        end
        if not data.items or #data.items == 0 then
            ytStatus.Text = "No results"
            ytStatus.TextColor3 = Color3.fromRGB(160, 160, 160)
            return
        end
        for _, item in ipairs(data.items) do addYtResult(item) end
        task.defer(function()
            ytResults.CanvasSize = UDim2.new(0, 0, 0, ytResultsLayout.AbsoluteContentSize.Y + 12)
        end)
        ytStatus.Text = "Found " .. #data.items .. " videos"
        ytStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
    end)
end

ytSearchBtn.MouseButton1Click:Connect(runYtSearch)
ytSearchBox.FocusLost:Connect(function(enter) if enter then runYtSearch() end end)

ytClose.MouseButton1Click:Connect(function()
    ytPanel.Visible = false
    ytButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    ytButton.TextColor3 = Color3.fromRGB(220, 220, 220)
end)

ytApply.MouseButton1Click:Connect(function()
    if not youtube then
        ytStatus.Text = "YouTube module unavailable"
        ytStatus.TextColor3 = Color3.fromRGB(220, 80, 80)
        return
    end
    if not youtube:setKey(ytKeyBox.Text) then
        ytStatus.Text = youtube.lastError or "Invalid API key"
        ytStatus.TextColor3 = Color3.fromRGB(220, 80, 80)
        ytPlayerFrame.Visible = false
        return
    end
    ytKeyBox.Text = ""
    ytKeyBox.PlaceholderText = "API key stored for this session"
    ytStatus.Text = "Validating…"
    ytStatus.TextColor3 = Color3.fromRGB(200, 200, 100)
    ytApply.Text = "…"
    ytApply.Active = false
    task.spawn(function()
        local ok, err = youtube:validate()
        ytApply.Text = "Apply"
        ytApply.Active = true
        if not ok then
            ytStatus.Text = tostring(err)
            ytStatus.TextColor3 = Color3.fromRGB(220, 80, 80)
            ytPlayerFrame.Visible = false
            return
        end
        ytStatus.Text = "Connected — YouTube Player ready"
        ytStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
        ytPlayerFrame.Visible = true
    end)
end)

ytButton.MouseButton1Click:Connect(function()
    ytPanel.Visible = not ytPanel.Visible
    if ytPanel.Visible then
        ytButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        ytButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        ytButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        ytButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    end
end)

-- ESP
local ticketEspFolder = Instance.new("Folder")
ticketEspFolder.Name = "TicketEspFolder"
ticketEspFolder.Parent = screenGui
local plrEspFolder = Instance.new("Folder")
plrEspFolder.Name = "PlrEspFolder"
plrEspFolder.Parent = screenGui

local function clearTicketESP() for _, v in pairs(ticketEspFolder:GetChildren()) do v:Destroy() end end
local function clearPlrESP() for _, v in pairs(plrEspFolder:GetChildren()) do v:Destroy() end end

local function createTicketESP(model)
    if not model or not model.Parent then return end
    local adornee = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")) or model
    if not adornee then return end
    local billboard = Instance.new("BillboardGui")
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
    local root = safeGetRoot(plr.Character)
    if not root then return end
    local billboard = Instance.new("BillboardGui")
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
            if ticketFolder then for _, t in pairs(ticketFolder:GetChildren()) do createTicketESP(t) end end
        else clearTicketESP() end
        if plrEspEnabled then
            clearPlrESP()
            for _, plr in pairs(Players:GetPlayers()) do createPlayerESP(plr) end
        else clearPlrESP() end
    end)
end

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

connections.characterAdded = player.CharacterAdded:Connect(function(char)
    task.wait(0.8)
    if isEnabled then teleportAndLock() end
    if spectateEnabled and selectedSpectatePlayer then
        local hum = safeGetHumanoid(selectedSpectatePlayer.Character)
        if hum then camera.CameraSubject = hum end
    else
        local myHum = safeGetHumanoid(char)
        if myHum and not spectateEnabled then camera.CameraSubject = myHum end
    end
end)

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
    if youtube then youtube:clearKey() end
end)
