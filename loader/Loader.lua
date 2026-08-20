--[[
    L Farmer Loader
    Fetches and executes the latest production source from the repository.
]]

local success, result = pcall(function()
    local source = game:HttpGet("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Main.lua")
    if not source or source == "" then
        error("Empty response from source")
    end
    local fn, err = loadstring(source)
    if not fn then
        error("loadstring failed: " .. tostring(err))
    end
    return fn()
end)

if not success then
    warn("[L Farmer] Failed to load: " .. tostring(result))
end
