--[[
    L Farmer - SpotifyAPI Module v1.2.0
    Session-only access token. No credentials stored or logged.
    Returns a module table for use by Main.lua
]]

local HttpService = game:GetService("HttpService")

local SpotifyAPI = {}
SpotifyAPI.__index = SpotifyAPI

local BASE = "https://api.spotify.com/v1"

-- Robust request wrapper for common Roblox executors
local function httpRequest(opts)
    local methods = {
        function()
            if syn and syn.request then return syn.request(opts) end
        end,
        function()
            if http and http.request then return http.request(opts) end
        end,
        function()
            if fluxus and fluxus.request then return fluxus.request(opts) end
        end,
        function()
            if request then return request(opts) end
        end,
        function()
            if http_request then return http_request(opts) end
        end,
    }

    for _, fn in ipairs(methods) do
        local ok, res = pcall(fn)
        if ok and res then
            return res
        end
    end

    -- Last resort: game:HttpGet (GET only, no custom headers reliably)
    if opts.Method == "GET" or not opts.Method then
        local ok, body = pcall(function()
            return game:HttpGet(opts.Url)
        end)
        if ok then
            return { StatusCode = 200, Body = body, Success = true }
        end
    end

    return nil, "No supported HTTP request method found"
end

function SpotifyAPI.new()
    local self = setmetatable({}, SpotifyAPI)
    self.token = nil
    self.lastError = nil
    self.connected = false
    self.profile = nil
    return self
end

function SpotifyAPI:setToken(token)
    if type(token) ~= "string" then
        self.lastError = "Token must be a string"
        self.connected = false
        self.token = nil
        return false
    end

    token = token:match("^%s*(.-)%s*$") or ""
    if token == "" then
        self.lastError = "Token is empty"
        self.connected = false
        self.token = nil
        return false
    end

    -- Basic format sanity (Spotify access tokens are long base64-ish strings)
    if #token < 20 then
        self.lastError = "Token looks too short"
        self.connected = false
        self.token = nil
        return false
    end

    self.token = token
    self.connected = false
    self.lastError = nil
    return true
end

function SpotifyAPI:clearToken()
    self.token = nil
    self.connected = false
    self.profile = nil
    self.lastError = nil
end

function SpotifyAPI:_request(method, path, query)
    if not self.token then
        self.lastError = "No token set"
        return nil, self.lastError
    end

    local url = BASE .. path
    if query and query ~= "" then
        url = url .. "?" .. query
    end

    local res, err = httpRequest({
        Url = url,
        Method = method or "GET",
        Headers = {
            ["Authorization"] = "Bearer " .. self.token,
            ["Content-Type"] = "application/json",
        },
    })

    if not res then
        self.lastError = err or "Request failed"
        return nil, self.lastError
    end

    local code = res.StatusCode or res.Status or 0
    local body = res.Body or res.body or ""

    if code == 401 then
        self.lastError = "Invalid or expired token"
        self.connected = false
        return nil, self.lastError
    elseif code == 403 then
        self.lastError = "Missing permissions / scopes"
        return nil, self.lastError
    elseif code == 429 then
        self.lastError = "Rate limited – wait a moment"
        return nil, self.lastError
    elseif code < 200 or code >= 300 then
        local msg = "HTTP " .. tostring(code)
        pcall(function()
            local data = HttpService:JSONDecode(body)
            if data and data.error and data.error.message then
                msg = data.error.message
            end
        end)
        self.lastError = msg
        return nil, self.lastError
    end

    if body == "" or body == nil then
        return {}, nil -- 204 No Content etc.
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if not ok then
        self.lastError = "Failed to parse response"
        return nil, self.lastError
    end

    self.lastError = nil
    return data, nil
end

function SpotifyAPI:validate()
    local data, err = self:_request("GET", "/me")
    if not data then
        self.connected = false
        return false, err
    end
    self.profile = data
    self.connected = true
    return true, data
end

function SpotifyAPI:getCurrentlyPlaying()
    return self:_request("GET", "/me/player/currently-playing")
end

function SpotifyAPI:getRecentlyPlayed(limit)
    limit = math.clamp(tonumber(limit) or 10, 1, 50)
    return self:_request("GET", "/me/player/recently-played", "limit=" .. limit)
end

function SpotifyAPI:getPlaylists(limit, offset)
    limit = math.clamp(tonumber(limit) or 20, 1, 50)
    offset = tonumber(offset) or 0
    return self:_request("GET", "/me/playlists", "limit=" .. limit .. "&offset=" .. offset)
end

function SpotifyAPI:getPlaylistTracks(playlistId, limit, offset)
    if not playlistId or playlistId == "" then
        return nil, "Missing playlist id"
    end
    limit = math.clamp(tonumber(limit) or 30, 1, 50)
    offset = tonumber(offset) or 0
    return self:_request("GET", "/playlists/" .. playlistId .. "/tracks", "limit=" .. limit .. "&offset=" .. offset)
end

function SpotifyAPI:getSavedTracks(limit, offset)
    limit = math.clamp(tonumber(limit) or 20, 1, 50)
    offset = tonumber(offset) or 0
    return self:_request("GET", "/me/tracks", "limit=" .. limit .. "&offset=" .. offset)
end

function SpotifyAPI:getProfile()
    if self.profile then
        return self.profile
    end
    return self:_request("GET", "/me")
end

-- Helper: format ms → m:ss
function SpotifyAPI.formatMs(ms)
    ms = tonumber(ms) or 0
    local totalSec = math.floor(ms / 1000)
    local m = math.floor(totalSec / 60)
    local s = totalSec % 60
    return string.format("%d:%02d", m, s)
end

-- Helper: extract best image url from images array
function SpotifyAPI.bestImage(images, preferredSize)
    if not images or #images == 0 then return nil end
    preferredSize = preferredSize or 300
    local best, bestDiff = images[1], math.huge
    for _, img in ipairs(images) do
        local w = img.width or 0
        local diff = math.abs(w - preferredSize)
        if diff < bestDiff then
            bestDiff = diff
            best = img
        end
    end
    return best and best.url or nil
end

return SpotifyAPI
