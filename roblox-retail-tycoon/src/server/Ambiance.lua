--[[
	Ambiance
	--------
	World lighting, atmosphere, and post-processing. This is what turns the
	flat-blocks look into something bright and "finished" — the single
	biggest visual upgrade, all from code. Tuned for a clean, colorful,
	friendly grocery-store feel (bright afternoon, punchy colors).

	Everything here is created under the Lighting service and replicates to
	every player automatically.
]]

local Lighting = game:GetService("Lighting")

local Ambiance = {}

local function clearOld()
	-- so re-running in Studio doesn't stack duplicate effects
	for _, name in ipairs({
		"GameSky", "GameAtmosphere", "GameBloom", "GameColorCorrection", "GameSunRays",
	}) do
		local existing = Lighting:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
end

function Ambiance.setup()
	clearOld()

	-- bright mid-afternoon with soft shadows
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 20
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0.1
	Lighting.EnvironmentDiffuseScale = 0.65
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.Ambient = Color3.fromRGB(120, 122, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(158, 166, 182)
	Lighting.ShadowSoftness = 0.55
	Lighting.FogEnd = 100000 -- Atmosphere handles distance haze instead

	-- sky
	local sky = Instance.new("Sky")
	sky.Name = "GameSky"
	sky.SunAngularSize = 21
	sky.Parent = Lighting

	-- gentle distance haze for depth
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "GameAtmosphere"
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(202, 212, 226)
	atmosphere.Decay = Color3.fromRGB(110, 118, 132)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting

	-- soft glow on bright things (neon pads, light fixtures)
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "GameBloom"
	bloom.Intensity = 0.55
	bloom.Size = 24
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	-- make the colors pop (the "clean & colorful" look)
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "GameColorCorrection"
	colorCorrection.Brightness = 0.02
	colorCorrection.Contrast = 0.13
	colorCorrection.Saturation = 0.2
	colorCorrection.TintColor = Color3.fromRGB(255, 251, 244)
	colorCorrection.Parent = Lighting

	-- subtle sun rays
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "GameSunRays"
	sunRays.Intensity = 0.1
	sunRays.Spread = 0.85
	sunRays.Parent = Lighting
end

return Ambiance
