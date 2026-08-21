--[[
    Evade RoundDetector (discovery-based)

    Does NOT hardcode remote names.
    Inspects client-accessible replicated state and listens only.
    Never fires or spoofs remotes.

    API:
      IsRoundActive : boolean
      CurrentState  : string
      OnRoundStarted(callback)
      OnRoundEnded(callback)
      Discover()    : discovery report table
      Destroy()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ACTIVE_TOKENS = {
	active = true, ingame = true, playing = true, inround = true,
	started = true, ongoing = true, running = true, live = true,
}
local IDLE_TOKENS = {
	lobby = true, waiting = true, intermission = true, ended = true,
	end = true, finished = true, results = true, menu = true,
	idle = true, none = true,
}
local KEYWORDS = {
	"round", "game", "state", "status", "phase", "match", "session",
	"intermission", "lobby", "playing", "ingame",
}

local function lower(s)
	return string.lower(tostring(s or ""))
end

local function nameLooksRelevant(name)
	local n = lower(name)
	for _, k in ipairs(KEYWORDS) do
		if string.find(n, k, 1, true) then return true end
	end
	return false
end

local function classifyValue(v)
	if v == nil then return "Unknown" end
	if type(v) == "boolean" then
		return v and "Active" or "Idle"
	end
	if type(v) == "number" then
		-- common pattern: 0 lobby, 1 active, 2 end — treated as unknown until observed
		if v == 0 then return "Idle" end
		if v > 0 then return "Active" end
	end
	local s = lower(v)
	for token in string.gmatch(s, "%w+") do
		if ACTIVE_TOKENS[token] then return "Active" end
		if IDLE_TOKENS[token] then return "Idle" end
	end
	if string.find(s, "end", 1, true) or string.find(s, "result", 1, true) then
		return "Ended"
	end
	return "Unknown"
end

local RoundDetector = {}
RoundDetector.__index = RoundDetector

function RoundDetector.new(opts)
	opts = opts or {}
	local self = setmetatable({}, RoundDetector)
	self.IsRoundActive = false
	self.CurrentState = "Unknown"
	self._startedCbs = {}
	self._endedCbs = {}
	self._conns = {}
	self._lastRoundId = 0
	self._endedForRound = nil
	self._discovered = { values = {}, remotes = {}, attributes = {} }
	self._debug = opts.Debug == true
	self._notify = opts.OnNotify -- optional function(title, text)

	self:_discoverAndBind()
	return self
end

function RoundDetector:_log(...)
	if self._debug then
		print("[RoundDetector]", ...)
	end
end

function RoundDetector:_addConn(c)
	if typeof(c) == "RBXScriptConnection" then
		table.insert(self._conns, c)
	end
end

function RoundDetector:_setState(newState, source)
	local prev = self.CurrentState
	local classified = classifyValue(newState)
	if classified == "Unknown" and type(newState) == "string" then
		classified = newState
	end

	local wasActive = self.IsRoundActive
	local nowActive = (classified == "Active")

	self.CurrentState = tostring(newState)
	self.IsRoundActive = nowActive

	if nowActive and not wasActive then
		self._lastRoundId = self._lastRoundId + 1
		self._endedForRound = nil
		self:_log("Round started via", source, self.CurrentState)
		for _, cb in ipairs(self._startedCbs) do
			task.spawn(cb, self.CurrentState, self._lastRoundId)
		end
	elif (not nowActive) and wasActive then
		if self._endedForRound ~= self._lastRoundId then
			self._endedForRound = self._lastRoundId
			self:_log("Round ended via", source, self.CurrentState)
			for _, cb in ipairs(self._endedCbs) do
				task.spawn(cb, self.CurrentState, self._lastRoundId)
			end
		end
	elseif classified == "Ended" and wasActive then
		if self._endedForRound ~= self._lastRoundId then
			self._endedForRound = self._lastRoundId
			self.IsRoundActive = false
			for _, cb in ipairs(self._endedCbs) do
				task.spawn(cb, self.CurrentState, self._lastRoundId)
			end
		end
	end
end

function RoundDetector:_bindValue(obj)
	if not obj or not obj.Parent then return end
	local className = obj.ClassName
	if className == "StringValue" or className == "IntValue" or className == "NumberValue" or className == "BoolValue" then
		table.insert(self._discovered.values, obj:GetFullName())
		self:_setState(obj.Value, obj:GetFullName())
		self:_addConn(obj:GetPropertyChangedSignal("Value"):Connect(function()
			self:_setState(obj.Value, obj:GetFullName())
		end))
		self:_addConn(obj.AncestryChanged:Connect(function(_, parent)
			if not parent then
				-- object removed; rediscovery deferred
				task.defer(function() self:_discoverAndBind() end)
			end
		end))
	end
end

function RoundDetector:_bindRemote(remote)
	if not remote or not remote:IsA("RemoteEvent") then return end
	if not nameLooksRelevant(remote.Name) then return end
	table.insert(self._discovered.remotes, remote:GetFullName())
	-- Observe only — never FireServer / FireClient
	self:_addConn(remote.OnClientEvent:Connect(function(...)
		local args = { ... }
		local payload = args[1]
		if type(payload) == "string" or type(payload) == "number" or type(payload) == "boolean" then
			self:_setState(payload, remote:GetFullName())
		elseif type(payload) == "table" then
			local st = payload.State or payload.state or payload.Status or payload.status
				or payload.Phase or payload.phase or payload.RoundState or payload.roundState
			if st ~= nil then
				self:_setState(st, remote:GetFullName())
			end
		end
	end))
end

function RoundDetector:_scanFolder(root, depth)
	depth = depth or 0
	if depth > 5 or not root then return end
	for _, child in ipairs(root:GetChildren()) do
		if nameLooksRelevant(child.Name) then
			if child:IsA("ValueBase") then
				self:_bindValue(child)
			elseif child:IsA("RemoteEvent") then
				self:_bindRemote(child)
			elseif child:IsA("Folder") or child:IsA("Configuration") or child:IsA("ModuleScript") == false then
				-- dig one level into relevant folders
				for _, sub in ipairs(child:GetChildren()) do
					if sub:IsA("ValueBase") then
						self:_bindValue(sub)
					elseif sub:IsA("RemoteEvent") and nameLooksRelevant(sub.Name) then
						self:_bindRemote(sub)
					end
				end
			end
		end
		-- attributes on instances with relevant names
		if nameLooksRelevant(child.Name) then
			for attr, val in pairs(child:GetAttributes()) do
				if nameLooksRelevant(attr) then
					table.insert(self._discovered.attributes, child:GetFullName() .. "." .. attr)
					self:_setState(val, child:GetFullName() .. "@" .. attr)
					self:_addConn(child:GetAttributeChangedSignal(attr):Connect(function()
						self:_setState(child:GetAttribute(attr), child:GetFullName() .. "@" .. attr)
					end))
				end
			end
		end
	end
end

function RoundDetector:_discoverAndBind()
	-- clear previous connections before rebinding
	for _, c in ipairs(self._conns) do
		pcall(function() c:Disconnect() end)
	end
	self._conns = {}
	self._discovered = { values = {}, remotes = {}, attributes = {} }

	-- Primary: ReplicatedStorage
	self:_scanFolder(ReplicatedStorage, 0)

	-- Secondary: common client-visible containers
	local player = Players.LocalPlayer
	if player then
		local pg = player:FindFirstChild("PlayerGui")
		if pg then self:_scanFolder(pg, 0) end
	end

	-- Watch for late-created relevant children under RS
	self:_addConn(ReplicatedStorage.ChildAdded:Connect(function(child)
		if nameLooksRelevant(child.Name) then
			task.defer(function() self:_discoverAndBind() end)
		end
	end))

	self:_log(
		"Discovery:",
		#self._discovered.values, "values,",
		#self._discovered.remotes, "remotes,",
		#self._discovered.attributes, "attrs"
	)
end

function RoundDetector:OnRoundStarted(cb)
	if type(cb) == "function" then table.insert(self._startedCbs, cb) end
	return function()
		for i, f in ipairs(self._startedCbs) do
			if f == cb then table.remove(self._startedCbs, i) break end
		end
	end
end

function RoundDetector:OnRoundEnded(cb)
	if type(cb) == "function" then table.insert(self._endedCbs, cb) end
	return function()
		for i, f in ipairs(self._endedCbs) do
			if f == cb then table.remove(self._endedCbs, i) break end
		end
	end
end

function RoundDetector:Discover()
	return {
		state = self.CurrentState,
		active = self.IsRoundActive,
		values = self._discovered.values,
		remotes = self._discovered.remotes,
		attributes = self._discovered.attributes,
	}
end

function RoundDetector:Destroy()
	for _, c in ipairs(self._conns) do
		pcall(function() c:Disconnect() end)
	end
	self._conns = {}
	self._startedCbs = {}
	self._endedCbs = {}
end

return RoundDetector
