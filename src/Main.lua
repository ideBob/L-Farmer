--[[
    L Farmer v1.1.0
    Pure AFK + L Esp + L Plr Esp + Spectate + FullBright + Anti-AFK + Auto Run
    Refined: stable lock, clean connections, modular systems, no teleport fighting
]]

local VERSION = "1.1.0"

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- ======================
-- CONFIG
-- ======================
local TELEPORT_POSITION = Vector3.new(0, 15000, 0)
local PLATFORM_SIZE = Vector3.new(60, 2, 60)
local LOCK_THRESHOLD = 6 -- only correct if drifted farther than this

-- State
local isEnabled = false
local espEnabled = false
local plrEspEnabled = false
local spectateEnabled = false
local selectedSpectatePlayer = nil

local platform = nil
local lockedCFrame = nil

-- Connection storage (for clean cleanup)
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
}

-- ======================
-- UTILITY
-- ======================
local function cleanupConnections()
    for name, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        elseif typeof(conn) == "thread" then
            task.cancel(conn)
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
-- FULLBRIGHT (Built-in)
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

    if connections.fullBright then
        connections.fullBright:Disconnect()
    end
    connections.fullBright = RunService.Heartbeat:Connect(function()
        if Lighting.Brightness < 1.5 or Lighting.FogEnd < 50000 then
            enableFullBright()
        end
    end)
end

-- ======================
-- ANTI-AFK (Built-in)
-- ======================
local function InitializeAntiAFK()
    if connections.antiAfkIdled then
        connections.antiAfkIdled:Disconnect()
    end
    connections.antiAfkIdled = player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    if connections.antiAfkPulse then
        task.cancel(connections.antiAfkPulse)
    end
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
-- AUTO RUN / ACTIVITY (Built-in)
-- ======================
local function InitializeAutoRun()
    if connections.autoRun then
        task.cancel(connections.autoRun)
    end

    connections.autoRun = task.spawn(function()
        while true do
            task.wait(12 + math.random() * 6)

            if isEnabled then
                continue
            end

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
    if platform and platform.Parent then
        platform:Destroy()
    end

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

    if not platform or not platform.Parent then
        createPlatform()
    end

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
    if connections.lockLoop then
        connections.lockLoop:Disconnect()
    end

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
-- SPECTATE SYSTEM
-- ======================
local function StopSpectating()
    -- Idempotent: safe to call repeatedly
    spectateEnabled = false
    selectedSpectatePlayer = nil

    -- Force camera back to local player
    local myHum = safeGetHumanoid(player.Character)
    if myHum then
        camera.CameraSubject = myHum
    elseif player.Character then
        camera.CameraSubject = player.Character
    end

    -- Ensure camera type is back to normal custom (prevents locked follow)
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
    if hum then
        camera.CameraSubject = hum
    end
end

local function InitializeSpectate()
    if connections.spectateLoop then
        connections.spectateLoop:Disconnect()
    end

    connections.spectateLoop = RunService.RenderStepped:Connect(function()
        if not spectateEnabled or not selectedSpectatePlayer then return end

        if not selectedSpectatePlayer.Parent then
            StopSpectating()
            return
        end

        local char = selectedSpectatePlayer.Character
        local hum = safeGetHumanoid(char)

        if hum then
            if camera.CameraSubject ~= hum then
                camera.CameraSubject = hum
            end
        end
        -- If target has no character yet (respawning), wait; do not force camera elsewhere
    end)
end

-- ======================
-- UI
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

local mainFrame, toggleButton = createButtonFrame("Main", UDim2.new(0, 160, 0, 48), UDim2.new(0.05, 0, 0.15, 0), "L Farmer: OFF")
local espFrame, espButton = createButtonFrame("EspFrame", UDim2.new(0, 110, 0, 40), UDim2.new(0.05, 0, 0.25, 0), "L Esp: OFF")
local plrEspFrame, plrEspButton = createButtonFrame("PlrEspFrame", UDim2.new(0, 130, 0, 40), UDim2.new(0.05, 0, 0.35, 0), "L Plr Esp: OFF")
local spectateFrame, spectateButton = createButtonFrame("SpectateFrame", UDim2.new(0, 140, 0, 40), UDim2.new(0.05, 0, 0.45, 0), "Spectate: OFF")
local turnOffSpectateFrame, turnOffSpectateButton = createButtonFrame("TurnOffSpectateFrame", UDim2.new(0, 170, 0, 40), UDim2.new(0.05, 0, 0.55, 0), "Turn Off Spectate")

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

-- Drag support
local function makeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
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
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

makeDraggable(mainFrame, toggleButton)
makeDraggable(espFrame, espButton)
makeDraggable(plrEspFrame, plrEspButton)
makeDraggable(spectateFrame, spectateButton)
makeDraggable(turnOffSpectateFrame, turnOffSpectateButton)

-- ======================
-- SPECTATE DROPDOWN
-- ======================
local function RefreshPlayerList()
    for _, child in pairs(dropScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
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

                if not spectateEnabled then
                    StartSpectating(plr)
                    spectateButton.BackgroundColor3 = Color3.fromRGB(0, 140, 60)
                else
                    StartSpectating(plr)
                end
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

-- Right-click still works as a quick toggle
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
        StarterGui:SetCore("SendNotification", {
            Title = "Spectate",
            Text = "Select a player first!",
            Duration = 3
        })
    end
end)

-- Dedicated Turn Off Spectate button
turnOffSpectateButton.MouseButton1Click:Connect(function()
    StopSpectating()

    -- Always reset the main Spectate button appearance
    spectateButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    spectateButton.Text = "Spectate: OFF"

    -- Close dropdown if open
    if dropdownFrame.Visible then
        dropdownFrame.Visible = false
        dropdownFrame.Size = UDim2.new(0, 180, 0, 0)
    end

    -- Visual feedback on the turn-off button
    turnOffSpectateButton.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
    task.delay(0.25, function()
        if turnOffSpectateButton and turnOffSpectateButton.Parent then
            turnOffSpectateButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)
end)

-- ======================
-- ESP SYSTEMS
-- ======================
local ticketEspFolder = Instance.new("Folder")
ticketEspFolder.Name = "TicketEspFolder"
ticketEspFolder.Parent = screenGui

local plrEspFolder = Instance.new("Folder")
plrEspFolder.Name = "PlrEspFolder"
plrEspFolder.Parent = screenGui

local function clearTicketESP()
    for _, v in pairs(ticketEspFolder:GetChildren()) do
        v:Destroy()
    end
end

local function clearPlrESP()
    for _, v in pairs(plrEspFolder:GetChildren()) do
        v:Destroy()
    end
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
    if connections.espLoop then
        connections.espLoop:Disconnect()
    end

    local lastUpdate = 0
    connections.espLoop = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - lastUpdate < 0.25 then return end
        lastUpdate = now

        if espEnabled then
            clearTicketESP()
            local ticketFolder = workspace:FindFirstChild("Effects") and workspace.Effects:FindFirstChild("Tickets")
            if ticketFolder then
                for _, ticket in pairs(ticketFolder:GetChildren()) do
                    createTicketESP(ticket)
                end
            end
        else
            clearTicketESP()
        end

        if plrEspEnabled then
            clearPlrESP()
            for _, plr in pairs(Players:GetPlayers()) do
                createPlayerESP(plr)
            end
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
        if platform then
            platform:Destroy()
            platform = nil
        end
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
-- CHARACTER / PLAYER HANDLING
-- ======================
local function onCharacterAdded(char)
    task.wait(0.8)

    if isEnabled then
        teleportAndLock()
    end

    if spectateEnabled and selectedSpectatePlayer then
        local hum = safeGetHumanoid(selectedSpectatePlayer.Character)
        if hum then
            camera.CameraSubject = hum
        end
    else
        local myHum = safeGetHumanoid(char)
        if myHum and not spectateEnabled then
            camera.CameraSubject = myHum
        end
    end
end

connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

connections.playerAdded = Players.PlayerAdded:Connect(function()
    if dropdownFrame.Visible then
        RefreshPlayerList()
    end
end)

connections.playerRemoving = Players.PlayerRemoving:Connect(function(leaving)
    if selectedSpectatePlayer == leaving then
        StopSpectating()
        spectateButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        spectateButton.Text = "Spectate: OFF"
    end
    if dropdownFrame.Visible then
        RefreshPlayerList()
    end
end)

-- ======================
-- INITIALIZATION
-- ======================
print("L Farmer v" .. VERSION .. " Initialized (Refined)")

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
    if platform then
        platform:Destroy()
    end
    clearTicketESP()
    clearPlrESP()
    StopSpectating()
    unlock()
end)
