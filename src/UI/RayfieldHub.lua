--[[
    L Farmer — Rayfield Gen2 Hub (pure black theme)
    loadstring-friendly module: returns bootstrap function.
]]

return function()
	local VERSION = "2.0.0"

	local okRF, Rayfield = pcall(function()
		return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
	end)
	if not okRF or not Rayfield then
		warn("[L Farmer] Rayfield Gen2 failed to load")
		return nil
	end

	-- Pure black custom theme
	local BlackTheme = {
		TextColor = Color3.fromRGB(235, 235, 240),
		Background = Color3.fromRGB(8, 8, 10),
		Topbar = Color3.fromRGB(12, 12, 14),
		Shadow = Color3.fromRGB(0, 0, 0),
		NotificationBackground = Color3.fromRGB(14, 14, 16),
		TabBackground = Color3.fromRGB(18, 18, 22),
		TabStroke = Color3.fromRGB(40, 40, 48),
		TabBackgroundSelected = Color3.fromRGB(32, 32, 38),
		TabTextColor = Color3.fromRGB(180, 180, 190),
		SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
		ElementBackground = Color3.fromRGB(16, 16, 20),
		ElementBackgroundHover = Color3.fromRGB(24, 24, 28),
		ElementStroke = Color3.fromRGB(36, 36, 42),
	}

	local window = Rayfield:CreateWindow({
		name = "L Farmer",
		subtitle = "v" .. VERSION .. " · Gen2",
		theme = BlackTheme,
		configuration = {
			autoSave = true,
			autoLoad = true,
			fileName = "LFarmer_Gen2",
		},
	})

	local function notify(title, content)
		pcall(function()
			window:Notify({ title = title, content = content })
		end)
	end

	-- ---------- load feature modules ----------
	local function loadMod(url)
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if not ok or type(body) ~= "string" then return nil end
		local fn = loadstring(body)
		if not fn then return nil end
		local mok, mod = pcall(fn)
		if mok then return mod end
		return nil
	end

	local BASE = "https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/"

	-- ---------- MAIN tab ----------
	local mainTab = window:CreateTab({ name = "Main" })
	mainTab:CreateSection({ name = "AFK / Farmer" })

	-- Core AFK state (lightweight bridge into existing systems via getgenv)
	local g = getgenv and getgenv() or _G
	g.LFarmer = g.LFarmer or {}
	local LF = g.LFarmer

	mainTab:CreateToggle({
		name = "L Farmer (AFK Lock)",
		description = "Teleport + lock on sky platform",
		flag = "LF_Enabled",
		callback = function(v)
			LF.Enabled = v
			-- fire existing floating button if present
			pcall(function()
				local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("LFarmerGui")
				if not gui then return end
				local btn = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Button")
				if btn and btn:IsA("TextButton") then
					-- simulate click only if state differs
					local isOn = btn.Text:find("ON")
					if (v and not isOn) or ((not v) and isOn) then
						btn:Activate()
					end
				end
			end)
			notify("L Farmer", v and "AFK lock ON" or "AFK lock OFF")
		end,
	})

	mainTab:CreateToggle({
		name = "Ticket ESP",
		flag = "LF_TicketESP",
		callback = function(v)
			LF.TicketESP = v
			pcall(function()
				local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("LFarmerGui")
				local btn = gui and gui:FindFirstChild("EspFrame") and gui.EspFrame:FindFirstChild("Button")
				if btn then
					local isOn = btn.Text:find("ON")
					if (v and not isOn) or ((not v) and isOn) then btn:Activate() end
				end
			end)
		end,
	})

	mainTab:CreateToggle({
		name = "Player ESP",
		flag = "LF_PlayerESP",
		callback = function(v)
			LF.PlayerESP = v
			pcall(function()
				local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("LFarmerGui")
				local btn = gui and gui:FindFirstChild("PlrEspFrame") and gui.PlrEspFrame:FindFirstChild("Button")
				if btn then
					local isOn = btn.Text:find("ON")
					if (v and not isOn) or ((not v) and isOn) then btn:Activate() end
				end
			end)
		end,
	})

	mainTab:CreateSection({ name = "Spectate" })
	mainTab:CreateButton({
		name = "Turn Off Spectate",
		callback = function()
			pcall(function()
				local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("LFarmerGui")
				local btn = gui and gui:FindFirstChild("TurnOffSpectateFrame") and gui.TurnOffSpectateFrame:FindFirstChild("Button")
				if btn then btn:Activate() end
			end)
			notify("Spectate", "Stopped")
		end,
	})

	-- ---------- ROUND TIMER tab ----------
	local rtTab = window:CreateTab({ name = "Round Timer" })
	rtTab:CreateSection({ name = "Overhead Timer" })

	local OverheadTimer = loadMod(BASE .. "RoundTimer/OverheadTimer.lua")
	local timerInst = OverheadTimer and OverheadTimer.new and OverheadTimer.new({ enabled = false }) or nil

	rtTab:CreateToggle({
		name = "Enable Overhead Timer",
		flag = "RT_Enabled",
		callback = function(v)
			if not timerInst then return end
			if v then timerInst:Enable() else timerInst:Disable() end
		end,
	})
	rtTab:CreateToggle({
		name = "Show ROUND Label",
		flag = "RT_ShowLabel",
		value = true,
		callback = function(v)
			if timerInst then timerInst:SetShowRoundLabel(v) end
		end,
	})
	rtTab:CreateToggle({
		name = "Always On Top",
		flag = "RT_AlwaysOnTop",
		value = true,
		callback = function(v)
			if timerInst then timerInst:SetAlwaysOnTop(v) end
		end,
	})
	rtTab:CreateSlider({
		name = "Timer Distance",
		range = { 25, 250 },
		increment = 1,
		value = 90,
		flag = "RT_Distance",
		callback = function(v)
			if timerInst then timerInst:SetMaxDistance(v) end
		end,
	})
	rtTab:CreateSlider({
		name = "Timer Size",
		range = { 150, 350 },
		increment = 1,
		value = 220,
		flag = "RT_Size",
		callback = function(v)
			if timerInst then timerInst:SetSize(v) end
		end,
	})
	rtTab:CreateSlider({
		name = "Vertical Offset",
		range = { 1, 6 },
		increment = 0.1,
		value = 2.9,
		flag = "RT_Offset",
		callback = function(v)
			if timerInst then timerInst:SetStudsOffsetY(v) end
		end,
	})

	-- ---------- SUNSET tab ----------
	local sunTab = window:CreateTab({ name = "Sunset" })
	sunTab:CreateSection({ name = "Cinematic Shader" })

	local SunsetShader = loadMod(BASE .. "Sunset/SunsetShader.lua")
	local shader = SunsetShader and SunsetShader.new and SunsetShader.new() or nil

	sunTab:CreateToggle({
		name = "Enable Sunset Shader",
		description = "Warm golden-hour lighting + bloom",
		flag = "SS_Enabled",
		callback = function(v)
			if not shader then return end
			if v then shader:Enable() else shader:Disable() end
			notify("Sunset", v and "Enabled" or "Disabled")
		end,
	})

	-- ---------- FRIENDS tab ----------
	local frTab = window:CreateTab({ name = "Friends" })
	frTab:CreateSection({ name = "Friend Requests" })
	frTab:CreateParagraph({
		name = "Note",
		content = "Pending accept/decline depends on authenticated friends API access. Official experiences cannot list requests. Use the floating Friends panel for the full UI when available.",
	})
	frTab:CreateButton({
		name = "Open Friends Panel",
		callback = function()
			pcall(function()
				local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("LFarmerGui")
				local btn = gui and gui:FindFirstChild("FriendsBtnFrame") and gui.FriendsBtnFrame:FindFirstChild("TextButton")
				if not btn then
					for _, d in ipairs(gui and gui:GetDescendants() or {}) do
						if d:IsA("TextButton") and d.Text == "Friends" then btn = d break end
					end
				end
				if btn then btn:Activate() end
			end)
		end,
	})

	-- ---------- MEDIA tab ----------
	local mediaTab = window:CreateTab({ name = "Media" })
	mediaTab:CreateSection({ name = "Spotify / YouTube" })
	mediaTab:CreateParagraph({
		name = "Info",
		content = "Spotify and YouTube panels remain available via their floating buttons when core UI is loaded. Use those for API keys and media cards.",
	})
	mediaTab:CreateButton({
		name = "Open Spotify",
		callback = function()
			pcall(function()
				local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("LFarmerGui")
				for _, d in ipairs(gui and gui:GetDescendants() or {}) do
					if d:IsA("TextButton") and d.Text == "Spotify" then d:Activate() break end
				end
			end)
		end,
	})
	mediaTab:CreateButton({
		name = "Open YouTube",
		callback = function()
			pcall(function()
				local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("LFarmerGui")
				for _, d in ipairs(gui and gui:GetDescendants() or {}) do
					if d:IsA("TextButton") and d.Text == "YouTube" then d:Activate() break end
				end
			end)
		end,
	})

	-- ---------- SETTINGS tab ----------
	local setTab = window:CreateTab({ name = "Settings" })
	setTab:CreateSection({ name = "Interface" })
	setTab:CreateButton({
		name = "Re-apply Black Theme",
		callback = function()
			pcall(function() window:ChangeTheme(BlackTheme) end)
			notify("Theme", "Black theme applied")
		end,
	})
	setTab:CreateParagraph({
		name = "About",
		content = "L Farmer v" .. VERSION .. " · Rayfield Gen2 · Black theme\nCore floating UI still runs underneath for full feature parity.",
	})

	notify("L Farmer", "Rayfield Gen2 ready · v" .. VERSION)
	return window
end
