--[[
    Polished floating button factory.
    create(opts) -> { Frame, Button, SetState, Destroy }
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TWEEN_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function clampToScreen(frame)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vs = cam.ViewportSize
	local abs = frame.AbsoluteSize
	local pos = frame.AbsolutePosition
	local x = math.clamp(pos.X, 0, math.max(0, vs.X - abs.X))
	local y = math.clamp(pos.Y, 0, math.max(0, vs.Y - abs.Y))
	frame.Position = UDim2.fromOffset(x, y)
end

local function create(opts)
	opts = opts or {}
	local parent = opts.Parent
	local name = opts.Name or "FloatingButton"
	local text = opts.Text or "Button"
	local size = opts.Size or UDim2.fromOffset(150, 42)
	local position = opts.Position or UDim2.new(0.05, 0, 0.2, 0)
	local accent = opts.Accent or Color3.fromRGB(100, 180, 255)
	local icon = opts.Icon -- optional emoji/string prefix

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(55, 55, 62)
	stroke.Thickness = 1.25
	stroke.Transparency = 0.25
	stroke.Parent = frame

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 34, 38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 16)),
	})
	grad.Rotation = 90
	grad.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = frame

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
	button.BackgroundTransparency = 0.15
	button.Text = (icon and (icon .. "  ") or "") .. text
	button.TextColor3 = Color3.fromRGB(230, 230, 235)
	button.Font = Enum.Font.GothamBold
	button.TextSize = opts.TextSize or 14
	button.AutoButtonColor = false
	button.Parent = frame

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 9)
	bCorner.Parent = button

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = frame

	-- Drag vs click
	local dragging = false
	local dragStart, startPos
	local moved = false
	local DRAG_THRESHOLD = 6

	local function onInputBegan(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		moved = false
		dragStart = input.Position
		startPos = frame.Position
		TweenService:Create(scale, TWEEN_PRESS, { Scale = 0.96 }):Play()
		TweenService:Create(button, TWEEN_PRESS, { BackgroundTransparency = 0.05 }):Play()

		local ended
		ended = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				TweenService:Create(scale, TWEEN_FAST, { Scale = 1 }):Play()
				TweenService:Create(button, TWEEN_FAST, { BackgroundTransparency = 0.15 }):Play()
				if ended then ended:Disconnect() end
			end
		end)
	end

	button.InputBegan:Connect(onInputBegan)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		if delta.Magnitude > DRAG_THRESHOLD then
			moved = true
		end
		if moved then
			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
			clampToScreen(frame)
		end
	end)

	-- Hover (desktop)
	button.MouseEnter:Connect(function()
		if dragging then return end
		TweenService:Create(stroke, TWEEN_FAST, { Color = accent, Transparency = 0.05 }):Play()
		TweenService:Create(button, TWEEN_FAST, { BackgroundColor3 = Color3.fromRGB(40, 40, 46) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(stroke, TWEEN_FAST, { Color = Color3.fromRGB(55, 55, 62), Transparency = 0.25 }):Play()
		TweenService:Create(button, TWEEN_FAST, { BackgroundColor3 = Color3.fromRGB(32, 32, 36) }):Play()
	end)

	local clickConn
	local onClick = opts.OnClick
	clickConn = button.MouseButton1Click:Connect(function()
		if moved then return end -- was a drag
		if onClick then task.spawn(onClick) end
	end)

	local api = {}
	api.Frame = frame
	api.Button = button

	function api:SetText(t)
		button.Text = (icon and (icon .. "  ") or "") .. tostring(t)
	end

	function api:SetState(active)
		if active then
			TweenService:Create(button, TWEEN_FAST, {
				BackgroundColor3 = accent,
				TextColor3 = Color3.fromRGB(12, 12, 14),
			}):Play()
			TweenService:Create(stroke, TWEEN_FAST, { Color = accent, Transparency = 0 }):Play()
		else
			TweenService:Create(button, TWEEN_FAST, {
				BackgroundColor3 = Color3.fromRGB(32, 32, 36),
				TextColor3 = Color3.fromRGB(230, 230, 235),
			}):Play()
			TweenService:Create(stroke, TWEEN_FAST, { Color = Color3.fromRGB(55, 55, 62), Transparency = 0.25 }):Play()
		end
	end

	function api:SetOnClick(fn)
		onClick = fn
	end

	function api:Destroy()
		if clickConn then clickConn:Disconnect() end
		frame:Destroy()
	end

	return api
end

return { create = create }
