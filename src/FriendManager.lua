--[[
    Friend Request Manager module v1.4.0
    Attempts real friends.roblox.com endpoints when the environment can authenticate.
    Falls back to official Players:GetFriendsAsync for the friends list.
    Does not invent unsupported engine APIs.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local FriendManager = {}
FriendManager.__index = FriendManager

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
	return nil, "No supported HTTP method"
end

function FriendManager.new()
	local self = setmetatable({}, FriendManager)
	self.lastError = nil
	self.busy = false
	return self
end

function FriendManager:getPendingRequests()
	self.lastError = nil
	local res, err = httpRequest({
		Url = "https://friends.roblox.com/v1/my/friends/requests?limit=25",
		Method = "GET",
		Headers = { ["Content-Type"] = "application/json" },
	})
	if not res then
		self.lastError = err or "Request failed"
		return nil, self.lastError
	end
	local code = res.StatusCode or res.Status or 0
	local body = res.Body or res.body or ""
	if code == 401 or code == 403 then
		self.lastError = "Not authenticated for friend requests (platform limit)"
		return nil, self.lastError
	end
	if code < 200 or code >= 300 then
		self.lastError = "HTTP " .. tostring(code)
		return nil, self.lastError
	end
	local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
	if not ok or not data then
		self.lastError = "Failed to parse friend requests"
		return nil, self.lastError
	end
	return data.data or {}, nil
end

function FriendManager:acceptRequest(userId)
	userId = tonumber(userId)
	if not userId then return false, "Invalid userId" end
	local res, err = httpRequest({
		Url = "https://friends.roblox.com/v1/users/" .. userId .. "/accept-friend-request",
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
	})
	if not res then return false, err or "Accept failed" end
	local code = res.StatusCode or res.Status or 0
	if code == 200 or code == 201 then return true end
	if code == 401 or code == 403 then
		return false, "Not allowed to accept requests from this environment"
	end
	return false, "HTTP " .. tostring(code)
end

function FriendManager:declineRequest(userId)
	userId = tonumber(userId)
	if not userId then return false, "Invalid userId" end
	local res, err = httpRequest({
		Url = "https://friends.roblox.com/v1/users/" .. userId .. "/decline-friend-request",
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
	})
	if not res then return false, err or "Decline failed" end
	local code = res.StatusCode or res.Status or 0
	if code == 200 or code == 201 then return true end
	if code == 401 or code == 403 then
		return false, "Not allowed to decline requests from this environment"
	end
	return false, "HTTP " .. tostring(code)
end

-- Official engine API: current friends list
function FriendManager:getFriendsList(userId)
	userId = userId or Players.LocalPlayer.UserId
	local friends = {}
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(userId)
	end)
	if not ok or not pages then
		return nil, "GetFriendsAsync failed"
	end
	while true do
		local pageOk, items = pcall(function() return pages:GetCurrentPage() end)
		if pageOk and items then
			for _, item in ipairs(items) do
				table.insert(friends, {
					id = item.Id or item.id,
					username = item.Username or item.username or "?",
					displayName = item.DisplayName or item.displayName or item.Username or "?",
					isOnline = item.IsOnline or item.isOnline,
				})
			end
		end
		if pages.IsFinished then break end
		local advOk = pcall(function() pages:AdvanceToNextPageAsync() end)
		if not advOk then break end
	end
	return friends, nil
end

function FriendManager.getThumbnail(userId)
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)
	end)
	if ok then return content end
	return nil
end

return FriendManager
