--[[
    Optional UI hooks for RoundDetector.
    install(screenGui, detector, StarterGui) -> { Destroy }
]]

local TweenService = game:GetService("TweenService")

return function(screenGui, detector, StarterGui)
	if not screenGui or not detector then return nil end

	local badge = Instance.new("Frame")
	badge.Name = "RoundStatusBadge"
	badge.Size = UDim2.fromOffset(160, 28)
	badge.Position = UDim2.new(0.5, -80, 0, 12)
	badge.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
	badge.BackgroundTransparency = 0.15
	badge.BorderSizePixel = 0
	badge.Parent = screenGui
	Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 68)
	stroke.Thickness = 1
	stroke.Transparency = 0.3
	stroke.Parent = badge

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 1, 0)
	label.Position = UDim2.fromOffset(4, 0)
	label.BackgroundTransparency = 1
	label.Text = "Round: " .. tostring(detector.CurrentState)
	label.TextColor3 = Color3.fromRGB(200, 200, 210)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.Parent = badge

	local function setLabel(text, color)
		label.Text = text
		if color then label.TextColor3 = color end
	end

	local unsubStart = detector:OnRoundStarted(function(state, id)
		setLabel("Round " .. tostring(id) .. ": Active", Color3.fromRGB(80, 220, 120))
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Evade",
				Text = "Round started",
				Duration = 2,
			})
		end)
	end)

	local unsubEnd = detector:OnRoundEnded(function(state, id)
		setLabel("Round " .. tostring(id) .. ": Ended", Color3.fromRGB(255, 160, 80))
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Evade",
				Text = "Round ended",
				Duration = 3,
			})
		end)
	end)

	-- periodic label sync without heavy polling
	local hb
	hb = game:GetService("RunService").Heartbeat:Connect(function()
		-- only refresh text if inactive and state text drifted
		if not detector.IsRoundActive then
			local want = "Round: " .. tostring(detector.CurrentState)
			if label.Text ~= want and not string.find(label.Text, "Ended", 1, true) then
				setLabel(want, Color3.fromRGB(200, 200, 210))
			end
		end
	end)

	return {
		Badge = badge,
		Destroy = function()
			if unsubStart then unsubStart() end
			if unsubEnd then unsubEnd() end
			if hb then hb:Disconnect() end
			badge:Destroy()
		end,
	}
end
