--[[
    L Farmer Loader v1.4.0
    Loads production Main, then attaches Friend Request Manager.
]]

local function safeHttpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 20 then return body end
    return nil
end

local function safeLoad(url)
    local src = safeHttpGet(url)
    if not src then return nil, "HttpGet failed" end
    local fn, err = loadstring(src)
    if not fn then return nil, err end
    local ok, res = pcall(fn)
    if not ok then return nil, res end
    return res
end

-- Prefer latest Main; if it is broken (stub), fall back to last known-good commit
local mainUrl = "https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Main.lua"
local fallbackUrl = "https://raw.githubusercontent.com/ideBob/L-Farmer/5dc176b100190492b93ce9e89655ad36ea18f58d/src/Main.lua"

local src = safeHttpGet(mainUrl)
if not src or src:find("error%(%s*[\"']Main%.lua push was truncated") or #src < 1000 then
    src = safeHttpGet(fallbackUrl)
end

if not src then
    warn("[L Farmer] Failed to download Main.lua")
    return
end

local fn, err = loadstring(src)
if not fn then
    warn("[L Farmer] loadstring failed: " .. tostring(err))
    return
end

local ok, res = pcall(fn)
if not ok then
    warn("[L Farmer] Main execution failed: " .. tostring(res))
    return
end

-- Friend Request Manager (idempotent attach)
task.defer(function()
    local FriendManager = safeLoad("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/FriendManager.lua")
    local installFriendUI = safeLoad("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/FriendRequestUI.lua")
    if type(installFriendUI) ~= "function" or not FriendManager then return end

    local player = game:GetService("Players").LocalPlayer
    local pg = player and player:FindFirstChild("PlayerGui")
    local gui = pg and pg:FindFirstChild("LFarmerGui")
    if not gui then return end
    if gui:FindFirstChild("FriendRequestPanel") then return end -- already installed

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
