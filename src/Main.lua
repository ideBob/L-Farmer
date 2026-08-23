--[[
    L Farmer v1.7.0 entry
    Core + Friends + RoundDetector + Round Timer + Sunset Shader
]]
local VERSION = "1.7.0"

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

-- Friend Request Manager
task.defer(function()
    local FriendManager = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/FriendManager.lua")
    local installFriendUI = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/FriendRequestUI.lua")
    if type(installFriendUI) ~= "function" or not FriendManager then return end
    local gui = waitForGui()
    if not gui or gui:FindFirstChild("FriendRequestPanel") then return end
    local StarterGui = game:GetService("StarterGui")
    local TweenService = game:GetService("TweenService")
    pcall(installFriendUI, gui, makeDraggableFactory(), StarterGui, TweenService, FriendManager)
end)

-- Evade RoundDetector
task.defer(function()
    local boot = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Evade/Bootstrap.lua")
    if type(boot) == "function" then pcall(boot) end
end)

-- Overhead Round Timer
task.defer(function()
    local gui = waitForGui()
    if not gui or gui:FindFirstChild("RoundTimerPanel") then return end
    local OverheadTimer = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/RoundTimer/OverheadTimer.lua")
    local installUI = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/RoundTimer/RoundTimerUI.lua")
    if type(installUI) ~= "function" or not OverheadTimer then return end
    pcall(installUI, gui, makeDraggableFactory(), game:GetService("StarterGui"), OverheadTimer)
end)

-- Sunset Shader
task.defer(function()
    local gui = waitForGui()
    if not gui or gui:FindFirstChild("SunsetPanel") then return end
    local SunsetShader = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Sunset/SunsetShader.lua")
    local installUI = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Sunset/SunsetUI.lua")
    if type(installUI) ~= "function" or not SunsetShader then return end
    pcall(installUI, gui, makeDraggableFactory(), game:GetService("StarterGui"), SunsetShader)
end)
