--[[
    Friend Request Manager UI installer
    install(screenGui, makeDraggable, StarterGui, TweenService, FriendManager)
]]

return function(screenGui, makeDraggable, StarterGui, TweenService, FriendManager)
	if not screenGui or not FriendManager then return nil end

	local mgr = FriendManager.new()
	local processing = {}

	-- Floating button
	local btnFrame = Instance.new("Frame")
	btnFrame.Name = "FriendsBtnFrame"
	btnFrame.Size = UDim2.new(0, 160, 0, 40)
	btnFrame.Position = UDim2.new(0.05, 0, 0.73, 0)
	btnFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	btnFrame.BorderSizePixel = 0
	btnFrame.Parent = screenGui
	Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 60)
	stroke.Thickness = 1.2
	stroke.Transparency = 0.3
	stroke.Parent = btnFrame

	local friendsBtn = Instance.new("TextButton")
	friendsBtn.Size = UDim2.new(1, -10, 1, -10)
	friendsBtn.Position = UDim2.new(0, 5, 0, 5)
	friendsBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	friendsBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	friendsBtn.TextSize = 14
	friendsBtn.Font = Enum.Font.GothamBold
	friendsBtn.Text = "Friends"
	friendsBtn.AutoButtonColor = false
	friendsBtn.Parent = btnFrame
	Instance.new("UICorner", friendsBtn).CornerRadius = UDim.new(0, 8)

	if makeDraggable then makeDraggable(btnFrame, friendsBtn) end

	-- Panel
	local panel = Instance.new("Frame")
	panel.Name = "FriendRequestPanel"
	panel.Size = UDim2.new(0, 360, 0, 500)
	panel.Position = UDim2.new(0.5, -180, 0.5, -250)
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ClipsDescendants = true
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(60, 60, 60)
	pStroke.Thickness = 1.2
	pStroke.Transparency = 0.3
	pStroke.Parent = panel

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -90, 0, 36)
	header.Position = UDim2.new(0, 14, 0, 8)
	header.BackgroundTransparency = 1
	header.Text = "Friend Request Manager"
	header.TextColor3 = Color3.fromRGB(100, 180, 255)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 16
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = panel

	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size = UDim2.new(0, 32, 0, 32)
	refreshBtn.Position = UDim2.new(1, -78, 0, 8)
	refreshBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	refreshBtn.Text = "↻"
	refreshBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	refreshBtn.Font = Enum.Font.GothamBold
	refreshBtn.TextSize = 16
	refreshBtn.AutoButtonColor = false
	refreshBtn.Parent = panel
	Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 8)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -40, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = panel
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -28, 0, 36)
	status.Position = UDim2.new(0, 14, 0, 44)
	status.BackgroundTransparency = 1
	status.Text = "Tap Refresh to load requests"
	status.TextColor3 = Color3.fromRGB(160, 160, 160)
	status.Font = Enum.Font.Gotham
	status.TextSize = 11
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextWrapped = true
	status.Parent = panel

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -100)
	scroll.Position = UDim2.new(0, 8, 0, 88)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	if makeDraggable then makeDraggable(panel, header) end

	local function toast(title, text)
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = title,
				Text = text,
				Duration = 3,
			})
		end)
	end

	local function clearList()
		for _, c in pairs(scroll:GetChildren()) do
			if not c:IsA("UIListLayout") then c:Destroy() end
		end
	end

	local function emptyState(msg)
		clearList()
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -8, 0, 80)
		lbl.BackgroundTransparency = 1
		lbl.Text = msg or "No pending friend requests"
		lbl.TextColor3 = Color3.fromRGB(140, 140, 140)
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 13
		lbl.TextWrapped = true
		lbl.Parent = scroll
		scroll.CanvasSize = UDim2.new(0, 0, 0, 90)
	end

	local function addRequestRow(entry)
		local userId = entry.id or entry.userId or (entry.friendRequest and entry.friendRequest.sender and entry.friendRequest.sender.id)
		local username = entry.name or entry.username or (entry.friendRequest and entry.friendRequest.sender and entry.friendRequest.sender.name) or "?"
		local displayName = entry.displayName or username
		if type(entry.friendRequest) == "table" and entry.friendRequest.sender then
			local s = entry.friendRequest.sender
			userId = s.id or userId
			username = s.name or username
			displayName = s.displayName or displayName
		end
		if not userId then return end

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -4, 0, 72)
		row.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
		row.BorderSizePixel = 0
		row.Parent = scroll
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

		local avatar = Instance.new("ImageLabel")
		avatar.Size = UDim2.new(0, 52, 0, 52)
		avatar.Position = UDim2.new(0, 10, 0, 10)
		avatar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		avatar.BorderSizePixel = 0
		avatar.Parent = row
		Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
		task.spawn(function()
			local thumb = FriendManager.getThumbnail(userId)
			if thumb and avatar.Parent then avatar.Image = thumb end
		end)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -180, 0, 18)
		nameLbl.Position = UDim2.new(0, 72, 0, 10)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = displayName
		nameLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = row

		local userLbl = Instance.new("TextLabel")
		userLbl.Size = UDim2.new(1, -180, 0, 16)
		userLbl.Position = UDim2.new(0, 72, 0, 28)
		userLbl.BackgroundTransparency = 1
		userLbl.Text = "@" .. username .. "  ·  " .. tostring(userId)
		userLbl.TextColor3 = Color3.fromRGB(140, 140, 140)
		userLbl.Font = Enum.Font.Gotham
		userLbl.TextSize = 11
		userLbl.TextXAlignment = Enum.TextXAlignment.Left
		userLbl.TextTruncate = Enum.TextTruncate.AtEnd
		userLbl.Parent = row

		local accept = Instance.new("TextButton")
		accept.Size = UDim2.new(0, 64, 0, 26)
		accept.Position = UDim2.new(1, -148, 1, -34)
		accept.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
		accept.Text = "Accept"
		accept.TextColor3 = Color3.fromRGB(255, 255, 255)
		accept.Font = Enum.Font.GothamBold
		accept.TextSize = 12
		accept.AutoButtonColor = false
		accept.Parent = row
		Instance.new("UICorner", accept).CornerRadius = UDim.new(0, 6)

		local decline = Instance.new("TextButton")
		decline.Size = UDim2.new(0, 64, 0, 26)
		decline.Position = UDim2.new(1, -76, 1, -34)
		decline.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
		decline.Text = "Decline"
		decline.TextColor3 = Color3.fromRGB(255, 255, 255)
		decline.Font = Enum.Font.GothamBold
		decline.TextSize = 12
		decline.AutoButtonColor = false
		decline.Parent = row
		Instance.new("UICorner", decline).CornerRadius = UDim.new(0, 6)

		local function setBusy(b)
			processing[userId] = b
			accept.Active = not b
			decline.Active = not b
			accept.Text = b and "…" or "Accept"
			decline.Text = b and "…" or "Decline"
		end

		accept.MouseButton1Click:Connect(function()
			if processing[userId] then return end
			setBusy(true)
			task.spawn(function()
				local ok, err = mgr:acceptRequest(userId)
				setBusy(false)
				if ok then
					toast("Friends", "Accepted " .. displayName)
					row:Destroy()
					task.defer(function()
						scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
					end)
				else
					toast("Friends", tostring(err))
					status.Text = tostring(err)
					status.TextColor3 = Color3.fromRGB(220, 80, 80)
				end
			end)
		end)

		decline.MouseButton1Click:Connect(function()
			if processing[userId] then return end
			setBusy(true)
			task.spawn(function()
				local ok, err = mgr:declineRequest(userId)
				setBusy(false)
				if ok then
					toast("Friends", "Declined " .. displayName)
					row:Destroy()
					task.defer(function()
						scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
					end)
				else
					toast("Friends", tostring(err))
					status.Text = tostring(err)
					status.TextColor3 = Color3.fromRGB(220, 80, 80)
				end
			end)
		end)
	end

	local function refresh()
		status.Text = "Loading…"
		status.TextColor3 = Color3.fromRGB(200, 200, 100)
		refreshBtn.Active = false
		clearList()

		task.spawn(function()
			local list, err = mgr:getPendingRequests()
			refreshBtn.Active = true

			if not list then
				-- Official fallback: show friends list so the panel is still useful
				local friends, ferr = mgr:getFriendsList()
				if friends and #friends > 0 then
					status.Text = "Requests unavailable · showing " .. #friends .. " friends\n" .. tostring(err)
					status.TextColor3 = Color3.fromRGB(200, 180, 80)
					for _, f in ipairs(friends) do
						local row = Instance.new("Frame")
						row.Size = UDim2.new(1, -4, 0, 56)
						row.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
						row.BorderSizePixel = 0
						row.Parent = scroll
						Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
						local av = Instance.new("ImageLabel")
						av.Size = UDim2.new(0, 40, 0, 40)
						av.Position = UDim2.new(0, 8, 0, 8)
						av.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
						av.BorderSizePixel = 0
						av.Parent = row
						Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)
						task.spawn(function()
							local t = FriendManager.getThumbnail(f.id)
							if t and av.Parent then av.Image = t end
						end)
						local n = Instance.new("TextLabel")
						n.Size = UDim2.new(1, -60, 0, 18)
						n.Position = UDim2.new(0, 56, 0, 10)
						n.BackgroundTransparency = 1
						n.Text = f.displayName or f.username
						n.TextColor3 = Color3.fromRGB(230, 230, 230)
						n.Font = Enum.Font.GothamBold
						n.TextSize = 13
						n.TextXAlignment = Enum.TextXAlignment.Left
						n.Parent = row
						local u = Instance.new("TextLabel")
						u.Size = UDim2.new(1, -60, 0, 14)
						u.Position = UDim2.new(0, 56, 0, 30)
						u.BackgroundTransparency = 1
						u.Text = "@" .. (f.username or "?") .. "  ·  " .. tostring(f.id)
						u.TextColor3 = Color3.fromRGB(140, 140, 140)
						u.Font = Enum.Font.Gotham
						u.TextSize = 11
						u.TextXAlignment = Enum.TextXAlignment.Left
						u.Parent = row
					end
					task.defer(function()
						scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
					end)
				else
					emptyState(
						"Pending requests cannot be loaded here.\n"
							.. "Roblox does not expose accept/decline APIs to experiences.\n"
							.. "Use the Roblox app/website for requests.\n"
							.. tostring(err or ferr or "")
					)
					status.Text = "Platform limitation · see empty state"
					status.TextColor3 = Color3.fromRGB(200, 180, 80)
				end
				return
			end

			if #list == 0 then
				emptyState("No pending friend requests")
				status.Text = "0 pending requests"
				status.TextColor3 = Color3.fromRGB(160, 160, 160)
				return
			end

			for _, entry in ipairs(list) do
				addRequestRow(entry)
			end
			task.defer(function()
				scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
			end)
			status.Text = #list .. " pending request(s)"
			status.TextColor3 = Color3.fromRGB(100, 180, 255)
		end)
	end

	refreshBtn.MouseButton1Click:Connect(refresh)

	closeBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
		friendsBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		friendsBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
	end)

	friendsBtn.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			friendsBtn.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
			friendsBtn.TextColor3 = Color3.fromRGB(10, 10, 10)
			TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
			}):Play()
			refresh()
		else
			friendsBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
			friendsBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
		end
	end)

	return { panel = panel, button = friendsBtn, refresh = refresh }
end
