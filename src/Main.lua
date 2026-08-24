--[[
    L Farmer v2.0.0 entry
    Core features + Rayfield Gen2 black theme hub
]]
local VERSION = "2.0.0"

-- Core floating UI (feature backend)
local src = game:HttpGet("https://raw.githubusercontent.com/ideBob/L-Farmer/5dc176b100190492b93ce9e89655ad36ea18f58d/src/Main.lua")
local fn, err = loadstring(src)
if not fn then
    error("L Farmer failed to load core: " .. tostring(err))
end
fn()

local function loadMod(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" then return nil end
    local f = loadstring(body)
    if not f then return nil end
    local mok, mod = pcall(f)
    if mok then return mod end
    return nil
end

local function makeDraggableFactory()
    local UserInputService = game:GetService("UserInputService")
    return function(frame, handle)
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
end

local function waitForGui()
    local player = game:GetService("Players").LocalPlayer
    local gui = player.PlayerGui:FindFirstChild("LFarmerGui")
    if gui then return gui end
    for _ = 1, 40 do
        task.wait(0.15)
        gui = player.PlayerGui:FindFirstChild("LFarmerGui")
        if gui then return gui end
    end
    return nil
end

-- Optional modules (floating panels still available)
task.defer(function()
    local FriendManager = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/FriendManager.lua")
    local installFriendUI = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/FriendRequestUI.lua")
    if type(installFriendUI) == "function" and FriendManager then
        local gui = waitForGui()
        if gui and not gui:FindFirstChild("FriendRequestPanel") then
            pcall(installFriendUI, gui, makeDraggableFactory(), game:GetService("StarterGui"), game:GetService("TweenService"), FriendManager)
        end
    end
end)

task.defer(function()
    local boot = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Evade/Bootstrap.lua")
    if type(boot) == "function" then pcall(boot) end
end)

task.defer(function()
    local gui = waitForGui()
    if gui and not gui:FindFirstChild("RoundTimerPanel") then
        local OverheadTimer = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/RoundTimer/OverheadTimer.lua")
        local installUI = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/RoundTimer/RoundTimerUI.lua")
        if type(installUI) == "function" and OverheadTimer then
            pcall(installUI, gui, makeDraggableFactory(), game:GetService("StarterGui"), OverheadTimer)
        end
    end
end)

task.defer(function()
    local gui = waitForGui()
    if gui and not gui:FindFirstChild("SunsetPanel") then
        local SunsetShader = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Sunset/SunsetShader.lua")
        local installUI = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Sunset/SunsetUI.lua")
        if type(installUI) == "function" and SunsetShader then
            pcall(installUI, gui, makeDraggableFactory(), game:GetService("StarterGui"), SunsetShader)
        end
    end
end)

-- Rayfield Gen2 black hub (primary UI)
task.defer(function()
    local hub = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/UI/RayfieldHub.lua")
    if type(hub) == "function" then
        pcall(hub)
    end
end)
