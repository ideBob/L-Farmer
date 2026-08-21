--[[
    L Farmer - YouTubeAPI Module v1.3.1
    Session-only API key + URL helpers + oEmbed (Player Media needs no key)
]]

local HttpService = game:GetService("HttpService")

local YouTubeAPI = {}
YouTubeAPI.__index = YouTubeAPI

local BASE = "https://www.googleapis.com/youtube/v3"

local function httpRequest(opts)
    local methods = {
        function() if syn and syn.request then return syn.request(opts) end end,
        function() if http and http.request then return http.request(opts) end end,
        function() if fluxus and fluxus.request then return fluxus.request(opts) end end,
        function() if request then return request(opts) end end,
        function() if http_request then return http_request(opts) end end,
    }
    for _, fn in ipairs(methods) do
        local ok, res = pcall(fn)
        if ok and res then return res end
    end
    if (opts.Method == "GET" or not opts.Method) then
        local ok, body = pcall(function() return game:HttpGet(opts.Url) end)
        if ok and body then
            return { StatusCode = 200, Body = body, Success = true }
        end
    end
    return nil, "No supported HTTP request method found"
end

function YouTubeAPI.new()
    local self = setmetatable({}, YouTubeAPI)
    self.key = nil
    self.connected = false
    self.lastError = nil
    return self
end

function YouTubeAPI:setKey(key)
    if type(key) ~= "string" then
        self.lastError = "Key must be a string"
        self.connected = false
        self.key = nil
        return false
    end
    key = key:match("^%s*(.-)%s*$") or ""
    if key == "" then
        self.lastError = "API key is empty"
        self.connected = false
        self.key = nil
        return false
    end
    if #key < 20 then
        self.lastError = "API key looks too short"
        self.connected = false
        self.key = nil
        return false
    end
    self.key = key
    self.connected = false
    self.lastError = nil
    return true
end

function YouTubeAPI:clearKey()
    self.key = nil
    self.connected = false
    self.lastError = nil
end

function YouTubeAPI:_request(path, query)
    if not self.key then
        self.lastError = "No API key set"
        return nil, self.lastError
    end
    local url = BASE .. path .. "?" .. (query or "") .. "&key=" .. self.key
    local res, err = httpRequest({
        Url = url,
        Method = "GET",
        Headers = { ["Content-Type"] = "application/json" },
    })
    if not res then
        self.lastError = err or "Request failed"
        return nil, self.lastError
    end
    local code = res.StatusCode or res.Status or 0
    local body = res.Body or res.body or ""
    if code == 400 or code == 403 then
        local msg = "Invalid or restricted API key"
        pcall(function()
            local data = HttpService:JSONDecode(body)
            if data and data.error and data.error.message then msg = data.error.message end
        end)
        self.lastError = msg
        self.connected = false
        return nil, self.lastError
    elseif code == 429 then
        self.lastError = "Rate limited – wait a moment"
        return nil, self.lastError
    elseif code < 200 or code >= 300 then
        self.lastError = "HTTP " .. tostring(code)
        return nil, self.lastError
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok then
        self.lastError = "Failed to parse response"
        return nil, self.lastError
    end
    if data.error then
        self.lastError = data.error.message or "API error"
        return nil, self.lastError
    end
    self.lastError = nil
    return data, nil
end

function YouTubeAPI:validate()
    local data, err = self:_request("/search", "part=snippet&type=video&maxResults=1&q=test")
    if not data then
        self.connected = false
        return false, err
    end
    self.connected = true
    return true, data
end

function YouTubeAPI:search(query, maxResults)
    if not query or query == "" then return nil, "Empty search query" end
    maxResults = math.clamp(tonumber(maxResults) or 10, 1, 25)
    local q = HttpService:UrlEncode(query)
    return self:_request("/search", "part=snippet&type=video&maxResults=" .. maxResults .. "&q=" .. q)
end

function YouTubeAPI:getVideoDetails(videoId)
    if not videoId or videoId == "" then return nil, "Missing video id" end
    return self:_request("/videos", "part=snippet,contentDetails,statistics&id=" .. videoId)
end

function YouTubeAPI.extractVideoId(input)
    if type(input) ~= "string" then return nil end
    input = input:match("^%s*(.-)%s*$") or ""
    if input == "" then return nil end
    if input:match("^[%w%-_]{11}$") then return input end
    local patterns = {
        "youtube%.com/watch%?.*v=([%w%-_]{11})",
        "youtu%.be/([%w%-_]{11})",
        "youtube%.com/embed/([%w%-_]{11})",
        "youtube%.com/shorts/([%w%-_]{11})",
        "youtube%.com/v/([%w%-_]{11})",
        "youtube%.com/live/([%w%-_]{11})",
        "music%.youtube%.com/watch%?.*v=([%w%-_]{11})",
    }
    for _, pat in ipairs(patterns) do
        local id = input:match(pat)
        if id then return id end
    end
    return nil
end

function YouTubeAPI.fetchOEmbed(videoId)
    if not videoId then return nil, "Missing video id" end
    local watch = "https://www.youtube.com/watch?v=" .. videoId
    local url = "https://www.youtube.com/oembed?url=" .. HttpService:UrlEncode(watch) .. "&format=json"
    local res, err = httpRequest({ Url = url, Method = "GET" })
    if not res then return nil, err or "oEmbed request failed" end
    local code = res.StatusCode or res.Status or 0
    local body = res.Body or res.body or ""
    if code < 200 or code >= 300 then
        return nil, "Invalid or unavailable video"
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok or not data then return nil, "Failed to parse video info" end
    return data, nil
end

function YouTubeAPI.formatDuration(iso)
    if type(iso) ~= "string" then return "" end
    local h = tonumber(iso:match("(%d+)H")) or 0
    local m = tonumber(iso:match("(%d+)M")) or 0
    local s = tonumber(iso:match("(%d+)S")) or 0
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

function YouTubeAPI.bestThumbnail(snippet)
    if not snippet or not snippet.thumbnails then return nil end
    local t = snippet.thumbnails
    for _, k in ipairs({ "medium", "high", "default", "standard", "maxres" }) do
        if t[k] and t[k].url then return t[k].url end
    end
    return nil
end

function YouTubeAPI.thumbnailForId(videoId)
    if not videoId then return nil end
    return "https://i.ytimg.com/vi/" .. videoId .. "/hqdefault.jpg"
end

return YouTubeAPI
