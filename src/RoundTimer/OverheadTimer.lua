--[[
    Overhead Round Timer — mirrors Evade's PlayerGui timer above the local head.
    Never modifies the game's original timer.
]]

local Players = game:GetService("Players")

local TIMER_PATH = { "Game", "HUD", "Overlay", "RoundOverlay", "RoundTimer", "RoundTimer", "Timer" }

local OverheadTimer = {}
OverheadTimer.__index = OverheadTimer

local DEFAULTS = {
	enabled = false,
	showRoundLabel = true,
	alwaysOnTop = true,
	maxDistance = 90,
	size = 220,
	studsOffsetY = 2.9,
}

local function findOriginalTimer(playerGui, timeout)
	timeout = timeout or 8
	local ok, result = pcall(function()
		local node = playerGui
		for i, name in ipairs(TIMER_PATH) do
			local waitTime = (i == 1) and timeout or 3
			node = node:WaitForChild(name, waitTime)
			if not node then return nil end
		end
		return node
	end)
	if ok and result and result:IsA("TextLabel") or (ok and result and result:IsA("GuiObject")) then
		return result
	end
	-- fallback: deep search for a TextLabel named Timer under Game
	local gameGui = playerGui:FindFirstChild("Game")
	if not gameGui then return nil end
	for _, d in ipairs(gameGui:GetDescendants()) do
		if d.Name == "Timer" and d:IsA("TextLabel") then
			local p = d.Parent
			if p and (p.Name == "RoundTimer" or (p.Parent and p.Parent.Name == "RoundTimer")) then
				return d
			end
		end
	end
	return nil
end

function OverheadTimer.new(opts)
	opts = opts or {}
	local self = setmetatable({}, OverheadTimer)
	self.player = Players.LocalPlayer
	self.playerGui = self.player:WaitForChild("PlayerGui")
	self.settings = {
		enabled = opts.enabled == true,
		showRoundLabel = opts.showRoundLabel ~= false,
		alwaysOnTop = opts.alwaysOnTop ~= false,
		maxDistance = tonumber(opts.maxDistance) or DEFAULTS.maxDistance,
		size = tonumber(opts.size) or DEFAULTS.size,
		studsOffsetY = tonumber(opts.studsOffsetY) or DEFAULTS.studsOffsetY,
	}
	self._billboard = nil
	self._timerLabel = nil
	self._titleLabel = nil
	self._syncConn = nil
	self._charConn = nil
	self._original = nil
	self._destroyed = false

	self._charConn = self.player.CharacterAdded:Connect(function(char)
		if self._destroyed then return end
		task.wait(0.45)
		if self.settings.enabled then
			self:_recreate(char)
		end
	end)

	if self.settings.enabled then
		task.defer(function() self:Enable() end)
	end
	return self
end

function OverheadTimer:_clearSync()
	if self._syncConn then
		pcall(function() self._syncConn:Disconnect() end)
		self._syncConn = nil
	end
end

function OverheadTimer:_destroyBillboard()
	self:_clearSync()
	if self._billboard then
		pcall(function() self._billboard:Destroy() end)
		self._billboard = nil
		self._timerLabel = nil
		self._titleLabel = nil
	end
	-- safety: remove any stragglers on head
	local char = self.player.Character
	if char then
		local head = char:FindFirstChild("Head")
		if head then
			local old = head:FindFirstChild("OverheadRoundTimer")
			if old then pcall(function() old:Destroy() end) end
		end
	end
end

function OverheadTimer:_resolveOriginal()
	if self._original and self._original.Parent then
		return self._original
	end
	self._original = findOriginalTimer(self.playerGui, 6)
	return self._original
end

function OverheadTimer:_createBillboard(character)
	self:_destroyBillboard()
	if not character then return false end

	local head = character:FindFirstChild("Head")
	if not head then
		head = character:WaitForChild("Head", 5)
	end
	if not head then return false end

	local original = self:_resolveOriginal()
	-- still create UI even if original missing; text stays "--:--" until found

	local size = self.settings.size
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OverheadRoundTimer"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(size, math.floor(size * 0.26))
	billboard.StudsOffset = Vector3.new(0, self.settings.studsOffsetY, 0)
	billboard.AlwaysOnTop = self.settings.alwaysOnTop
	billboard.MaxDistance = self.settings.maxDistance
	billboard.Parent = head

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	bg.BackgroundTransparency = 0.22
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.82
	stroke.Thickness = 1.4
	stroke.Parent = bg

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 32, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 14)),
	})
	gradient.Rotation = 90
	gradient.Parent = bg

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerText"
	timerLabel.Size = UDim2.new(1, -12, 1, -6)
	timerLabel.Position = UDim2.fromOffset(6, 3)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = (original and original.Text) or "--:--"
	timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timerLabel.TextStrokeTransparency = 0.65
	timerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextSize = math.clamp(math.floor(size * 0.12), 18, 32)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Center
	timerLabel.TextYAlignment = Enum.TextYAlignment.Center
	timerLabel.Parent = bg

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 15)
	title.Position = UDim2.fromOffset(0, 2)
	title.BackgroundTransparency = 1
	title.Text = "ROUND"
	title.TextColor3 = Color3.fromRGB(170, 170, 185)
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 11
	title.TextTransparency = 0.25
	title.Visible = self.settings.showRoundLabel
	title.Parent = bg

	self._billboard = billboard
	self._timerLabel = timerLabel
	self._titleLabel = title

	self:_bindSync(original)
	return true
end

function OverheadTimer:_bindSync(original)
	self:_clearSync()
	if not original or not self._timerLabel then return end

	self._timerLabel.Text = original.Text
	self._syncConn = original:GetPropertyChangedSignal("Text"):Connect(function()
		if self._timerLabel and self._timerLabel.Parent then
			self._timerLabel.Text = original.Text
		end
	end)

	-- if original is destroyed, try to re-resolve later
	original.AncestryChanged:Connect(function(_, parent)
		if not parent and self.settings.enabled then
			self:_clearSync()
			task.delay(1, function()
				if self._destroyed or not self.settings.enabled then return end
				local again = self:_resolveOriginal()
				if again then self:_bindSync(again) end
			end)
		end
	end)
end

function OverheadTimer:_recreate(character)
	if not self.settings.enabled then return end
	character = character or self.player.Character
	self:_createBillboard(character)
end

function OverheadTimer:Enable()
	self.settings.enabled = true
	local char = self.player.Character
	if char then
		self:_recreate(char)
	else
		-- wait for character
		task.spawn(function()
			local c = self.player.Character or self.player.CharacterAdded:Wait()
			task.wait(0.4)
			if self.settings.enabled then self:_recreate(c) end
		end)
	end
end

function OverheadTimer:Disable()
	self.settings.enabled = false
	self:_destroyBillboard()
end

function OverheadTimer:SetShowRoundLabel(v)
	self.settings.showRoundLabel = v and true or false
	if self._titleLabel then
		self._titleLabel.Visible = self.settings.showRoundLabel
	end
end

function OverheadTimer:SetAlwaysOnTop(v)
	self.settings.alwaysOnTop = v and true or false
	if self._billboard then
		self._billboard.AlwaysOnTop = self.settings.alwaysOnTop
	end
end

function OverheadTimer:SetMaxDistance(n)
	n = math.clamp(tonumber(n) or DEFAULTS.maxDistance, 25, 250)
	self.settings.maxDistance = n
	if self._billboard then
		self._billboard.MaxDistance = n
	end
end

function OverheadTimer:SetSize(n)
	n = math.clamp(tonumber(n) or DEFAULTS.size, 150, 350)
	self.settings.size = n
	if self._billboard then
		self._billboard.Size = UDim2.fromOffset(n, math.floor(n * 0.26))
		if self._timerLabel then
			self._timerLabel.TextSize = math.clamp(math.floor(n * 0.12), 18, 32)
		end
	end
end

function OverheadTimer:SetStudsOffsetY(n)
	n = math.clamp(tonumber(n) or DEFAULTS.studsOffsetY, 1, 6)
	self.settings.studsOffsetY = n
	if self._billboard then
		self._billboard.StudsOffset = Vector3.new(0, n, 0)
	end
end

function OverheadTimer:GetSettings()
	local s = {}
	for k, v in pairs(self.settings) do s[k] = v end
	return s
end

function OverheadTimer:Destroy()
	self._destroyed = true
	self:Disable()
	if self._charConn then
		pcall(function() self._charConn:Disconnect() end)
		self._charConn = nil
	end
end

return OverheadTimer
