--[[
    SunsetShader — cinematic sunset via Lighting / Atmosphere / post-fx.
    Applies max graphics once on init when possible.
    Smooth tween in/out. No per-frame forcing.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local TWEEN_IN = TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- Snapshot helpers
local function snapshotLighting()
	return {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ColorShift_Top = Lighting.ColorShift_Top,
		ColorShift_Bottom = Lighting.ColorShift_Bottom,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		GlobalShadows = Lighting.GlobalShadows,
		ShadowSoftness = Lighting.ShadowSoftness,
		ExposureCompensation = Lighting.ExposureCompensation,
		FogColor = Lighting.FogColor,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
	}
end

local function applyLightingTable(t, instant)
	if not t then return end
	if instant then
		for k, v in pairs(t) do
			pcall(function() Lighting[k] = v end)
		end
		return
	end
	local goals = {}
	for k, v in pairs(t) do
		if typeof(v) == "number" or typeof(v) == "Color3" or typeof(v) == "boolean" then
			goals[k] = v
		end
	end
	-- booleans can't tween reliably — set after
	local bools = {}
	for k, v in pairs(goals) do
		if type(v) == "boolean" then
			bools[k] = v
			goals[k] = nil
		end
	end
	local tw = TweenService:Create(Lighting, TWEEN_IN, goals)
	tw:Play()
	for k, v in pairs(bools) do
		pcall(function() Lighting[k] = v end)
	end
	return tw
end

local SunsetShader = {}
SunsetShader.__index = SunsetShader

function SunsetShader.new()
	local self = setmetatable({}, SunsetShader)
	self.Enabled = false
	self._saved = nil
	self._effects = {} -- created instances
	self._savedEffects = {} -- prior state of existing effects we reuse
	self._tweens = {}
	self:_tryMaxGraphics()
	return self
end

function SunsetShader:_tryMaxGraphics()
	-- Official client settings surface when available
	pcall(function()
		local UserSettings = UserSettings()
		local gq = UserSettings.GameSettings
		if gq and gq.SavedQualityLevel ~= nil then
			-- Enum.SavedQualitySetting.QualityLevel10 is max on many clients
			local maxEnum = Enum.SavedQualitySetting.QualityLevel10
			gpcall = pcall
			gpcall(function() gq.SavedQualityLevel = maxEnum end)
		end
	end)
	-- Fallback: settings() quality level (executor-dependent)
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level21
	end)
	pcall(function()
		settings().Rendering.QualityLevel = 21
	end)
end

function SunsetShader:_cancelTweens()
	for _, tw in ipairs(self._tweens) do
		pcall(function() tw:Cancel() end)
	end
	self._tweens = {}
end

function SunsetShader:_ensureEffect(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing, false
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst, true
end

function SunsetShader:_captureExistingEffect(inst)
	if not inst then return nil end
	local data = { Name = inst.Name, ClassName = inst.ClassName, Props = {} }
	-- store common props
	for _, prop in ipairs({
		"Enabled", "Intensity", "Size", "Threshold", "Spread",
		"Brightness", "Contrast", "Saturation", "TintColor",
		"Density", "Offset", "Color", "Decay", "Glare", "Haze",
		"Color", "Decay", "Glare", "Haze", "Density",
	}) do
		local ok, val = pcall(function() return inst[prop] end)
		if ok then data.Props[prop] = val end
	end
	return data
end

function SunsetShader:Enable()
	if self.Enabled then return end
	self.Enabled = true
	self:_cancelTweens()

	-- Snapshot current lighting once
	if not self._saved then
		self._saved = snapshotLighting()
	end

	-- Atmosphere
	local atmo, createdAtmo = self:_ensureEffect("Atmosphere", "LFarmerSunsetAtmosphere")
	if createdAtmo then table.insert(self._effects, atmo) end
	if not createdAtmo and not self._savedEffects[atmo] then
		self._savedEffects[atmo] = self:_captureExistingEffect(atmo)
	end
	pcall(function()
		local tw = TweenService:Create(atmo, TWEEN_IN, {
			Density = 0.38,
			Offset = 0.12,
			Color = Color3.fromRGB(255, 140, 70),
			Decay = Color3.fromRGB(255, 90, 50),
			Glare = 0.35,
			Haze = 1.8,
		})
		tw:Play()
		table.insert(self._tweens, tw)
	end)

	-- ColorCorrection — warm cinematic grade
	local cc, createdCC = self:_ensureEffect("ColorCorrectionEffect", "LFarmerSunsetCC")
	if createdCC then table.insert(self._effects, cc) end
	if not createdCC and not self._savedEffects[cc] then
		self._savedEffects[cc] = self:_captureExistingEffect(cc)
	end
	pcall(function()
		cc.Enabled = true
		local tw = TweenService:Create(cc, TWEEN_IN, {
			Brightness = 0.04,
			Contrast = 0.12,
			Saturation = 0.18,
			TintColor = Color3.fromRGB(255, 210, 175),
		})
		tw:Play()
		table.insert(self._tweens, tw)
	end)

	-- Bloom — soft glow on bright areas
	local bloom, createdBloom = self:_ensureEffect("BloomEffect", "LFarmerSunsetBloom")
	if createdBloom then table.insert(self._effects, bloom) end
	if not createdBloom and not self._savedEffects[bloom] then
		self._savedEffects[bloom] = self:_captureExistingEffect(bloom)
	end
	pcall(function()
		bloom.Enabled = true
		local tw = TweenService:Create(bloom, TWEEN_IN, {
			Intensity = 0.55,
			Size = 28,
			Threshold = 0.92,
		})
		tw:Play()
		table.insert(self._tweens, tw)
	end)

	-- Optional subtle sun rays if supported
	pcall(function()
		local rays, created = self:_ensureEffect("SunRaysEffect", "LFarmerSunsetRays")
		if created then table.insert(self._effects, rays) end
		rays.Enabled = true
		local tw = TweenService:Create(rays, TWEEN_IN, {
			Intensity = 0.08,
			Spread = 0.65,
		})
		tw:Play()
		table.insert(self._tweens, tw)
	end)

	-- Lighting properties — golden hour
	local goals = {
		ClockTime = 17.85,
		Brightness = 1.65,
		Ambient = Color3.fromRGB(95, 55, 40),
		OutdoorAmbient = Color3.fromRGB(160, 95, 60),
		ColorShift_Top = Color3.fromRGB(255, 160, 90),
		ColorShift_Bottom = Color3.fromRGB(255, 100, 70),
		EnvironmentDiffuseScale = 0.85,
		EnvironmentSpecularScale = 0.55,
		ShadowSoftness = 0.35,
		ExposureCompensation = 0.15,
		FogColor = Color3.fromRGB(255, 130, 80),
		FogStart = 80,
		FogEnd = 1200,
	}
	local tw = TweenService:Create(Lighting, TWEEN_IN, goals)
	tw:Play()
	table.insert(self._tweens, tw)
	pcall(function() Lighting.GlobalShadows = true end)
end

function SunsetShader:Disable()
	if not self.Enabled then return end
	self.Enabled = false
	self:_cancelTweens()

	-- Restore lighting snapshot
	if self._saved then
		local goals = {}
		for k, v in pairs(self._saved) do
			if type(v) ~= "boolean" then goals[k] = v end
		end
		local tw = TweenService:Create(Lighting, TWEEN_OUT, goals)
		tw:Play()
		table.insert(self._tweens, tw)
		for k, v in pairs(self._saved) do
			if type(v) == "boolean" then
				pcall(function() Lighting[k] = v end)
			end
		end
	end

	-- Restore or remove effects we created / modified
	for inst, data in pairs(self._savedEffects) do
		if inst and inst.Parent and data and data.Props then
			local goals = {}
			for prop, val in pairs(data.Props) do
				if type(val) ~= "boolean" then goals[prop] = val end
			end
			pcall(function()
				local tw = TweenService:Create(inst, TWEEN_OUT, goals)
				tw:Play()
				table.insert(self._tweens, tw)
			end)
			for prop, val in pairs(data.Props) do
				if type(val) == "boolean" then
					pcall(function() inst[prop] = val end)
				end
			end
		end
	end

	-- Destroy effects we created after short delay (let tween finish)
	local toDestroy = {}
	for _, inst in ipairs(self._effects) do
		table.insert(toDestroy, inst)
	end
	self._effects = {}
	task.delay(1.7, function()
		for _, inst in ipairs(toDestroy) do
			pcall(function()
				if inst and inst.Parent then inst:Destroy() end
			end)
		end
	end)
end

function SunsetShader:Toggle()
	if self.Enabled then
		self:Disable()
	else
		self:Enable()
	end
	return self.Enabled
end

function SunsetShader:Destroy()
	if self.Enabled then
		-- instant restore
		self:_cancelTweens()
		if self._saved then applyLightingTable(self._saved, true) end
		for _, inst in ipairs(self._effects) do
			pcall(function() inst:Destroy() end)
		end
		self._effects = {}
		self.Enabled = false
	end
end

return SunsetShader
