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

	-- soft mid-afternoon with gentle shadows (dialed back so nothing blows out)
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 20
	Lighting.Brightness = 1.4
	Lighting.ExposureCompensation = -0.05
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.45
	Lighting.Ambient = Color3.fromRGB(92, 94, 104)
	Lighting.OutdoorAmbient = Color3.fromRGB(136, 144, 158)
	Lighting.ShadowSoftness = 0.6
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

	-- glow ONLY on genuinely bright things (high threshold = no white-out)
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "GameBloom"
	bloom.Intensity = 0.2
	bloom.Size = 18
	bloom.Threshold = 2.0
	bloom.Parent = Lighting

	-- gently richen the colors (subtle, not garish)
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "GameColorCorrection"
	colorCorrection.Brightness = 0
	colorCorrection.Contrast = 0.06
	colorCorrection.Saturation = 0.1
	colorCorrection.TintColor = Color3.fromRGB(255, 252, 247)
	colorCorrection.Parent = Lighting

	-- barely-there sun rays
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "GameSunRays"
	sunRays.Intensity = 0.06
	sunRays.Spread = 0.9
	sunRays.Parent = Lighting
end

return Ambiance
