--[[
    Sunset Shader UI section for L Farmer.
    install(screenGui, makeDraggable, StarterGui, SunsetShader) -> controller
]]

local TweenService = game:GetService("TweenService")

return function(screenGui, makeDraggable, StarterGui, SunsetShader)
	if not screenGui or not SunsetShader then return nil end

	local shader = SunsetShader.new()

	-- Floating button
	local btnFrame = Instance.new("Frame")
	btnFrame.Name = "SunsetBtnFrame"
	btnFrame.Size = UDim2.fromOffset(140, 40)
	btnFrame.Position = UDim2.new(0.05, 0, 0.05, 0)
	btnFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	btnFrame.BorderSizePixel = 0
	btnFrame.Parent = screenGui
	Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 140, 70)
	stroke.Thickness = 1.2
	stroke.Transparency = 0.45
	stroke.Parent = btnFrame

	local openBtn = Instance.new("TextButton")
	openBtn.Size = UDim2.new(1, -8, 1, -8)
	openBtn.Position = UDim2.fromOffset(4, 4)
	openBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
	openBtn.Text = "Sunset"
	openBtn.TextColor3 = Color3.fromRGB(255, 200, 150)
	openBtn.Font = Enum.Font.GothamBold
	openBtn.TextSize = 13
	openBtn.AutoButtonColor = false
	openBtn.Parent = btnFrame
	Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)

	if makeDraggable then makeDraggable(btnFrame, openBtn) end

	-- Panel
	local panel = Instance.new("Frame")
	panel.Name = "SunsetPanel"
	panel.Size = UDim2.fromOffset(300, 200)
	panel.Position = UDim2.new(0.5, -150, 0.5, -100)
	panel.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(255, 130, 60)
	pStroke.Thickness = 1.15
	pStroke.Transparency = 0.4
	pStroke.Parent = panel

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -50, 0, 34)
	header.Position = UDim2.fromOffset(14, 8)
	header.BackgroundTransparency = 1
	header.Text = "Sunset Shader"
	header.TextColor3 = Color3.fromRGB(255, 170, 100)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 16
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(30, 30)
	closeBtn.Position = UDim2.new(1, -38, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 40)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 13
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = panel
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -28, 0, 40)
	desc.Position = UDim2.fromOffset(14, 44)
	desc.BackgroundTransparency = 1
	desc.Text = "Cinematic golden-hour lighting, warm atmosphere, soft bloom. Max graphics applied once on load."
	desc.TextColor3 = Color3.fromRGB(150, 150, 160)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 12
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Parent = panel

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -28, 0, 18)
	status.Position = UDim2.fromOffset(14, 90)
	status.BackgroundTransparency = 1
	status.Text = "Status: Off"
	status.TextColor3 = Color3.fromRGB(160, 160, 170)
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = panel

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(1, -28, 0, 40)
	toggleBtn.Position = UDim2.fromOffset(14, 120)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 70)
	toggleBtn.Text = "Enable Sunset"
	toggleBtn.TextColor3 = Color3.fromRGB(20, 12, 8)
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 14
	toggleBtn.AutoButtonColor = false
	toggleBtn.Parent = panel
	Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

	if makeDraggable then makeDraggable(panel, header) end

	local function refresh()
		if shader.Enabled then
			status.Text = "Status: On · cinematic sunset"
			status.TextColor3 = Color3.fromRGB(255, 180, 100)
			toggleBtn.Text = "Disable Sunset"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 45)
			toggleBtn.TextColor3 = Color3.fromRGB(255, 200, 160)
			openBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 70)
			openBtn.TextColor3 = Color3.fromRGB(20, 12, 8)
		else
			status.Text = "Status: Off"
			status.TextColor3 = Color3.fromRGB(160, 160, 170)
			toggleBtn.Text = "Enable Sunset"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 70)
			toggleBtn.TextColor3 = Color3.fromRGB(20, 12, 8)
			openBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
			openBtn.TextColor3 = Color3.fromRGB(255, 200, 150)
		end
	end

	toggleBtn.MouseButton1Click:Connect(function()
		shader:Toggle()
		refresh()
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Sunset Shader",
				Text = shader.Enabled and "Enabled" or "Disabled",
				Duration = 2,
			})
		end)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	openBtn.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
			}):Play()
		end
	end)

	refresh()

	return {
		Shader = shader,
		Panel = panel,
		Destroy = function()
			shader:Destroy()
			panel:Destroy()
			btnFrame:Destroy()
		end,
	}
end
