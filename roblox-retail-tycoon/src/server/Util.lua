--[[
	Util
	----
	Shared helpers: part building, signs/billboards, NPC characters
	(real R15 rigs with walk animations), NPC walking, and player toasts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = {}

-- ============================ Parts & signs ============================

-- Create an anchored, smooth Part from a property table.
function Util.part(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		if key ~= "Parent" then
			part[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end

-- Floating text above a part. Returns the TextLabel so callers can update it.
function Util.billboard(adornee, text, options)
	options = options or {}
	local gui = Instance.new("BillboardGui")
	gui.Name = "InfoBillboard"
	gui.Adornee = adornee
	gui.Size = options.size or UDim2.fromOffset(180, 60)
	gui.StudsOffset = Vector3.new(0, options.offsetY or 3, 0)
	gui.AlwaysOnTop = options.alwaysOnTop ~= false
	gui.MaxDistance = options.maxDistance or 90

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = options.backgroundTransparency or 0.35
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	label.TextColor3 = options.textColor or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	gui.Parent = adornee
	return label
end

-- Big flat text on a part face (used for storefront signs).
function Util.surfaceSign(part, face, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.Parent = gui

	gui.Parent = part
	return label
end

-- ================================ NPCs =================================

local SKIN_TONES = {
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(160, 105, 70),
	Color3.fromRGB(110, 74, 52),
	Color3.fromRGB(245, 205, 175),
}

local WALK_ANIMATION = "rbxassetid://507777826" -- Roblox default R15 walk

-- Fallback blocky rig, used if R15 creation fails (e.g. no asset access).
local function createBlockRig(displayName, shirtColor)
	local model = Instance.new("Model")
	model.Name = displayName

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model

	local function bodyPart(name, size, offset, color)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.CanCollide = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = root.CFrame * CFrame.new(offset)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end

	bodyPart("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), shirtColor)
	bodyPart("Legs", Vector3.new(1.8, 2, 0.9), Vector3.new(0, -2, 0), Color3.fromRGB(60, 60, 80))
	local head = bodyPart("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 1.7, 0), SKIN_TONES[1])
	head.Shape = Enum.PartType.Ball

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.HipHeight = 2
	humanoid.Parent = model

	model.PrimaryPart = root
	return model, humanoid, root
end

-- Real R15 character with randomized skin tone / build and colored
-- "clothes" (body part colors). Falls back to the block rig on failure.
function Util.createNPC(displayName, shirtColor, pantsColor)
	pantsColor = pantsColor or Color3.fromRGB(52, 60, 88)

	local model, humanoid, root
	local ok = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin = SKIN_TONES[math.random(#SKIN_TONES)]
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = shirtColor
		description.LeftLegColor = pantsColor
		description.RightLegColor = pantsColor
		description.HeightScale = 0.95 + math.random() * 0.12
		description.BodyTypeScale = math.random() * 0.25
		description.WidthScale = 0.95 + math.random() * 0.12

		model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		model.Name = displayName
		humanoid = model:FindFirstChildOfClass("Humanoid")
		root = model:FindFirstChild("HumanoidRootPart")
		assert(humanoid and root, "incomplete rig")
	end)

	if not ok or not humanoid then
		if model then
			model:Destroy()
		end
		model, humanoid, root = createBlockRig(displayName, shirtColor)
	else
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

		-- walk animation, driven by actual movement speed
		pcall(function()
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = humanoid
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = WALK_ANIMATION
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Movement
			humanoid.Running:Connect(function(speed)
				if speed > 0.5 then
					if not track.IsPlaying then
						track:Play(0.15)
					end
					track:AdjustSpeed(speed / 14)
				elseif track.IsPlaying then
					track:Stop(0.2)
				end
			end)
		end)
	end

	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	local head = model:FindFirstChild("Head") or root
	Util.billboard(head, displayName, {
		size = UDim2.fromOffset(140, 30),
		offsetY = 1.6,
		backgroundTransparency = 0.6,
		maxDistance = 60,
	})

	return model, humanoid, root
end

-- Walk an NPC to a world position. Blocks until it arrives (or gives up).
-- Returns true if the NPC reached the target and still exists.
function Util.walkTo(model, position, timeout)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return false
	end
	timeout = timeout or 12

	-- MoveTo silently gives up after 8 seconds, so retry for long walks
	for _ = 1, 3 do
		if not model.Parent then
			return false
		end
		local finished = false
		local reached = false
		local connection = humanoid.MoveToFinished:Connect(function(ok)
			reached = ok
			finished = true
		end)
		humanoid:MoveTo(position)
		local started = os.clock()
		while not finished and os.clock() - started < timeout do
			if not model.Parent then
				connection:Disconnect()
				return false
			end
			task.wait(0.1)
		end
		connection:Disconnect()
		if reached then
			return true
		end
		local flat = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
		if flat.Magnitude < 5 then
			return true -- close enough
		end
	end
	return model.Parent ~= nil
end

-- Walk through several points in order.
function Util.walkPath(model, points)
	for _, point in ipairs(points) do
		if not Util.walkTo(model, point) then
			return false
		end
	end
	return true
end

-- Toast notification on the player's screen (handled by the client script).
function Util.notify(player, text, kind)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local notify = remotes and remotes:FindFirstChild("Notify")
	if notify and player and player.Parent then
		notify:FireClient(player, text, kind or "info")
	end
end

return Util
