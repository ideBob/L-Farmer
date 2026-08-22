--[[
    Round Timer settings panel for L Farmer.
    install(screenGui, makeDraggable, StarterGui, OverheadTimerModule) -> controller
]]

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local CONFIG_KEY = "LFarmer_RoundTimer_v1"

local function loadConfig()
	local ok, data = pcall(function()
		if isfile and isfile(CONFIG_KEY .. ".json") then
			return HttpService:JSONDecode(readfile(CONFIG_KEY .. ".json"))
		end
	end)
	if ok and type(data) == "table" then return data end
	return nil
end

local function saveConfig(settings)
	pcall(function()
		if writefile then
			writefile(CONFIG_KEY .. ".json", HttpService:JSONEncode(settings))
		end
	end)
end

local function makeToggle(parent, y, labelText, default, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -24, 0, 32)
	row.Position = UDim2.fromOffset(12, y)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -70, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(56, 26)
	btn.Position = UDim2.new(1, -56, 0.5, -13)
	btn.BackgroundColor3 = default and Color3.fromRGB(40, 160, 90) or Color3.fromRGB(50, 50, 55)
	btn.Text = default and "ON" or "OFF"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.AutoButtonColor = false
	btn.Parent = row
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local state = default
	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.Text = state and "ON" or "OFF"
		btn.BackgroundColor3 = state and Color3.fromRGB(40, 160, 90) or Color3.fromRGB(50, 50, 55)
		if onChange then onChange(state) end
	end)
	return row, function() return state end, function(v)
		state = v and true or false
		btn.Text = state and "ON" or "OFF"
		btn.BackgroundColor3 = state and Color3.fromRGB(40, 160, 90) or Color3.fromRGB(50, 50, 55)
	end
end

local function makeSlider(parent, y, labelText, minV, maxV, default, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -24, 0, 48)
	row.Position = UDim2.fromOffset(12, y)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -50, 0, 18)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local valLbl = Instance.new("TextLabel")
	valLbl.Size = UDim2.fromOffset(48, 18)
	valLbl.Position = UDim2.new(1, -48, 0, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.Text = tostring(default)
	valLbl.TextColor3 = Color3.fromRGB(160, 160, 170)
	valLbl.Font = Enum.Font.GothamMedium
	valLbl.TextSize = 12
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Position = UDim2.fromOffset(0, 28)
	track.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	track.BorderSizePixel = 0
	track.Parent = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((default - minV) / (maxV - minV), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
	fill.BorderSizePixel = 0
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("TextButton")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Position = UDim2.new((default - minV) / (maxV - minV), -8, 0.5, -8)
	knob.BackgroundColor3 = Color3.fromRGB(230, 230, 240)
	knob.Text = ""
	knob.AutoButtonColor = false
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local value = default
	local dragging = false
	local UserInputService = game:GetService("UserInputService")

	local function setFromAlpha(a)
		a = math.clamp(a, 0, 1)
		value = math.floor((minV + a * (maxV - minV)) * 10 + 0.5) / 10
		if maxV - minV > 20 then value = math.floor(value + 0.5) end
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, -8, 0.5, -8)
		valLbl.Text = tostring(value)
		if onChange then onChange(value) end
	end

	local function updateFromInput(input)
		local rel = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		setFromAlpha(rel)
	end

	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromInput(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			updateFromInput(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return row, function() return value end, function(v)
		setFromAlpha((v - minV) / (maxV - minV))
	end
end

return function(screenGui, makeDraggable, StarterGui, OverheadTimer)
	if not screenGui or not OverheadTimer then return nil end

	local saved = loadConfig() or {}
	local timer = OverheadTimer.new({
		enabled = saved.enabled == true,
		showRoundLabel = saved.showRoundLabel ~= false,
		alwaysOnTop = saved.alwaysOnTop ~= false,
		maxDistance = saved.maxDistance or 90,
		size = saved.size or 220,
		studsOffsetY = saved.studsOffsetY or 2.9,
	})

	local function persist()
		saveConfig(timer:GetSettings())
	end

	-- Floating open button
	local btnFrame = Instance.new("Frame")
	btnFrame.Name = "RoundTimerBtnFrame"
	btnFrame.Size = UDim2.fromOffset(150, 40)
	btnFrame.Position = UDim2.new(0.05, 0, 0.91, 0)
	btnFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	btnFrame.BorderSizePixel = 0
	btnFrame.Parent = screenGui
	Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 68)
	stroke.Thickness = 1.2
	stroke.Transparency = 0.3
	stroke.Parent = btnFrame

	local openBtn = Instance.new("TextButton")
	openBtn.Size = UDim2.new(1, -8, 1, -8)
	openBtn.Position = UDim2.fromOffset(4, 4)
	openBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
	openBtn.Text = "Round Timer"
	openBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
	openBtn.Font = Enum.Font.GothamBold
	openBtn.TextSize = 13
	openBtn.AutoButtonColor = false
	openBtn.Parent = btnFrame
	Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)

	if makeDraggable then makeDraggable(btnFrame, openBtn) end

	-- Panel
	local panel = Instance.new("Frame")
	panel.Name = "RoundTimerPanel"
	panel.Size = UDim2.fromOffset(320, 420)
	panel.Position = UDim2.new(0.5, -160, 0.5, -210)
	panel.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ClipsDescendants = true
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(60, 60, 68)
	pStroke.Thickness = 1.2
	pStroke.Transparency = 0.25
	pStroke.Parent = panel

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -50, 0, 36)
	header.Position = UDim2.fromOffset(14, 8)
	header.BackgroundTransparency = 1
	header.Text = "Round Timer"
	header.TextColor3 = Color3.fromRGB(100, 180, 255)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 17
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(32, 32)
	closeBtn.Position = UDim2.new(1, -40, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = panel
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -28, 0, 20)
	status.Position = UDim2.fromOffset(14, 42)
	status.BackgroundTransparency = 1
	status.Text = timer.settings.enabled and "Overhead timer enabled" or "Overhead timer off"
	status.TextColor3 = Color3.fromRGB(150, 150, 160)
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = panel

	if makeDraggable then makeDraggable(panel, header) end

	local s = timer.settings
	local y = 70

	local _, _, setEnabledUI
	_, _, setEnabledUI = makeToggle(panel, y, "Enable Overhead Timer", s.enabled, function(on)
		if on then
			timer:Enable()
			status.Text = "Overhead timer enabled"
			status.TextColor3 = Color3.fromRGB(80, 200, 120)
		else
			timer:Disable()
			status.Text = "Overhead timer off"
			status.TextColor3 = Color3.fromRGB(150, 150, 160)
		end
		persist()
	end)
	y = y + 38

	makeToggle(panel, y, "Show \"ROUND\" Label", s.showRoundLabel, function(on)
		timer:SetShowRoundLabel(on)
		persist()
	end)
	y = y + 38

	makeToggle(panel, y, "Always On Top", s.alwaysOnTop, function(on)
		timer:SetAlwaysOnTop(on)
		persist()
	end)
	y = y + 42

	makeSlider(panel, y, "Timer Distance", 25, 250, s.maxDistance, function(v)
		timer:SetMaxDistance(v)
		persist()
	end)
	y = y + 54

	makeSlider(panel, y, "Timer Size", 150, 350, s.size, function(v)
		timer:SetSize(v)
		persist()
	end)
	y = y + 54

	makeSlider(panel, y, "Vertical Offset", 1, 6, s.studsOffsetY, function(v)
		timer:SetStudsOffsetY(v)
		persist()
	end)

	closeBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
		openBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
		openBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
	end)

	openBtn.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			openBtn.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
			openBtn.TextColor3 = Color3.fromRGB(10, 10, 12)
			TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
			}):Play()
		else
			openBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
			openBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
		end
	end)

	return {
		Timer = timer,
		Panel = panel,
		Destroy = function()
			timer:Destroy()
			panel:Destroy()
			btnFrame:Destroy()
		end,
	}
end
