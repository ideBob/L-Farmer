--[[
    Evade bootstrap — attach RoundDetector + RoundUI + optional polished button demo.
    Call after LFarmerGui exists.
]]

return function()
	local function loadMod(url)
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if not ok or type(body) ~= "string" then return nil end
		local fn = loadstring(body)
		if not fn then return nil end
		local mok, mod = pcall(fn)
		if mok then return mod end
		return nil
	end

	local Players = game:GetService("Players")
	local StarterGui = game:GetService("StarterGui")
	local player = Players.LocalPlayer
	local gui = player and player.PlayerGui:FindFirstChild("LFarmerGui")
	if not gui then return end

	local RoundDetector = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Evade/RoundDetector.lua")
	local installRoundUI = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Evade/RoundUI.lua")
	local FloatingButton = loadMod("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/UI/FloatingButton.lua")

	if not RoundDetector or not RoundDetector.new then return end

	local detector = RoundDetector.new({ Debug = false })

	-- Print discovery once (useful in-game console)
	task.defer(function()
		local report = detector:Discover()
		print("[L Farmer] RoundDetector discovery")
		print("  State:", report.state, "Active:", report.active)
		print("  Values:", table.concat(report.values, ", "))
		print("  Remotes:", table.concat(report.remotes, ", "))
		print("  Attrs:", table.concat(report.attributes, ", "))
	end)

	if type(installRoundUI) == "function" then
		pcall(installRoundUI, gui, detector, StarterGui)
	end

	-- Polished "Round" floating button: shows state / re-runs discovery
	if FloatingButton and FloatingButton.create then
		local btn = FloatingButton.create({
			Parent = gui,
			Name = "RoundDetectorBtn",
			Text = "Round: ?",
			Icon = "◎",
			Size = UDim2.fromOffset(150, 42),
			Position = UDim2.new(0.05, 0, 0.82, 0),
			Accent = Color3.fromRGB(255, 160, 80),
			OnClick = function()
				local r = detector:Discover()
				pcall(function()
					StarterGui:SetCore("SendNotification", {
						Title = "Round Detector",
						Text = string.format(
							"%s | values:%d remotes:%d",
							r.state,
							#r.values,
							#r.remotes
						),
						Duration = 4,
					})
				end)
			end,
		})
		detector:OnRoundStarted(function()
			btn:SetText("Round: ON")
			btn:SetState(true)
		end)
		detector:OnRoundEnded(function()
			btn:SetText("Round: END")
			btn:SetState(false)
		end)
	end

	return detector
end
