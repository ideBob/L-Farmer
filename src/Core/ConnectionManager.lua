--[[
    ConnectionManager — track and disconnect RBXScriptConnections cleanly.
]]

local ConnectionManager = {}
ConnectionManager.__index = ConnectionManager

function ConnectionManager.new()
	return setmetatable({ _list = {} }, ConnectionManager)
end

function ConnectionManager:add(conn)
	if typeof(conn) == "RBXScriptConnection" then
		table.insert(self._list, conn)
	end
	return conn
end

function ConnectionManager:addNamed(name, conn)
	if self._list[name] and typeof(self._list[name]) == "RBXScriptConnection" then
		self._list[name]:Disconnect()
	end
	if typeof(conn) == "RBXScriptConnection" then
		self._list[name] = conn
	end
	return conn
end

function ConnectionManager:disconnect(name)
	local c = self._list[name]
	if typeof(c) == "RBXScriptConnection" then
		c:Disconnect()
	end
	self._list[name] = nil
end

function ConnectionManager:disconnectAll()
	for k, c in pairs(self._list) do
		if typeof(c) == "RBXScriptConnection" then
			pcall(function() c:Disconnect() end)
		end
		self._list[k] = nil
	end
end

return ConnectionManager
