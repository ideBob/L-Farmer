--[[
    L Farmer Loader v2.0.0 — Rayfield Gen2 black theme
]]
local function safeHttpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 20 then return body end
    return nil
end

local mainUrl = "https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Main.lua"
local src = safeHttpGet(mainUrl)
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
end
