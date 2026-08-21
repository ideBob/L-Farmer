--[[
    L Farmer v1.5.0 entry
    Loads core Main snapshot, Friend Manager, then Evade RoundDetector bootstrap.
]]
local VERSION = "1.5.0"

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

-- Friend Request Manager
task.defer(function()
    local FriendManager = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/FriendManager.lua")
    local installFriendUI = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/FriendRequestUI.lua")
    if type(installFriendUI) ~= "function" or not FriendManager then return end

    local player = game:GetService("Players").LocalPlayer
    local gui = player.PlayerGui:FindFirstChild("LFarmerGui")
    if not gui or gui:FindFirstChild("FriendRequestPanel") then return end

    local TweenService = game:GetService("TweenService")
    local StarterGui = game:GetService("StarterGui")
    local UserInputService = game:GetService("UserInputService")

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

    pcall(installFriendUI, gui, makeDraggable, StarterGui, TweenService, FriendManager)
end)

-- Evade RoundDetector + polished Round floating button
task.defer(function()
    local boot = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Evade/Bootstrap.lua")
    if type(boot) == "function" then
        pcall(boot)
    end
end)
